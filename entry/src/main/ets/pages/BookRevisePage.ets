import { BookReviseContract, BookReviseResult, BookThreadEntry } from '../core/BookReviseContract';
import { bookReviseService } from '../data/BookReviseService';
import { ShelfBook } from '../data/BooksService';
import { umengAnalytics } from '../data/UmengAnalytics';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

const BOOK_REVISE_POLL_MS: number = 6000;
const BOOK_REVISE_SHEET_ENTER_MS: number = 280;
const BOOK_REVISE_SHEET_EXIT_MS: number = 220;
const BOOK_REVISE_SHEET_OFFSCREEN_Y: number = 960;

@Component
export struct BookRevisePage {
  @StorageLink('safeAreaBottomPx') private safeAreaBottomPx: number = 0;
  book: ShelfBook = new ShelfBook();
  onClose: () => void = () => {};
  @State private thread: BookThreadEntry[] = [];
  @State private loading: boolean = true;
  @State private input: string = '';
  @State private sending: boolean = false;
  @State private denied: string = '';
  @State private errorText: string = '';
  @State private presented: boolean = false;
  private pollTimer: number = -1;
  private enterTimer: number = -1;
  private exitTimer: number = -1;
  private closing: boolean = false;
  private active: boolean = false;
  private generation: number = 0;

  aboutToAppear(): void {
    this.active = true;
    this.generation++;
    this.sending = false;
    this.loading = true;
    umengAnalytics.capture('修书页面');
    this.load(true).catch(() => {});
    this.enterTimer = setTimeout(() => {
      this.enterTimer = -1;
      if (this.closing) return;
      animateTo({ duration: BOOK_REVISE_SHEET_ENTER_MS, curve: Curve.EaseOut }, () => {
        this.presented = true;
      });
    }, 0);
  }

  aboutToDisappear(): void {
    this.active = false;
    this.generation++;
    this.stopPolling();
    if (this.enterTimer >= 0) clearTimeout(this.enterTimer);
    if (this.exitTimer >= 0) clearTimeout(this.exitTimer);
  }

  private close(): void {
    if (this.closing) return;
    this.closing = true;
    if (this.enterTimer >= 0) {
      clearTimeout(this.enterTimer);
      this.enterTimer = -1;
    }
    animateTo({ duration: BOOK_REVISE_SHEET_EXIT_MS, curve: Curve.EaseIn }, () => {
      this.presented = false;
    });
    this.exitTimer = setTimeout(() => {
      this.exitTimer = -1;
      this.onClose();
    }, BOOK_REVISE_SHEET_EXIT_MS);
  }

  private safeAreaBottom(): number {
    return this.safeAreaBottomPx > 0 ? this.getUIContext().px2vp(this.safeAreaBottomPx) : 0;
  }

  private canSend(): boolean {
    return BookReviseContract.canSend(this.input, this.sending, this.loading, this.thread, this.denied);
  }

  private running(): boolean { return BookReviseContract.isRunning(this.thread); }

  private async load(showLoading: boolean): Promise<void> {
    const requestGeneration: number = this.generation;
    if (showLoading) this.loading = true;
    try {
      const result = await bookReviseService.history(this.book.slug);
      if (!this.active || requestGeneration !== this.generation) return;
      if (result.loaded && result.value !== undefined) {
        this.thread = result.value.thread;
        this.denied = '';
        this.errorText = '';
      } else if (result.denied) {
        this.denied = result.message;
        this.errorText = '';
      } else if (this.thread.length === 0 || !this.running()) {
        this.errorText = result.message;
      }
    } catch (_) {
      if (!this.active || requestGeneration !== this.generation) return;
      if (this.thread.length === 0 || !this.running()) this.errorText = '没连上服务器，请检查网络后重试。';
    }
    if (!this.active || requestGeneration !== this.generation) return;
    this.loading = false;
    this.syncPolling();
  }

