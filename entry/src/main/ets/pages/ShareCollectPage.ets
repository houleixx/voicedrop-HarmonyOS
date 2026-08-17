import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { AppPreferences } from '../data/AppPreferences';
import { authStore } from '../data/AuthStore';
import {
  ShareDatasetItem,
  ShareDatasetSnapshot,
  ShareImport,
  ShareImportKind
} from '../core/ShareImport';
import { PrivacyStartup } from '../core/PrivacyStartup';
import { ShareCollectResult, shareCollectService } from '../share/ShareCollectService';

const shareStorage: LocalStorage = new LocalStorage();

@Entry(shareStorage)
@Component
struct ShareCollectPage {
  @LocalStorageProp('shareType') private shareType: string = '';
  @LocalStorageProp('shareUris') private shareUris: string = '[]';
  @LocalStorageProp('shareText') private shareText: string = '';
  @LocalStorageProp('shareTitle') private shareTitle: string = '';
  @State private kind: ShareImportKind = ShareImportKind.DATASET;
  @State private dataset: ShareDatasetSnapshot = new ShareDatasetSnapshot();
  @State private collected: boolean = false;
  @State private clearAfter: boolean = true;
  @State private busy: boolean = false;
  @State private ready: boolean = false;
  @State private message: string = '';
  private context?: common.UIExtensionContext;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIExtensionContext;
    this.initialize().catch((error: Object) => {
      this.message = `分享初始化失败：${String(error)}`;
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
      return;
    }
    await authStore.initialize(this.context);
    const uris: string[] = this.uris();
    this.kind = ShareImport.classify(this.shareType, uris);
    if (this.kind === ShareImportKind.DATASET) await this.loadDataset();
    this.ready = true;
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
    if (this.kind === ShareImportKind.IMAGE) return `${this.uris().length} 张图片，确认后开始看图成文。`;
    if (this.collected) return this.message;
    const chars: number = this.shareText.trim().length;
    const files: number = this.uris().length;
    const source: string = files > 0 ? `${files} 个文档${chars > 0 ? '和分享文字' : ''}` : `${chars} 字分享文字`;
    return `${source}将作为写作语料，确认后加入你的风格数据集。`;
  }

  private preview(): string {
    const text: string = this.shareText.trim();
    if (text.length > 0) return text.length > 240 ? `${text.substring(0, 240)}…` : text;
    return this.uris().slice(0, 4).map((uri: string) => {
      const clean: string = uri.split('?')[0];
      try { return decodeURIComponent(clean.substring(clean.lastIndexOf('/') + 1)) || '分享文件'; }
      catch (_) { return clean.substring(clean.lastIndexOf('/') + 1) || '分享文件'; }
    }).join('\n');
  }

