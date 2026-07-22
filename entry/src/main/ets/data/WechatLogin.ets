import { common } from '@kit.AbilityKit';
import { SendAuthReq, WXApi, WXAPIFactory } from '@tencent/wechat_open_sdk';

export class WechatLogin {
  static readonly APP_ID: string = 'wx1573f936967f5420';
  static readonly STATE: string = 'voicedrop_harmonyos_wechat_login';
  private static readonly api: WXApi = WXAPIFactory.createWXAPI(WechatLogin.APP_ID);

  static async start(context: common.UIAbilityContext): Promise<boolean> {
    if (!WechatLogin.api.isWXAppInstalled()) return false;
    const request: SendAuthReq = new SendAuthReq();
    request.scope = 'snsapi_userinfo';
    request.state = WechatLogin.STATE;
    request.callbackAbility = 'EntryAbility';
    const result: boolean | Promise<boolean> = WechatLogin.api.sendReq(context, request);
    return typeof result === 'boolean' ? result : await result;
  }

  static wxApi(): WXApi { return WechatLogin.api; }
}
