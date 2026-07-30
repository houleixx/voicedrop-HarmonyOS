export interface ArticleVersionHead {
  v: number;
}

export class ArticleVersionNavigation {
  static target(head: number, versions: ArticleVersionHead[], delta: number): number | undefined {
    let target: number | undefined = undefined;
    for (const version of versions) {
      if (delta < 0 && version.v < head && (target === undefined || version.v > target)) {
        target = version.v;
      } else if (delta > 0 && version.v > head && (target === undefined || version.v < target)) {
        target = version.v;
      }
    }
    return target;
  }
}
