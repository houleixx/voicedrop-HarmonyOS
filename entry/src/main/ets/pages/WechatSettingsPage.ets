import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { WechatAuthorizationPage, WechatBindStatus, WechatBinding, WechatQrCropRegion } from '../core/WechatBinding';
import { settingsStore } from '../data/SettingsStore';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

@Component
export struct WechatSettingsPage {
  onBack: () => void = () => {};
  @Prop @Watch('onForegroundSequence') foregroundSequence: number = 0;
  @State private loading: boolean = true;
  @State private disconnecting: boolean = false;
  @State private connected: boolean = false;
  @State private accountName: string = '';
  @State private authorizationVisible: boolean = false;
  @State private authorizationLoading: boolean = false;
  @State private authorizationSaving: boolean = false;
  @State private authorizationHtml: string = '';
  @State private authorizationBaseUrl: string = '';
  @State private authorizationTitle: string = '授权公众号';
  private authorizationController: webview.WebviewController = new webview.WebviewController();
  private authorizationControllerReady: boolean = false;
  private authorizationLoadStarted: boolean = false;
  private qrAttemptSequence: number = 0;

  aboutToAppear(): void {
    webview.WebviewController.enableWholeWebPageDrawing();
    const cached: WechatBindStatus | undefined = settingsStore.cachedWechatBindStatus();
    if (cached) {
      this.applyStatus(cached);
      this.loading = false;
    }
    this.refreshStatus(!cached);
  }

  private onForegroundSequence(): void {
    if (!this.loading && !this.authorizationVisible) {
      this.refreshStatus(false);
    }
  }

  private applyStatus(status: WechatBindStatus): void {
    this.connected = status.connected;
    this.accountName = status.accountName;
  }

  private async refreshStatus(showLoading: boolean = false): Promise<void> {
    if (showLoading) this.loading = true;
    try {
      const status: WechatBindStatus = await settingsStore.wechatBindStatus();
      this.applyStatus(status);
    } catch (_) {
      if (showLoading) {
        this.connected = false;
        this.accountName = '';
        promptAction.showToast({ message: '连接状态加载失败' });
      }
    } finally {
      if (showLoading) this.loading = false;
    }
  }

  private connectWechat(): void {
    if (this.disconnecting) return;
    this.authorizationTitle = this.connected ? '重新授权公众号' : '授权公众号';
    this.authorizationHtml = '';
    this.authorizationBaseUrl = '';
    this.authorizationControllerReady = false;
    this.authorizationLoadStarted = false;
    this.authorizationLoading = true;
    this.authorizationVisible = true;
    this.requestAuthorizationPage();
  }

  private async requestAuthorizationPage(): Promise<void> {
    try {
      const status: WechatBindStatus = await settingsStore.wechatBindStatus();
      this.applyStatus(status);
      this.authorizationTitle = this.connected ? '重新授权公众号' : '授权公众号';
    } catch (_) {}
    try {
      const page: WechatAuthorizationPage = await settingsStore.createWechatAuthorizationPage();
      if (page.html.length === 0) {
        promptAction.showToast({ message: '暂时无法打开公众号授权页' });
        this.authorizationLoading = false;
        return;
      }
      this.authorizationTitle = this.connected ? '重新授权公众号' : '授权公众号';
      this.authorizationHtml = page.html;
      this.authorizationBaseUrl = page.scanUrl;
      this.loadAuthorizationPage();
    } catch (_) {
      this.authorizationLoading = false;
      promptAction.showToast({ message: '无法打开公众号授权页，请稍后重试' });
    }
  }

  private closeAuthorization(): void {
    this.qrAttemptSequence++;
    this.authorizationVisible = false;
    this.authorizationLoading = false;
    this.authorizationControllerReady = false;
    this.authorizationLoadStarted = false;
    this.authorizationHtml = '';
    this.authorizationBaseUrl = '';
    this.refreshStatus(false);
  }

  private loadAuthorizationPage(): void {
    if (!this.authorizationControllerReady || this.authorizationLoadStarted ||
      this.authorizationHtml.length === 0 || this.authorizationBaseUrl.length === 0) return;
    try {
      this.authorizationLoadStarted = true;
      this.authorizationController.loadData(this.authorizationHtml, 'text/html', 'UTF-8',
        this.authorizationBaseUrl, this.authorizationBaseUrl);
    } catch (_) {
      this.authorizationLoading = false;
      promptAction.showToast({ message: '授权页加载失败，请稍后重试' });
    }
  }

  private centerQrWhenReady(): void {
    const sequence: number = ++this.qrAttemptSequence;
    this.centerQr(sequence, 0);
  }

