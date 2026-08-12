import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { bookWritingService, BookWritingResult } from '../data/BookWritingService';

@Component
export struct BookWritingPage {
  onBack: () => void = () => {};
  onOpenShelf: () => void = () => {};
  @State private seed: string = '';
  @State private sending: boolean = false;
  @State private submitted: boolean = false;
  @State private message: string = '';
  @State private error: boolean = false;

  private async start(): Promise<void> {
    const value: string = this.seed.trim().substring(0, 20000);
    if (value.length === 0 || this.sending || this.submitted) return;
    this.sending = true; this.message = ''; this.error = false;
    let result: BookWritingResult = new BookWritingResult(0, false, '没连上服务器，请检查网络后重试。');
    try { result = await bookWritingService.start(value); } catch (_) {}
    this.sending = false; this.submitted = result.accepted; this.error = !result.accepted;
    this.message = result.message;
  }

  build() {
    Column() {
      PageHeader({ title: '写书', onBack: this.onBack })
      Scroll() {
        Column({ space: 14 }) {
          Text('给一个词、一句话，或贴一整篇文章。每本书消耗 320 算力；提交后可以关闭 App，服务器会继续写，通常 10–30 分钟后出现在公开书架。')
            .fontSize(14).lineHeight(22).fontColor(Theme.SECONDARY).width('100%')
          Row() {
            Row({ space: 8 }) {
              RemixIcon({ glyph: RI.BOOK_OPEN, iconSize: 21, color: Theme.INK })
              Text('公开书架').fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.INK)
            }.alignItems(VerticalAlign.Center)
            Blank()
            Text('查看已出版的书 ›').fontSize(13).fontColor(Theme.SECONDARY)
          }.height(60).padding({ left: 16, right: 16 }).backgroundColor(Theme.CARD).borderRadius(14)
            .border({ width: 0.5, color: Theme.BORDER }).width('100%').onClick(this.onOpenShelf)
          TextArea({ text: this.seed, placeholder: '书的种子：一个词、一句话，或一整篇文章……' })
            .height(230).fontSize(16).fontColor(Theme.INK).placeholderColor(Theme.FAINT).padding(16)
            .backgroundColor(Theme.CARD).borderRadius(14).border({ width: 1, color: Theme.ACCENT })
            .enabled(!this.submitted).onChange((value: string) => { this.seed = value.substring(0, 20000); this.message = ''; })
          if (this.message.length > 0) {
            Text(this.message).fontSize(13).lineHeight(20).fontColor(this.error ? '#D64532' : Theme.GREEN).width('100%')
          }
          Button(this.submitted ? '已受理' : (this.sending ? '提交中…' : '开写'))
            .width('100%').height(48).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .backgroundColor(this.submitted || this.sending || this.seed.trim().length === 0 ? Theme.FAINT : Theme.ACCENT)
            .enabled(!this.submitted && !this.sending && this.seed.trim().length > 0).onClick(() => this.start())
        }.padding({ left: 20, right: 20, top: 12, bottom: 32 }).width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
