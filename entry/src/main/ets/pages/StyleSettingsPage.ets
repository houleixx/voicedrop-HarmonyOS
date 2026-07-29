import { promptAction } from '@kit.ArkUI';
import { settingsStore, StyleHistory, StyleSettings, StyleVersion } from '../data/SettingsStore';
import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';

@Component
export struct StyleSettingsPage {
  onBack: () => void = () => {};
  @State private name: string = '';
  @State private style: string = '';
  @State private saving: boolean = false;
  @State private loading: boolean = true;
  @State private history: StyleHistory = new StyleHistory();
  @State private selectedStyles: number[] = [];
  @State private selectedHead: number = -1;
  @State private selectedHeadStyle: string = '';
  @State private compareOn: boolean = false;
  @State private listOpen: boolean = true;

  aboutToAppear(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    this.loading = true;
    const values: [StyleSettings, StyleHistory] =
      await Promise.all([settingsStore.loadStyle(), settingsStore.loadStyleHistory()]);
    this.name = values[0].name ?? '';
    this.style = values[0].style ?? '';
    this.selectedStyles = (values[0].styles ?? []).slice();
    this.history = values[1];
    this.selectedHead = this.history.head;
    if (this.selectedHead < 0 && this.history.versions.length > 0) {
      this.selectedHead = this.history.versions[this.history.versions.length - 1].v;
    }
    const head: StyleVersion | undefined =
      this.history.versions.find((version: StyleVersion) => version.v === this.selectedHead);
    this.selectedHeadStyle = head?.style ?? this.style;
    this.compareOn = this.selectedStyles.length > 0;
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

  private selectedLabel(): string {
    return this.selectedStyles.slice().sort((a: number, b: number) => b - a)
      .map((version: number) => `v${version}`).join('、');
  }

  private currentLabel(): string {
    if (this.compareOn) return this.selectedStyles.length > 0 ? this.selectedLabel() : '未选版本';
    const head: StyleVersion | undefined =
      this.history.versions.find((version: StyleVersion) => version.v === this.selectedHead);
    return head ? this.styleName(head.style) : '当前风格';
  }

  private async toggleCompare(value: boolean): Promise<void> {
    this.compareOn = value;
    if (!value) this.selectedStyles = [];
    const ok: boolean = await settingsStore.saveStyleSelection(this.selectedStyles);
    if (!ok) promptAction.showToast({ message: '多风格选择保存失败' });
  }

  private async selectVersion(version: StyleVersion): Promise<void> {
    if (this.compareOn) {
      const index: number = this.selectedStyles.indexOf(version.v);
      if (index >= 0) this.selectedStyles.splice(index, 1);
      else if (this.selectedStyles.length < 3) this.selectedStyles.push(version.v);
      else {
        promptAction.showToast({ message: '最多选择 3 个风格版本' });
        return;
      }
      this.selectedStyles = this.selectedStyles.slice();
      if (!await settingsStore.saveStyleSelection(this.selectedStyles)) {
        promptAction.showToast({ message: '多风格选择保存失败' });
      }
      return;
    }
    this.selectedHead = version.v;
    this.selectedHeadStyle = version.style;
    this.style = version.style;
  }

  private async save(): Promise<void> {
    if (this.saving) return;
    this.saving = true;
    const nextName: string = this.name.trim().substring(0, 20);
    const nextStyle: string = this.style.trim();
    const nameOk: boolean = await settingsStore.saveName(nextName);
    let styleOk: boolean;
    if (this.selectedHead >= 0 && nextStyle === this.selectedHeadStyle.trim()) {
      styleOk = await settingsStore.saveStyleHead(this.selectedHead);
    } else {
      styleOk = await settingsStore.saveStyle(nextStyle);
    }
    this.saving = false;
    if (nameOk && styleOk) {
      promptAction.showToast({ message: '名字与写作风格已保存' });
      await this.reload();
    } else {
      promptAction.showToast({ message: '保存失败，请重试' });
    }
  }

  @Builder
  private versionModeBar() {
    Row({ space: 12 }) {
      Row({ space: 6 }) {
        Text(this.compareOn ? '对比' : `v${Math.max(0, this.selectedHead)}`)
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
        .fontColor(this.compareOn ? Theme.SECONDARY : Theme.INK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(this.compareOn ? `${this.selectedStyles.length} / 3` : `共 ${this.history.versions.length} 版`)
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
      if (this.compareOn) {
        Row() {
          if (this.selectedStyles.includes(version.v)) {
            RemixIcon({ glyph: RI.CHECK, iconSize: 17, color: Color.White })
          }
        }.width(24).height(24).justifyContent(FlexAlign.Center)
          .backgroundColor(this.selectedStyles.includes(version.v) ? Theme.ACCENT : Color.Transparent)
          .border({
            width: this.selectedStyles.includes(version.v) ? 0 : 1,
            color: '#C9C1B5',
            radius: 6
          }).borderRadius(6)
      } else {
        RemixIcon({
          glyph: this.selectedHead === version.v ? RI.CHECK : RI.ARROW_RIGHT,
          iconSize: 18,
          color: this.selectedHead === version.v ? Theme.ACCENT : Theme.FAINT
        })
      }
    }
      .height(56)
      .padding({ left: 14, right: 12 })
      .backgroundColor(this.versionSelected(version.v) ? Theme.ACCENT_SOFT : Theme.CARD)
      .borderRadius(8)
      .onClick(() => this.selectVersion(version))
  }

  private versionSelected(version: number): boolean {
    return this.compareOn ? this.selectedStyles.includes(version) : this.selectedHead === version;
  }

  @Builder
  private versionPanel() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('多风格对比').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
          Text('勾选 2-3 个版本，成文时各生成一篇并排挑')
            .fontSize(12)
            .fontColor(Theme.FAINT)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.compareOn })
          .onChange((value: boolean) => this.toggleCompare(value))
      }.padding({ left: 14, right: 12, top: 10, bottom: 10 }).width('100%')
      Divider().color(Theme.DIVIDER)
      if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress().width(26).height(26).color(Theme.ACCENT)
          Text('正在加载写作风格…').fontSize(12).fontColor(Theme.FAINT)
        }.height(112).justifyContent(FlexAlign.Center)
      } else if (this.history.versions.length === 0) {
        Text('暂无可选风格版本。先保存几个写作风格版本后再开启。')
          .fontSize(12)
          .fontColor(Theme.FAINT)
          .padding(14)
          .width('100%')
      } else {
        ForEach(this.history.versions.slice().reverse(), (version: StyleVersion) => {
          this.versionRow(version)
        }, (version: StyleVersion) => `${version.v}`)
      }
      if (this.compareOn) {
        Divider().color(Theme.DIVIDER)
        Text((this.selectedStyles.length === 0 ? '勾选 2-3 个版本。' :
          `将分别用 ${this.selectedLabel()} 生成文章。`) + ' 关闭开关会清空多风格选择。')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(Theme.FAINT)
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .width('100%')
      }
    }
      .backgroundColor(Theme.CARD)
      .borderRadius(10)
      .shadow({ radius: 12, color: '#26000000', offsetY: 5 })
      .width('100%')
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.End }) {
        PageHeader({ title: '写作风格', onBack: this.onBack })
        Button(this.saving ? '保存中…' : '保存')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .height(40)
          .padding({ left: 18, right: 18 })
          .backgroundColor(this.saving ? '#C2B9A8' : Theme.ACCENT)
          .borderRadius(11)
          .enabled(!this.saving && !this.loading)
          .margin({ right: 16 })
          .onClick(() => this.save())
      }.height(56).width('100%')
      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 7 }) {
            Text('名字').fontSize(14).fontColor(Theme.SECONDARY).width('100%')
            TextInput({ text: this.name, placeholder: '你的名字' })
              .height(54)
              .fontSize(17)
              .padding({ left: 14, right: 14 })
              .backgroundColor('#F7F2EC')
              .borderRadius(14)
              .onChange((value: string) => this.name = value.substring(0, 20))
            Text('这个名字会出现在文章署名，以及挖文章时对你的称呼。随时可改。')
              .fontSize(13)
              .fontColor(Theme.SECONDARY)
              .width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Text('写作风格').fontSize(14).fontColor(Theme.SECONDARY).width('100%')
            this.versionModeBar()
            if (this.listOpen) this.versionPanel()
            TextArea({
              text: this.style,
              placeholder: '例如：温柔克制，段落短一点，多保留现场细节，结尾自然收束。'
            })
              .height(300)
              .fontSize(16)
              .lineHeight(24)
              .padding(14)
              .backgroundColor('#F7F2EC')
              .borderRadius(14)
              .onChange((value: string) => this.style = value)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.padding({ left: 18, right: 18, top: 8, bottom: 32 }).width('100%')
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.height('100%').backgroundColor(Theme.BG)
  }
}
