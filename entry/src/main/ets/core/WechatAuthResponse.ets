interface WechatAuthWire {
  error?: string;
  detail?: string;
  session?: string;
  scope?: string;
}

export class ParsedWechatAuthResponse {
  ok: boolean;
  error: string;
  detail: string;
  session: string;
  scope: string;

  constructor(ok: boolean, error: string, detail: string, session: string, scope: string) {
    this.ok = ok;
    this.error = error;
    this.detail = detail;
    this.session = session;
    this.scope = scope;
  }
}

export class WechatAuthResponse {
  static parse(statusCode: number, text: string): ParsedWechatAuthResponse {
    let wire: WechatAuthWire = {};
    try {
      wire = JSON.parse(text || '{}') as WechatAuthWire;
    } catch (_) {
      if (statusCode >= 200 && statusCode < 300) {
        return new ParsedWechatAuthResponse(false, 'bad_session', '', '', '');
      }
    }
    if (statusCode < 200 || statusCode >= 300) {
      return new ParsedWechatAuthResponse(false, wire.error?.trim() || 'wechat_auth_failed',
        wire.detail?.trim() || '', '', '');
    }
    const session: string = wire.session?.trim() || '';
    const scope: string = wire.scope?.trim() || '';
    if (!WechatAuthResponse.isSessionToken(session) || !/^users\/[^/]+\/$/.test(scope)) {
      return new ParsedWechatAuthResponse(false, 'bad_session', '', '', '');
    }
    return new ParsedWechatAuthResponse(true, '', '', session, scope);
  }

  static requiresAccountSwitch(scope: string, anonymousAccountId: string): boolean {
    const accountId: string = anonymousAccountId.trim();
    if (accountId.length === 0 || !/^users\/[^/]+\/$/.test(scope)) return false;
    return scope !== `users/${accountId}/`;
  }

  static message(error: string, detail: string): string {
    if (detail.trim().length > 0) return detail.trim();
    if (error === 'missing_code' || error === 'missing code') return '微信登录没有返回授权码';
    if (error === 'invalid wechat code') return '微信授权已失效，请重新登录';
    if (error === 'wechat appid mismatch') return '微信应用配置不匹配';
    if (error.startsWith('server misconfigured:')) return '微信登录服务尚未配置';
    if (error === 'bad_session') return '服务端返回了无效登录会话';
    return '微信登录服务请求失败';
  }

  private static isSessionToken(token: string): boolean {
    const parts: string[] = token.split('.');
    return parts.length === 3 &&
      parts.every((part: string) => part.length >= 8 && /^[A-Za-z0-9_-]+$/.test(part));
  }
}
