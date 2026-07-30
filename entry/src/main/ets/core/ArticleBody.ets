export interface ArticleBlock {
  kind: 'text' | 'photo';
  value: string;
  lineNumber?: number;
  imageNumber?: number;
}

export interface ArticleText {
  title: string;
  body: string;
}

interface ArticleTextLineMatch {
  rangeStart: number;
  rangeEnd: number;
  lineCount: number;
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

  static locatedBlocks(body: string): ArticleBlock[] {
    const result: ArticleBlock[] = [];
    let lineNumber: number = 0;
    let imageNumber: number = 0;
    for (const block of ArticleBody.blocks(body)) {
      if (block.kind === 'photo') {
        lineNumber++;
        imageNumber++;
        result.push({ kind: 'photo', value: block.value, lineNumber, imageNumber });
        continue;
      }
      for (const raw of block.value.split('\n')) {
        const paragraph: string = raw.trim();
        if (paragraph.length === 0) continue;
        lineNumber++;
        result.push({ kind: 'text', value: paragraph, lineNumber, imageNumber: 0 });
      }
    }
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

  /**
   * Image editing requires the article body to contain the resolved photo key.
   * Older articles may still use positional markers such as [[photo:1]], which
   * remain valid for rendering but cannot be targeted by the current edit API.
   */
  static materializePhotoMarker(body: string, token: string, photos?: string[]): string {
    const legacyToken: string = token.trim();
    if (!/^\d+$/.test(legacyToken)) return body;
    const key: string | undefined = ArticleBody.resolvePhotoKey(legacyToken, photos);
    if (!key || key.trim().length === 0) return body;
    const markerPattern: RegExp = new RegExp(`\\[\\[photo:\\s*${legacyToken}\\s*\\]\\]`, 'g');
    return body.replace(markerPattern, `[[photo:${key.trim()}]]`);
  }

  /**
   * Replaces one visible detail row without changing surrounding whitespace,
   * metadata comments, or photo markers. Non-blank text lines and photos share
   * the same one-based row sequence.
   */
  static replacingLine(targetLine: number, newText: string, body: string): string {
    if (targetLine < 1) return body;
    const photos: RegExp = /\[\[photo:([^\]]+)\]\]/g;
    let cursor: number = 0;
    let line: number = 0;
    let photo: RegExpExecArray | null = photos.exec(body);
    while (photo) {
      const textMatch: ArticleTextLineMatch =
        ArticleBody.findTextLine(body, cursor, photo.index, targetLine, line);
      if (textMatch.rangeStart >= 0) {
        return body.substring(0, textMatch.rangeStart) + newText + body.substring(textMatch.rangeEnd);
      }
      line = textMatch.lineCount + 1;
      if (line === targetLine) return body;
      cursor = photo.index + photo[0].length;
      photo = photos.exec(body);
    }
    const tail: ArticleTextLineMatch =
      ArticleBody.findTextLine(body, cursor, body.length, targetLine, line);
    if (tail.rangeStart < 0) return body;
    return body.substring(0, tail.rangeStart) + newText + body.substring(tail.rangeEnd);
  }

  /**
   * Maps a row rendered from a trimmed or duplicate-title-free body back into
   * the stored body before replacing it.
   */
  static replacingRenderedLine(targetLine: number, newText: string,
    renderedBody: string, originalBody: string): string {
    const replaced: string = ArticleBody.replacingLine(targetLine, newText, renderedBody);
    if (replaced === renderedBody) return originalBody;
    const start: number = originalBody.indexOf(renderedBody);
    if (start < 0) return originalBody;
    return originalBody.substring(0, start) + replaced +
      originalBody.substring(start + renderedBody.length);
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

  static firstArticlePhotoKey(articles: ArticleText[], photos?: string[]): string | undefined {
    for (const article of articles) {
      const key: string | undefined = ArticleBody.firstPhotoKey(article.body, photos);
      if (key && key.trim().length > 0) return key.trim();
    }
    return undefined;
  }

  static shareText(articles: ArticleText[]): string {
    const multiple: boolean = articles.length > 1;
    return articles.map((article: ArticleText) => {
      const title: string = multiple ? `【${article.title}】` : article.title;
      return `${title}\n\n${ArticleBody.stripMarkers(article.body)}`;
    }).join('\n\n---\n\n');
  }

  private static findTextLine(body: string, start: number, end: number,
    targetLine: number, initialLine: number): ArticleTextLineMatch {
    let line: number = initialLine;
    let lineStart: number = start;
    while (lineStart <= end) {
      const newline: number = body.indexOf('\n', lineStart);
      const lineEnd: number = newline >= 0 && newline < end ? newline : end;
      const raw: string = body.substring(lineStart, lineEnd);
      const visible: string = raw.replace(/<!--.*?-->/gs, '');
      if (visible.trim().length > 0) {
        line++;
        if (line === targetLine) {
          if (visible !== raw) return { rangeStart: -1, rangeEnd: -1, lineCount: line };
          let leading: number = 0;
          while (leading < raw.length && /\s/.test(raw.charAt(leading))) leading++;
          let trailing: number = raw.length;
          while (trailing > leading && /\s/.test(raw.charAt(trailing - 1))) trailing--;
          return {
            rangeStart: lineStart + leading,
            rangeEnd: lineStart + trailing,
            lineCount: line
          };
        }
      }
      if (lineEnd >= end) break;
      lineStart = lineEnd + 1;
    }
    return { rangeStart: -1, rangeEnd: -1, lineCount: line };
  }
}