  private syncPolling(): void {
    this.stopPolling();
    if (!this.active || !this.running()) return;
    this.pollTimer = setTimeout(() => {
      this.pollTimer = -1;
      this.load(false).catch(() => this.syncPolling());
    }, BOOK_REVISE_POLL_MS);
  }

  private stopPolling(): void {
    if (this.pollTimer >= 0) clearTimeout(this.pollTimer);
    this.pollTimer = -1;
  }

  private async send(): Promise<void> {
    if (!this.canSend()) return;
    const requestGeneration: number = this.generation;
    const instruction: string = BookReviseContract.instruction(this.input);
    this.sending = true;
    this.errorText = '';
    umengAnalytics.capture('修书发起');
    let result: BookReviseResult = new BookReviseResult(0, false, '没连上服务器，请检查网络后重试。');
    try { result = await bookReviseService.revise(this.book.slug, instruction); } catch (_) {}
    if (!this.active || requestGeneration !== this.generation) return;
    this.sending = false;
    if (result.accepted) {
      this.input = '';
      const ts: number = result.ts > 0 ? result.ts : Date.now();
      this.thread = this.thread.concat([new BookThreadEntry(ts, 'revise', instruction, 'running')]);
      umengAnalytics.capture('修书已受理');
      this.syncPolling();
      return;
    }
    this.errorText = result.message;
    if (result.code === 403 || result.code === 404) this.denied = result.message;
    if (result.code === 409) await this.load(false);
  }

  private static stamp(ms: number): string {
    if (ms <= 0) return '';
    const date: Date = new Date(ms);
    const minute: string = date.getMinutes() < 10 ? `0${date.getMinutes()}` : `${date.getMinutes()}`;
    const hour: string = date.getHours() < 10 ? `0${date.getHours()}` : `${date.getHours()}`;
    return `${date.getMonth() + 1}月${date.getDate()}日 ${hour}:${minute}`;
  }

  @Builder
  private reply(entry: BookThreadEntry) {
    if (entry.status === 'running') {
      Row({ space: 8 }) {
        LoadingProgress().width(18).height(18).color(Theme.SECONDARY)
        Text(BookReviseContract.replyText(entry)).fontSize(14).lineHeight(20).fontColor(Theme.SECONDARY)
          .layoutWeight(1)
      }
        .padding({ left: 13, right: 13, top: 10, bottom: 10 }).width('88%')
        .backgroundColor(Theme.CARD).borderRadius(12).border({ width: 1, color: Theme.BORDER })
    } else {
      Text(BookReviseContract.replyText(entry))
        .fontSize(entry.status === 'failed' ? 14 : 15).lineHeight(22)
        .fontColor(entry.status === 'failed' ? Theme.ACCENT_STRONG : Theme.INK)
        .padding({ left: 13, right: 13, top: 10, bottom: 10 }).constraintSize({ maxWidth: '88%' })
        .backgroundColor(Theme.CARD).borderRadius(12).border({ width: 1, color: Theme.BORDER })
    }
  }

