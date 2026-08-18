import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { AppPreferences } from '../data/AppPreferences';
import { authStore } from '../data/AuthStore';
import { ShareDatasetSnapshot, ShareImport, ShareImportKind } from '../core/ShareImport';
import { PrivacyStartup } from '../core/PrivacyStartup';
import { ShareCollectResult, shareCollectService } from '../share/ShareCollectService';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

const shareStorage: LocalStorage = new LocalStorage();

enum DatasetIncomingState {
  SAVING = 'saving',
  DONE = 'done',
  FAILED = 'failed'
}

@Entry(shareStorage)
@Component
struct ShareCollectPage {
  @LocalStorageProp('shareType') private shareType: string = '';
  @LocalStorageProp('shareUris') private shareUris: string = '[]';
  @LocalStorageProp('shareText') private shareText: string = '';
  @LocalStorageProp('shareTitle') private shareTitle: string = '';
  @State private kind: ShareImportKind = ShareImportKind.DATASET;
  @State private dataset: ShareDatasetSnapshot = new ShareDatasetSnapshot();
  @State private clearAfter: boolean = true;
  @State private busy: boolean = false;
  @State private ready: boolean = false;
  @State private message: string = '';
  @State private incomingState: DatasetIncomingState = DatasetIncomingState.SAVING;
  @State private incomingTitle: string = '正在读取分享内容…';
  @State private incomingTypeLabel: string = '文字';
  @State private incomingMeta: string = '';
  private context?: common.UIExtensionContext;
  private datasetStarted: boolean = false;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIExtensionContext;
    this.initialize().catch((error: Object) => {
      this.message = `分享初始化失败：${String(error)}`;
      this.incomingTitle = '分享初始化失败';
      this.incomingState = DatasetIncomingState.FAILED;
      this.ready = true;
    });
  }

  onBackPress(): boolean {
    this.close(systemShare.ShareAbilityResultCode.BACK);
    return true;
  }

  private async initialize(): Promise<void> {
    if (!this.context) return;
    const store: preferences.Preferences =
      await preferences.getPreferences(this.context, { name: 'voicedrop.prefs' });
    const accepted: boolean = PrivacyStartup.accepted(
      String(store.getSync('privacyAcceptedVersion', '') ?? ''), AppPreferences.PRIVACY_VERSION);
    if (!accepted) {
      this.message = '请先打开 VoiceDrop，完成隐私确认和账号初始化后再分享。';
      this.incomingTitle = '需要先完成应用初始化';
      this.incomingState = DatasetIncomingState.FAILED;
      this.ready = true;
      return;
    }
    await authStore.initialize(this.context);
    const uris: string[] = this.uris();
    this.kind = ShareImport.classify(this.shareType, uris);
    if (this.kind !== ShareImportKind.DATASET) {
      this.ready = true;
      return;
    }
    await this.loadDataset();
    this.prepareIncomingDatasetItem();
    this.ready = true;
    if (!this.datasetStarted) await this.collectDatasetIncoming();
  }

  private uris(): string[] {
    try { return JSON.parse(this.shareUris) as string[]; } catch (_) { return []; }
  }

  private async loadDataset(): Promise<void> {
    this.dataset = await shareCollectService.fetchDataset();
  }

  private title(): string {
    if (this.kind === ShareImportKind.AUDIO) return '从这段录音成文';
    if (this.kind === ShareImportKind.IMAGE) return '看图写一篇';
    return '风格数据集';
  }

  private description(): string {
    if (this.kind === ShareImportKind.AUDIO) return '确认后上传音频，VoiceDrop 会自动转写并生成文章。';
    return `${this.uris().length} 张图片，确认后开始看图成文。`;
  }

  private preview(): string {
    const text: string = this.shareText.trim();
    if (text.length > 0) return text.length > 240 ? `${text.substring(0, 240)}…` : text;
    return this.uris().slice(0, 4).map((uri: string) => this.fileName(uri)).join('\n');
  }

  private fileName(uri: string): string {
    const clean: string = uri.split('?')[0];
    const raw: string = clean.substring(clean.lastIndexOf('/') + 1);
    try { return decodeURIComponent(raw) || '分享文档'; } catch (_) { return raw || '分享文档'; }
  }

  private webHost(value: string): string {
    const match: RegExpMatchArray | null = value.trim().match(/^https?:\/\/([^/?#]+)/i);
    return match?.[1] ?? value.trim();
  }

  private prepareIncomingDatasetItem(): void {
    const text: string = this.shareText.trim();
    const uris: string[] = this.uris();
    if (uris.length > 0) {
      this.incomingTypeLabel = '文档';
      this.incomingTitle = this.shareTitle.trim() || this.fileName(uris[0]);
      this.incomingMeta = uris.length > 1 ? `${uris.length} 个文档` : this.fileName(uris[0]);
    } else if (ShareImport.isWebUrl(text)) {
      this.incomingTypeLabel = '网页';
      this.incomingTitle = '正在解析网页…';
      this.incomingMeta = this.webHost(text);
    } else {
      this.incomingTypeLabel = '文字';
      this.incomingTitle = '正在保存…';
      this.incomingMeta = ShareImport.formatChars(text.length);
    }
  }

  private successfulIncomingTitle(): string {
    const explicit: string = this.shareTitle.trim();
    if (explicit.length > 0) return explicit;
    const text: string = this.shareText.trim();
    if (this.incomingTypeLabel === '网页') return this.webHost(text);
    if (this.incomingTypeLabel === '文档') return this.fileName(this.uris()[0] ?? '');
    return ShareImport.firstLineTitle(text, '分享的文字');
  }

  private async collectDatasetIncoming(): Promise<void> {
    if (!this.context || this.busy) return;
    this.datasetStarted = true;
    this.busy = true;
    this.incomingState = DatasetIncomingState.SAVING;
    this.message = '';
    try {
      const result: ShareCollectResult = await shareCollectService.collectIncoming(
        this.context, this.shareType, this.uris(), this.shareText, this.shareTitle);
      this.message = result.message;
      if (!result.ok) {
        this.incomingTitle = '未能保存本次内容';
        this.incomingState = DatasetIncomingState.FAILED;
        return;
      }
      this.incomingTitle = this.successfulIncomingTitle();
      this.incomingMeta = ShareImport.formatChars(result.collectedChars);
      this.incomingState = DatasetIncomingState.DONE;
      try {
        await this.loadDataset();
      } catch (_) {
        this.message = '内容已保存，但数据集统计刷新失败';
      }
    } catch (error) {
      this.message = `分享导入失败：${String(error)}`;
      this.incomingTitle = '未能保存本次内容';
      this.incomingState = DatasetIncomingState.FAILED;
    } finally {
      this.busy = false;
    }
  }

  private async confirmCompose(): Promise<void> {
    if (!this.context || !this.ready || this.busy) return;
    this.busy = true;
    try {
      const result: ShareCollectResult = await shareCollectService.collectIncoming(
        this.context, this.shareType, this.uris(), this.shareText, this.shareTitle);
      this.message = result.message;
      if (result.ok) this.close(systemShare.ShareAbilityResultCode.CLOSE);
    } catch (error) {
      this.message = `分享导入失败：${String(error)}`;
    } finally {
      this.busy = false;
    }
  }

  private async extractStyle(): Promise<void> {
    if (this.busy || !ShareImport.canExtract(this.dataset)) return;
    this.busy = true;
    try {
      const result: ShareCollectResult = await shareCollectService.extractStyle(this.clearAfter);
      this.message = result.message;
      if (result.ok) this.close(systemShare.ShareAbilityResultCode.CLOSE);
    } catch (error) {
      this.message = `文风提取失败：${String(error)}`;
    } finally {
      this.busy = false;
    }
  }

  private close(resultCode: number): void {
    this.context?.terminateSelfWithResult({ resultCode: resultCode }).catch(() => {});
  }

  private incomingGlyph(): string {
    return this.incomingTypeLabel === '网页' ? RI.LINK : RI.FILE_TEXT;
  }

  private incomingSubtitle(): string {
    if (this.incomingState === DatasetIncomingState.DONE) {
      return `${this.incomingTypeLabel} · ${this.incomingMeta} · 刚刚`;
    }
    if (this.incomingState === DatasetIncomingState.FAILED) {
      return `${this.incomingTypeLabel} · ${this.message || '请关闭后重试'}`;
    }
    return `${this.incomingTypeLabel} · ${this.incomingMeta}`;
  }

  @Builder
  private datasetHeader() {
    Column({ space: 3 }) {
      Row({ space: 12 }) {
        Column({ space: 3 }) {
          Text('风格数据集')
            .fontSize(21).fontWeight(FontWeight.Bold).fontColor(Theme.INK).width('100%')
          Text(`已收集 ${this.dataset.count} 项 · ${ShareImport.formatTotalChars(this.dataset.totalChars)}`)
            .fontSize(13).fontColor(Theme.SECONDARY).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button('关闭')
          .height(40).padding({ left: 10, right: 2 }).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(Theme.SECONDARY).backgroundColor(Color.Transparent).enabled(!this.busy)
          .onClick(() => this.close(systemShare.ShareAbilityResultCode.BACK))
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').padding({ left: 20, right: 20, bottom: 12 })
  }

  @Builder
  private incomingDatasetCard() {
    Row({ space: 12 }) {
      Row() {
        RemixIcon({ glyph: this.incomingGlyph(), iconSize: 19,
          color: this.incomingState === DatasetIncomingState.DONE ? '#C0682E' : Theme.SECONDARY })
      }
        .justifyContent(FlexAlign.Center).width(42).height(42).borderRadius(10)
        .backgroundColor(this.incomingState === DatasetIncomingState.DONE ? '#F3DDCB' : Theme.TILE_NEUTRAL)
      Column({ space: 3 }) {
        Text(this.incomingTitle)
          .fontSize(15).fontWeight(this.incomingState === DatasetIncomingState.DONE ?
            FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.incomingState === DatasetIncomingState.DONE ? '#9A4A30' : Theme.SECONDARY)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(this.incomingSubtitle())
          .fontSize(12).fontColor(this.incomingState === DatasetIncomingState.DONE ? '#A9674D' : '#8A8175')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.incomingState === DatasetIncomingState.SAVING) {
        LoadingProgress().width(20).height(20).color(Theme.AMBER)
      } else if (this.incomingState === DatasetIncomingState.DONE) {
        RemixIcon({ glyph: RI.CHECK, iconSize: 19, color: Theme.ACCENT })
      } else {
        RemixIcon({ glyph: RI.INFORMATION, iconSize: 20, color: '#A79F93' })
      }
    }
      .width('100%').padding({ left: 12, right: 12, top: 13, bottom: 13 }).borderRadius(12)
      .backgroundColor(this.incomingState === DatasetIncomingState.DONE ? '#FBF1E9' : Theme.CARD)
      .border({ width: 1, color: this.incomingState === DatasetIncomingState.DONE ? '#E8C9B8' : Theme.BORDER })
  }

  @Builder
  private datasetFooter() {
    Column({ space: 0 }) {
      Divider().strokeWidth(1).color(Theme.DIVIDER)
      Row({ space: 9 }) {
        Checkbox({ name: 'clearAfter', group: 'styleDataset' })
          .select(this.clearAfter)
          .selectedColor(Theme.ACCENT)
          .unselectedColor('#E2D8C8')
          .shape(CheckBoxShape.ROUNDED_SQUARE)
          .width(22).height(22)
          .enabled(!this.busy)
          .onChange((selected: boolean) => this.clearAfter = selected)
        Row() {
          Text('提取后清空数据集').fontSize(14).fontColor(Theme.SECONDARY)
          Blank()
          Text('下次从零开始').fontSize(12).fontColor('#8A8175')
        }
          .layoutWeight(1).height('100%').enabled(!this.busy)
          .onClick(() => this.clearAfter = !this.clearAfter)
      }.width('100%').height(52).alignItems(VerticalAlign.Center)
      if (this.ready && this.dataset.count > 0 && !ShareImport.canExtract(this.dataset)) {
        Text(`素材还太少（共 ${this.dataset.totalChars} 字），攒到 ${ShareImport.MIN_STYLE_CHARS} 字以上再提取`)
          .fontSize(12).fontColor('#C0682E').width('100%').padding({ bottom: 8 })
      }
      Row({ space: 10 }) {
        Button('继续收集')
          .width(110).height(50).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.INK)
          .backgroundColor(Theme.CARD).border({ width: 1, color: '#E2D8C8' }).borderRadius(11)
          .enabled(!this.busy).onClick(() => this.close(systemShare.ShareAbilityResultCode.CLOSE))
        Button() {
          Row({ space: 8 }) {
            if (this.busy && this.incomingState === DatasetIncomingState.DONE) {
              LoadingProgress().width(18).height(18).color(Theme.WHITE)
            } else {
              RemixIcon({ glyph: RI.DOWNLOAD, iconSize: 20, color: Theme.WHITE })
            }
            Text(this.busy && this.incomingState === DatasetIncomingState.DONE ? '处理中…' : '提取文章风格')
              .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.WHITE)
          }.justifyContent(FlexAlign.Center).width('100%')
        }
          .layoutWeight(1).height(50).backgroundColor(ShareImport.canExtract(this.dataset) ?
            Theme.ACCENT : '#D9B3A8').borderRadius(11)
          .enabled(!this.busy && ShareImport.canExtract(this.dataset)).onClick(() => this.extractStyle())
      }.width('100%')
    }.width('100%').padding({ left: 20, right: 20, bottom: 22 })
  }

  @Builder
  private datasetPage() {
    Column() {
      Row().width(40).height(5).borderRadius(3).backgroundColor('#DDD3C2')
        .margin({ top: 10, bottom: 8 })
      this.datasetHeader()
      Scroll() {
        Column({ space: 10 }) {
          Row({ space: 9 }) {
            Text('本次新增').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#C0682E')
              .letterSpacing(2)
            Divider().vertical(false).strokeWidth(1).color('#E8C9B8').layoutWeight(1)
          }.width('100%').padding({ left: 4, right: 4, top: 10, bottom: 4 })
          this.incomingDatasetCard()
        }.width('100%').padding({ left: 16, right: 16, bottom: 12 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      this.datasetFooter()
    }
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Center)
      .backgroundColor(Theme.BG)
  }

  @Builder
  private composePage() {
    Column() {
      Row() {
        Text(this.title()).fontSize(21).fontWeight(FontWeight.Bold).fontColor(Theme.INK).layoutWeight(1)
        Button('关闭').fontSize(13).fontColor(Theme.SECONDARY).backgroundColor(Color.Transparent)
          .enabled(!this.busy).onClick(() => this.close(systemShare.ShareAbilityResultCode.BACK))
      }.width('100%')
      Scroll() {
        Column({ space: 12 }) {
          Text(this.description()).fontSize(14).lineHeight(22).fontColor('#666666').width('100%')
          if (this.preview().length > 0) {
            Text(this.preview()).fontSize(14).lineHeight(22).fontColor('#333333').width('100%')
              .padding(14).backgroundColor('#F4F1EB').borderRadius(12)
          }
          if (this.message.length > 0) {
            Text(this.message).fontSize(13).lineHeight(20).fontColor('#C44C35').width('100%')
          }
        }.width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(48).fontColor('#333333').backgroundColor('#E8E8E5')
          .enabled(!this.busy).onClick(() => this.close(systemShare.ShareAbilityResultCode.BACK))
        Button(this.busy ? '处理中…' : '开始生成文章')
          .layoutWeight(1).height(48).fontColor(Theme.WHITE).backgroundColor(Theme.ACCENT)
          .enabled(this.ready && !this.busy).onClick(() => this.confirmCompose())
      }.width('100%')
    }
      .width('100%').height('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 18 })
      .backgroundColor(Theme.BG)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.kind === ShareImportKind.DATASET) this.datasetPage()
      else this.composePage()
    }.width('100%').height('100%')
  }
}
