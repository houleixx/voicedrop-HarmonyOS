import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
import { BooksService, ShelfBook, booksService } from '../data/BooksService';
import { WechatCommunityShare } from '../data/WechatCommunityShare';
import { WechatBookShare, WechatBookShareTarget, WechatBookShareTargetValue } from '../core/WechatBookShare';
import { DetailShareUi } from '../core/DetailShareUi';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { ShareBottomSheet, ShareSheetTarget } from '../components/ShareBottomSheet';
import { BookRevisePage } from './BookRevisePage';

@Component
export struct BooksShelfPage {
  onWrite: () => void = () => {};
  onRead: (book: ShelfBook) => void = () => {};
  @State private books: ShelfBook[] = [];
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private refreshStatus: RefreshStatus = RefreshStatus.Inactive;
  @State private refreshOffset: number = 0;
  @State private error: string = '';

  aboutToAppear(): void {
    this.books = booksService.cached(); this.loading = this.books.length === 0;
    this.load().catch(() => {});
  }
  private async load(): Promise<void> {
    try { this.books = await booksService.load(); this.error = ''; }
    catch (_) { if (this.books.length === 0) this.error = '书架加载失败，下拉重试'; }
    finally { this.loading = false; this.refreshing = false; }
  }
  private shelfItemCount(): number { return this.books.length + 1; }
  private shelfRows(): number[] {
    const rows: number[] = [];
    for (let index: number = 0; index < this.shelfItemCount(); index += 2) rows.push(index);
    return rows;
  }
  @Builder private refreshPlaceholder() {
    Row() {
    }
      .width(1)
      .height(1)
      .opacity(0)
  }
  @Builder private writeCover() {
    Column({ space: 10 }) {
      Text('+').width(32).height(32).fontSize(26).fontWeight(FontWeight.Lighter)
        .fontColor(Color.White).textAlign(TextAlign.Center)
        .backgroundColor(Theme.ACCENT_STRONG).borderRadius(16)
        .shadow({ radius: 5, color: '#4DE5392E', offsetY: 3 })
      Text('写书').fontSize(15).fontWeight(FontWeight.Medium).letterSpacing(1).fontColor('#6F685D')
    }
      .width('100%').aspectRatio(0.7)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#F3ECE0')
      .border({ width: 1.5, color: '#CFC0A6', style: BorderStyle.Dashed, radius: 5 })
  }
  @Builder private bookCover(book: ShelfBook) {
    Stack() {
      Stack({ alignContent: Alignment.TopStart }) {
        Column().width('100%').height('100%')
          .linearGradient({ angle: 145, colors: [[book.c, 0], [book.c2, 1]] })
        if (book.cover) Image(book.coverUrl()).width('100%').height('100%').objectFit(ImageFit.Cover)
        else Column({ space: 10 }) {
          Text(book.main).fontFamily('serif').fontSize(22).fontWeight(FontWeight.Bold)
            .letterSpacing(3).lineHeight(31).fontColor('#F7F1DF')
            .textAlign(TextAlign.Start).width('100%').maxLines(4)
          Divider().width(26).strokeWidth(1).color('#8CF7F1DF')
          if (book.sub.length > 0) {
            Text(book.sub).fontFamily('serif').fontSize(11.5).lineHeight(18).fontColor('#B8F7F1DF')
              .textAlign(TextAlign.Start).width('100%').maxLines(3)
          }
        }.width('100%').height('100%').padding({ left: 24, right: 16, top: 26 })
          .alignItems(HorizontalAlign.Start)
        Row() {
          Row().width(13).height('100%')
            .linearGradient({ angle: 90, colors: [['#5C000000', 0], ['#1A000000', 0.55], ['#1FFFFFFF', 1]] })
          Blank()
        }.width('100%').height('100%')
        Row() {
          Blank()
          Row().width(3).height('100%')
            .linearGradient({ angle: 90, colors: [['#D9FFFFFF', 0], ['#E6D6CAB4', 0.5], ['#D9FFFFFF', 1]] })
        }.width('100%').height('100%')
      }
        .width('100%').height('100%')
        .borderRadius({ topLeft: 2, bottomLeft: 2, topRight: 5, bottomRight: 5 }).clip(true)
        .shadow({ radius: 2, color: '#333C2D1E', offsetY: 2 })
    }
      .width('100%').aspectRatio(0.7)
      .shadow({ radius: 8, color: '#593C2D1E', offsetY: 7 })
  }
  @Builder private shelfCard(index: number) {
    Column({ space: 7 }) {
      if (index === 0) {
        this.writeCover()
        Column() {
          Text('写一本新书').fontFamily('serif').fontSize(14.5).fontWeight(FontWeight.Medium).fontColor(Theme.INK)
            .maxLines(1).width('100%')
        }.height(40).width('100%').alignItems(HorizontalAlign.Start)
      } else if (index <= this.books.length) {
        this.bookCover(this.books[index - 1])
        Column({ space: 1 }) {
          Text(this.books[index - 1].main).fontFamily('serif').fontSize(14.5).fontWeight(FontWeight.Medium)
            .fontColor(Theme.INK).maxLines(1).width('100%')
          Text(this.books[index - 1].chapters > 0 ? `${this.books[index - 1].chapters} 章` : this.books[index - 1].sub)
            .fontSize(12.5).fontColor('#A89E8E').maxLines(1).width('100%')
        }.height(40).width('100%').alignItems(HorizontalAlign.Start)
      }
    }.layoutWeight(1).onClick(() => {
      if (index === 0) this.onWrite();
      else if (index <= this.books.length) this.onRead(this.books[index - 1]);
    })
  }
  @Builder private shelfRow(startIndex: number) {
    Column() {
      Row({ space: 19 }) {
        this.shelfCard(startIndex)
        if (startIndex + 1 < this.shelfItemCount()) this.shelfCard(startIndex + 1)
        else Blank().layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Top).padding({ left: 18, right: 18 })
      Row() {
        Row().width('100%').height(6)
          .linearGradient({ angle: 180, colors: [['#E3D7C2', 0], ['#C9B99E', 1]] })
          .borderRadius(1).shadow({ radius: 3.5, color: '#2E785F3C', offsetY: 3 })
      }.width('100%').padding({ left: 14, right: 14, top: 2, bottom: 14 })
    }.width('100%').padding({ top: startIndex === 0 ? 0 : 8 })
  }
  build() {
    Column() {
      if (this.loading && this.books.length === 0) {
        Column({ space: 12 }) {
          LoadingProgress().width(32).height(32).color(Theme.ACCENT_STRONG)
          Text('正在整理书架…').fontSize(14).fontColor(Theme.SECONDARY)
        }
          .layoutWeight(1).width('100%')
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      }
      else if (this.error.length > 0 && this.books.length === 0) Text(this.error).layoutWeight(1).width('100%').textAlign(TextAlign.Center).fontColor(Theme.SECONDARY)
      else Stack({ alignContent: Alignment.Top }) {
        Refresh({ refreshing: this.refreshing, builder: () => { this.refreshPlaceholder() } }) {
          List() {
            ForEach(this.shelfRows(), (startIndex: number) => {
              ListItem() { this.shelfRow(startIndex) }
            }, (startIndex: number) => `${startIndex}`)
          }.width('100%').height('100%').padding({ bottom: 28 }).scrollBar(BarState.Off)
        }
          .width('100%').height('100%')
          .onStateChange((status: RefreshStatus) => this.refreshStatus = status)
          .onOffsetChange((offset: number) => this.refreshOffset = offset)
          .onRefreshing(() => { this.refreshing = true; this.load().catch(() => {}); })
        if (this.refreshing ||
          ((this.refreshStatus === RefreshStatus.Drag || this.refreshStatus === RefreshStatus.OverDrag) &&
            this.refreshOffset > 0)) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(Theme.ACCENT_STRONG)
            .translate({ y: Math.max(0, this.refreshOffset / 2 - 20) })
        }
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }
}

@Component
export struct BookReaderPage {
  @StorageLink('safeAreaTopPx') private safeAreaTopPx: number = 0;
  @StorageLink('safeAreaBottomPx') private safeAreaBottomPx: number = 0;
  book: ShelfBook = new ShelfBook();
  onBack: () => void = () => {};
  @State private loading: boolean = true;
  @State private showMoreMenu: boolean = false;
  @State private showShareSheet: boolean = false;
  @State private showRevise: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private currentPageUrl: string = '';
  private currentPageTitle: string = '';
  private currentShare(): WechatBookShareTargetValue {
    return WechatBookShare.target(this.book.readerUrl(), this.currentPageUrl, this.currentPageTitle,
      this.book.title || this.book.main, this.book.author);
  }
  private async shareBook(target: WechatBookShareTarget): Promise<void> {
    this.showShareSheet = false;
    const share: WechatBookShareTargetValue = this.currentShare();
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      if (!WechatCommunityShare.isWechatInstalled()) {
        await pasteboard.getSystemPasteboard().setData(
          pasteboard.createPlainTextData(`${share.title}\n${share.url}`));
        promptAction.showToast({ message: '没检测到微信，链接在剪贴板里' });
        return;
      }
      if (this.book.cover) promptAction.showToast({ message: '正在准备微信分享…' });
      const message: string = await WechatCommunityShare.sendBook(context, this.book, share, target);
      promptAction.showToast({ message: message });
    } catch (error) {
      promptAction.showToast({ message: `微信分享失败：${String(error)}` });
    }
  }
  private async shareBookWithSystem(): Promise<void> {
    this.showShareSheet = false;
    const share: WechatBookShareTargetValue = this.currentShare();
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const record: systemShare.SharedRecord = {
        utd: 'general.plain-text',
        content: `${share.title}\n${share.url}`,
        title: share.title
      };
      const data: systemShare.SharedData = new systemShare.SharedData(record);
      await new systemShare.ShareController(data).show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (_) {
      promptAction.showToast({ message: '无法打开系统分享面板' });
    }
  }
  private async copyBookLink(): Promise<void> {
    this.showShareSheet = false;
    try {
      await pasteboard.getSystemPasteboard().setData(
        pasteboard.createPlainTextData(this.currentShare().url));
      promptAction.showToast({ message: '链接已复制' });
    } catch (_) {
      promptAction.showToast({ message: '复制失败' });
    }
  }
  private shareTargets(): ShareSheetTarget[] {
    return DetailShareUi.targetIds('book').map((id: string) => this.shareTarget(id));
  }
  private shareTarget(id: string): ShareSheetTarget {
    if (id === 'friend') return new ShareSheetTarget(id, '微信好友', RI.WECHAT, '#07C160', '#FFFFFF', 26);
    if (id === 'timeline') return new ShareSheetTarget(id, '朋友圈', RI.CAMERA_LENS, '#07C160', '#FFFFFF', 27);
    if (id === 'copy') return new ShareSheetTarget(id, '复制链接', RI.LINK, '#F3F1ED', Theme.SECONDARY, 23);
    return new ShareSheetTarget(id, '其它分享', RI.SHARE_FORWARD, '#F3F1ED', Theme.SECONDARY, 24);
  }
  private runShareAction(id: string): void {
    if (id === 'friend') this.shareBook('friend').catch(() => {});
    else if (id === 'timeline') this.shareBook('timeline').catch(() => {});
    else if (id === 'copy') this.copyBookLink().catch(() => {});
    else if (id === 'system') this.shareBookWithSystem().catch(() => {});
  }
  private safeAreaBottom(): number {
    return this.safeAreaBottomPx > 0 ? this.getUIContext().px2vp(this.safeAreaBottomPx) : 0;
  }
  private safeAreaTop(): number {
    return this.safeAreaTopPx > 0 ? this.getUIContext().px2vp(this.safeAreaTopPx) : 0;
  }
  private closeRevise(): void {
    this.showRevise = false;
    try { this.controller.refresh(true); } catch (_) {}
  }
  private runMoreAction(id: string): void {
    this.showMoreMenu = false;
    if (id === 'revise') this.showRevise = true;
    else if (id === 'share') this.showShareSheet = true;
  }
  private moreMenuLabel(id: string): string {
    return id === 'revise' ? '修改这本书' : '分享';
  }
  private moreMenuGlyph(id: string): string {
    return id === 'revise' ? RI.EDIT : RI.SHARE_FORWARD;
  }
  @Builder private moreMenuRow(id: string) {
    Row() {
      Text(this.moreMenuLabel(id)).fontSize(14).fontColor(Theme.INK).layoutWeight(1).maxLines(1)
      RemixIcon({ glyph: this.moreMenuGlyph(id), iconSize: 20, color: Theme.INK })
    }
      .height(44).padding({ left: 14, right: 12 }).width('100%')
      .onClick(() => this.runMoreAction(id))
  }
  @Builder private bookMoreMenu() {
    Column() {
      ForEach(DetailShareUi.bookMenuIds(), (id: string, index: number) => {
        this.moreMenuRow(id)
        if (index < DetailShareUi.bookMenuIds().length - 1) {
          Divider().color('#E0D8CC').margin({ left: 14, right: 14 })
        }
      }, (id: string) => id)
    }
      .padding({ top: 1, bottom: 1 }).width(196)
      .backgroundColor('#FCFFFFFF')
      .border({ width: 1, color: '#ECE7DE', radius: 14 })
      .borderRadius(14).clip(true)
      .shadow({ radius: 12, color: '#2B2A2529', offsetX: 0, offsetY: 5 })
  }
  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        PageHeader({
          title: this.book.main,
          actionGlyph: RI.MORE,
          actionLabel: '更多',
          actionFilled: false,
          rightInset: DetailShareUi.MENU_RIGHT_INSET,
          onBack: () => {
            if (this.showMoreMenu) this.showMoreMenu = false;
            else if (this.showShareSheet) this.showShareSheet = false;
            else this.onBack();
          },
          onAction: () => this.showMoreMenu = !this.showMoreMenu
        }).backgroundColor(Theme.BOOK_READER_BG)
        Stack({ alignContent: Alignment.Top }) {
          Web({ src: this.book.readerUrl(), controller: this.controller })
            .width('100%').height('100%')
            .javaScriptAccess(true).domStorageAccess(true).fileAccess(false).mixedMode(MixedMode.None)
            .onPageBegin((event: OnPageBeginEvent): void => {
              this.loading = true;
              this.currentPageUrl = event.url;
              this.currentPageTitle = '';
            })
            .onPageEnd((event: OnPageEndEvent): void => {
              this.loading = false;
              this.currentPageUrl = event.url;
            })
            .onRefreshAccessedHistory((event: OnRefreshAccessedHistoryEvent): void => {
              this.currentPageUrl = event.url;
            })
            .onTitleReceive((event: OnTitleReceiveEvent): void => {
              this.currentPageTitle = event.title;
            })
            .onErrorReceive((event: OnErrorReceiveEvent): void => {
              if (event.request.isMainFrame()) this.loading = false;
            })
          if (this.loading) {
            Column() {
              Column({ space: 14 }) {
                LoadingProgress().width(40).height(40).color(Theme.ACCENT_STRONG)
                Text('正在加载...').fontSize(16).fontColor(Theme.SECONDARY)
              }
                .height(180).margin({ top: 50 }).width('100%')
                .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              Blank()
            }.width('100%').height('100%').backgroundColor(Theme.BOOK_READER_BG)
          }
        }.layoutWeight(1).width('100%').backgroundColor(Theme.BOOK_READER_BG)
      }
        .width('100%')
        .height('100%')
        .padding({ top: this.safeAreaTop() })
        .backgroundColor(Theme.BOOK_READER_BG)
      if (this.showMoreMenu) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column().width('100%').height('100%').onClick(() => this.showMoreMenu = false)
          Column() { this.bookMoreMenu() }.margin({
            top: this.safeAreaTop() + DetailShareUi.MENU_TOP_OFFSET,
            right: DetailShareUi.MENU_RIGHT_INSET
          }).zIndex(1)
        }.width('100%').height('100%').zIndex(9)
      }
      if (this.showShareSheet) {
        ShareBottomSheet({
          targets: this.shareTargets(),
          safeAreaBottom: this.safeAreaBottom(),
          onDismiss: () => this.showShareSheet = false,
          onSelect: (id: string) => this.runShareAction(id)
        }).zIndex(10)
      }
      if (this.showRevise) {
        BookRevisePage({ book: this.book, onClose: () => this.closeRevise() }).zIndex(20)
      }
    }.width('100%').height('100%').backgroundColor(Theme.BOOK_READER_BG)
  }
}
