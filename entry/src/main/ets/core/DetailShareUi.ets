export type DetailShareSurface = 'recording' | 'community' | 'book';

/** Stable user-visible channel contract shared by the three detail surfaces. */
export class DetailShareUi {
  static readonly DETAIL_HEADER_HEIGHT: number = 56;
  static readonly MENU_TOP_GAP: number = 8;
  static readonly MENU_TOP_OFFSET: number =
    DetailShareUi.DETAIL_HEADER_HEIGHT + DetailShareUi.MENU_TOP_GAP;
  static readonly MENU_RIGHT_INSET: number = 12;

  static bookMenuIds(): string[] {
    return ['revise', 'share'];
  }

  static targetIds(surface: DetailShareSurface): string[] {
    if (surface === 'recording') return ['wechat', 'timeline', 'xhs', 'style', 'copy', 'system'];
    if (surface === 'community') return ['wechat', 'timeline', 'copy', 'system'];
    return ['friend', 'timeline', 'copy', 'system'];
  }

  static needsDivider(surface: DetailShareSurface): boolean {
    return DetailShareUi.targetIds(surface).length > 4;
  }
}
