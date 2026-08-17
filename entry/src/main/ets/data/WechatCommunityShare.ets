import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import {
  SendMessageToWXReq,
  WXMediaMessage,
  WXMiniProgramObject,
  WXMiniProgramType,
  WXWebpageObject
} from '@tencent/wechat_open_sdk';
import { Api } from '../core/Api';
import { WechatBookShare, WechatBookShareTarget, WechatBookShareTargetValue } from '../core/WechatBookShare';
import { WechatShareContent } from '../core/WechatShareContent';
import { BinaryResponse, httpClient } from '../net/HttpClient';
import { ShelfBook } from './BooksService';
import { WechatLogin } from './WechatLogin';

export class WechatCommunityShare {
  private static readonly MINI_PROGRAM_ORIGINAL_ID: string = 'gh_451de6440ef4';
  private static readonly THUMBNAIL_LIMIT_BYTES: number = 64 * 1024;

  static isWechatInstalled(): boolean { return WechatLogin.wxApi().isWXAppInstalled(); }

  static async send(context: common.UIAbilityContext, shareId: string, articleIndex: number,
    title: string, description: string, thumbnailUrl: string = ''): Promise<string> {
    const thumbnail: Uint8Array = await WechatCommunityShare.thumbnail(context, thumbnailUrl);
    return WechatCommunityShare.sendCard(
      context,
      WechatShareContent.withSection(Api.sharePage(shareId), articleIndex),
      WechatShareContent.communityMiniProgramPath(shareId, articleIndex),
      title,
      description,
      thumbnail,
      'voicedrop-community-share-',
      SendMessageToWXReq.WXSceneSession
    );
  }

  static async sendPublicArticle(context: common.UIAbilityContext, webpageUrl: string, articleIndex: number,
    title: string, description: string, thumbnailUrl: string = ''): Promise<string> {
    const path: string = WechatShareContent.publicMiniProgramPath(webpageUrl, articleIndex);
    if (path.length === 0) return '无法生成小程序分享卡片';
    return WechatCommunityShare.sendCard(
      context, webpageUrl, path, title, description,
      await WechatCommunityShare.thumbnail(context, thumbnailUrl),
      'voicedrop-article-share-', SendMessageToWXReq.WXSceneSession
    );
  }

  static async sendBook(
    context: common.UIAbilityContext,
    book: ShelfBook,
    share: WechatBookShareTargetValue,
    target: WechatBookShareTarget = 'friend'
  ): Promise<string> {
    let thumbnail: Uint8Array = await context.resourceManager.getRawFileContent('voicedrop-share-thumb.jpg');
    if (book.cover) {
      try {
        const response: BinaryResponse = await httpClient.getBytes(book.coverUrl());
        if (response.ok()) thumbnail = await WechatCommunityShare.imageThumbnail(response.data);
      } catch (_) {}
    }
    return WechatCommunityShare.sendWebpage(
      context,
      share.url,
      share.title,
      share.isChapter ? WechatBookShare.title(book.title, book.main, book.author) : 'VoiceDrop 图书馆 · 点开即读',
      thumbnail,
      WechatBookShare.isTimeline(target) ?
        SendMessageToWXReq.WXSceneTimeline : SendMessageToWXReq.WXSceneSession
    );
  }

  static async sendTimeline(
    context: common.UIAbilityContext,
    webpageUrl: string,
    title: string,
    description: string
  ): Promise<string> {
    const thumbnail: Uint8Array = await WechatCommunityShare.thumbnail(context, '');
    return WechatCommunityShare.sendWebpage(
      context,
      webpageUrl,
      title,
      description,
      thumbnail,
      SendMessageToWXReq.WXSceneTimeline
    );
  }

  static async sendTimelineWithThumbnail(
    context: common.UIAbilityContext,
    webpageUrl: string,
    title: string,
    description: string,
    thumbnailUrl: string
  ): Promise<string> {
    return WechatCommunityShare.sendWebpage(
      context, webpageUrl, title, description,
      await WechatCommunityShare.thumbnail(context, thumbnailUrl),
      SendMessageToWXReq.WXSceneTimeline
    );
  }

