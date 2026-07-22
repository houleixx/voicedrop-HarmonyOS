import { Api } from '../core/Api';
import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';

class WechatCodeBody {
  code: string;
  constructor(code: string) { this.code = code; }
}
interface WechatAuthWire { error?: string; detail?: string; session?: string; scope?: string; }

export class WechatAuthResult {
  ok: boolean; error: string; detail: string; session: string; scope: string;
  constructor(ok: boolean, error: string, detail: string, session: string, scope: string) {
    this.ok = ok; this.error = error; this.detail = detail; this.session = session; this.scope = scope;
  }
}

export class WechatAuthStore {
  static async exchange(code: string): Promise<WechatAuthResult> {
    const response: HttpResponse = await httpClient.postJson(`${Api.FILES}/auth/wechat`, authStore.anonymousBearer(),
      new WechatCodeBody(code));
    let wire: WechatAuthWire = {};
    try { wire = JSON.parse(response.text || '{}') as WechatAuthWire; } catch (_) {}
    if (!response.ok()) return new WechatAuthResult(false, wire.error ?? 'wechat_auth_failed', wire.detail ?? '', '', '');
    const session: string = wire.session ?? ''; const scope: string = wire.scope ?? '';
    return new WechatAuthResult(session.length > 0 && scope.length > 0, session.length > 0 ? '' : 'bad_session', '', session, scope);
  }
}
