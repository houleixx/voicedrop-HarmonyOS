export type DetailShareSurface = 'recording' | 'community' | 'book';

/** Stable user-visible channel contract shared by the three detail surfaces. */
export class DetailShareUi {
  static bookMenuIds(): string[] {
    return ['revise', 'share'];
  }

  static targetIds(surface: DetailShareSurface): string[] {
    if (surface === 'recording') return ['wechat', 'timeline', 'xhs', 'copy', 'system'];
    if (surface === 'community') return ['wechat', 'timeline', 'copy', 'system'];
    return ['friend', 'timeline', 'copy', 'system'];
  }

  static needsDivider(surface: DetailShareSurface): boolean {
    return DetailShareUi.targetIds(surface).length > 4;
  }
}
