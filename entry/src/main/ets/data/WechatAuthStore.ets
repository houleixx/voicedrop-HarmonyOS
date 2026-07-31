import { Api } from '../core/Api';
import { ParsedWechatAuthResponse, WechatAuthResponse } from '../core/WechatAuthResponse';
import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';

class WechatCodeBody {
  code: string;
  constructor(code: string) { this.code = code; }
}
export class WechatAuthResult {
  ok: boolean; error: string; detail: string; session: string; scope: string;
  constructor(ok: boolean, error: string, detail: string, session: string, scope: string) {
    this.ok = ok; this.error = error; this.detail = detail; this.session = session; this.scope = scope;
  }

  message(): string { return WechatAuthResponse.message(this.error, this.detail); }
}

export class WechatAuthStore {
  static async exchange(code: string): Promise<WechatAuthResult> {
    const cleanCode: string = code.trim();
    if (cleanCode.length === 0) {
      return new WechatAuthResult(false, 'missing_code', '', '', '');
    }
    const response: HttpResponse = await httpClient.postJson(`${Api.FILES}/auth/wechat`, authStore.anonymousBearer(),
      new WechatCodeBody(cleanCode));
    const parsed: ParsedWechatAuthResponse = WechatAuthResponse.parse(response.code, response.text);
    return new WechatAuthResult(parsed.ok, parsed.error, parsed.detail, parsed.session, parsed.scope);
  }
}
