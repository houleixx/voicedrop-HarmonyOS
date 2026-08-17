import { ArticleBody } from './ArticleBody';

/** Pure share-card contract kept separate from the WeChat SDK for unit testing. */
export class WechatShareContent {
  static excerpt(body: string | undefined, fallback: string): string {
    const plain: string = body ? ArticleBody.stripMarkers(body).replace(/\s+/g, ' ').trim() : '';
    if (plain.length === 0) return fallback;
    return plain.length <= 44 ? plain : `${plain.substring(0, 44)}……`;
  }

  static publicShareId(url: string): string {
    const clean: string = url.trim();
    if (!/^https:\/\/(?:www\.)?(?:voicedrop\.cn|jianshuo\.dev)\//i.test(clean)) return '';
    const match: RegExpMatchArray | null = clean.match(/\/([A-Za-z0-9_-]{6,16})(?:\?[^#]*)?(?:#.*)?$/);
    return match ? match[1] : '';
  }

  static publicMiniProgramPath(url: string, articleIndex: number): string {
    const shareId: string = WechatShareContent.publicShareId(url);
    if (shareId.length === 0) return '';
    const section: number = Math.max(0, Math.floor(articleIndex));
    return `pages/shared-article/index?shareId=${encodeURIComponent(shareId)}` +
      `&section=${section}&fromShare=1`;
  }

  static withSection(url: string, articleIndex: number): string {
    const section: number = Math.max(0, Math.floor(articleIndex));
    const separator: string = url.includes('?') ? '&' : '?';
    return `${url}${separator}s=${section}`;
  }

  static communityMiniProgramPath(shareId: string, articleIndex: number): string {
    const section: number = Math.max(0, Math.floor(articleIndex));
    return `pages/community-detail/index?shareId=${encodeURIComponent(shareId.trim())}` +
      `&section=${section}&fromShare=1`;
  }
}
