import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { BookCoverPolicy } from '../core/BookCoverPolicy';
import { ShelfBook } from './BooksService';

export class BookCoverDecoder {
  static async isDecodable(data: ArrayBuffer): Promise<boolean> {
    if (!BookCoverPolicy.hasJpegSignature(data)) return false;
    let source: image.ImageSource | undefined;
    let pixelMap: image.PixelMap | undefined;
    try {
      source = image.createImageSource(data);
      pixelMap = await source.createPixelMap({
        desiredSize: { width: 1, height: 1 },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const info: image.ImageInfo = await pixelMap.getImageInfo();
      return info.size.width > 0 && info.size.height > 0;
    } catch (_) {
      return false;
    } finally {
      if (pixelMap) try { await pixelMap.release(); } catch (_) {}
      if (source) try { await source.release(); } catch (_) {}
    }
  }
}

export class BookCoverRequest {
  private static nextId: number = 0;
  private url: string;
  private path: string;
  private id: number;
  private cancelled: boolean = false;
  private request?: http.HttpRequest;
  private timer: number = -1;
  private wake?: () => void;

  constructor(url: string, path: string) {
    this.url = url;
    this.path = path;
    this.id = ++BookCoverRequest.nextId;
  }

  cancel(): void {
    this.cancelled = true;
    if (this.timer >= 0) clearTimeout(this.timer);
    this.timer = -1;
    this.wake?.();
    this.wake = undefined;
    try { this.request?.destroy(); } catch (_) {}
    this.request = undefined;
  }

  async load(): Promise<string> {
    const delays: number[] = BookCoverPolicy.retryDelays();
    for (let attempt: number = 0; attempt < delays.length; attempt++) {
      if (this.cancelled) return '';
      if (delays[attempt] > 0) await this.wait(delays[attempt]);
      if (this.cancelled) return '';
      try {
        const data: ArrayBuffer = await this.download(BookCoverPolicy.shouldBypassNetworkCache(attempt));
        if (!this.cancelled && await BookCoverDecoder.isDecodable(data) &&
          !this.cancelled && this.persist(data, attempt)) return `file://${this.path}`;
      } catch (_) {
        if (this.cancelled) return '';
      }
    }
    return '';
  }

  private wait(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      this.wake = resolve;
      this.timer = setTimeout(() => {
        this.timer = -1;
        this.wake = undefined;
        resolve();
      }, milliseconds);
    });
  }

  private async download(bypassCache: boolean): Promise<ArrayBuffer> {
    const active: http.HttpRequest = http.createHttp();
    this.request = active;
    const headers: Record<string, string> = {
      'Accept': 'image/jpeg,image/*',
      'X-VD-Platform': 'harmonyos'
    };
    if (bypassCache) {
      headers['Cache-Control'] = 'no-cache';
      headers['Pragma'] = 'no-cache';
    }
    try {
      const response: http.HttpResponse = await active.request(this.url, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) return new ArrayBuffer(0);
      return response.result as ArrayBuffer;
    } finally {
      try { active.destroy(); } catch (_) {}
      if (this.request === active) this.request = undefined;
    }
  }

  private persist(data: ArrayBuffer, attempt: number): boolean {
    const temporary: string = `${this.path}.tmp.${this.id}.${attempt}`;
    let output: fs.File | undefined;
    try {
      output = fs.openSync(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(output.fd, data);
      fs.closeSync(output);
      output = undefined;
      if (this.cancelled) {
        fs.unlinkSync(temporary);
        return false;
      }
      try { fs.unlinkSync(this.path); } catch (_) {}
      fs.renameSync(temporary, this.path);
      return true;
    } catch (_) {
      try { fs.unlinkSync(temporary); } catch (_) {}
      return false;
    } finally {
      if (output) try { fs.closeSync(output); } catch (_) {}
    }
  }
}

export class BookCoverStore {
  static readonly DIRECTORY_NAME: string = 'book-cover-cache-v1';
  private root: string = '';
  private activeRequests: Set<BookCoverRequest> = new Set<BookCoverRequest>();

  initialize(context: common.Context): void {
    this.root = `${context.cacheDir}/${BookCoverStore.DIRECTORY_NAME}`;
    try { fs.mkdirSync(this.root); } catch (_) {}
  }

  async cachedSource(book: ShelfBook): Promise<string> {
    const path: string = this.path(book);
    if (path.length === 0) return '';
    let file: fs.File | undefined;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(file.fd).size;
      if (size <= 0) throw new Error('empty book cover cache');
      const data: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, data);
      fs.closeSync(file);
      file = undefined;
      if (await BookCoverDecoder.isDecodable(data)) return `file://${path}`;
    } catch (_) {
    } finally {
      if (file) try { fs.closeSync(file); } catch (_) {}
    }
    try { fs.unlinkSync(path); } catch (_) {}
    return '';
  }

  invalidate(book: ShelfBook): void {
    const path: string = this.path(book);
    if (path.length > 0) try { fs.unlinkSync(path); } catch (_) {}
  }

  request(book: ShelfBook): BookCoverRequest | undefined {
    const path: string = this.path(book);
    if (!book.cover || path.length === 0) return undefined;
    const request: BookCoverRequest = new BookCoverRequest(book.coverUrl(), path);
    this.activeRequests.add(request);
    return request;
  }

  release(request: BookCoverRequest): void {
    this.activeRequests.delete(request);
  }

  clear(): void {
    if (this.root.length === 0) return;
    this.activeRequests.forEach((request: BookCoverRequest) => request.cancel());
    this.activeRequests.clear();
    try {
      for (const name of fs.listFileSync(this.root)) {
        try { fs.unlinkSync(`${this.root}/${name}`); } catch (_) {}
      }
    } catch (_) {}
  }

  private path(book: ShelfBook): string {
    if (!book.cover || book.slug.length === 0 || this.root.length === 0) return '';
    return `${this.root}/${BookCoverPolicy.cacheKey(book.slug, book.coverAt)}`;
  }
}

export const bookCoverStore: BookCoverStore = new BookCoverStore();
