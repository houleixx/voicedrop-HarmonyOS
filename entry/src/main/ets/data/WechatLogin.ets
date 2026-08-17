import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { SendAuthReq, WXApi, WXAPIFactory } from '@tencent/wechat_open_sdk';
import { WechatLoginState } from '../core/WechatLoginState';

export class WechatLogin {
  static readonly APP_ID: string = 'wx1573f936967f5420';
  private static readonly STORE_NAME: string = 'voicedrop.wechat.login';
  private static readonly STATE_KEY: string = 'pendingState';
  private static readonly ISSUED_AT_KEY: string = 'issuedAt';
  private static api?: WXApi;

  static async start(context: common.UIAbilityContext): Promise<boolean> {
    const api: WXApi = WechatLogin.wxApi();
    if (!api.isWXAppInstalled()) return false;
    const state: string =
      `${WechatLoginState.PREFIX}${util.generateRandomUUID(true).replace(/-/g, '')}`;
    await WechatLogin.savePendingState(context, state);
    const request: SendAuthReq = new SendAuthReq();
    request.scope = 'snsapi_userinfo';
    request.state = state;
    request.callbackAbility = 'EntryAbility';
    try {
      const result: boolean | Promise<boolean> = api.sendReq(context, request);
      const sent: boolean = typeof result === 'boolean' ? result : await result;
      if (!sent) await WechatLogin.clearPendingState(context);
      return sent;
    } catch (error) {
      await WechatLogin.clearPendingState(context);
      throw new Error(String(error));
    }
  }

  static async consumeState(context: common.Context, returnedState: string): Promise<boolean> {
    const store: preferences.Preferences =
      await preferences.getPreferences(context, { name: WechatLogin.STORE_NAME });
    const pendingState: string = String(store.getSync(WechatLogin.STATE_KEY, '') ?? '');
    const issuedAt: number = Number(store.getSync(WechatLogin.ISSUED_AT_KEY, 0) ?? 0);
    const now: number = Date.now();
    const valid: boolean =
      WechatLoginState.isValid(pendingState, returnedState.trim(), issuedAt, now);
    const pendingActive: boolean =
      WechatLoginState.isValid(pendingState, pendingState, issuedAt, now);
    if (valid || !pendingActive) {
      store.deleteSync(WechatLogin.STATE_KEY);
      store.deleteSync(WechatLogin.ISSUED_AT_KEY);
      await store.flush();
    }
    return valid;
  }

  static wxApi(): WXApi {
    if (!WechatLogin.api) WechatLogin.api = WXAPIFactory.createWXAPI(WechatLogin.APP_ID);
    return WechatLogin.api;
  }

  private static async savePendingState(context: common.Context, state: string): Promise<void> {
    const store: preferences.Preferences =
      await preferences.getPreferences(context, { name: WechatLogin.STORE_NAME });
    store.putSync(WechatLogin.STATE_KEY, state);
    store.putSync(WechatLogin.ISSUED_AT_KEY, Date.now());
    await store.flush();
  }

  private static async clearPendingState(context: common.Context): Promise<void> {
    const store: preferences.Preferences =
      await preferences.getPreferences(context, { name: WechatLogin.STORE_NAME });
    store.deleteSync(WechatLogin.STATE_KEY);
    store.deleteSync(WechatLogin.ISSUED_AT_KEY);
    await store.flush();
  }
}