  @Builder
  private entry(entry: BookThreadEntry) {
    Column({ space: 8 }) {
      Column({ space: 3 }) {
        Text(entry.kind === 'create' ? '开书种子' : '修改指令').fontSize(11).fontColor(Theme.FAINT)
        Text(entry.instruction).fontSize(15).lineHeight(22).fontColor(Color.White)
          .padding({ left: 13, right: 13, top: 10, bottom: 10 })
          .constraintSize({ maxWidth: '88%' }).backgroundColor(Theme.ACCENT).borderRadius(12)
        if (BookRevisePage.stamp(entry.ts).length > 0) {
          Text(BookRevisePage.stamp(entry.ts)).fontSize(11).fontColor(Theme.FAINT)
        }
      }.width('100%').alignItems(HorizontalAlign.End)
      Column() { this.reply(entry) }.width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private conversation() {
    Scroll() {
      Column({ space: 14 }) {
        ForEach(this.thread, (entry: BookThreadEntry) => {
          this.entry(entry)
        }, (entry: BookThreadEntry) => `${entry.ts}-${entry.kind}`)
        if (this.errorText.length > 0) {
          Column({ space: 8 }) {
            Text(this.errorText).fontSize(13).lineHeight(19).fontColor(Theme.ACCENT_STRONG).width('100%')
            if (this.thread.length === 0) {
              Button('重试').height(36).fontSize(14).fontColor(Theme.ACCENT)
                .backgroundColor(Theme.ACCENT_SOFT).onClick(() => this.load(true))
            }
          }.width('100%').alignItems(HorizontalAlign.Start)
        }
      }.padding({ left: 18, right: 18, top: 8, bottom: 14 }).width('100%').alignItems(HorizontalAlign.Start)
    }.layoutWeight(1).width('100%').edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  private inputBar() {
    Column({ space: 7 }) {
      Row({ space: 10 }) {
        TextArea({ text: this.input, placeholder: '想怎么改这本书？比如：第三章开头太啰嗦，删一半' })
          .layoutWeight(1).height(76).fontSize(15).fontColor(Theme.INK).placeholderColor(Theme.FAINT)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 }).backgroundColor(Theme.CARD)
          .borderRadius(12).border({ width: 1.5, color: Theme.ACCENT })
          .onChange((value: string) => this.input = value.substring(0, 4000))
        Button({ type: ButtonType.Circle }) {
          if (this.sending) LoadingProgress().width(20).height(20).color(Color.White)
          else RemixIcon({ glyph: RI.SEND_PLANE, iconSize: 20, color: Color.White })
        }
          .width(44).height(44).padding(0).backgroundColor(this.canSend() ? Theme.ACCENT : '#B8B0A1')
          .enabled(this.canSend()).onClick(() => this.send())
      }.width('100%').alignItems(VerticalAlign.Bottom)
      Text(this.running() ? '有一个修改正在进行，等它改完再提下一个' :
        `每次修改 ${BookReviseContract.PRICE} 算力 · 提交后可以关掉，改完这里会留下修改说明`)
        .fontSize(12).lineHeight(18).fontColor(Theme.FAINT).textAlign(TextAlign.Center).width('100%')
    }
      .padding({ left: 16, right: 16, top: 10, bottom: 10 + this.safeAreaBottom() }).width('100%')
      .backgroundColor(Theme.BG).border({ width: { top: 1 }, color: Theme.BORDER })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#61000000')
        .opacity(this.presented ? 1 : 0)
        .onClick(() => this.close())
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Text(`修改《${this.book.main}》`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.INK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '72%' })
          Row() {
            Blank()
            Button({ type: ButtonType.Circle }) {
              RemixIcon({ glyph: RI.CLOSE, iconSize: 22, color: Theme.SECONDARY })
            }
              .width(38)
              .height(38)
              .padding(0)
              .backgroundColor(Color.Transparent)
              .stateEffect(false)
              .accessibilityText('关闭修改书')
              .onClick(() => this.close())
          }.width('100%').padding({ left: 14, right: 14 })
        }.width('100%').height(50)
        if (this.loading && this.thread.length === 0 && this.denied.length === 0) {
          Column({ space: 12 }) {
            LoadingProgress().width(34).height(34).color(Theme.ACCENT_STRONG)
            Text('正在加载修改记录…').fontSize(14).fontColor(Theme.SECONDARY)
          }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .translate({ y: -180 })
        } else if (this.denied.length > 0) {
          Column({ space: 12 }) {
            RemixIcon({ glyph: RI.INFORMATION, iconSize: 42, color: Theme.FAINT })
            Text(this.denied).fontSize(14).lineHeight(22).fontColor(Theme.SECONDARY)
              .textAlign(TextAlign.Center).padding({ left: 36, right: 36 })
          }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .translate({ y: -180 })
        } else {
          this.conversation()
          this.inputBar()
        }
      }
        .width('100%')
        .height('84%')
        .backgroundColor(Theme.BG)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .clip(true)
        .translate({ y: this.presented ? 0 : BOOK_REVISE_SHEET_OFFSCREEN_Y })
    }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
