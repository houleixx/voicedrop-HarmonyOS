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
      new PromptMarketFilter('hot', '热门', 'hot', ''),
      new PromptMarketFilter('new', '最新', 'new', ''),
      new PromptMarketFilter('text', '文字', 'hot', 'text'),
      new PromptMarketFilter('image', '配图', 'hot', 'image')
    ];
  }

  static resolve(key: string): PromptMarketFilter {
    return PromptMarketFilters.all().find((item: PromptMarketFilter) => item.key === key) ??
      new PromptMarketFilter('hot', '热门', 'hot', '');
  }
}