  private async confirm(): Promise<void> {
    if (!this.context || !this.ready || this.busy) return;
    this.busy = true;
    try {
      const result: ShareCollectResult = await shareCollectService.collectIncoming(
        this.context, this.shareType, this.uris(), this.shareText, this.shareTitle);
      this.message = result.message;
      if (!result.ok) return;
      if (result.kind === ShareImportKind.DATASET) {
        this.collected = true;
        await this.loadDataset();
      } else {
        this.close(systemShare.ShareAbilityResultCode.CLOSE);
      }
    } catch (error) {
      this.message = `分享导入失败：${String(error)}`;
    } finally { this.busy = false; }
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
    } finally { this.busy = false; }
  }

  private close(resultCode: number): void {
    this.context?.terminateSelfWithResult({ resultCode: resultCode }).catch(() => {});
  }

  @Builder
  private datasetSummary() {
    Column({ space: 8 }) {
      Row() {
        Text(`已收集 ${this.dataset.count} 项 · ${this.dataset.totalChars} 字`)
          .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#8A8175')
        Blank()
        Text(ShareImport.canExtract(this.dataset) ? '可以提取' :
          `还差 ${Math.max(0, ShareImport.MIN_STYLE_CHARS - this.dataset.totalChars)} 字`)
          .fontSize(12).fontColor(ShareImport.canExtract(this.dataset) ? '#4E7B55' : '#C0682E')
      }.width('100%')
      ForEach(this.dataset.items.slice(0, 3), (item: ShareDatasetItem) => {
        Row({ space: 10 }) {
          Text(item.type === 'web' ? '网页' : (item.type === 'doc' ? '文档' : '文字'))
            .fontSize(11).fontColor('#C0682E').width(34)
          Text(item.title || item.source || '未命名语料').fontSize(13).fontColor('#2A2521')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          Text(`${item.chars} 字`).fontSize(11).fontColor('#A79F93')
        }.width('100%')
      }, (item: ShareDatasetItem) => item.id)
    }.padding(12).backgroundColor('#FFFFFF').borderRadius(10).width('100%')
  }

  build() {
    Column() {
      Row() {
        Text(this.title()).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#2A2521').layoutWeight(1)
        Button('关闭').fontSize(13).fontColor('#6B6357').backgroundColor(Color.Transparent)
          .enabled(!this.busy).onClick(() => this.close(systemShare.ShareAbilityResultCode.BACK))
      }.width('100%')
      Scroll() {
        Column({ space: 12 }) {
          Text(this.description()).fontSize(14).lineHeight(22).fontColor('#666666').width('100%')
          if (this.kind === ShareImportKind.DATASET && this.ready) this.datasetSummary()
          if (this.preview().length > 0) {
            Text(this.preview()).fontSize(14).lineHeight(22).fontColor('#333333').width('100%')
              .padding(14).backgroundColor('#F4F1EB').borderRadius(12)
          }
          if (this.message.length > 0 && !this.collected) {
            Text(this.message).fontSize(13).lineHeight(20).fontColor('#C44C35').width('100%')
          }
        }.width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      if (this.kind === ShareImportKind.DATASET && this.collected) {
        Button() {
          Row({ space: 8 }) {
            Text(this.clearAfter ? '✓' : '').fontSize(13).fontColor(Color.White)
              .textAlign(TextAlign.Center).width(20).height(20)
              .backgroundColor(this.clearAfter ? '#D8593B' : '#FFFFFF')
              .border({ width: 1, color: this.clearAfter ? '#D8593B' : '#E2D8C8' }).borderRadius(6)
            Text('提取后清空数据集').fontSize(13).fontColor('#6B6357')
          }.width('100%')
        }.height(36).padding(0).backgroundColor(Color.Transparent).enabled(!this.busy)
          .onClick(() => this.clearAfter = !this.clearAfter)
        Row({ space: 10 }) {
          Button('继续收集').layoutWeight(1).height(48).fontColor('#2A2521').backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E2D8C8' }).enabled(!this.busy)
            .onClick(() => this.close(systemShare.ShareAbilityResultCode.CLOSE))
          Button(this.busy ? '处理中…' : '提取文章风格').layoutWeight(1).height(48).fontColor(Color.White)
            .backgroundColor(ShareImport.canExtract(this.dataset) ? '#D8593B' : '#D9B3A8')
            .enabled(!this.busy && ShareImport.canExtract(this.dataset))
            .onClick(() => this.extractStyle())
        }.width('100%')
      } else {
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(48).fontColor('#333333').backgroundColor('#E8E8E5')
            .enabled(!this.busy).onClick(() => this.close(systemShare.ShareAbilityResultCode.BACK))
          Button(this.busy ? '处理中…' : (this.kind === ShareImportKind.DATASET ? '加入数据集' : '开始生成文章'))
            .layoutWeight(1).height(48).fontColor(Color.White).backgroundColor('#D8593B')
            .enabled(this.ready && !this.busy).onClick(() => this.confirm())
        }.width('100%')
      }
    }
      .width('100%').height('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 18 })
      .backgroundColor('#FAF6EF')
  }
}
