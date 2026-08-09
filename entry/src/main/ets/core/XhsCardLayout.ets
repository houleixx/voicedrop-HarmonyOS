export type XhsMeasureText = (value: string) => number;

export class XhsCardLine {
  text: string;
  y: number;
  constructor(text: string, y: number) { this.text = text; this.y = y; }
}

export class XhsCardPage {
  lines: XhsCardLine[];
  constructor(lines: XhsCardLine[] = []) { this.lines = lines; }
}

export class XhsCard {
  kind: string;
  title: string;
  date: string;
  lines: XhsCardLine[];
  constructor(kind: string, title: string = '', date: string = '', lines: XhsCardLine[] = []) {
    this.kind = kind; this.title = title; this.date = date; this.lines = lines;
  }
}

export class XhsCardLayout {
  static readonly WIDTH: number = 1080;
  static readonly HEIGHT: number = 1440;
  static readonly MAX_IMAGES: number = 9;
  static readonly MAX_BODY_PAGES: number = 11;
  static readonly BODY_LEFT: number = 110;
  static readonly BODY_TOP: number = 150;
  static readonly BODY_WIDTH: number = 860;
  static readonly BODY_HEIGHT: number = 1120;
  static readonly BODY_FONT_SIZE: number = 42;
  static readonly LINE_SPACING: number = 26;
  static readonly LINE_ADVANCE: number = XhsCardLayout.BODY_FONT_SIZE + XhsCardLayout.LINE_SPACING;
  static readonly PARAGRAPH_SPACING: number = 36;
  static readonly TITLE_WIDTH: number = 860;
  private static readonly CLOSING_PUNCTUATION: string = '，。！？；：、）》】〕〉”’…,.!?;:%）';
  private static readonly OPENING_PUNCTUATION: string = '（《【〔〈“‘';

  static generatedCardSlots(originalCount: number): number {
    return Math.max(0, XhsCardLayout.MAX_IMAGES - Math.max(0, Math.floor(originalCount)));
  }

  static estimatedWidth(value: string, fontSize: number): number {
    let width: number = 0;
    for (const character of Array.from(value)) {
      width += /^[\x00-\xff]$/.test(character) ? fontSize * 0.56 : fontSize;
    }
    return width;
  }

  static wrapParagraph(value: string, maxWidth: number, measureText: XhsMeasureText): string[] {
    const text: string = value.trim();
    if (text.length === 0 || maxWidth <= 0) return [];
    const lines: string[] = [];
    let line: string = '';
    const tokens: string[] = XhsCardLayout.tokens(text);
    for (const rawToken of tokens) {
      const token: string = /^\s+$/.test(rawToken) ? (line.length > 0 ? ' ' : '') : rawToken;
      if (token.length === 0) continue;
      const candidate: string = `${line}${token}`;
      if (measureText(candidate) <= maxWidth) { line = candidate; continue; }
      if (line.length > 0 && XhsCardLayout.CLOSING_PUNCTUATION.includes(token)) {
        line = candidate; continue;
      }
      let carry: string = token.trimStart();
      if (line.length > 0 && XhsCardLayout.OPENING_PUNCTUATION.includes(line.substring(line.length - 1))) {
        carry = `${line.substring(line.length - 1)}${carry}`;
        line = line.substring(0, line.length - 1);
      }
      if (line.trim().length > 0) lines.push(line.trim());
      line = '';
      if (measureText(carry) <= maxWidth) { line = carry; continue; }
      for (const character of Array.from(carry)) {
        const characterCandidate: string = `${line}${character}`;
        if (line.length === 0 || measureText(characterCandidate) <= maxWidth) line = characterCandidate;
        else { lines.push(line.trim()); line = character; }
      }
    }
    if (line.trim().length > 0) lines.push(line.trim());
    return lines;
  }

  static paginateBody(body: string, measureText: XhsMeasureText): XhsCardPage[] {
    const paragraphs: string[] = body.split(/\n+/).map((value: string): string => value.trim())
      .filter((value: string): boolean => value.length > 0);
    const pages: XhsCardPage[] = [];
    let lines: XhsCardLine[] = [];
    let y: number = XhsCardLayout.BODY_TOP;
    for (let paragraphIndex: number = 0; paragraphIndex < paragraphs.length; paragraphIndex++) {
      if (paragraphIndex > 0 && lines.length > 0) y += XhsCardLayout.PARAGRAPH_SPACING;
      const paragraphLines: string[] = XhsCardLayout.wrapParagraph(
        paragraphs[paragraphIndex], XhsCardLayout.BODY_WIDTH, measureText);
      for (const text of paragraphLines) {
        if (y + XhsCardLayout.BODY_FONT_SIZE > XhsCardLayout.BODY_TOP + XhsCardLayout.BODY_HEIGHT) {
          if (lines.length > 0) pages.push(new XhsCardPage(lines));
          lines = []; y = XhsCardLayout.BODY_TOP;
        }
        if (pages.length >= XhsCardLayout.MAX_BODY_PAGES) return pages;
        lines.push(new XhsCardLine(text, y));
        y += XhsCardLayout.LINE_ADVANCE;
      }
    }
    if (lines.length > 0 && pages.length < XhsCardLayout.MAX_BODY_PAGES) pages.push(new XhsCardPage(lines));
    return pages;
  }

  static cards(title: string, body: string, date: string, maximum: number,
    measureText: XhsMeasureText): XhsCard[] {
    const limit: number = Math.max(0, Math.floor(maximum));
    if (limit === 0) return [];
    const cards: XhsCard[] = [new XhsCard('title', title.trim() || '一篇文章', date.trim())];
    for (const page of XhsCardLayout.paginateBody(body, measureText)) {
      if (cards.length >= limit) break;
      cards.push(new XhsCard('body', '', '', page.lines));
    }
    return cards;
  }

  static titleLines(title: string, measureText: XhsMeasureText): string[] {
    return XhsCardLayout.wrapParagraph(title, XhsCardLayout.TITLE_WIDTH, measureText);
  }

  private static tokens(value: string): string[] {
    const tokens: string[] = [];
    let word: string = '';
    const flush = (): void => {
      if (word.length > 0) tokens.push(word);
      word = '';
    };
    for (const character of Array.from(value)) {
      if (/^[A-Za-z0-9.:/\-]$/.test(character)) { word += character; continue; }
      flush();
      if (/^\s$/.test(character)) {
        if (tokens.length === 0 || tokens[tokens.length - 1] !== ' ') tokens.push(' ');
      } else tokens.push(character);
    }
    flush();
    return tokens;
  }
}
