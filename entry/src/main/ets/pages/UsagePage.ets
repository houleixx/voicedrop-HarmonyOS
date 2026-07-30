import { promptAction } from '@kit.ArkUI';
import { usageStore, UsageBalance, UsageEntry, UsageLedgerPage, UsageSummary, UsageSummaryRow } from '../data/UsageStore';
import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

@Component
export struct UsagePage {
  onBack: () => void = () => {};
  @State private balance: UsageBalance = new UsageBalance();
  @State private summary: UsageSummary = new UsageSummary();
  @State private entries: UsageEntry[] = [];
  @State private nextCursor: string = '';
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private errorText: string = '';

  aboutToAppear(): void {
    Promise.all([usageStore.balance(), usageStore.summary(), usageStore.ledger()])
      .then((values: [UsageBalance, UsageSummary, UsageLedgerPage]) => {
        this.balance = values[0]; this.summary = values[1]; this.entries = values[2].entries;
        this.nextCursor = values[2].nextCursor; this.loading = false;
      }).catch((error: Error) => { this.errorText = error.message; this.loading = false; });
  }

  private amount(value: number): string { return value < 10 ? value.toFixed(1) : `${Math.round(value)}`; }

  private entryLabel(entry: UsageEntry): string {
    if (entry.reason === 'signup') return '注册赠送';
    if (entry.reason === 'asr') return '语音转写';
    if (entry.reason === 'mine') return '挖文章';
    if (entry.reason === 'edit') return '语音修改';
    if (entry.reason.startsWith('campaign:')) return '活动赠送';
    return entry.reason.length > 0 ? entry.reason : entry.kind;
  }

  private two(value: number): string { return value < 10 ? `0${value}` : `${value}`; }

  private entryTime(timestamp: number): string {
    const date: Date = new Date(timestamp);
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${this.two(date.getHours())}:${this.two(date.getMinutes())}`;
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore || this.nextCursor.length === 0) return;
    this.loadingMore = true;
    try {
      const page: UsageLedgerPage = await usageStore.ledger(this.nextCursor);
      this.entries = this.entries.concat(page.entries); this.nextCursor = page.nextCursor;
    } catch (error) { promptAction.showToast({ message: `加载更多失败：${String(error)}`}); }
    finally { this.loadingMore = false; }
  }

  @Builder
  private itemDivider() {
    Divider()
      .strokeWidth(1)
      .color('#EEE6DB')
      .margin({ left: 15, right: 15 })
  }

  build() {
    Column() {
      PageHeader({ title: '算力', onBack: this.onBack })
      if (this.loading) {
        Column() {
          LoadingProgress().width(48).height(48).color(Theme.ACCENT_STRONG)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      }
      else if (this.errorText.length > 0) {
        Column({ space: 12 }) {
          Text('算力加载失败').fontSize(18).fontWeight(FontWeight.Bold)
          Text(this.errorText).fontSize(13).fontColor('#777777').textAlign(TextAlign.Center)
        }.margin({ top: 80 }).padding(24)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 8 }) {
              Text('剩余算力').fontSize(13).fontColor('#C9BFAE').letterSpacing(1).width('100%')
              Row() {
                Text(`${Math.round(this.balance.suanli)}`).fontSize(42).fontWeight(FontWeight.Bold).fontColor(Color.White)
                Text(`≈ ${usageStore.articleCapacity(this.balance.suanli)} 篇`).fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor('#E2B871').margin({ left: 10, bottom: 6 })
              }.alignItems(VerticalAlign.Bottom).width('100%')
              Text(`累计获赠 ${Math.round(this.balance.suanli + this.balance.spentSuanli)} · 已用 ${Math.round(this.balance.spentSuanli)}`)
                .fontSize(13).fontColor('#C9BFAE').margin({ top: 4 }).width('100%')
            }.padding(22).width('100%').backgroundColor('#211D19').borderRadius(16).alignItems(HorizontalAlign.Start)
            if (this.summary.granted.length > 0) {
              Text('算力来源').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#777777').width('100%').margin({ top: 6 })
              Column() {
                ForEach(this.summary.granted, (row: UsageSummaryRow, index: number) => {
                  Row() { Text(row.reason).fontSize(15).layoutWeight(1); if (row.count > 1) Text(`${row.count} 笔`).fontSize(12).fontColor('#999999').margin({ right: 8 }); Text(`+${this.amount(row.suanli)}`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#2F9B68') }.padding(15).width('100%')
                  if (index < this.summary.granted.length - 1) this.itemDivider()
                }, (row: UsageSummaryRow) => `grant-${row.reasonCode}`)
              }.width('100%').backgroundColor(Color.White).borderRadius(14)
                .border({ width: 1, color: '#EFE4D4' })
            }
            if (this.summary.spent.length > 0) {
              Text('花费总结').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#777777').width('100%').margin({ top: 6 })
              Column() {
                ForEach(this.summary.spent, (row: UsageSummaryRow, index: number) => {
                  Row() { Text(row.reason).fontSize(15).layoutWeight(1); if (row.count > 1) Text(`${row.count} 笔`).fontSize(12).fontColor('#999999').margin({ right: 8 }); Text(`-${this.amount(row.suanli)}`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#D92D20') }.padding(15).width('100%')
                  if (index < this.summary.spent.length - 1) this.itemDivider()
                }, (row: UsageSummaryRow) => `spent-${row.reasonCode}`)
              }.width('100%').backgroundColor(Color.White).borderRadius(14)
                .border({ width: 1, color: '#EFE4D4' })
            }
            Text('明细').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#777777').width('100%').margin({ top: 6 })
            Column() {
              if (this.entries.length === 0) Text('暂无记录').fontSize(14).fontColor('#777777').padding(18).width('100%')
              ForEach(this.entries, (entry: UsageEntry, index: number) => {
                Row() {
                  Column({ space: 3 }) { Text(this.entryLabel(entry)).fontSize(15); Text(this.entryTime(entry.ts)).fontSize(12).fontColor('#999999') }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(`${entry.kind === 'grant' ? '+' : '-'}${this.amount(entry.suanli)}`).fontSize(15).fontWeight(FontWeight.Bold).fontColor(entry.kind === 'grant' ? '#2F9B68' : '#D92D20')
                }.padding(15).width('100%')
                if (index < this.entries.length - 1 || this.nextCursor.length > 0) this.itemDivider()
              }, (entry: UsageEntry) => `${entry.id}`)
              if (this.nextCursor.length > 0) Button(this.loadingMore ? '加载中…' : '加载更早的记录').enabled(!this.loadingMore)
                .width('100%').backgroundColor(Color.Transparent).fontColor('#777777').onClick(() => this.loadMore())
            }.width('100%').backgroundColor(Color.White).borderRadius(14)
              .border({ width: 1, color: '#EFE4D4' })
          }.padding({ left: 16, right: 16, top: 6, bottom: 30 }).width('100%')
        }.layoutWeight(1).width('100%').edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
    }.height('100%')
  }
}
