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

  static trustedReaderUrl(url: string, rootUrl: string): boolean {
    const candidate: string = url.trim();
    const root: string = rootUrl.trim();
    const bookUrlPattern: RegExp = /^https:\/\/(?:www\.)?voicedrop\.cn\/books\/[^\s]*$/i;
    return bookUrlPattern.test(candidate) && bookUrlPattern.test(root) && candidate.startsWith(root);
  }

  static target(rootUrl: string, currentUrl: string, pageTitle: string,
    title: string, author: string): WechatBookShareTargetValue {
    const root: string = rootUrl.trim();
    const candidate: string = currentUrl.trim();
    const bookTitle: string = WechatBookShare.title(title, title, author);
    const relative: string = candidate.startsWith(root) ? candidate.substring(root.length) : '';
    if (!WechatBookShare.trustedReaderUrl(candidate, root) || relative.length === 0 ||
      relative.startsWith('?') || relative.startsWith('#')) {
      return new WechatBookShareTargetValue(root, bookTitle, false);
    }
    const cleanPageTitle: string = pageTitle.trim();
    return new WechatBookShareTargetValue(candidate,
      cleanPageTitle.length > 0 ? cleanPageTitle : bookTitle, true);
  }
}

export class WechatBookShareTargetValue {
  url: string;
  title: string;
  isChapter: boolean;
  constructor(url: string, title: string, isChapter: boolean) {
    this.url = url; this.title = title; this.isChapter = isChapter;
  }
}
