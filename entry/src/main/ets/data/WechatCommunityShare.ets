import { common } from '@kit.AbilityKit';
import {
  SendMessageToWXReq,
  WXMediaMessage,
  WXMiniProgramObject,
  WXMiniProgramType
} from '@tencent/wechat_open_sdk';
import { Api } from '../core/Api';
import { WechatLogin } from './WechatLogin';

export class WechatCommunityShare {
  private static readonly MINI_PROGRAM_ORIGINAL_ID: string = 'gh_451de6440ef4';

  static async send(context: common.UIAbilityContext, shareId: string, title: string): Promise<string> {
    if (!WechatLogin.wxApi().isWXAppInstalled()) return '未安装微信';

    const miniProgram: WXMiniProgramObject = new WXMiniProgramObject();
    miniProgram.webpageUrl = Api.sharePage(shareId);
    miniProgram.userName = WechatCommunityShare.MINI_PROGRAM_ORIGINAL_ID;
    miniProgram.path =
      `pages/community-detail/index?shareId=${encodeURIComponent(shareId.trim())}&fromShare=1`;
    miniProgram.withShareTicket = false;
    miniProgram.miniprogramType = WXMiniProgramType.RELEASE;
    miniProgram.disableForward = false;
    miniProgram.isUpdatableMessage = false;
    miniProgram.isSecretMessage = false;

    const message: WXMediaMessage = new WXMediaMessage();
    message.title = title.trim().length > 0 ? title.trim().substring(0, 128) : 'VoiceDrop 文章';
    message.description = '打开 VoiceDrop 小程序阅读全文';
    message.mediaObject = miniProgram;
    try {
      message.thumbData = await context.resourceManager.getRawFileContent('voicedrop-share-thumb.jpg');
    } catch (_) {}

    const request: SendMessageToWXReq = new SendMessageToWXReq();
    request.transaction = `voicedrop-community-share-${Date.now()}`;
    request.callbackAbility = 'EntryAbility';
    request.message = message;
    request.scene = SendMessageToWXReq.WXSceneSession;
    const result: boolean | Promise<boolean> = WechatLogin.wxApi().sendReq(context, request);
    return (typeof result === 'boolean' ? result : await result)
      ? '已打开微信，请选择好友发送小程序卡片'
      : '微信未能发起分享';
  }
}
