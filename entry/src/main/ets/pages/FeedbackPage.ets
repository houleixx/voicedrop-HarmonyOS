import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { settingsStore, StyleSettings } from '../data/SettingsStore';

@Component
export struct FeedbackPage {
  onBack: () => void = () => {};
  @State private draft: string = '';
  @State private profileName: string = '';
  @State private sending: boolean = false;
  @State private sent: boolean = false;
  @State private error: string = '';

  aboutToAppear(): void {
    settingsStore.loadStyle().then((style: StyleSettings) => this.profileName = style.name ?? '').catch(() => {});
  }

  private async send(): Promise<void> {
    const text: string = this.draft.trim().substring(0, 2000);
    if (text.length === 0 || this.sending || this.sent) return;
    this.sending = true; this.error = '';
    try {
      this.sent = await settingsStore.sendFeedback(text, this.profileName, 'HarmonyOS');
      if (!this.sent) this.error = '发送失败，请检查网络后重试';
    } catch (_) { this.error = '发送失败，请检查网络后重试'; }
    finally { this.sending = false; }
  }

  build() {
    Column() {
      PageHeader({ title: '意见反馈', onBack: this.onBack })
      Column({ space: 14 }) {
        TextArea({ text: this.draft, placeholder: '哪里不顺手？想要什么功能？\n写一句就行。' })
          .height(230).fontSize(16).fontColor(Theme.INK).placeholderColor(Theme.FAINT)
          .padding(16).backgroundColor(Theme.CARD).borderRadius(14).border({ width: 1, color: Theme.ACCENT })
          .enabled(!this.sent).onChange((value: string) => { this.draft = value.substring(0, 2000); this.error = ''; })
        Text(this.sent ? '收到了，谢谢！' : (this.error.length > 0 ? this.error : '会带上你的账户身份，方便改进后回访。'))
          .fontSize(13).fontColor(this.error.length > 0 ? '#D64532' : (this.sent ? Theme.GREEN : Theme.SECONDARY)).width('100%')
        Button(this.sent ? '已发送' : (this.sending ? '发送中…' : '发送'))
          .width('100%').height(48).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .backgroundColor(this.sent || this.sending || this.draft.trim().length === 0 ? Theme.FAINT : Theme.ACCENT)
          .enabled(!this.sent && !this.sending && this.draft.trim().length > 0).onClick(() => this.send())
      }.padding({ left: 20, right: 20, top: 12 }).width('100%').layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
