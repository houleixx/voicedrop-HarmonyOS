import { KeyboardAvoidMode, promptAction } from '@kit.ArkUI';
import { settingsStore, StyleHistory, StyleSettings, StyleVersion } from '../data/SettingsStore';
import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';

@Component
export struct StyleSettingsPage {
  onBack: () => void = () => {};
  @State private style: string = '';
  @State private saving: boolean = false;
  @State private loading: boolean = true;
  @State private history: StyleHistory = new StyleHistory();
  @State private selectedHead: number = -1;
  @State private selectedHeadStyle: string = '';
  private savedHead: number = -1;
  @State private listOpen: boolean = false;
  private keyboardAvoidMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  private keyboardAvoidModeSaved: boolean = false;

  aboutToAppear(): void {
    this.keyboardAvoidMode = this.getUIContext().getKeyboardAvoidMode();
    this.keyboardAvoidModeSaved = true;
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.reload();
  }

  aboutToDisappear(): void {
    if (!this.keyboardAvoidModeSaved) return;
    this.getUIContext().setKeyboardAvoidMode(this.keyboardAvoidMode);
    this.keyboardAvoidModeSaved = false;
  }

  private async reload(): Promise<void> {
    this.loading = true;
    const values: [StyleSettings, StyleHistory] =
      await Promise.all([settingsStore.loadStyle(), settingsStore.loadStyleHistory()]);
    this.style = values[0].style ?? '';
    this.history = values[1];
    this.savedHead = this.history.head;
    this.selectedHead = this.history.head;
    if (this.selectedHead < 0 && this.history.versions.length > 0) {
      this.selectedHead = this.history.versions[this.history.versions.length - 1].v;
    }
    const head: StyleVersion | undefined =
      this.history.versions.find((version: StyleVersion) => version.v === this.selectedHead);
    this.selectedHeadStyle = head?.style ?? this.style;
    this.loading = false;
  }

  private styleName(style: string): string {
    const lines: string[] = style.split('\n');
    for (const line of lines) {
      const value: string = line.trim();
      if (value.length > 0) return value;
    }
    return '未命名风格';
  }

  private currentLabel(): string {
    const head: StyleVersion | undefined =
      this.history.versions.find((version: StyleVersion) => version.v === this.selectedHead);
    return head ? this.styleName(head.style) : '当前风格';
  }

  private selectVersion(version: StyleVersion): void {
    this.selectedHead = version.v;
    this.selectedHeadStyle = version.style;
    this.style = version.style;
    this.listOpen = false;
  }

  private async save(): Promise<void> {
    if (this.saving) return;
    const nextStyle: string = this.style.trim();
    const switchingVersion: boolean =
      this.selectedHead >= 0 && nextStyle === this.selectedHeadStyle.trim();
    if (switchingVersion && this.selectedHead === this.savedHead) {
      promptAction.showToast({ message: '写作风格已保存' });
      return;
    }
    this.saving = true;
    let styleOk: boolean = false;
    try {
      if (switchingVersion) {
        styleOk = await settingsStore.saveStyleHead(this.selectedHead);
      } else {
        styleOk = await settingsStore.saveStyle(nextStyle);
      }
    } catch (_) {
      styleOk = false;
    } finally {
      this.saving = false;
    }
    if (styleOk) {
      promptAction.showToast({ message: switchingVersion ? '写作风格版本已切换' : '写作风格已保存' });
      try {
        await this.reload();
      } catch (_) {
        promptAction.showToast({ message: '写作风格刷新失败，请重新进入页面' });
      }
    } else {
      promptAction.showToast({
        message: switchingVersion ? '写作风格版本切换失败，请重试' : '写作风格保存失败，请重试'
      });
    }
  }

