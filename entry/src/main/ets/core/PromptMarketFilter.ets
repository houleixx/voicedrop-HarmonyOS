import { AppLocale } from './AppLocale';

export class PromptMarketFilter {
  key: string;
  label: string;
  sort: string;
  scope: string;

  constructor(key: string, label: string, sort: string, scope: string) {
    this.key = key;
    this.label = label;
    this.sort = sort;
    this.scope = scope;
  }
}

export class PromptMarketFilters {
  static all(): PromptMarketFilter[] {
    return [
      new PromptMarketFilter('hot', AppLocale.text('热门'), 'hot', ''),
      new PromptMarketFilter('new', AppLocale.text('最新'), 'new', ''),
      new PromptMarketFilter('text', AppLocale.text('文字'), 'hot', 'text'),
      new PromptMarketFilter('image', AppLocale.text('配图'), 'hot', 'image')
    ];
  }

  static resolve(key: string): PromptMarketFilter {
    return PromptMarketFilters.all().find((item: PromptMarketFilter) => item.key === key) ??
      new PromptMarketFilter('hot', AppLocale.text('热门'), 'hot', '');
  }
}
