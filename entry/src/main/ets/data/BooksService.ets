import { httpClient, HttpResponse } from '../net/HttpClient';
import { appPreferences } from './AppPreferences';

interface ShelfBookWire { slug?: string; title?: string; main?: string; sub?: string; c?: string; c2?: string; cover?: boolean; chapters?: number; }
interface ShelfIndexWire { books?: ShelfBookWire[]; }

export class ShelfBook {
  slug: string; title: string; main: string; sub: string; c: string; c2: string; cover: boolean; chapters: number;
  constructor(wire: ShelfBookWire = {}) {
    this.slug = wire.slug ?? ''; this.title = wire.title ?? ''; this.main = wire.main ?? wire.title ?? '未命名';
    this.sub = wire.sub ?? ''; this.c = wire.c ?? '#8B6652'; this.c2 = wire.c2 ?? '#4B342C';
    this.cover = wire.cover === true; this.chapters = Math.max(0, wire.chapters ?? 0);
  }
  readerUrl(): string { return `https://voicedrop.cn/books/${encodeURIComponent(this.slug)}/`; }
  coverUrl(): string { return `https://voicedrop.cn/books/${encodeURIComponent(this.slug)}/cover.jpg`; }
}

export class BooksService {
  static readonly INDEX: string = 'https://voicedrop.cn/books/?format=json';
  cached(): ShelfBook[] { return this.parse(appPreferences.bookShelfCache()); }
  async load(): Promise<ShelfBook[]> {
    const response: HttpResponse = await httpClient.get(BooksService.INDEX);
    if (!response.ok()) throw new Error(`书架加载失败 HTTP ${response.code}`);
    const books: ShelfBook[] = this.parse(response.text);
    await appPreferences.saveBookShelfCache(response.text);
    return books;
  }
  parse(raw: string): ShelfBook[] {
    try {
      const wire: ShelfIndexWire = JSON.parse(raw || '{}') as ShelfIndexWire;
      return (wire.books ?? []).map((item: ShelfBookWire) => new ShelfBook(item)).filter((item: ShelfBook) => item.slug.length > 0);
    } catch (_) { return []; }
  }
}
export const booksService: BooksService = new BooksService();
