export type WechatBookShareTarget = 'friend' | 'timeline';

export class WechatBookShare {
  static title(title: string, fallback: string, author: string): string {
    const cleanTitle: string = (title || fallback || '未命名').trim() || '未命名';
    const cleanAuthor: string = author.trim();
    return `《${cleanTitle}》${cleanAuthor.length > 0 ? ` — ${cleanAuthor}` : ''}`;
  }

  static miniProgramPath(slug: string, title: string, author: string, hasCover: boolean): string {
    return `pages/book-reader/index?slug=${encodeURIComponent(slug.trim())}` +
      `&title=${encodeURIComponent(title.trim())}` +
      `&author=${encodeURIComponent(author.trim())}` +
      `&cover=${hasCover ? '1' : '0'}`;
  }

  static isTimeline(target: WechatBookShareTarget): boolean {
    return target === 'timeline';
  }
}
