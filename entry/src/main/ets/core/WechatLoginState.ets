export class WechatLoginState {
  static readonly PREFIX: string = 'voicedrop_harmonyos_wechat_login:';
  static readonly MAX_AGE_MS: number = 10 * 60 * 1000;

  static isValid(pendingState: string, returnedState: string, issuedAt: number, now: number): boolean {
    if (!pendingState.startsWith(WechatLoginState.PREFIX) ||
      pendingState.length <= WechatLoginState.PREFIX.length) return false;
    if (returnedState !== pendingState) return false;
    if (!Number.isFinite(issuedAt) || issuedAt <= 0 || issuedAt > now) return false;
    return now - issuedAt <= WechatLoginState.MAX_AGE_MS;
  }
}
