import { webview } from '@kit.ArkWeb';
import { ManualSectionSelection, ManualWebUi } from '../core/ManualWebUi';
import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

class ManualJavaScriptBridge {
  onChanged: (index: number) => void = (_index: number): void => {};

  onSectionChanged(index: number): void {
    this.onChanged(index);
  }
}

@Component
export struct HelpManualPage {
  onBack: () => void = () => {};
  onOpenExternal: (url: string) => void = (_url: string) => {};
  @State private activeSection: number = 0;
  @State private pageReady: boolean = false;
  @State private loadFailed: boolean = false;
  private readonly controller: webview.WebviewController = new webview.WebviewController();
  private readonly bridge: ManualJavaScriptBridge = new ManualJavaScriptBridge();
  private readonly sectionSelection: ManualSectionSelection = new ManualSectionSelection();
  private pendingSection: number = -1;

  aboutToAppear(): void {
    this.bridge.onChanged = (index: number): void => {
      if (index >= 0 && index < ManualWebUi.SECTION_LABELS.length) {
        this.activeSection = this.sectionSelection.report(index);
      }
    };
  }

  aboutToDisappear(): void {
    this.bridge.onChanged = (_index: number): void => {};
    this.sectionSelection.releaseTarget();
  }

  private injectManualUi(): void {
    this.controller.runJavaScript(ManualWebUi.setupScript()).then(() => {
      const section: number = this.pendingSection;
      this.pendingSection = -1;
      if (section >= 0) this.scrollToSection(section);
    }).catch(() => {});
  }

  private scrollToSection(index: number): void {
    const script: string = ManualWebUi.scrollScript(index);
    if (script.length === 0) return;
    this.activeSection = this.sectionSelection.select(index);
    if (!this.pageReady) {
      this.pendingSection = index;
      return;
    }
    this.controller.runJavaScript(script).catch(() => {});
  }

  private retry(): void {
    this.loadFailed = false;
    this.pageReady = false;
    this.controller.refresh();
  }

  build() {
    Column() {
      PageHeader({ title: '使用手册', onBack: this.onBack })
      Scroll() {
        Row({ space: 6 }) {
          ForEach(ManualWebUi.SECTION_LABELS, (label: string, index: number) => {
            Text(label)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.activeSection === index ? Theme.ACCENT : Theme.SECONDARY)
              .height(36)
              .padding({ left: 12, right: 12 })
              .textAlign(TextAlign.Center)
              .backgroundColor(this.activeSection === index ? Theme.ACCENT_SOFT : Theme.CARD)
              .borderRadius(10)
              .border({ width: 0.5, color: this.activeSection === index ? '#EDC7B8' : Theme.BORDER })
              .accessibilityText(`跳到${label}`)
              .onClick(() => this.scrollToSection(index))
          }, (label: string) => label)
        }.padding({ left: 16, right: 10, top: 4, bottom: 8 })
      }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      Stack({ alignContent: Alignment.Center }) {
        Web({ src: ManualWebUi.URL, controller: this.controller })
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.BG)
          .javaScriptAccess(true)
          .domStorageAccess(false)
          .zoomAccess(true)
          .javaScriptProxy({
            object: this.bridge,
            name: 'VoiceDropManual',
            methodList: ['onSectionChanged'],
            controller: this.controller
          })
          .onPageBegin(() => {
            this.pageReady = false;
            this.loadFailed = false;
          })
          .onPageEnd((event: OnPageEndEvent) => {
            if (!ManualWebUi.isManualUrl(event.url)) return;
            this.pageReady = true;
            this.loadFailed = false;
            this.injectManualUi();
          })
          .onErrorReceive((event: OnErrorReceiveEvent) => {
            if (event.request.isMainFrame()) this.loadFailed = true;
          })
          .onOverrideUrlLoading((request: WebResourceRequest) => {
            const url: string = request.getRequestUrl();
            if (ManualWebUi.isManualUrl(url)) return false;
            if (ManualWebUi.shouldOpenExternally(url)) this.onOpenExternal(url);
            return true;
          })
        if (!this.pageReady && !this.loadFailed) {
          LoadingProgress().width(40).height(40).color(Theme.ACCENT)
        }
        if (this.loadFailed) {
          Column({ space: 14 }) {
            Text('使用手册暂时无法打开').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.INK)
            Text('请检查网络后重试').fontSize(14).fontColor(Theme.SECONDARY)
            Button('重试').fontSize(15).fontColor(Color.White).backgroundColor(Theme.ACCENT).onClick(() => this.retry())
          }
        }
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
