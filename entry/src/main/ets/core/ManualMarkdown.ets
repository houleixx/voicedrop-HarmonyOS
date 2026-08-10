export enum ManualBlockKind {
  TITLE = 'title',
  CHAPTER = 'chapter',
  SECTION = 'section',
  PARAGRAPH = 'paragraph',
  BULLETS = 'bullets',
  NUMBERED = 'numbered',
  TABLE = 'table',
  CODE = 'code'
}

export class ManualBlock {
  kind: ManualBlockKind;
  text: string;
  items: string[];
  rows: string[][];

  constructor(kind: ManualBlockKind, text: string = '', items: string[] = [], rows: string[][] = []) {
    this.kind = kind;
    this.text = text;
    this.items = items;
    this.rows = rows;
  }
}

export class ManualInline {
  text: string;
  bold: boolean;
  code: boolean;
  url: string;

  constructor(text: string, bold: boolean = false, code: boolean = false, url: string = '') {
    this.text = text;
    this.bold = bold;
    this.code = code;
    this.url = url;
  }
}

export class ManualMarkdown {
  static readonly ASSET: string = 'help_manual.md';
  static readonly SECTION_LABELS: string[] = [
    '1 上手', '2 录音', '3 改稿', '4 发布',
    '5 社区', '6 文风', '7 账号', '8 FAQ'
  ];

  static parse(markdown: string): ManualBlock[] {
    const blocks: ManualBlock[] = [];
    let paragraph: string[] = [];
    let bullets: string[] = [];
    let numbered: string[] = [];
    let table: string[][] = [];
    let code: string[] = [];
    let inCode: boolean = false;

    const flushParagraph = (): void => {
      if (paragraph.length > 0) blocks.push(new ManualBlock(ManualBlockKind.PARAGRAPH, paragraph.join(' ')));
      paragraph = [];
    };
    const flushBullets = (): void => {
      if (bullets.length > 0) blocks.push(new ManualBlock(ManualBlockKind.BULLETS, '', bullets));
      bullets = [];
    };
    const flushNumbered = (): void => {
      if (numbered.length > 0) blocks.push(new ManualBlock(ManualBlockKind.NUMBERED, '', numbered));
      numbered = [];
    };
    const flushTable = (): void => {
      if (table.length > 0) blocks.push(new ManualBlock(ManualBlockKind.TABLE, '', table[0], table.slice(1)));
      table = [];
    };
    const flushAll = (): void => {
      flushParagraph();
      flushBullets();
      flushNumbered();
      flushTable();
    };

    for (const raw of markdown.replace(/\r\n/g, '\n').split('\n')) {
      const line: string = raw.trim();
      if (inCode) {
        if (line.startsWith('```')) {
          blocks.push(new ManualBlock(ManualBlockKind.CODE, code.join('\n')));
          code = [];
          inCode = false;
        } else {
          code.push(raw);
        }
        continue;
      }
      if (line.startsWith('```')) {
        flushAll();
        inCode = true;
        continue;
      }
      if (line.length === 0) {
        flushAll();
        continue;
      }
      if (line.startsWith('### ')) {
        flushAll();
        blocks.push(new ManualBlock(ManualBlockKind.SECTION, line.substring(4)));
        continue;
      }
      if (line.startsWith('## ')) {
        flushAll();
        blocks.push(new ManualBlock(ManualBlockKind.CHAPTER, line.substring(3)));
        continue;
      }
      if (line.startsWith('# ')) {
        flushAll();
        blocks.push(new ManualBlock(ManualBlockKind.TITLE, line.substring(2)));
        continue;
      }
      if (line.startsWith('|')) {
        flushParagraph();
        flushBullets();
        flushNumbered();
        const cells: string[] = ManualMarkdown.tableCells(line);
        if (!ManualMarkdown.isTableDivider(cells)) table.push(cells);
        continue;
      }
      if (line.startsWith('- ')) {
        flushParagraph();
        flushNumbered();
        flushTable();
        bullets.push(line.substring(2));
        continue;
      }
      if (/^\d+\.\s+/.test(line)) {
        flushParagraph();
        flushBullets();
        flushTable();
        numbered.push(line.replace(/^\d+\.\s+/, ''));
        continue;
      }
      flushBullets();
      flushNumbered();
      flushTable();
      paragraph.push(line);
    }
    flushAll();
    if (inCode && code.length > 0) blocks.push(new ManualBlock(ManualBlockKind.CODE, code.join('\n')));
    return blocks;
  }

  static inline(value: string): ManualInline[] {
    const result: ManualInline[] = [];
    const pattern: RegExp = /(\*\*.+?\*\*|`[^`]+`|\[[^\]]+]\(https?:\/\/[^)]+\))/g;
    let cursor: number = 0;
    let match: RegExpExecArray | null = pattern.exec(value);
    while (match) {
      if (match.index > cursor) result.push(new ManualInline(value.substring(cursor, match.index)));
      const token: string = match[0];
      if (token.startsWith('**')) {
        result.push(new ManualInline(token.substring(2, token.length - 2), true));
      } else if (token.startsWith('`')) {
        result.push(new ManualInline(token.substring(1, token.length - 1), false, true));
      } else {
        const divider: number = token.lastIndexOf('](');
        result.push(new ManualInline(token.substring(1, divider), false, false,
          token.substring(divider + 2, token.length - 1)));
      }
      cursor = match.index + token.length;
      match = pattern.exec(value);
    }
    if (cursor < value.length) result.push(new ManualInline(value.substring(cursor)));
    return result;
  }

  static chapterBlockIndexes(blocks: ManualBlock[]): number[] {
    const indexes: number[] = [];
    blocks.forEach((block: ManualBlock, index: number) => {
      if (block.kind === ManualBlockKind.CHAPTER) indexes.push(index);
    });
    return indexes;
  }

  static plainInline(value: string): string {
    return ManualMarkdown.inline(value).map((part: ManualInline) => part.text).join('');
  }

  private static tableCells(line: string): string[] {
    return line.replace(/^\|/, '').replace(/\|$/, '').split('|').map((cell: string) => cell.trim());
  }

  private static isTableDivider(cells: string[]): boolean {
    return cells.length > 0 && cells.every((cell: string) => /^:?-{3,}:?$/.test(cell));
  }
}

export class ManualSectionSelection {
  private activeSection: number = 0;
  private targetSection: number = -1;

  select(index: number): number {
    if (index !== this.activeSection) this.targetSection = index;
    this.activeSection = index;
    return this.activeSection;
  }

  report(index: number): number {
    if (this.targetSection >= 0) {
      if (index === this.targetSection) this.targetSection = -1;
      return this.activeSection;
    }
    this.activeSection = index;
    return this.activeSection;
  }

  releaseTarget(): void {
    this.targetSection = -1;
  }
}
