import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Api } from '../core/Api';
import { RecordingName } from '../core/RecordingName';
import { authStore } from './AuthStore';
import { httpClient } from '../net/HttpClient';
import { appPreferences } from './AppPreferences';
import { common } from '@kit.AbilityKit';
import { ArticleBody } from '../core/ArticleBody';
import { ClientReliability } from '../core/ClientReliability';
import { PhotoJpeg } from '../core/PhotoJpeg';
import { ArticleDoc } from '../model/Models';

export interface UploadedPhoto {
  key: string;
  sourceUri: string;
}

export class CapturedPhoto {
  key: string;
  localPath: string;
  sourceUri: string;
  constructor(key: string, localPath: string, sourceUri: string) {
    this.key = key; this.localPath = localPath; this.sourceUri = sourceUri;
  }
}

interface PendingPhotoValue { key: string; localPath: string; sourceUri?: string; }

export class PhotoService {
  private context?: common.Context;
  private articleCacheRoot: string = '';
  private articlePhotoTasks: Map<string, Promise<string>> = new Map<string, Promise<string>>();
  private articlePhotoGenerations: Map<string, number> = new Map<string, number>();
  private articlePhotoEpoch: number = 0;

  initialize(context: common.Context): void {
    this.context = context;
    this.articleCacheRoot = `${context.cacheDir}/photo-cache`;
    try { fs.mkdirSync(this.articleCacheRoot); } catch (_) {}
    this.trimArticlePhotoCache();
  }

  articlePhotoKeys(doc?: ArticleDoc): string[] {
    if (!doc) return [];
    const owner: string = (doc.owner ?? '').replace(/\/+$/, '');
    const keys: Set<string> = new Set<string>();
    for (const article of doc.articles ?? []) {
      for (const block of ArticleBody.blocks(article.body)) {
        if (block.kind !== 'photo') continue;
        const key: string | undefined = ArticleBody.resolvePhotoKey(block.value, doc.photos);
        if (!key) continue;
        keys.add(owner.length > 0 && !key.startsWith('users/') ? `${owner}/${key}` : key);
      }
    }
    const values: string[] = [];
    keys.forEach((key: string) => values.push(key));
    return values;
  }

  articlePhotoSource(fullKey: string): string {
    const path: string = this.articlePhotoPath(fullKey);
    if (path.length > 0) {
      try {
        const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
        const valid: boolean = fs.statSync(file.fd).size > 0;
        fs.closeSync(file);
        if (valid) return `file://${path}`;
      } catch (_) {}
    }
    return ArticleBody.photoUrl(fullKey);
  }

  reconcileArticlePhotos(previous?: ArticleDoc, next?: ArticleDoc, refreshKeys: string[] = []): void {
    const invalid: string[] = ClientReliability.photoCacheInvalidations(
      this.articlePhotoKeys(previous), this.articlePhotoKeys(next), refreshKeys);
    for (const key of invalid) this.invalidateArticlePhoto(key);
  }

  async cacheArticlePhotos(doc?: ArticleDoc, refreshKeys: string[] = []): Promise<void> {
    const forced: Set<string> = new Set<string>(refreshKeys);
    const tasks: Promise<string>[] = this.articlePhotoKeys(doc)
      .map((key: string) => this.cacheArticlePhoto(key, forced.has(key)));
    await Promise.all(tasks);
  }

  async cacheArticlePhoto(fullKey: string, force: boolean = false): Promise<string> {
    if (force) this.invalidateArticlePhoto(fullKey);
    const existing: string = this.articlePhotoSource(fullKey);
    if (!force && existing.startsWith('file://')) return existing;
    if (this.articleCacheRoot.length === 0) return existing;
    const active: Promise<string> | undefined = this.articlePhotoTasks.get(fullKey);
    if (active) return active;
    const generation: number = this.articlePhotoGenerations.get(fullKey) ?? 0;
    const epoch: number = this.articlePhotoEpoch;
    const task: Promise<string> = this.downloadArticlePhoto(fullKey, existing, generation, epoch, force);
    this.articlePhotoTasks.set(fullKey, task);
    try { return await task; }
    finally { if (this.articlePhotoTasks.get(fullKey) === task) this.articlePhotoTasks.delete(fullKey); }
  }

  async fetchArticlePhoto(fullKey: string, ignoringLocalCache: boolean = false): Promise<string> {
    if (fullKey.length === 0) return '';
    const source: string = await this.cacheArticlePhoto(fullKey, ignoringLocalCache);
    return source.startsWith('file://') ? source : '';
  }