  private centerQr(sequence: number, attempt: number): void {
    setTimeout(async (): Promise<void> => {
      if (sequence !== this.qrAttemptSequence || !this.authorizationVisible) return;
      try {
        const script: string = '(function(){var all=[].slice.call(document.querySelectorAll(' +
          '\'img,canvas,svg,[class*=qr],[id*=qr],[class*=code],[id*=code]\'));' +
          'var qr=all.map(function(e){return {e:e,r:e.getBoundingClientRect()};})' +
          '.filter(function(x){return x.r.width>=100&&x.r.height>=100&&x.r.width/x.r.height>.65&&x.r.width/x.r.height<1.35;})' +
          '.sort(function(a,b){return b.r.width*b.r.height-a.r.width*a.r.height;})[0];' +
          'if(!qr)return false;var r=qr.r,root=document.scrollingElement||document.documentElement||document.body;' +
          'var x=Math.max(0,root.scrollLeft+r.left-(window.innerWidth-r.width)/2);' +
          'var y=Math.max(0,root.scrollTop+r.top-(window.innerHeight-r.height)/2);' +
          'root.scrollLeft=x;root.scrollTop=y;document.body.scrollLeft=x;document.body.scrollTop=y;' +
          'document.documentElement.scrollLeft=x;document.documentElement.scrollTop=y;window.scrollTo(x,y);return true;})()';
        const result: string = await this.authorizationController.runJavaScript(script);
        if (result === 'true') {
          this.authorizationLoading = false;
        } else if (attempt < 6) {
          this.centerQr(sequence, attempt + 1);
        } else {
          this.authorizationLoading = false;
        }
      } catch (_) {
        if (attempt < 6) this.centerQr(sequence, attempt + 1);
        else this.authorizationLoading = false;
      }
    }, 500 + attempt * 350);
  }

  private snapshotWebPage(): Promise<webview.SnapshotResult> {
    return new Promise((resolve: (value: webview.SnapshotResult) => void,
      reject: (reason?: Object) => void): void => {
      this.authorizationController.webPageSnapshot({ size: { width: '100%', height: '100%' } },
        (error: BusinessError, result: webview.SnapshotResult): void => {
          if (error) reject(error);
          else resolve(result);
        });
    });
  }

  private async cropToQr(pixelMap: image.PixelMap): Promise<void> {
    const script: string = '(function(){var all=[].slice.call(document.querySelectorAll(' +
      '\'img,canvas,svg,[class*=qr],[id*=qr],[class*=code],[id*=code]\'));' +
      'var qr=all.map(function(e){return {e:e,r:e.getBoundingClientRect()};})' +
      '.filter(function(x){return x.r.width>=100&&x.r.height>=100&&x.r.width/x.r.height>.65&&x.r.width/x.r.height<1.35;})' +
      '.sort(function(a,b){return b.r.width*b.r.height-a.r.width*a.r.height;})[0];' +
      'if(!qr)return \"\";var r=qr.r,root=document.scrollingElement||document.documentElement||document.body;' +
      'var w=Math.max(root.scrollWidth,document.documentElement.scrollWidth,document.body.scrollWidth);' +
      'var h=Math.max(root.scrollHeight,document.documentElement.scrollHeight,document.body.scrollHeight);' +
      'return [r.left+root.scrollLeft,r.top+root.scrollTop,r.width,r.height,w,h].join(\",\");})()';
    const bounds: string = await this.authorizationController.runJavaScript(script);
    const info: image.ImageInfo = await pixelMap.getImageInfo();
    const region: WechatQrCropRegion = WechatBinding.qrCropRegion(bounds, info.size.width, info.size.height);
    if (region.width <= 0 || region.height <= 0) throw new Error('未找到二维码区域');
    await pixelMap.crop({ x: region.x, y: region.y, size: { width: region.width, height: region.height } });
  }

