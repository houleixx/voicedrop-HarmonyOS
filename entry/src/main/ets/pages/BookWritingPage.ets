import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { bookWritingService, BookWritingResult, BookWritingService } from '../data/BookWritingService';
import { usageStore } from '../data/UsageStore';
import { referralService, InviteLink } from '../data/ReferralService';

@Component
export struct BookWritingPage {
  onBack: () => void = () => {};
  onOpenShelf: () => void = () => {};
  onInvite: () => void = () => {};
  @State private seed: string = '';
  @State private sending: boolean = false;
  @State private submitted: boolean = false;
  @State private message: string = '';
  @State private balance?: number = undefined;
  @State private invite?: InviteLink = undefined;
  @StorageLink('safeAreaBottomPx') private safeAreaBottomPx: number = 0;

  aboutToAppear(): void { this.loadContext().catch(() => {}); }
  private async loadContext(): Promise<void> {
    try { this.balance = (await usageStore.balance()).suanli; } catch (_) {}
    await this.loadInviteIfNeeded();
  }
  private async loadInviteIfNeeded(): Promise<void> {
    if (!BookWritingService.shouldLoadInvite(this.balance) || this.invite !== undefined) return;
    try { this.invite = await referralService.inviteLink(); } catch (_) {}
  }
  private shortfall(): number { return BookWritingService.shortfall(this.balance); }
  private canSubmit(): boolean { return this.seed.trim().length > 0 && !this.sending && (this.balance === undefined || this.balance >= 320); }
  private safeAreaBottom(): number { return this.getUIContext().px2vp(this.safeAreaBottomPx); }
  private async start(): Promise<void> {
    const value: string = this.seed.trim().substring(0, 20000);
    if (!this.canSubmit()) return;
    this.sending = true; this.message = '';
    let result: BookWritingResult = new BookWritingResult(0, false, '没连上服务器，请检查网络后重试。');
    try { result = await bookWritingService.start(value); } catch (_) {}
    this.sending = false;
    if (result.accepted) this.submitted = true;
    else {
      this.message = result.message;
      if (result.balance !== undefined) {
        this.balance = result.balance;
        this.loadInviteIfNeeded().catch(() => {});
      }
    }
  }
  @Builder private sectionLabel(label: string) {
    Text(label).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#9A948B').letterSpacing(2).width('100%')
  }
  @Builder private earnRow(glyph: string, tileColor: string, iconColor: string, title: string, copy: string) {
    Row({ space: 12 }) {
      Row() {
        RemixIcon({ glyph: glyph, iconSize: 22, color: iconColor })
      }
        .width(42)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(tileColor)
        .borderRadius(10)
        .margin({ top: 5 })
      Column({ space: 3 }) {
        Text(title).fontSize(14).fontWeight(FontWeight.Bold).lineHeight(20).fontColor(Theme.INK).width('100%')
        Text(copy).fontSize(12.5).lineHeight(19).fontColor(Theme.SECONDARY).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }
  @Builder private step(number: string, title: string, copy: string) {
    Row({ space: 10 }) {
      Text(number).width(28).height(28).fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT)
        .textAlign(TextAlign.Center).backgroundColor('#F9E5DE').borderRadius(9)
      Column({ space: 1 }) {
        Text(title).fontSize(14.5).fontWeight(FontWeight.Bold).lineHeight(20).fontColor(Theme.INK).width('100%')
        Text(copy).fontSize(12.5).lineHeight(18).fontColor(Theme.SECONDARY).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 12, right: 12, top: 9, bottom: 9 }).alignItems(VerticalAlign.Top)
  }
  @Builder private stepDivider() {
    Divider().strokeWidth(0.5).color(Theme.BORDER).margin({ left: 50, right: 12 })
  }
  build() {
    Column() {
      PageHeader({ title: '写书', onBack: this.onBack })
      if (this.submitted) Column({ space: 16 }) {
        Row() {
          RemixIcon({ glyph: RI.CHECK, iconSize: 34, color: Color.White })
        }
          .width(56).height(56)
          .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
          .backgroundColor(Theme.GREEN).borderRadius(28)
        Text('开始写了！').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
        Text('现在可以关掉 App。书通常 10–30 分钟写完，过稿一章、上架一章——下拉刷新「写书」书架就能看到。').fontSize(15).lineHeight(24).fontColor(Theme.SECONDARY).textAlign(TextAlign.Center)
        Button('好').width(150).height(48).fontColor(Color.White).backgroundColor(Theme.ACCENT).onClick(this.onOpenShelf)
      }
        .layoutWeight(1)
        .padding({ left: 30, right: 30, top: 48, bottom: 30 })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
      else {
        Scroll() { Column({ space: 18 }) {
          Row() {
            Column({ space: 3 }) {
              Row({ space: 4 }) {
                RemixIcon({ glyph: RI.FLASHLIGHT, iconSize: 22, color: Theme.AMBER })
                  .translate({ y: -2 })
                Text('320').fontSize(34).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
                Text('算力').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.SECONDARY).margin({ top: 12 })
              }.alignItems(VerticalAlign.Center)
              Text('写一本书的价钱，提交时一次扣清').fontSize(12.5).fontColor('#928A80')
            }.alignItems(HorizontalAlign.Start)
            Blank()
            if (this.balance === undefined) {
              Text('加载中…').fontSize(13).fontColor(Theme.FAINT)
            } else {
              Column({ space: 3 }) {
                Text(`${Math.round(this.balance)}`).fontSize(24).fontWeight(FontWeight.Bold)
                  .fontColor(this.shortfall() > 0 ? '#C64232' : Theme.GREEN)
                Text('你现在的算力').fontSize(12.5).fontColor('#928A80')
              }.alignItems(HorizontalAlign.End)
            }
          }.width('100%').padding({ left: 18, right: 18, top: 16, bottom: 16 })
            .backgroundColor('#FCEBCB').borderRadius(14).border({ width: 1, color: '#EBD9B8' })
          if (this.shortfall() > 0) {
            Column({ space: 8 }) {
              this.sectionLabel('算力不够？')
              Column({ space: 14 }) {
                Text(`还差 ${this.shortfall()} 算力，两条来路：`)
                  .fontSize(14).fontWeight(FontWeight.Bold).lineHeight(21).fontColor(Theme.INK).width('100%')
                this.earnRow(RI.FLASHLIGHT, Theme.AMBER_BG, Theme.AMBER,
                  (this.invite?.suanliFeedAuthor ?? 0) > 0
                    ? `请朋友给你的文章「加油」——一次约得 ${this.invite!.suanliFeedAuthor} 算力`
                    : '请朋友给你的文章「加油」——作者每次都得算力',
                  '把文章分享到 VD社区或发给朋友，读的人点「加油」你就进账')
                this.earnRow(RI.TEAM, Theme.ACCENT_SOFT, Theme.ACCENT,
                  (this.invite?.suanliInviter ?? 0) > 0
                    ? `邀请朋友装 VoiceDrop——装一个约得 ${this.invite!.suanliInviter} 算力`
                    : '邀请朋友装 VoiceDrop——每装一个你都得算力',
                  '朋友通过你的链接安装，双方都到账')
                if ((this.invite?.url ?? '').length > 0) {
                  Button('把邀请链接发给朋友')
                    .width('100%').height(44).fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    .backgroundColor(Theme.ACCENT).borderRadius(12).onClick(this.onInvite)
                }
              }
                .padding({ left: 16, right: 16, top: 15, bottom: 16 })
                .width('100%').backgroundColor(Theme.CARD).borderRadius(14)
                .border({ width: 0.5, color: Theme.BORDER })
                .alignItems(HorizontalAlign.Start)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
          Column({ space: 8 }) {
          this.sectionLabel('中心思想')
          Text('一句话说清这本书要讲明白的那一个问题或主张。想法越聚焦，书越好看；也可以贴一整篇文章当种子。').fontSize(13).lineHeight(20).fontColor(Theme.SECONDARY).width('100%')
          TextArea({ text: this.seed, placeholder: '比如：为什么一切都在变乱？\n或：钱不脏，是我一直躲着它。' })
            .height(150).fontSize(16).fontColor(Theme.INK).placeholderColor(Theme.FAINT)
            .placeholderFont({ size: 14 })
            .padding({ left: 20, right: 20, top: 18, bottom: 18 }).backgroundColor(Theme.CARD)
            .borderRadius(14).border({ width: 1.5, color: Theme.ACCENT })
            .onChange((value: string) => this.seed = value.substring(0, 20000))
          }.width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 8 }) {
          this.sectionLabel('怎么写成')
          Column() {
          this.step('1', '拆大纲', 'AI 建筑师把中心思想拆成一环扣一环的章节')
          this.stepDivider()
          this.step('2', '并行写', '每章一个写手，费曼式大白话，名词当场讲人话')
          this.stepDivider()
          this.step('3', '独立评审', '另一个 AI 只看成稿挑错，不过就打回重写')
          this.stepDivider()
          this.step('4', '上你的架', '过一章发一章到「写书」书架，署你的名字（设置里的「名字」）')
          }.width('100%').backgroundColor(Theme.CARD).borderRadius(12)
            .border({ width: 0.5, color: Theme.BORDER })
          }.width('100%').alignItems(HorizontalAlign.Start)
          if (this.message.length > 0) Text(this.message).fontSize(13).fontColor('#D64532').width('100%')
        }.padding({ left: 16, right: 16, top: 4, bottom: 30 }).width('100%').alignItems(HorizontalAlign.Start) }
          .layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        Column({ space: 9 }) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 8 }) {
              if (this.sending) {
                LoadingProgress().width(20).height(20).color(Color.White)
              }
              Text(this.sending ? '提交中…' :
                (this.shortfall() > 0 ? `算力不够 · 还差 ${this.shortfall()}` : '开始写书 · 320 算力'))
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
            }.justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
          }
            .width('100%').height(50).padding(0)
            .backgroundColor(this.sending || this.canSubmit() ? Theme.ACCENT : '#B8B0A1').borderRadius(12)
            .shadow({ radius: 10, color: this.sending || this.canSubmit() ? '#30D8593B' : '#18000000', offsetY: 4 })
            .enabled(this.canSubmit()).onClick(() => this.start())
          Text('提交后就可以关 App · 10–30 分钟写完，出现在「写书」书架')
            .fontSize(12.5).fontColor('#928A80').textAlign(TextAlign.Center)
        }.padding({ left: 16, right: 16, top: 12, bottom: 10 + this.safeAreaBottom() }).width('100%')
          .backgroundColor(Theme.BG).border({ width: { top: 1 }, color: '#E6DED2' })
      }
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
