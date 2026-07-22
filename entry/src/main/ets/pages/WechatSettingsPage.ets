import { promptAction } from '@kit.ArkUI';
import { settingsStore, WechatSettings } from '../data/SettingsStore';
import { PageHeader } from '../ui/PageHeader';

@Component
export struct WechatSettingsPage {
  onBack: () => void = () => {};
  @State private appid: string = '';
  @State private secret: string = '';
  @State private isEnabled: boolean = true;
  @State private validating: boolean = false;

  aboutToAppear(): void {
    settingsStore.loadWechat().then((data: WechatSettings) => {
      this.appid = data.appid ?? '';
      this.secret = data.secret ?? '';
      this.isEnabled = data.enabled ?? true;
    });
  }

  build() {
    Column() {
      PageHeader({ title: '微信公众号', onBack: this.onBack })
      Scroll() {
        Column({ space: 16 }) {
          Text('文章可以直接发送到公众号草稿箱。AppSecret 只会通过加密连接保存到你的 VoiceDrop 存储空间。').fontSize(14).lineHeight(22).fontColor('#666666').width('100%')
          TextInput({ text: this.appid, placeholder: 'AppID（wx 开头）' }).onChange((value: string) => this.appid = value).backgroundColor(Color.White)
          TextInput({ text: this.secret, placeholder: 'AppSecret' }).type(InputType.Password).onChange((value: string) => this.secret = value).backgroundColor(Color.White)
          Row() { Text('启用公众号发布').layoutWeight(1); Toggle({ type: ToggleType.Switch, isOn: this.isEnabled }).onChange((value: boolean) => this.isEnabled = value) }
          Button(this.validating ? '正在验证…' : '验证并保存').width('100%').height(50).backgroundColor('#111111')
            .enabled(!this.validating).onClick(async () => {
            const error: string = settingsStore.wechatCredentialError(this.appid, this.secret);
            if (error.length > 0) { promptAction.showToast({ message: error }); return; }
            this.validating = true;
            const validation: string = await settingsStore.validateWechat(this.appid, this.secret);
            if (validation.length > 0) {
              this.validating = false; promptAction.showToast({ message: validation, duration: 5000 }); return;
            }
            const data: WechatSettings = new WechatSettings();
            data.appid = this.appid.trim(); data.secret = this.secret.trim(); data.enabled = this.isEnabled;
            const ok: boolean = await settingsStore.saveWechat(data);
            this.validating = false;
            promptAction.showToast({ message: ok ? '已保存' : '保存失败' });
          })
        }.padding({ left: 16, right: 16, top: 6, bottom: 30 })
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.height('100%')
  }
}
