export class CommunityLikeState {
  static toggled(current: boolean): boolean {
    return !current;
  }

  static contains(raw: string, shareId: string): boolean {
    if (shareId.trim().length === 0) return false;
    return CommunityLikeState.ids(raw).includes(shareId);
  }

  static update(raw: string, shareId: string, liked: boolean): string {
    if (shareId.trim().length === 0) return raw;
    const ids: string[] = CommunityLikeState.ids(raw)
      .filter((value: string) => value !== shareId);
    if (liked) ids.push(shareId);
    return JSON.stringify(ids);
  }

  private static ids(raw: string): string[] {
    try {
      const values: string[] = JSON.parse(raw.length > 0 ? raw : '[]') as string[];
      return Array.from(new Set<string>(
        values.filter((value: string) => typeof value === 'string' && value.trim().length > 0)));
    } catch (_) {
      return [];
    }
  }
}