  private async saveQrScreenshot(): Promise<void> {
    if (this.authorizationSaving || this.authorizationLoading) {
      if (this.authorizationLoading) promptAction.showToast({ message: '二维码还在加载，请稍后再试' });
      return;
    }
    this.authorizationSaving = true;
    let pixelMap: image.PixelMap | undefined;
    let packer: image.ImagePacker | undefined;
    try {
      const snapshot: webview.SnapshotResult = await this.snapshotWebPage();
      pixelMap = snapshot.imagePixelMap;
      if (snapshot.status !== true || !pixelMap) throw new Error('网页截图失败');
      await this.cropToQr(pixelMap);
      packer = image.createImagePacker();
      const png: ArrayBuffer = await packer.packToData(pixelMap, {
        format: 'image/png', quality: 100, bufferSize: 12 * 1024 * 1024
      });
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const path: string = `${context.cacheDir}/VoiceDrop-公众号授权-${Date.now()}.png`;
      const output: fs.File = fs.openSync(path,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try { fs.writeSync(output.fd, png); } finally { fs.closeSync(output); }
      const saved: string[] = await photoAccessHelper.getPhotoAccessHelper(context).showAssetsCreationDialog(
        [fileUri.getUriFromPath(path)], [{
          title: 'VoiceDrop-公众号授权',
          fileNameExtension: 'png',
          photoType: photoAccessHelper.PhotoType.IMAGE
        }]);
      if (saved.length > 0) {
        const asset: fs.File = fs.openSync(saved[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try {
          fs.writeSync(asset.fd, png);
          fs.fsyncSync(asset.fd);
        } finally {
          fs.closeSync(asset);
        }
        await promptAction.showDialog({
          title: '二维码已保存到相册',
          message: '请打开微信，进入「扫一扫」后点击页面上的「相册」，选择刚保存的二维码完成公众号授权。',
          buttons: [{ text: '知道了', color: Theme.ACCENT_STRONG }]
        });
      }
    } catch (_) {
      promptAction.showToast({ message: '截图保存失败，请使用系统截图' });
    } finally {
      if (pixelMap) {
        try { await pixelMap.release(); } catch (_) {}
      }
      if (packer) {
        try { await packer.release(); } catch (_) {}
      }
      this.authorizationSaving = false;
    }
  }

  private async disconnectWechat(): Promise<void> {
    if (this.disconnecting) return;
    const confirmation = await promptAction.showDialog({
      title: '取消连接？',
      message: '取消后，VoiceDrop 将不能再向这个公众号保存或更新草稿。',
      buttons: [{ text: '暂不取消', color: Theme.SECONDARY }, { text: '取消连接', color: Theme.ACCENT_STRONG }]
    });
    if (confirmation.index !== 1) return;
    this.disconnecting = true;
    try {
      if (!await settingsStore.unbindWechat()) {
        promptAction.showToast({ message: '取消连接失败，请稍后重试' });
        return;
      }
      promptAction.showToast({ message: '已取消公众号连接' });
      await this.refreshStatus();
    } catch (_) {
      promptAction.showToast({ message: '取消连接失败，请稍后重试' });
    } finally {
      this.disconnecting = false;
    }
  }

  @Builder
  private authorizationHeader() {
    Stack({ alignContent: Alignment.Center }) {
      Text(this.authorizationTitle)
        .fontSize(23).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: '46%' })
      Row() {
        Button({ type: ButtonType.Normal }) {
          RemixIcon({ glyph: RI.ARROW_LEFT, iconSize: 25, color: Theme.INK })
        }
          .width(40).height(40).padding(0).backgroundColor(Theme.CARD)
          .border({ width: 1, color: Theme.BORDER, radius: 11 }).borderRadius(11).clip(true)
          .stateEffect(false).onClick(() => this.closeAuthorization())
        Blank()
        Button(this.authorizationSaving ? '正在保存…' : '截图二维码')
          .height(40).padding({ left: 13, right: 13 }).fontSize(14).fontWeight(FontWeight.Bold)
          .fontColor(Theme.WHITE).backgroundColor(Theme.ACCENT).borderRadius(10)
          .enabled(!this.authorizationSaving && !this.authorizationLoading)
          .onClick(() => this.saveQrScreenshot())
      }.width('100%').padding({ left: 16, right: 16 })
    }.width('100%').height(56)
  }

  @Builder
  private authorizationContent() {
    Column() {
      this.authorizationHeader()
      Stack({ alignContent: Alignment.Center }) {
        Web({
          src: 'about:blank',
          controller: this.authorizationController,
          renderMode: RenderMode.SYNC_RENDER
        })
          .width('100%').height(360)
          .javaScriptAccess(true).domStorageAccess(true).fileAccess(false)
          .mixedMode(MixedMode.None)
          .onOverrideUrlLoading((request: WebResourceRequest): boolean =>
            !WechatBinding.isTrustedAuthorizationNavigation(request.getRequestUrl()))
          .onPageEnd((event: OnPageEndEvent): void => {
            if (event.url === 'about:blank') {
              this.authorizationControllerReady = true;
              this.loadAuthorizationPage();
              return;
            }
            this.centerQrWhenReady();
          })
          .onErrorReceive((event: OnErrorReceiveEvent): void => {
            if (event.request.isMainFrame()) {
              this.authorizationLoading = false;
              promptAction.showToast({ message: '授权页加载失败，请检查网络后重试' });
            }
          })
        if (this.authorizationLoading) {
          Column({ space: 10 }) {
            LoadingProgress().width(28).height(28).color(Theme.ACCENT_STRONG)
            Text('二维码加载中…').fontSize(14).fontColor(Theme.SECONDARY)
          }
            .padding({ left: 22, right: 22, top: 18, bottom: 18 })
            .backgroundColor(Theme.CARD).borderRadius(14)
            .alignItems(HorizontalAlign.Center)
        }
      }.width('100%').height(360)
      Text((this.connected ? '重新授权会更新当前公众号的授权信息。\n\n' : '') +
        '进入微信授权二维码页后：\n1. 点右上角「截图二维码」，保存二维码\n2. 打开微信「扫一扫」后，点击页面上的「相册」，选择刚才保存的二维码\n\n授权过程中请勿关闭此页面；看到“授权成功”后，再返回 VoiceDrop。')
        .width('100%').fontSize(13).lineHeight(20).fontColor(Theme.SECONDARY)
        .padding({ left: 20, right: 20, top: 14, bottom: 20 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor(Theme.BG)
  }

  @Builder
  private connectionContent() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.connected) {
          Circle().width(56).height(56).fill(Theme.GREEN)
          RemixIcon({ glyph: RI.CHECK, iconSize: 34, color: Theme.WHITE })
        } else {
          Circle().width(56).height(56).fill(Theme.ACCENT_SOFT)
          RemixIcon({ glyph: RI.SEND_PLANE, iconSize: 34, color: Theme.ACCENT })
        }
      }.width('100%').height(62).margin({ bottom: 12 })

      Text(this.connected ? '已连接微信公众号' : '未连接微信公众号')
        .width('100%').textAlign(TextAlign.Center).fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
      Text(this.connected ? '授权成功，现在可以将文章保存或更新到公众号草稿箱。' :
        '连接后，VoiceDrop 可以将文章保存到你的公众号草稿箱。不会自动群发。')
        .width('100%').textAlign(TextAlign.Center).fontSize(15).lineHeight(22).fontColor(Theme.SECONDARY)
        .padding({ left: 18, right: 18 }).margin({ top: 10, bottom: 28 })

      if (this.connected) {
        Column({ space: 5 }) {
          Text('已授权账号').fontSize(12).fontWeight(FontWeight.Bold).fontColor(Theme.GREEN)
          Text(this.accountName.length > 0 ? this.accountName : '微信公众号')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
          Text('草稿箱已就绪 · VoiceDrop 不会自动群发').fontSize(13).fontColor(Theme.SECONDARY)
        }
          .width('100%').alignItems(HorizontalAlign.Start).padding({ left: 18, right: 18, top: 14, bottom: 14 })
          .backgroundColor('#FFF1F7F2').border({ width: 1, color: '#FFD3E4D7' }).borderRadius(14)
          .margin({ bottom: 24 })
      }

      Button(this.connected ? (this.disconnecting ? '正在取消连接…' : '取消连接') : '连接微信公众号')
        .width('100%').height(56).fontSize(this.connected ? 16 : 18).fontWeight(FontWeight.Bold)
        .fontColor(this.connected ? Theme.SECONDARY : Theme.WHITE)
        .backgroundColor(this.connected ? Color.Transparent : Theme.ACCENT)
        .border(this.connected ? { width: 1, color: Theme.BORDER } : { width: 0 })
        .borderRadius(10).enabled(!this.disconnecting)
        .onClick(() => this.connected ? this.disconnectWechat() : this.connectWechat())

      if (!this.connected) {
        Column({ space: 8 }) {
          Text('连接方法').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
          Text('1. 在授权页面打开二维码后，点右上角「截图二维码」，保存二维码')
            .fontSize(13).lineHeight(20).fontColor(Theme.SECONDARY)
          Text('2. 打开微信「扫一扫」后，点击页面上的「相册」，选择刚才保存的二维码完成授权')
            .fontSize(13).lineHeight(20).fontColor(Theme.SECONDARY)
        }
          .width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Theme.CARD)
          .border({ width: 1, color: Theme.BORDER }).borderRadius(14).margin({ top: 18 })
      }
    }
      .width('100%').height('100%')
      .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Start)
  }

  build() {
    if (this.authorizationVisible) {
      this.authorizationContent()
    } else {
      Column() {
        PageHeader({ title: '微信公众号', onBack: this.onBack })
        if (this.loading) {
          Column({ space: 14 }) {
            LoadingProgress().width(40).height(40).color(Theme.ACCENT_STRONG)
            Text('正在检查公众号连接状态…').fontSize(16).fontColor(Theme.SECONDARY)
          }
            .width('100%').height(180).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            .margin({ top: 24 })
        } else {
          Scroll() {
            this.connectionContent()
          }
            .layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .padding({ left: 20, right: 20, top: 10, bottom: 28 })
        }
      }
        .width('100%').height('100%').justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
        .backgroundColor(Theme.BG)
    }
  }
}
