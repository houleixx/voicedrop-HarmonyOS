export class CommunityShareUi {
  static shouldApplyLookup(lookupGeneration: number, currentGeneration: number): boolean {
    return lookupGeneration === currentGeneration;
  }

  static successMessage(isReply: boolean): string {
    return isReply ? '登录后已自动续发社区回复' : '已在 VD 社区可见';
  }
}
