export interface SearchableShelfBook {
  slug: string; title: string; main: string; sub: string; author: string; category: string; mine: boolean; video?: boolean;
}
interface ChapterWire { t?: string; b?: string; }
interface SearchWire { slug?: string; sub?: string; intro?: string; toc?: ChapterWire[]; }
interface SearchResponse { books?: SearchWire[]; }
export class ShelfSearchChapter {
  t: string; b: string;
  constructor(wire: ChapterWire) {
    this.t = typeof wire.t === 'string' ? wire.t : '';
    this.b = typeof wire.b === 'string' ? wire.b : '';
  }
}
export class ShelfSearchEntry {
  slug: string; sub: string; intro: string; toc: ShelfSearchChapter[];
  constructor(wire: SearchWire) {
    this.slug = typeof wire.slug === 'string' ? wire.slug : '';
    this.sub = typeof wire.sub === 'string' ? wire.sub : '';
    this.intro = typeof wire.intro === 'string' ? wire.intro : '';
    this.toc = Array.isArray(wire.toc) ? wire.toc.filter((c: ChapterWire) => c !== null && typeof c === 'object')
      .map((c: ChapterWire) => new ShelfSearchChapter(c)) : [];
  }
}
export class BookShelfSearch {
  static readonly CATEGORIES: string[] = ['商业', '投资', 'AI', '科学', '人文', '身心', '生活', '故事'];
  static parse(raw: string): ShelfSearchEntry[] {
    const response: SearchResponse = JSON.parse(raw) as SearchResponse;
    if (!response || !Array.isArray(response.books)) throw new Error('Invalid book search index');
    return response.books.filter((entry: SearchWire) => entry !== null && typeof entry === 'object')
      .map((entry: SearchWire) => new ShelfSearchEntry(entry)).filter((entry: ShelfSearchEntry) => entry.slug.length > 0);
  }
  static filters(books: SearchableShelfBook[]): string[] {
    const filters: string[] = ['全部', '我的'];
    if (books.some((book: SearchableShelfBook) => book.video === true)) filters.push('视频');
    return filters.concat(BookShelfSearch.CATEGORIES.filter((category: string) =>
      books.some((book: SearchableShelfBook) => book.category === category)));
  }
  static validFilter(books: SearchableShelfBook[], filter: string): string {
    return BookShelfSearch.filters(books).includes(filter) ? filter : '全部';
  }
  static matchesFilter(book: SearchableShelfBook, filter: string): boolean {
    if (filter === '视频') return book.video === true;
    return filter === '全部' || (filter === '我的' ? book.mine === true : book.category === filter);
  }
  // undefined means no match; an empty hit means book metadata matched first.
  static hit(book: SearchableShelfBook, query: string, entry?: ShelfSearchEntry): string | undefined {
    const q: string = query.trim().toLocaleLowerCase();
    if (q.length === 0 || [book.title, book.main, book.sub, book.author, book.category]
      .some((text: string) => text.toLocaleLowerCase().includes(q))) return '';
    if (!entry) return undefined;
    if ([entry.sub, entry.intro].some((text: string) => text.toLocaleLowerCase().includes(q))) return '';
    const chapter: ShelfSearchChapter | undefined = entry.toc.find((c: ShelfSearchChapter) =>
      c.t.toLocaleLowerCase().includes(q) || c.b.toLocaleLowerCase().includes(q));
    return chapter ? chapter.t : undefined;
  }
  static rowKey(books: SearchableShelfBook[], query: string, startIndex: number): string {
    const first: number = startIndex - (BookShelfSearch.showWrite(query) ? 1 : 0);
    const firstKey: string = first < 0 ? 'write' : books[first]?.slug ?? '';
    const secondKey: string = books[first + 1]?.slug ?? '';
    return `${startIndex}:${firstKey}:${secondKey}`;
  }
  static showWrite(query: string): boolean { return query.trim().length === 0; }
}
/** One attempt per query session; explicit retry/refresh resets failure. */
export class BookSearchRequestState {
  generation: number = 0;
  identity: string = '';
  loading: boolean = false;
  loaded: boolean = false;
  failed: boolean = false;
  invalidate(identity: string): void {
    this.generation++; this.identity = identity; this.loading = false; this.loaded = false; this.failed = false;
  }
  begin(query: string, retry: boolean = false): number {
    if (query.trim().length === 0 || this.loading || this.loaded || (this.failed && !retry)) return -1;
    this.loading = true; this.failed = false; return ++this.generation;
  }
  accepts(generation: number, identity: string): boolean {
    return generation === this.generation && identity === this.identity && identity.length > 0;
  }
  finish(generation: number, identity: string, success: boolean): boolean {
    if (!this.accepts(generation, identity)) return false;
    this.loading = false; this.loaded = success; this.failed = !success; return true;
  }
}
