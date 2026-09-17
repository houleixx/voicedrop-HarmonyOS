import { authStore } from '../data/AuthStore';
import { BookShelfSearch, ShelfSearchEntry, BookSearchRequestState } from '../core/BookShelfSearch';
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
import { BooksService, ShelfBook, booksService } from '../data/BooksService';
import { BookCoverRequest, bookCoverStore } from '../data/BookCoverStore';
import { BookCoverPolicy } from '../core/BookCoverPolicy';
import { BookShelfLoadingPolicy } from '../core/BookShelfLoadingPolicy';
import { WechatCommunityShare } from '../data/WechatCommunityShare';
import { WechatBookShare, WechatBookShareTarget, WechatBookShareTargetValue } from '../core/WechatBookShare';
import { DetailShareUi } from '../core/DetailShareUi';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { ShareBottomSheet, ShareSheetTarget } from '../components/ShareBottomSheet';
import { BookRevisePage } from './BookRevisePage';
import { AppLocale } from '../core/AppLocale';
import { BookPdfDownloadPolicy } from '../core/BookPdfDownloadPolicy';
import { httpClient } from '../net/HttpClient';

@Component
struct CachedBookCoverImage {
  @Prop @Watch('onBookChanged') book: ShelfBook = new ShelfBook();
  @State private source: string = '';
  private active: boolean = false;
  private generation: number = 0;
  private displayRecoveryUsed: boolean = false;
  private request?: BookCoverRequest;

  aboutToAppear(): void {
    this.active = true;
    this.restoreOrLoad().catch(() => {});
  }

  aboutToDisappear(): void {
    this.active = false;
    this.generation++;
    this.request?.cancel();
    if (this.request) bookCoverStore.release(this.request);
    this.request = undefined;
  }

  private onBookChanged(): void {
    this.generation++;
    this.request?.cancel();
    if (this.request) bookCoverStore.release(this.request);
    this.request = undefined;
    this.displayRecoveryUsed = false;
    this.source = '';
    if (this.active) this.restoreOrLoad().catch(() => {});
  }

  private async restoreOrLoad(): Promise<void> {
    const generation: number = ++this.generation;
    const source: string = await bookCoverStore.cachedSource(this.book);
    if (!BookCoverPolicy.shouldApplyResult(this.active, generation, this.generation)) return;
    if (source.length > 0) {
      this.source = source;
      return;
    }
    await this.load();
  }

  private onDisplayError(): void {
    if (!BookCoverPolicy.shouldRecoverDisplayFailure(this.displayRecoveryUsed)) return;
    this.displayRecoveryUsed = true;
    this.source = '';
    bookCoverStore.invalidate(this.book);
    this.load().catch(() => {});
  }

  private async load(): Promise<void> {
    const request: BookCoverRequest | undefined = bookCoverStore.request(this.book);
    if (!request) return;
    this.request?.cancel();
    if (this.request) bookCoverStore.release(this.request);
    this.request = request;
    const generation: number = ++this.generation;
    const source: string = await request.load();
    if (source.length > 0 && BookCoverPolicy.shouldApplyResult(this.active, generation, this.generation)) {
      this.source = source;
    }
    bookCoverStore.release(request);
    if (this.request === request) this.request = undefined;
  }

  build() {
    if (this.source.length > 0) {
      Image(this.source).width('100%').height('100%').objectFit(ImageFit.Cover)
        .onError(() => this.onDisplayError())
    }
  }
}

@Component
export struct BooksShelfPage {
  onWrite: () => void = () => {};
  onRead: (book: ShelfBook) => void = () => {};
  @Prop @Watch('onAccountChanged') accountRevision: number = 0;
  @State private books: ShelfBook[] = [];
  @State private visibleBooks: ShelfBook[] = [];
  @StorageProp('appDisplayLanguage') private displayLanguage: string = AppLocale.currentLanguage();
  @State private filter: string = '全部';
  @State private searching: boolean = false;
  @State private query: string = '';
  @State private searchLoading: boolean = false;
  @State private searchFailed: boolean = false;
  private searchEntries: ShelfSearchEntry[] = [];
  private searchRequest: BookSearchRequestState = new BookSearchRequestState();
  private searchInput: TextInputController = new TextInputController();
  private loadGeneration: number = 0;
  private active: boolean = false;
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private refreshStatus: RefreshStatus = RefreshStatus.Inactive;
  @State private refreshOffset: number = 0;
  @State private error: string = '';