  @Builder
  private versionModeBar() {
    Row({ space: 12 }) {
      Row({ space: 6 }) {
        Text(`v${Math.max(0, this.selectedHead)}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        RemixIcon({
          glyph: RI.ARROW_RIGHT,
          iconSize: 15,
          color: Theme.WHITE
        })
          .rotate({ angle: this.listOpen ? 270 : 90 })
      }
        .height(36)
        .padding({ left: 12, right: 10 })
        .backgroundColor(Theme.ACCENT)
        .borderRadius(7)
      Text(this.currentLabel())
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.INK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(`共 ${this.history.versions.length} 版`)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.FAINT)
    }
      .height(52)
      .padding({ left: 12, right: 12 })
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: '#B9B0A6', radius: 8 })
      .borderRadius(8)
      .onClick(() => this.listOpen = !this.listOpen)
  }

  @Builder
  private versionRow(version: StyleVersion) {
    Row({ space: 8 }) {
      Text(`v${version.v}`)
        .width(42)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.versionSelected(version.v) ? Theme.ACCENT : Theme.INK)
      Text(this.styleName(version.style))
        .fontSize(14)
        .fontWeight(this.versionSelected(version.v) ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.versionSelected(version.v) ? Theme.ACCENT : Theme.INK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(`${version.style.length} 字`)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.FAINT)
      RemixIcon({
        glyph: this.selectedHead === version.v ? RI.CHECK : RI.ARROW_RIGHT,
        iconSize: 18,
        color: this.selectedHead === version.v ? Theme.ACCENT : Theme.FAINT
      })
    }
      .height(56)
      .padding({ left: 14, right: 12 })
      .backgroundColor(this.versionSelected(version.v) ? Theme.ACCENT_SOFT : Theme.CARD)
      .borderRadius(8)
      .margin({ left: 8, right: 8, top: 3, bottom: 3 })
      .onClick(() => this.selectVersion(version))
  }

  private versionSelected(version: number): boolean {
    return this.selectedHead === version;
  }

  @Builder
  private versionPanel() {
    Column() {
      if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress().width(26).height(26).color(Theme.ACCENT_STRONG)
          Text('正在加载写作风格…').fontSize(12).fontColor(Theme.FAINT)
        }.height(112).justifyContent(FlexAlign.Center)
      } else if (this.history.versions.length === 0) {
        Text('暂无可选风格版本。先保存一份写作风格。')
          .fontSize(12)
          .fontColor(Theme.FAINT)
          .padding(14)
          .width('100%')
      } else {
        ForEach(this.history.versions.slice().reverse(), (version: StyleVersion) => {
          this.versionRow(version)
        }, (version: StyleVersion) => `${version.v}`)
      }
    }
      .backgroundColor(Theme.CARD)
      .borderRadius(10)
      .shadow({ radius: 12, color: '#26000000', offsetY: 5 })
      .width('100%')
  }

  build() {
    Column() {
      PageHeader({ title: '写作风格', onBack: this.onBack })
      Column({ space: 12 }) {
        this.versionModeBar()
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.loading) {
            Column({ space: 10 }) {
              LoadingProgress()
                .width(28)
                .height(28)
                .color(Theme.ACCENT)
              Text('正在加载写作风格…')
                .fontSize(13)
                .fontColor(Theme.SECONDARY)
            }
              .width('100%')
              .height('100%')
              .padding({ top: 28 })
              .justifyContent(FlexAlign.Start)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(Color.White)
              .borderRadius(14)
          } else {
            TextArea({
              text: this.style,
              placeholder: '例如：温柔克制，段落短一点，多保留现场细节，结尾自然收束。'
            })
              .width('100%')
              .height('100%')
              .fontSize(16)
              .lineHeight(24)
              .fontColor(Theme.INK)
              .placeholderColor(Theme.FAINT)
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .backgroundColor(Color.White)
              .borderRadius(14)
              .onChange((value: string) => this.style = value)
          }
          if (this.listOpen) {
            Column() {
              this.versionPanel()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .zIndex(2)
          }
        }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
      }
        .padding({ left: 18, right: 18, top: 8, bottom: 10 })
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
      Column() {
        Button(this.saving ? '保存中…' : '保存')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .height(54)
          .width('100%')
          .backgroundColor(this.saving ? '#C2B9A8' : Theme.ACCENT)
          .borderRadius(12)
          .enabled(!this.saving && !this.loading)
          .onClick(() => this.save())
      }
        .padding({ left: 18, right: 18, bottom: 16 })
        .width('100%')
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.BG)
  }
}
