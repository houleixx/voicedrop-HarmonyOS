import { ArticleBody } from './ArticleBody';

export class StyleRewriteUi {
  static articleStyleVersion(style: number | undefined, body: string): number | undefined {
    return style ?? ArticleBody.styleVersion(body);
  }

  private static styleText(style?: string, source?: string): string {
    if (typeof style === 'string') return style;
    return typeof source === 'string' ? source : '';
  }

  static displayName(style?: string, source?: string): string {
    const value: string = StyleRewriteUi.styleText(style, source);
    const firstLine: string = (value.split('\n')[0] ?? '').trim();
    return firstLine.length > 16 ? `${firstLine.substring(0, 16)}…` : firstLine;
  }

  static shortDate(value?: string | number): string {
    const trimmed: string = value === undefined ? '' : String(value).trim();
    if (trimmed.length === 0) return '';
    if (/^\d{10,13}$/.test(trimmed)) {
      let epoch: number = Number(trimmed);
      if (trimmed.length === 10) epoch *= 1000;
      const date: Date = new Date(epoch);
      if (date.getTime() > 0) return `${date.getMonth() + 1}月${date.getDate()}日`;
    }
    const dateMatch: RegExpMatchArray | null = trimmed.match(/\d{4}[-/](\d{1,2})[-/](\d{1,2})/);
    if (dateMatch) return `${Number(dateMatch[1])}月${Number(dateMatch[2])}日`;
    return trimmed;
  }

  static metadata(style?: string, savedAt?: string | number, source?: string): string {
    const value: string = StyleRewriteUi.styleText(style, source);
    const date: string = StyleRewriteUi.shortDate(savedAt);
    return `${value.length} 字${date.length > 0 ? ` · ${date}` : ''}`;
  }

  static actionLabel(styleVersion: number, generated: boolean): string {
    if (styleVersion < 0) return '选一个版本';
    return generated ? `切换到 v${styleVersion} 风格` : `用 v${styleVersion} 重写本文`;
  }
}
