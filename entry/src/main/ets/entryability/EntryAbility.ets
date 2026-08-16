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
    if (response instanceof SendAuthResp) {
      this.handleWechatAuthResponse(response).catch((error: Object) => {
        hilog.error(0x0000, 'VoiceDrop', 'handle WeChat response failed: %{public}s', JSON.stringify(error));
        this.publishWechatCallback('', '微信登录回调处理失败，请重试');
      });
      return;
    }
    let message: string = '';
    if ((response.transaction ?? '').startsWith('voicedrop-community-share-') ||
      (response.transaction ?? '').startsWith('voicedrop-book-share-')) {
      if (response.errCode === ErrCode.ERR_USER_CANCEL) message = '已取消微信分享';
      else if (response.errCode !== ErrCode.ERR_OK) message = response.errStr?.trim() || '微信分享失败';
      else return;
    } else {
      return;
    }
    this.publishWechatCallback('', message);
  }

  private async handleWechatAuthResponse(response: SendAuthResp): Promise<void> {
    const validState: boolean = await WechatLogin.consumeState(this.context, response.state ?? '');
    if (!validState) {
      this.publishWechatCallback('', '微信登录返回无效，请重新发起登录');
      return;
    }
    if (response.errCode === ErrCode.ERR_USER_CANCEL) {
      this.publishWechatCallback('', '已取消微信登录');
      return;
    }
    if (response.errCode !== ErrCode.ERR_OK) {
      const fallback: string = response.errCode === ErrCode.ERR_AUTH_DENIED ? '微信授权未通过' : '微信登录失败';
      this.publishWechatCallback('', response.errStr?.trim() || fallback);
      return;
    }
    const code: string = response.code?.trim() ?? '';
    this.publishWechatCallback(code, code.length > 0 ? '' : '微信登录返回无效，请重新发起登录');
  }

  private publishWechatCallback(code: string, message: string): void {
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
        // Keep the status bar transparent so root-level ArkUI backgrounds and
        // modal scrims are composited behind it in the same animation frame.
        statusBarColor: '#00000000',
        statusBarContentColor: '#2A2521',
        isStatusBarLightIcon: false,
        navigationBarColor: '#FAF6EF',
        navigationBarContentColor: '#2A2521',
        isNavigationBarLightIcon: false
      }).catch((error: Object) => {
        hilog.error(0x0000, 'VoiceDrop', 'set system bar properties failed: %{public}s', JSON.stringify(error));
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
