import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BaseReq, BaseResp, ErrCode, SendAuthResp, WXApiEventHandler } from '@tencent/wechat_open_sdk';
import { WechatLogin } from '../data/WechatLogin';

export default class EntryAbility extends UIAbility implements WXApiEventHandler {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.routeWant(want);
    hilog.info(0x0000, 'VoiceDrop', 'VoiceDrop created');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.routeWant(want);
  }

  onForeground(): void {
    const sequence: number = AppStorage.get<number>('foregroundSequence') ?? 0;
    AppStorage.setOrCreate<number>('foregroundSequence', sequence + 1);
  }

  onReq(request: BaseReq): void {}

  onResp(response: BaseResp): void {
    let code: string = ''; let message: string = '';
    if (response instanceof SendAuthResp) {
      if (response.errCode === ErrCode.ERR_OK && response.state === WechatLogin.STATE) code = response.code?.trim() ?? '';
      else if (response.errCode === ErrCode.ERR_USER_CANCEL) message = '已取消微信登录';
      else message = response.errStr?.trim() || '微信登录失败';
    } else if ((response.transaction ?? '').startsWith('voicedrop-community-share-')) {
      if (response.errCode === ErrCode.ERR_USER_CANCEL) message = '已取消微信分享';
      else if (response.errCode !== ErrCode.ERR_OK) message = response.errStr?.trim() || '微信分享失败';
      else return;
    } else {
      return;
    }
    if (code.length === 0 && message.length === 0) message = '微信登录返回无效';
    AppStorage.setOrCreate<string>('wechatCode', code);
    AppStorage.setOrCreate<string>('wechatMessage', message);
    const sequence: number = AppStorage.get<number>('wechatSequence') ?? 0;
    AppStorage.setOrCreate<number>('wechatSequence', sequence + 1);
  }

  private routeWant(want: Want): void {
    if (!WechatLogin.wxApi().handleWant(want, this)) this.saveWant(want);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true).catch((error: Object) => {
        hilog.error(0x0000, 'VoiceDrop', 'enable immersive layout failed: %{public}s', JSON.stringify(error));
      });
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#1F1F1F',
        isStatusBarLightIcon: false,
        navigationBarColor: '#00000000',
        navigationBarContentColor: '#777777',
        isNavigationBarLightIcon: false
      }).catch((error: Object) => {
        hilog.error(0x0000, 'VoiceDrop', 'set transparent system bars failed: %{public}s', JSON.stringify(error));
      });
      this.updateSafeAreas(mainWindow);
      mainWindow.on('avoidAreaChange', (options: window.AvoidAreaOptions) => {
        if (options.type === window.AvoidAreaType.TYPE_SYSTEM ||
          options.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) this.updateSafeAreas(mainWindow);
      });
    } catch (error) {
      hilog.error(0x0000, 'VoiceDrop', 'configure main window failed: %{public}s', JSON.stringify(error));
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'VoiceDrop', 'loadContent failed: %{public}s', JSON.stringify(err));
      }
    });
  }

  private updateSafeAreas(mainWindow: window.Window): void {
    try {
      const systemArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navigationArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate<number>('safeAreaTopPx', systemArea.topRect.height);
      AppStorage.setOrCreate<number>('safeAreaBottomPx', navigationArea.bottomRect.height);
      AppStorage.setOrCreate<number>('windowWidthPx', mainWindow.getWindowProperties().windowRect.width);
      AppStorage.setOrCreate<number>('windowHeightPx', mainWindow.getWindowProperties().windowRect.height);
    } catch (error) {
      AppStorage.setOrCreate<number>('safeAreaTopPx', 0);
      AppStorage.setOrCreate<number>('safeAreaBottomPx', 0);
      hilog.error(0x0000, 'VoiceDrop', 'read window safe area failed: %{public}s', JSON.stringify(error));
    }
  }

  private saveWant(want: Want): void {
    const shortcutUri: string = String(want.parameters?.['voicedrop.uri'] ?? '');
    AppStorage.setOrCreate<string>('launchUri', want.uri ?? shortcutUri);
    AppStorage.setOrCreate<string>('sharedText', String(want.parameters?.['ohos.extra.param.key.content'] ?? ''));
    AppStorage.setOrCreate<string>('sharedTitle', String(want.parameters?.['ohos.extra.param.key.contentTitle'] ?? ''));
    AppStorage.setOrCreate<string>('sharedMime', want.type ?? '');
    const streams: Object | undefined = want.parameters?.['ability.params.stream'];
    let uris: string[] = [];
    if (typeof streams === 'string') uris = [streams];
    else if (Array.isArray(streams)) uris = streams as string[];
    AppStorage.setOrCreate<string>('sharedUris', JSON.stringify(uris));
    const sequence: number = AppStorage.get<number>('shareSequence') ?? 0;
    AppStorage.setOrCreate<number>('shareSequence', sequence + 1);
  }
}
