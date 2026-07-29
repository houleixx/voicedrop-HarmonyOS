export interface ArticleBlock {
  kind: 'text' | 'photo';
  value: string;
}

export interface ArticleText {
  title: string;
  body: string;
}

export class ArticleBody {
  static blocks(body: string): ArticleBlock[] {
    const stripped: string = ArticleBody.stripComments(body);
    const photoPattern: RegExp = /\[\[photo:([^\]]+)\]\]/g;
    const result: ArticleBlock[] = [];
    let cursor: number = 0;
    let match: RegExpExecArray | null = photoPattern.exec(stripped);
    while (match) {
      if (match.index > cursor) {
        const text: string = stripped.substring(cursor, match.index).trim();
        if (text.length > 0) result.push({ kind: 'text', value: text });
      }
      result.push({ kind: 'photo', value: match[1].trim() });
      cursor = match.index + match[0].length;
      match = photoPattern.exec(stripped);
    }
    if (cursor < stripped.length) {
      const text: string = stripped.substring(cursor).trim();
      if (text.length > 0) result.push({ kind: 'text', value: text });
    }
    if (result.length === 0) result.push({ kind: 'text', value: stripped });
    return result;
  }

  static visibleLine(blocks: ArticleBlock[], targetIndex: number): number {
    let line: number = 1;
    for (let index: number = 0; index < targetIndex && index < blocks.length; index++) {
      if (blocks[index].kind === 'photo') {
        line++;
      } else {
        line += blocks[index].value.split('\n').filter((part: string) => part.trim().length > 0).length;
      }
    }
    return line;
  }

  static photoUrl(key: string): string {
    return `https://voicedrop.cn/files/api/photo/${key.split('/').map((part: string) => encodeURIComponent(part)).join('/')}`;
  }

  /** Small feed/list images use Cloudflare's edge rendition; article bodies use photoUrl. */
  static photoThumbnailUrl(key: string): string {
    return `https://jianshuo.dev/cdn-cgi/image/width=512,quality=60/files/api/photo/${key.split('/').map((part: string) => encodeURIComponent(part)).join('/')}`;
  }

  static insertPhoto(body: string, key: string, offset: number): string {
    const marker: string = `\n\n[[photo:${key}]]\n\n`;
    const safeOffset: number = Math.max(0, Math.min(offset, body.length));
    return body.substring(0, safeOffset).trimEnd() + marker + body.substring(safeOffset).trimStart();
  }

  static resolvePhotoKey(token: string, photos?: string[]): string | undefined {
    const index: number = Number(token) - 1;
    if (/^\d+$/.test(token)) return photos && index >= 0 && index < photos.length ? photos[index] : undefined;
    return token;
  }

  static stripMarkers(body: string): string {
    return ArticleBody.stripComments(body).replace(/\[\[photo:[^\]]+\]\]/g, '')
      .replace(/\n{3,}/g, '\n\n').trim();
  }

  static stripComments(body: string): string {
    return body.replace(/<!--.*?-->/gs, '').trim();
  }

  static styleLabel(body: string): string | undefined {
    const pattern: RegExp = /<!--\s*([A-Za-z][\w-]*)\s*:\s*(.*?)\s*-->/gs;
    let label: string | undefined = undefined;
    let match: RegExpExecArray | null = pattern.exec(body);
    while (match) {
      if (match[1] === 'style' && match[2].trim().length > 0) label = match[2].trim();
      match = pattern.exec(body);
    }
    return label;
  }

  static styleLabelForVersion(version: number): string {
    return `风格 v${version}`;
  }

  static styleVersion(body: string): number | undefined {
    const label: string | undefined = ArticleBody.styleLabel(body);
    const match: RegExpMatchArray | null = label ? label.match(/\d+/) : null;
    return match ? Number(match[0]) : undefined;
  }

  static firstPhotoKey(body: string, photos?: string[]): string | undefined {
    const first: ArticleBlock | undefined = ArticleBody.blocks(body).find((block: ArticleBlock) => block.kind === 'photo');
    return first ? ArticleBody.resolvePhotoKey(first.value, photos) : undefined;
  }

  static shareText(articles: ArticleText[]): string {
    const multiple: boolean = articles.length > 1;
    return articles.map((article: ArticleText) => {
      const title: string = multiple ? `【${article.title}】` : article.title;
      return `${title}\n\n${ArticleBody.stripMarkers(article.body)}`;
    }).join('\n\n---\n\n');
  }
}