  aboutToAppear(): void {
    this.active = true;
    this.onAccountChanged();
  }
  aboutToDisappear(): void {
    this.active = false; this.loadGeneration++;
    this.searchRequest.invalidate(''); this.searchEntries = [];
  }
  private onAccountChanged(): void {
    this.invalidateSearch();
    this.books = booksService.cached(); this.loading = this.books.length === 0;
    this.updateVisible();
    if (this.active) this.load().catch(() => {});
  }
  private invalidateSearch(): void {
    this.searchRequest.invalidate(authStore.bookShelfCacheIdentity());
    this.searchEntries = []; this.searchLoading = false; this.searchFailed = false;
  }
  private updateVisible(): void {
    this.visibleBooks = this.books.filter((book: ShelfBook) => BookShelfSearch.matchesFilter(book, this.filter) &&
      BookShelfSearch.hit(book, this.query, this.searchEntries.find((entry: ShelfSearchEntry) => entry.slug === book.slug)) !== undefined);
  }
  private async load(): Promise<void> {
    const generation: number = ++this.loadGeneration;
    this.invalidateSearch(); this.updateVisible();
    try {
      const books: ShelfBook[] = await booksService.load();
      if (!this.active || generation !== this.loadGeneration) return;
      this.books = books; this.error = '';
      if (!BookShelfSearch.filters(this.books).includes(this.filter)) this.filter = '全部';
      this.updateVisible();
    } catch (_) {
      if (this.active && generation === this.loadGeneration && this.books.length === 0) this.error = AppLocale.text('书架加载失败，下拉重试');
    } finally {
      if (this.active && generation === this.loadGeneration) {
        this.loading = false; this.refreshing = false;
        this.loadSearch().catch(() => {});
      }
    }
  }
  private async loadSearch(retry: boolean = false): Promise<void> {
    const generation: number = this.searchRequest.begin(this.query, retry);
    if (generation < 0) return;
    this.searchLoading = true; this.searchFailed = false;
    try {
      const entries: ShelfSearchEntry[] = await booksService.searchIndex();
      if (!this.active || !this.searchRequest.finish(generation, authStore.bookShelfCacheIdentity(), true)) return;
      this.searchEntries = entries; this.updateVisible();
    } catch (_) {
      if (!this.active || !this.searchRequest.finish(generation, authStore.bookShelfCacheIdentity(), false)) return;
      this.searchFailed = true;
    } finally {
      if (this.searchRequest.accepts(generation, authStore.bookShelfCacheIdentity())) this.searchLoading = false;
    }
  }
  private updateQuery(value: string): void {
    this.query = value; this.updateVisible();
    if (!this.loading && !this.refreshing) this.loadSearch().catch(() => {});
  }
  private cancelSearch(): void {
    this.searchInput.stopEditing();
    this.searching = false; this.query = ''; this.updateVisible();
    if (this.searchRequest.failed) this.invalidateSearch();
  }
  private bookIndex(index: number): number { return index - (BookShelfSearch.showWrite(this.query) ? 1 : 0); }
  private shelfItemCount(): number { return this.visibleBooks.length + (BookShelfSearch.showWrite(this.query) ? 1 : 0); }
  private bookDetail(book: ShelfBook): string {
    const hit: string = BookShelfSearch.hit(book, this.query,
      this.searchEntries.find((entry: ShelfSearchEntry) => entry.slug === book.slug)) ?? '';
    if (hit.length > 0) return `↳ ${hit}`;
    return [book.chapters > 0 ? `${book.chapters}${AppLocale.text('章')}` : book.sub, AppLocale.resolve(this.displayLanguage, book.category)].filter((part: string) => part.length > 0).join(' · ') || book.sub;
  }
  @Builder private searchToolbar() {
    // Keep filtering and searching in the same slot so content never moves on toggle.
    Stack({ alignContent: Alignment.Top }) {
      if (this.searching) {
        Row({ space: 10 }) {
          TextInput({ text: this.query, placeholder: AppLocale.text('搜书名、作者、章节'), controller: this.searchInput })
            .id('bookShelfSearchInput')
            .onAppear(() => {
              setTimeout(() => { if (this.searching) focusControl.requestFocus('bookShelfSearchInput'); }, 50);
            })
            .height(34).layoutWeight(1).fontSize(14).fontColor(Theme.INK).placeholderColor(Theme.FAINT)
            .backgroundColor(Theme.CARD).borderRadius(18).border({ width: 0.5, color: Theme.BORDER })
            .onChange((value: string) => this.updateQuery(value))
          Text(AppLocale.text('取消')).fontSize(14).fontColor(Theme.INK).onClick(() => this.cancelSearch())
        }.height(42).padding({ left: 14, right: 18 }).width('100%')
      } else {
        Row({ space: 4 }) {
          Scroll() {
            Row({ space: 12 }) {
              ForEach(BookShelfSearch.filters(this.books), (filter: string) => {
                Text(AppLocale.resolve(this.displayLanguage, filter))
                  .fontSize(15).fontWeight(this.filter === filter ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.filter === filter ? Theme.INK : Theme.SECONDARY)
                  .padding({ left: 4, right: 4, top: 4, bottom: 4 })
                  .onClick(() => { this.filter = filter; this.updateVisible(); })
              }, (filter: string) => `${filter}:${this.displayLanguage}`)
            }
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).layoutWeight(1)
          Row() { RemixIcon({ glyph: RI.SEARCH, iconSize: 20, color: Theme.SECONDARY }) }
            .width(40).height(40).justifyContent(FlexAlign.Center)
            .accessibilityText(AppLocale.text('搜索')).onClick(() => this.searching = true)
        }.height(42).padding({ left: 14, right: 14 }).width('100%')
      }
    }.width('100%').height(46).padding({ bottom: 4 })
    if (this.query.trim().length > 0 && (this.searchLoading || this.searchFailed)) {
      Text(AppLocale.text(this.searchLoading ? '正在翻章节…' : '章节搜索暂不可用，点此重试'))
        .fontSize(12).fontColor(Theme.SECONDARY).padding(8)
        .onClick(() => { if (this.searchFailed) this.loadSearch(true).catch(() => {}); })
    }
  }
  private emptyMessage(): string {
    if (this.searchLoading && this.query.trim().length > 0) return AppLocale.text('正在翻章节…');
    if (this.query.trim().length > 0) return `${AppLocale.text('没有找到：')}${this.query.trim()}`;
    return AppLocale.text(this.filter === '我的' ? '还没有你的书，点「写书」开始' : '书架还没有书，点「写书」开始');
  }
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
      Text(AppLocale.text('写书')).fontSize(15).fontWeight(FontWeight.Medium).letterSpacing(1).fontColor('#6F685D')
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
        Column({ space: 10 }) {
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
        if (book.cover) CachedBookCoverImage({ book: book })
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
      if (book.hidden) {
        Text(AppLocale.text('隐藏'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#B8654A')
          .borderRadius(10)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .position({ top: 8, right: 8 })
      }
    }
      .width('100%').aspectRatio(0.7)
      .shadow({ radius: 8, color: '#593C2D1E', offsetY: 7 })
  }
  @Builder private shelfCard(index: number) {
    Column({ space: 7 }) {
      if (this.bookIndex(index) < 0) {
        this.writeCover()
        Column() {
          Text(AppLocale.text('写一本新书')).fontFamily('serif').fontSize(14.5).fontWeight(FontWeight.Medium).fontColor(Theme.INK)
            .maxLines(1).width('100%')
        }.height(40).width('100%').alignItems(HorizontalAlign.Start)
      } else if (this.bookIndex(index) < this.visibleBooks.length) {
        this.bookCover(this.visibleBooks[this.bookIndex(index)])
        Column({ space: 1 }) {
          Text(this.visibleBooks[this.bookIndex(index)].main).fontFamily('serif').fontSize(14.5).fontWeight(FontWeight.Medium)
            .fontColor(Theme.INK).maxLines(1).width('100%')
          Text(this.bookDetail(this.visibleBooks[this.bookIndex(index)]))
            .fontSize(12.5).fontColor('#A89E8E').maxLines(1).width('100%')
        }.height(40).width('100%').alignItems(HorizontalAlign.Start)
      }
    }.layoutWeight(1).onClick(() => {
      if (this.bookIndex(index) < 0) this.onWrite();
      else if (this.bookIndex(index) < this.visibleBooks.length) this.onRead(this.visibleBooks[this.bookIndex(index)]);
    })
  }
  @Builder private shelfRow(startIndex: number, isLast: boolean) {
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
      }.width('100%').padding({ left: 14, right: 14, top: 2, bottom: isLast ? 0 : 14 })
    }.width('100%').padding({ top: startIndex === 0 ? 0 : 8 })
  }
  build() {
    Column() {
      this.searchToolbar()
      if (BookShelfLoadingPolicy.shouldShowExclusiveLoading(this.loading, this.books.length)) {
        Column({ space: 12 }) {
          LoadingProgress().width(32).height(32).color(Theme.ACCENT_STRONG)
          Text(AppLocale.text('正在整理书架…')).fontSize(14).fontColor(Theme.SECONDARY)
        }
          .layoutWeight(1).width('100%')
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      }
      else if (this.error.length > 0 && this.books.length === 0) Text(AppLocale.text(this.error)).layoutWeight(1).width('100%').textAlign(TextAlign.Center).fontColor(Theme.SECONDARY)
      else Stack({ alignContent: Alignment.Top }) {
        Refresh({ refreshing: this.refreshing, builder: () => { this.refreshPlaceholder() } }) {
          Scroll() {
            Column() {
              if (this.visibleBooks.length === 0) {
                Text(this.emptyMessage()).fontSize(14).fontColor(Theme.SECONDARY).padding(24).width('100%').textAlign(TextAlign.Center)
              }
              ForEach(this.shelfRows(), (startIndex: number) => {
                this.shelfRow(startIndex, startIndex + 2 >= this.shelfItemCount())
              }, (startIndex: number) => BookShelfSearch.rowKey(this.visibleBooks, this.query, startIndex))
            }.width('100%').padding({ bottom: 24 })
          }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
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
  @State private isMine: boolean = false;
  @State private isHidden: boolean = false;
  @State private changingHidden: boolean = false;
  @State private downloadingPdf: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private currentPageUrl: string = '';
  private currentPageTitle: string = '';
  aboutToAppear(): void {
    // The shelf's mine flag is only a first-frame hint. Ownership may have
    // changed since its cache was written, so menu permissions come from here.
    this.isMine = this.book.mine;
    this.isHidden = this.book.hidden;
    this.loadOwnership().catch(() => {});
  }
  private currentShare(): WechatBookShareTargetValue {
    return WechatBookShare.target(this.book.shareUrl(), this.currentPageUrl, this.currentPageTitle,
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
        promptAction.showToast({ message: AppLocale.text('没检测到微信，链接在剪贴板里') });
        return;
      }
      if (this.book.cover) promptAction.showToast({ message: AppLocale.text('正在准备微信分享…') });
      const message: string = await WechatCommunityShare.sendBook(context, this.book, share, target);
      promptAction.showToast({ message: message });
    } catch (error) {
      promptAction.showToast({ message: `${AppLocale.text('微信分享失败：')}${String(error)}` });
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
      promptAction.showToast({ message: AppLocale.text('无法打开系统分享面板') });
    }
  }
  private async copyBookLink(): Promise<void> {
    this.showShareSheet = false;
    try {
      await pasteboard.getSystemPasteboard().setData(
        pasteboard.createPlainTextData(this.currentShare().url));
      promptAction.showToast({ message: AppLocale.text('链接已复制') });
    } catch (_) {
      promptAction.showToast({ message: AppLocale.text('复制失败') });
    }
  }
  private shareTargets(): ShareSheetTarget[] {
    return DetailShareUi.targetIds('book').map((id: string) => this.shareTarget(id));
  }
  private shareTarget(id: string): ShareSheetTarget {
    if (id === 'friend') return new ShareSheetTarget(id, AppLocale.text('微信好友'), RI.WECHAT, '#07C160', '#FFFFFF', 26);
    if (id === 'timeline') return new ShareSheetTarget(id, AppLocale.text('朋友圈'), RI.CAMERA_LENS, '#07C160', '#FFFFFF', 27);
    if (id === 'copy') return new ShareSheetTarget(id, AppLocale.text('复制链接'), RI.LINK, '#F3F1ED', Theme.SECONDARY, 23);
    return new ShareSheetTarget(id, AppLocale.text('其它分享'), RI.SHARE_FORWARD, '#F3F1ED', Theme.SECONDARY, 24);
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
  private async downloadBookPdf(url: string = BookPdfDownloadPolicy.url(this.book.slug)): Promise<void> {
    if (this.downloadingPdf) return;
    if (!BookPdfDownloadPolicy.isTrustedUrl(url, this.book.slug)) {
      promptAction.showToast({ message: AppLocale.text('这本书暂时不能下载') });
      return;
    }
    this.downloadingPdf = true;
    let destinationUri: string = '';
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [BookPdfDownloadPolicy.fileName(this.book.title || this.book.main, this.book.slug)];
      options.fileSuffixChoices = ['PDF 文档|.pdf'];
      const uris: string[] = await new picker.DocumentViewPicker(context).save(options);
      if (uris.length === 0) {
        promptAction.showToast({ message: AppLocale.text('已取消保存') });
        return;
      }
      destinationUri = uris[0];
      promptAction.showToast({ message: AppLocale.text('正在生成 PDF，首次下载约需一分钟') });
      const response = await httpClient.getBytes(url, '', 180000);
      if (!response.ok() || response.data.byteLength === 0) throw new Error(`HTTP ${response.code}`);
      const destination: fs.File = fs.openSync(destinationUri, fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try { fs.writeSync(destination.fd, response.data); }
      finally { fs.closeSync(destination); }
      promptAction.showToast({ message: AppLocale.text('PDF 已保存') });
    } catch (_) {
      if (destinationUri.length > 0) try { fs.unlinkSync(destinationUri); } catch (_) {}
      promptAction.showToast({ message: AppLocale.text('下载失败，请检查网络后重试') });
    } finally { this.downloadingPdf = false; }
  }
  private closeRevise(): void {
    this.showRevise = false;
    try { this.controller.refresh(true); } catch (_) {}
  }
  private async loadOwnership(): Promise<void> {
    const ownership = await booksService.ownership(this.book.slug);
    this.isMine = ownership.mine;
    this.isHidden = ownership.hidden;
  }
  private async toggleHidden(): Promise<void> {
    if (!this.isMine || this.changingHidden) return;
    const next: boolean = !this.isHidden;
    this.changingHidden = true;
    try {
      await booksService.setHidden(this.book.slug, next);
      this.isHidden = next;
      promptAction.showToast({ message: AppLocale.text(next ? '已隐藏，书架上看不到了' : '已取消隐藏') });
    } catch (error) {
      const message: string = String(error);
      if (message.includes('HTTP 403')) {
        this.isMine = false;
        promptAction.showToast({ message: AppLocale.text('这不是你的书，改不了') });
      } else {
        promptAction.showToast({ message: AppLocale.text('没改成，过会儿再试') });
      }
    } finally { this.changingHidden = false; }
  }
  private moreMenuIds(): string[] {
    return this.isMine ? ['hidden', 'revise', 'download', 'share'] : ['download', 'share'];
  }
  private runMoreAction(id: string): void {
    this.showMoreMenu = false;
    if (id === 'hidden') this.toggleHidden().catch(() => {});
    else if (id === 'revise') this.showRevise = true;
    else if (id === 'download') this.downloadBookPdf().catch(() => {});
    else if (id === 'share') this.showShareSheet = true;
  }
  private moreMenuLabel(id: string): string {
    if (id === 'hidden') return AppLocale.text(this.isHidden ? '取消隐藏本书' : '隐藏本书');
    if (id === 'revise') return AppLocale.text('修改这本书');
    return AppLocale.text(id === 'download' ? '下载 PDF' : '分享');
  }
  private moreMenuGlyph(id: string): string {
    if (id === 'hidden') return RI.CLOSE;
    if (id === 'revise') return RI.EDIT;
    return id === 'download' ? RI.DOWNLOAD : RI.SHARE_FORWARD;
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
      ForEach(this.moreMenuIds(), (id: string, index: number) => {
        this.moreMenuRow(id)
        if (index < this.moreMenuIds().length - 1) {
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
          actionLabel: AppLocale.text('更多'),
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
            .onDownloadStart((event: OnDownloadStartEvent): void => {
              this.downloadBookPdf(event.url).catch(() => {});
            })
          if (this.loading) {
            Column() {
              Column({ space: 14 }) {
                LoadingProgress().width(40).height(40).color(Theme.ACCENT_STRONG)
                Text(AppLocale.text('正在加载...')).fontSize(16).fontColor(Theme.SECONDARY)
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
