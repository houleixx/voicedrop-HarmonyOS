import { httpClient, HttpResponse } from '../net/HttpClient';
import { appPreferences } from './AppPreferences';
import { Api } from '../core/Api';
import { authStore } from './AuthStore';
import { BookShelfCachePolicy } from '../core/BookShelfCachePolicy';

interface ShelfBookWire { slug?: string; title?: string; main?: string; sub?: string; c?: string; c2?: string; cover?: boolean; coverAt?: number; chapters?: number; author?: string; createdAt?: number; hidden?: boolean; }
interface ShelfIndexWire { books?: ShelfBookWire[]; }

export class ShelfBook {
  slug: string; title: string; main: string; sub: string; c: string; c2: string; cover: boolean; chapters: number;
  author: string; createdAt: number; coverAt: number; hidden: boolean;
  constructor(wire: ShelfBookWire = {}) {
    this.slug = wire.slug ?? ''; this.title = wire.title ?? ''; this.main = wire.main ?? wire.title ?? '未命名';
    this.sub = wire.sub ?? ''; this.c = wire.c ?? '#8B6652'; this.c2 = wire.c2 ?? '#4B342C';
    this.cover = wire.cover === true; this.chapters = Math.max(0, wire.chapters ?? 0);
    this.author = wire.author ?? ''; this.createdAt = Math.max(0, wire.createdAt ?? 0);
    this.coverAt = Math.max(0, wire.coverAt ?? 0);
    this.hidden = wire.hidden === true;
  }
  readerUrl(): string { return `${Api.PUBLIC_WEB_BASE}/books/${encodeURIComponent(this.slug)}/`; }
  shareUrl(): string { return `https://voicedrop.cn/books/${encodeURIComponent(this.slug)}/`; }
  coverUrl(): string {
    const base: string = `${Api.PUBLIC_WEB_BASE}/books/${encodeURIComponent(this.slug)}/cover.jpg`;
    return this.coverAt > 0 ? `${base}?v=${this.coverAt}` : base;
  }
  shareText(): string {
    const title: string = (this.title || this.main || '未命名').trim() || '未命名';
    const byline: string = this.author.trim().length > 0 ? ` — ${this.author.trim()}` : '';
    return `《${title}》${byline}\n${this.shareUrl()}`;
  }
}

export class BooksService {
  static get INDEX(): string { return `${Api.PUBLIC_WEB_BASE}/books/?format=json`; }
  cached(): ShelfBook[] { return this.parse(appPreferences.bookShelfCache(authStore.bookShelfCacheIdentity())); }
  async load(): Promise<ShelfBook[]> {
    const bearer: string = authStore.bearer();
    const cacheIdentity: string = authStore.bookShelfCacheIdentity();
    const response: HttpResponse = await httpClient.get(BooksService.INDEX, bearer);
    if (!response.ok()) throw new Error(`书架加载失败 HTTP ${response.code}`);
    if (!BookShelfCachePolicy.shouldAcceptResponse(cacheIdentity, authStore.bookShelfCacheIdentity())) {
      throw new Error('书架加载期间账号已切换，请重试');
    }
    const books: ShelfBook[] = this.parse(response.text);
    await appPreferences.saveBookShelfCache(cacheIdentity, response.text);
    if (!BookShelfCachePolicy.shouldAcceptResponse(cacheIdentity, authStore.bookShelfCacheIdentity())) {
      throw new Error('书架加载期间账号已切换，请重试');
    }
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
