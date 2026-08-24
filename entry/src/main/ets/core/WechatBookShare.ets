export type WechatBookShareTarget = 'friend' | 'timeline';

export class WechatBookShare {
  static title(title: string, fallback: string, author: string): string {
    const cleanTitle: string = (title || fallback || '未命名').trim() || '未命名';
    const cleanAuthor: string = author.trim();
    return `《${cleanTitle}》${cleanAuthor.length > 0 ? ` — ${cleanAuthor}` : ''}`;
  }

  static miniProgramPath(slug: string, title: string, main: string, author: string,
    hasCover: boolean, coverAt: number, chapterUrl: string = ''): string {
    return `pages/book-reader/index?slug=${encodeURIComponent(slug.trim())}` +
      `&title=${encodeURIComponent(title.trim())}` +
      `&main=${encodeURIComponent(main.trim())}` +
      `&author=${encodeURIComponent(author.trim())}` +
      `&cover=${hasCover ? '1' : '0'}` +
      `&coverAt=${Math.max(0, coverAt)}` +
      (chapterUrl.trim().length > 0 ? `&page=${encodeURIComponent(chapterUrl.trim())}` : '');
  }

  static isTimeline(target: WechatBookShareTarget): boolean {
    return target === 'timeline';
  }

  static trustedReaderUrl(url: string, rootUrl: string): boolean {
    const candidate: string = WechatBookShare.canonicalReaderUrl(url);
    const root: string = WechatBookShare.canonicalReaderUrl(rootUrl);
    return candidate.length > 0 && root.length > 0 && candidate.startsWith(root);
  }

  static target(rootUrl: string, currentUrl: string, pageTitle: string,
    title: string, author: string): WechatBookShareTargetValue {
    const root: string = WechatBookShare.canonicalReaderUrl(rootUrl);
    const candidate: string = WechatBookShare.canonicalReaderUrl(currentUrl);
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

  /** App 内阅读可走 CF；任何系统/微信分享都归一回备案的 .cn 公共链接。 */
  private static canonicalReaderUrl(value: string): string {
    const candidate: string = value.trim();
    const cn: RegExpMatchArray | null = candidate.match(
      /^https:\/\/(?:www\.)?voicedrop\.cn(\/books\/[^\s]*)$/i);
    if (cn) return `https://voicedrop.cn${cn[1]}`;
    const cf: RegExpMatchArray | null = candidate.match(
      /^https:\/\/(?:www\.)?jianshuo\.dev\/voicedrop(\/books\/[^\s]*)$/i);
    return cf ? `https://voicedrop.cn${cf[1]}` : '';
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
