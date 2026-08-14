export class AccountIdentity {
  static readonly valueEllipsisMode: EllipsisMode = EllipsisMode.CENTER;

  static accountIdFromScope(scope: string): string {
    let value: string = scope.trim();
    if (value.startsWith('users/')) value = value.substring('users/'.length);
    while (value.endsWith('/')) value = value.substring(0, value.length - 1);
    return value;
  }

  static shortCodeFromAccountId(accountId: string): string {
    const normalized: string = accountId.trim().toLowerCase();
    const value: string = normalized.startsWith('anon-') ? normalized.substring('anon-'.length) : normalized;
    return /^[0-9a-f]{6,}$/.test(value) ? value.substring(0, 6).toUpperCase() : '';
  }

  static visibleShortCode(accountId: string, wechatAuthenticated: boolean): string {
    return wechatAuthenticated ? '' : AccountIdentity.shortCodeFromAccountId(accountId);
  }

  static maskedToken(token: string): string {
    return token.length <= 16 ? token : `${token.substring(0, 10)}••••••${token.substring(token.length - 4)}`;
  }
}
