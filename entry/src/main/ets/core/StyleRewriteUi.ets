import { ArticleBody } from './ArticleBody';
import { AppLocale } from './AppLocale';

export class StyleRewriteUi {
  static readonly ARTICLE_RELOAD_ATTEMPTS: number = 3;

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
      if (date.getTime() > 0) return AppLocale.dateShort(epoch);
    }
    const dateMatch: RegExpMatchArray | null = trimmed.match(/\d{4}[-/](\d{1,2})[-/](\d{1,2})/);
    if (dateMatch) return AppLocale.monthDay(Number(dateMatch[1]), Number(dateMatch[2]));
    return trimmed;
  }

  static metadata(style?: string, savedAt?: string | number, source?: string): string {
    const value: string = StyleRewriteUi.styleText(style, source);
    const date: string = StyleRewriteUi.shortDate(savedAt);
    return `${value.length}${AppLocale.text(' 字')}${date.length > 0 ? ` · ${date}` : ''}`;
  }

  static actionLabel(styleVersion: number, generated: boolean): string {
    if (styleVersion < 0) return AppLocale.text('选一个版本');
    return generated ? `${AppLocale.text('切换到 v')}${styleVersion}${AppLocale.text(' 风格')}` :
      `${AppLocale.text('用 v')}${styleVersion}${AppLocale.text(' 重写本文')}`;
  }

  static navigationBarColor(blocking: boolean): string {
    return blocking ? '#C8C5BF' : '#FAF6EF';
  }

  static shouldRetryArticleLoad(available: boolean, attempt: number): boolean {
    return !available && attempt + 1 < StyleRewriteUi.ARTICLE_RELOAD_ATTEMPTS;
  }

  static articleReloadDelay(attempt: number): number {
    if (attempt <= 0) return 0;
    return attempt === 1 ? 150 : 350;
  }
}
