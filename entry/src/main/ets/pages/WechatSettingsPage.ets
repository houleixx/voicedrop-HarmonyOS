import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { settingsStore, WechatSettings } from '../data/SettingsStore';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

const WECHAT_CONSOLE_URL: string = 'https://developers.weixin.qq.com/console/';
const WECHAT_SERVER_IP: string = '66.42.45.128';

@Component
export struct WechatSettingsPage {
  onBack: () => void = () => {};
  @State private appid: string = '';
  @State private secret: string = '';
  @State private isEnabled: boolean = false;
  @State private validating: boolean = false;
  @State private saved: boolean = false;
  @State private secretVisible: boolean = false;
  @State private errorText: string = '';

  aboutToAppear(): void {
    settingsStore.loadWechat().then((data: WechatSettings) => {
      this.appid = data.appid ?? '';
      this.secret = data.secret ?? '';
      this.isEnabled = data.enabled ?? false;
    });
  }

  private canSave(): boolean {
    return this.appid.trim().length > 0 && this.secret.trim().length > 0 && !this.validating;
  }

  private fieldChanged(): void {
    this.saved = false;
    this.errorText = '';
  }

  private async openWechatConsole(): Promise<void> {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: WECHAT_CONSOLE_URL
      });
    } catch (_) {
      promptAction.showToast({ message: '无法打开浏览器'});
    }
  }

  private async copyServerIp(): Promise<void> {
    await pasteboard.getSystemPasteboard().setData(pasteboard.createPlainTextData(WECHAT_SERVER_IP));
    promptAction.showToast({ message: 'IP 已复制'});
  }

  private async save(): Promise<void> {
    if (!this.canSave()) return;
    this.validating = true;
    this.saved = false;
    this.errorText = '';
    try {
      const formatError: string = settingsStore.wechatCredentialError(this.appid, this.secret);
      if (formatError.length > 0) {
        this.errorText = formatError;
        return;
      }
      const validation: string = await settingsStore.validateWechat(this.appid, this.secret);
      if (validation.length > 0) {
        this.errorText = validation;
        return;
      }
      const data: WechatSettings = new WechatSettings();
      data.appid = this.appid.trim();
      data.secret = this.secret.trim();
      data.enabled = this.isEnabled;
      if (!await settingsStore.saveWechat(data)) {
        this.errorText = '公众号配置保存失败，请稍后再试';
        return;
      }
      this.saved = true;
      promptAction.showToast({ message: '公众号配置已保存'});
    } catch (error) {
      this.errorText = `公众号配置失败：${String(error)}`;
    } finally {
      this.validating = false;
    }
  }

  @Builder
  private inputField() {
    TextInput({ text: this.appid, placeholder: 'AppID（wx...）' })
      .height(46)
      .fontSize(15)
      .fontColor(Theme.INK)
      .placeholderColor(Theme.FAINT)
      .padding({ left: 14, right: 14 })
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: Theme.BORDER })
      .borderRadius(7)
      .onChange((value: string) => {
        this.appid = value;
        this.fieldChanged();
      })
  }

  @Builder
  private secretField() {
    Row() {
      TextInput({ text: this.secret, placeholder: 'AppSecret' })
        .type(this.secretVisible ? InputType.Normal : InputType.Password)
        .layoutWeight(1)
        .height(44)
        .fontSize(15)
        .fontColor(Theme.INK)
        .placeholderColor(Theme.FAINT)
        .padding({ left: 14, right: 4 })
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => {
          this.secret = value;
          this.fieldChanged();
        })
      Button(this.secretVisible ? '隐藏' : '显示')
        .height(38)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.SECONDARY)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.secretVisible = !this.secretVisible)
    }
      .height(46)
      .width('100%')
      .padding({ right: 4 })
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: Theme.BORDER })
      .borderRadius(7)
  }

  build() {
    Column() {
      PageHeader({ title: '微信公众号', onBack: this.onBack })
      Scroll() {
        Column() {
          Row({ space: 10 }) {
            RemixIcon({ glyph: RI.SEND_PLANE, iconSize: 18, color: Theme.SECONDARY })
            Text('填入公众号 AppID / AppSecret 即可连接。')
              .fontSize(13)
              .fontColor(Theme.SECONDARY)
              .layoutWeight(1)
          }
            .height(42)
            .padding({ left: 14, right: 14 })
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.BORDER })
            .borderRadius(9)
            .margin({ bottom: 20 })

          Row() {
            Column({ space: 2 }) {
              Text('自动推草稿').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
              Text('挖出新文章后自动发到公众号草稿箱').fontSize(13).fontColor(Theme.SECONDARY)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
              .selectedColor(Theme.ACCENT)
              .onChange((value: boolean) => {
                this.isEnabled = value;
                this.fieldChanged();
              })
          }
            .height(56)
            .padding({ left: 14, right: 14 })
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.BORDER })
            .borderRadius(9)
            .margin({ bottom: 20 })

          Text('凭据').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
            .width('100%').margin({ bottom: 8 })
          this.inputField()
          Blank().height(8)
          this.secretField()
          Text('凭证只保存在你的设备与服务器的加密配置里，不会出现在文章中。')
            .fontSize(13).lineHeight(19).fontColor(Theme.FAINT).width('100%').margin({ top: 10, bottom: 4 })
          if (this.errorText.length > 0) {
            Text(this.errorText).fontSize(13).lineHeight(20).fontColor('#C66A35').width('100%').margin({ bottom: 8 })
          }

          Row({ space: 6 }) {
            RemixIcon({ glyph: RI.LINK, iconSize: 14, color: Theme.ACCENT })
            Text('去哪里找 AppID / AppSecret？').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT)
            RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 13, color: Theme.ACCENT })
          }
            .height(38)
            .width('100%')
            .onClick(() => this.openWechatConsole())
          Text('点上方链接打开公众平台后台，出现登录二维码时先截屏，再打开微信「扫一扫 → 右上角相册」选中截图，选择要绑定的公众号完成登录；进「设置与开发 → 基本配置」：AppID 直接复制，AppSecret 需点「生成」（或「重置」）、管理员扫码确认后显示；同时在该页把下方的 IP 地址加入「IP 白名单」。')
            .fontSize(13).lineHeight(19).fontColor(Theme.FAINT).width('100%').margin({ bottom: 24 })

          Divider().strokeWidth(1).color(Theme.DIVIDER).margin({ bottom: 20 })
          Text('IP 白名单').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
            .width('100%').margin({ bottom: 8 })
          Text('在公众号后台 → 开发 → 基本配置 → IP 白名单中加入以下地址，服务器才能正常调用接口推草稿。')
            .fontSize(13).lineHeight(19).fontColor(Theme.SECONDARY).width('100%').margin({ bottom: 10 })
          Row() {
            Text(WECHAT_SERVER_IP).fontSize(15).fontColor(Theme.INK).fontFamily('monospace').layoutWeight(1)
            Button({ type: ButtonType.Normal }) {
              RemixIcon({ glyph: RI.FILE_COPY, iconSize: 20, color: Theme.SECONDARY })
            }
              .width(40)
              .height(40)
              .padding(0)
              .backgroundColor(Color.Transparent)
              .onClick(() => this.copyServerIp())
          }
            .height(46)
            .padding({ left: 14, right: 5 })
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.BORDER })
            .borderRadius(7)
            .margin({ bottom: 24 })

          Button(this.validating ? '保存中…' : (this.saved ? '已保存' : '保存'))
            .width('100%')
            .height(52)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(this.canSave() || this.validating || this.saved ? Theme.ACCENT : '#EBA092')
            .opacity(this.canSave() || this.validating || this.saved ? 1 : 0.62)
            .enabled(this.canSave())
            .onClick(() => this.save())
        }
          .padding({ left: 16, right: 16, top: 6, bottom: 28 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.height('100%').backgroundColor(Theme.BG)
  }
}