  private async downloadArticlePhoto(fullKey: string, existing: string, generation: number, epoch: number,
    ignoringLocalCache: boolean = false): Promise<string> {
    let url: string = ArticleBody.photoUrl(fullKey);
    if (ignoringLocalCache) url = `${url}${url.includes('?') ? '&' : '?'}v=${Date.now()}`;
    const response = await httpClient.getBytes(url, '');
    if (!response.ok() || response.data.byteLength === 0) return existing;
    const path: string = this.articlePhotoPath(fullKey);
    const temporary: string = `${path}.tmp.${epoch}.${generation}`;
    let output: fs.File | undefined;
    try {
      output = fs.openSync(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(output.fd, response.data);
      fs.closeSync(output); output = undefined;
      if (this.articlePhotoEpoch !== epoch || (this.articlePhotoGenerations.get(fullKey) ?? 0) !== generation) {
        fs.unlinkSync(temporary);
        return this.articlePhotoSource(fullKey);
      }
      try { fs.unlinkSync(path); } catch (_) {}
      fs.renameSync(temporary, path);
      return `file://${path}`;
    } catch (_) {
      try { fs.unlinkSync(temporary); } catch (_) {}
      return existing;
    } finally { if (output) try { fs.closeSync(output); } catch (_) {} }
  }

  invalidateArticlePhoto(fullKey: string): void {
    this.articlePhotoGenerations.set(fullKey, (this.articlePhotoGenerations.get(fullKey) ?? 0) + 1);
    this.articlePhotoTasks.delete(fullKey);
    const path: string = this.articlePhotoPath(fullKey);
    if (path.length > 0) try { fs.unlinkSync(path); } catch (_) {}
  }

  removeArticlePhotos(doc?: ArticleDoc): void {
    for (const key of this.articlePhotoKeys(doc)) this.invalidateArticlePhoto(key);
  }

  clearArticlePhotoCache(): void {
    if (this.articleCacheRoot.length === 0) return;
    this.articlePhotoEpoch++;
    this.articlePhotoTasks.clear();
    this.articlePhotoGenerations.clear();
    try {
      for (const name of fs.listFileSync(this.articleCacheRoot)) {
        try { fs.unlinkSync(`${this.articleCacheRoot}/${name}`); } catch (_) {}
      }
    } catch (_) {}
  }

  private articlePhotoPath(fullKey: string): string {
    if (this.articleCacheRoot.length === 0 || fullKey.length === 0) return '';
    return `${this.articleCacheRoot}/${ClientReliability.photoCacheKey(fullKey)}`;
  }

  private trimArticlePhotoCache(): void {
    if (this.articleCacheRoot.length === 0) return;
    try {
      const names: string[] = fs.listFileSync(this.articleCacheRoot);
      let total: number = 0;
      for (const name of names) total += fs.statSync(`${this.articleCacheRoot}/${name}`).size;
      if (total <= 512 * 1024 * 1024) return;
      for (const name of names.slice(0, Math.ceil(names.length / 2))) {
        try { fs.unlinkSync(`${this.articleCacheRoot}/${name}`); } catch (_) {}
      }
    } catch (_) {}
  }

  async pickForRecording(sessionTimestamp: string, elapsedSeconds: number, maximum: number = 9): Promise<CapturedPhoto[]> {
    if (!this.context || !sessionTimestamp) throw new Error('录音照片服务尚未初始化');
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = maximum; options.isPhotoTakingSupported = true; options.isOriginalSupported = true;
    const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
    const added: CapturedPhoto[] = [];
    for (const uri of result.photoUris) {
      const input: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      try {
        const bytes: ArrayBuffer = new ArrayBuffer(fs.statSync(input.fd).size); fs.readSync(input.fd, bytes);
        const jpeg: ArrayBuffer = await this.asJpeg(bytes);
        const localToken: string = util.generateRandomUUID(true).replace(/-/g, '').toLowerCase();
        const random: string = localToken.substring(0, 3);
        const key: string = RecordingName.photoKey(sessionTimestamp, elapsedSeconds, random);
        // Remote keys intentionally use the iOS-compatible three-character suffix,
        // while local retry files use the whole UUID to avoid cross-session collisions.
        const localPath: string = `${this.context.filesDir}/pending-photo-${localToken}.jpg`;
        const output: fs.File = fs.openSync(localPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try { fs.writeSync(output.fd, jpeg); } finally { fs.closeSync(output); }
        const photo: CapturedPhoto = new CapturedPhoto(key, localPath, uri); added.push(photo);
      } finally { fs.closeSync(input); }
    }
    const queue: CapturedPhoto[] = this.pending(); queue.push(...added); await this.persist(queue);
    return added;
  }

  async removeCaptured(photo: CapturedPhoto): Promise<void> {
    try { fs.unlinkSync(photo.localPath); } catch (_) {}
    await this.persist(this.pending().filter((value: CapturedPhoto) => value.key !== photo.key));
  }

  async discardCaptured(photos: CapturedPhoto[]): Promise<void> {
    const keys: Set<string> = new Set<string>();
    photos.forEach((photo: CapturedPhoto) => {
      keys.add(photo.key); try { fs.unlinkSync(photo.localPath); } catch (_) {}
    });
    await this.persist(this.pending().filter((value: CapturedPhoto) => !keys.has(value.key)));
  }

  async uploadCaptured(photos: CapturedPhoto[]): Promise<number> {
    let uploaded: number = 0;
    for (const photo of photos) {
      try {
        const file: fs.File = fs.openSync(photo.localPath, fs.OpenMode.READ_ONLY);
        try {
          const bytes: ArrayBuffer = new ArrayBuffer(fs.statSync(file.fd).size); fs.readSync(file.fd, bytes);
          const response = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(photo.key)}`,
            authStore.bearer(), bytes, 'image/jpeg');
          if (!response.ok()) continue;
        } finally { fs.closeSync(file); }
        uploaded++; await this.removeCaptured(photo);
      } catch (_) {}
    }
    return uploaded;
  }

  async retryPending(): Promise<number> { return this.uploadCaptured(this.pending()); }
  pendingCount(): number { return this.pending().length; }

  private pending(): CapturedPhoto[] {
    try {
      return (JSON.parse(appPreferences.pendingPhotos()) as PendingPhotoValue[])
        .map((value: PendingPhotoValue) => new CapturedPhoto(value.key, value.localPath, value.sourceUri ?? ''));
    } catch (_) { return []; }
  }

  private async persist(values: CapturedPhoto[]): Promise<void> {
    await appPreferences.savePendingPhotos(JSON.stringify(values));
  }

  async pickAndUpload(recordingName: string, maximum: number = 9): Promise<UploadedPhoto[]> {
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = maximum;
    options.isPhotoTakingSupported = true;
    options.isOriginalSupported = true;
    const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
    const uploaded: UploadedPhoto[] = [];
    let offset: number = 0;
    for (const uri of result.photoUris) {
      const key: string = await this.uploadUri(uri, recordingName, offset++);
      if (key.length > 0) uploaded.push({ key: key, sourceUri: uri });
    }
    if (result.photoUris.length > 0 && uploaded.length === 0) throw new Error('所选图片上传失败');
    return uploaded;
  }

  async uploadUri(uri: string, recordingName: string, offset: number): Promise<string> {
    const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const size: number = fs.statSync(file.fd).size;
      const bytes: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, bytes);
      const parsed = RecordingName.parse(recordingName);
      const session: string = parsed?.sessionTs ?? `${Date.now()}`;
      const random: string = util.generateRandomUUID(true).replace(/-/g, '').substring(0, 3).toLowerCase();
      const key: string = RecordingName.photoKey(session, offset, random);
      const jpeg: ArrayBuffer = await this.asJpeg(bytes);
      const response = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(key)}`,
        authStore.bearer(), jpeg, 'image/jpeg');
      return response.ok() ? key : '';
    } finally {
      fs.closeSync(file);
    }
  }


  async uploadBytes(bytes: ArrayBuffer, recordingName: string, offset: number): Promise<string> {
    const parsed = RecordingName.parse(recordingName);
    const session: string = parsed?.sessionTs ?? `${Date.now()}`;
    const random: string = util.generateRandomUUID(true).replace(/-/g, '').substring(0, 3).toLowerCase();
    const key: string = RecordingName.photoKey(session, offset, random);
    const jpeg: ArrayBuffer = await this.asJpeg(bytes);
    const response = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(key)}`,
      authStore.bearer(), jpeg, 'image/jpeg');
    return response.ok() ? key : '';
  }

  private async asJpeg(bytes: ArrayBuffer): Promise<ArrayBuffer> {
    return PhotoJpeg.transcode(bytes);
  }
}

export const photoService: PhotoService = new PhotoService();