  private static async sendCard(
    context: common.UIAbilityContext,
    webpageUrl: string,
    path: string,
    title: string,
    description: string,
    thumbnail: Uint8Array,
    transactionPrefix: string,
    scene: number
  ): Promise<string> {
    if (!WechatLogin.wxApi().isWXAppInstalled()) return '未安装微信';

    const miniProgram: WXMiniProgramObject = new WXMiniProgramObject();
    miniProgram.webpageUrl = webpageUrl;
    miniProgram.userName = WechatCommunityShare.MINI_PROGRAM_ORIGINAL_ID;
    miniProgram.path = path;
    miniProgram.withShareTicket = false;
    miniProgram.miniprogramType = WXMiniProgramType.RELEASE;
    miniProgram.disableForward = false;
    miniProgram.isUpdatableMessage = false;
    miniProgram.isSecretMessage = false;

    const message: WXMediaMessage = new WXMediaMessage();
    const cleanTitle: string = title.trim();
    message.title = cleanTitle.length > 0 ? cleanTitle.substring(0, 128) : 'VoiceDrop';
    message.description = description;
    message.mediaObject = miniProgram;
    message.thumbData = thumbnail;

    const request: SendMessageToWXReq = new SendMessageToWXReq();
    request.transaction = `${transactionPrefix}${Date.now()}`;
    request.callbackAbility = 'EntryAbility';
    request.message = message;
    request.scene = scene;
    const result: boolean | Promise<boolean> = WechatLogin.wxApi().sendReq(context, request);
    return (typeof result === 'boolean' ? result : await result)
      ? (scene === SendMessageToWXReq.WXSceneTimeline ? '已打开微信，请确认分享到朋友圈' :
        '已打开微信，请选择好友发送小程序卡片')
      : '微信未能发起分享';
  }

  private static async sendWebpage(
    context: common.UIAbilityContext,
    webpageUrl: string,
    title: string,
    description: string,
    thumbnail: Uint8Array,
    scene: number
  ): Promise<string> {
    if (!WechatLogin.wxApi().isWXAppInstalled()) return '未安装微信';

    const webpage: WXWebpageObject = new WXWebpageObject();
    webpage.webpageUrl = webpageUrl;

    const message: WXMediaMessage = new WXMediaMessage();
    const cleanTitle: string = title.trim();
    message.title = cleanTitle.length > 0 ? cleanTitle.substring(0, 128) : 'VoiceDrop 分享';
    message.description = description;
    message.mediaObject = webpage;
    message.thumbData = thumbnail;

    const request: SendMessageToWXReq = new SendMessageToWXReq();
    request.transaction = `voicedrop-webpage-share-${Date.now()}`;
    request.callbackAbility = 'EntryAbility';
    request.message = message;
    request.scene = scene;
    const result: boolean | Promise<boolean> = WechatLogin.wxApi().sendReq(context, request);
    if (!(typeof result === 'boolean' ? result : await result)) return '微信未能发起分享';
    return scene === SendMessageToWXReq.WXSceneTimeline ?
      '已打开微信，请确认分享到朋友圈' : '已打开微信，请选择好友';
  }

  private static async imageThumbnail(bytes: ArrayBuffer): Promise<Uint8Array> {
    const source: image.ImageSource = image.createImageSource(bytes);
    const packer: image.ImagePacker = image.createImagePacker();
    let pixelMap: image.PixelMap | undefined;
    try {
      const info: image.ImageInfo = await source.getImageInfo();
      const scale: number = Math.min(1, 256 / Math.max(info.size.width, info.size.height));
      pixelMap = await source.createPixelMap({
        desiredSize: {
          width: Math.max(1, Math.round(info.size.width * scale)),
          height: Math.max(1, Math.round(info.size.height * scale))
        },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const qualities: number[] = [82, 68, 52, 38];
      for (let index: number = 0; index < qualities.length; index++) {
        const packed: ArrayBuffer = await packer.packToData(pixelMap, {
          format: 'image/jpeg', quality: qualities[index], bufferSize: 256 * 1024
        });
        const thumbnail: Uint8Array = new Uint8Array(packed);
        if (thumbnail.byteLength <= WechatCommunityShare.THUMBNAIL_LIMIT_BYTES) return thumbnail;
      }
      throw new Error('微信分享缩略图过大');
    } finally {
      if (pixelMap) try { await pixelMap.release(); } catch (_) {}
      try { await source.release(); } catch (_) {}
      try { await packer.release(); } catch (_) {}
    }
  }

  private static async thumbnail(context: common.UIAbilityContext, url: string): Promise<Uint8Array> {
    if (url.length > 0) {
      try {
        const response: BinaryResponse = await httpClient.getBytes(url);
        if (response.ok() && response.data.byteLength > 0) {
          return await WechatCommunityShare.imageThumbnail(response.data);
        }
      } catch (_) {}
    }
    return context.resourceManager.getRawFileContent('voicedrop-share-thumb.jpg');
  }
}
