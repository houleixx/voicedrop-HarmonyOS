import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import {
  ManualBlock,
  ManualBlockKind,
  ManualInline,
  ManualMarkdown,
  ManualSectionSelection
} from '../core/ManualMarkdown';
import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

@Component
export struct HelpManualPage {
  onBack: () => void = () => {};
  onOpenExternal: (url: string) => void = (_url: string) => {};
  @State private activeSection: number = 0;
  @State private blocks: ManualBlock[] = [];
  @State private loading: boolean = true;
  @State private loadFailed: boolean = false;
  private readonly manualScroller: Scroller = new Scroller();
  private readonly sectionSelection: ManualSectionSelection = new ManualSectionSelection();
  private chapterIndexes: number[] = [];

  aboutToAppear(): void {
    this.loadBundledManual();
  }

  aboutToDisappear(): void {
    this.sectionSelection.releaseTarget();
  }

  private async loadBundledManual(): Promise<void> {
    this.loading = true;
    this.loadFailed = false;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const bytes: Uint8Array = await context.resourceManager.getRawFileContent(ManualMarkdown.ASSET);
      const markdown: string = new util.TextDecoder('utf-8').decodeWithStream(bytes);
      const parsed: ManualBlock[] = ManualMarkdown.parse(markdown);
      const indexes: number[] = ManualMarkdown.chapterBlockIndexes(parsed);
      if (indexes.length !== ManualMarkdown.SECTION_LABELS.length) throw new Error('manual chapters missing');
      this.chapterIndexes = indexes;
      this.blocks = parsed;
      this.loading = false;
    } catch (_error) {
      this.loading = false;
      this.loadFailed = true;
    }
  }

  private scrollToSection(index: number): void {
    if (index < 0 || index >= this.chapterIndexes.length) return;
    this.activeSection = this.sectionSelection.select(index);
    this.manualScroller.scrollToIndex(this.chapterIndexes[index], true, ScrollAlign.START);
  }

  private reportVisibleBlock(blockIndex: number): void {
    let section: number = 0;
    for (let index: number = 0; index < this.chapterIndexes.length; index++) {
      if (this.chapterIndexes[index] <= blockIndex) section = index;
      else break;
    }
    this.activeSection = this.sectionSelection.report(section);
  }

  @Builder
  private inlineText(value: string, size: number = 15.5, weight: FontWeight = FontWeight.Normal) {
    Text() {
      ForEach(ManualMarkdown.inline(value), (part: ManualInline) => {
        Span(part.text)
          .fontWeight(part.bold ? FontWeight.Bold : weight)
          .fontColor(part.url.length > 0 ? Theme.ACCENT : Theme.INK)
          .onClick(() => {
            if (part.url.length > 0) this.onOpenExternal(part.url);
          })
      }, (part: ManualInline, index: number) => `${index}-${part.text}`)
    }
      .fontSize(size)
      .fontColor(Theme.INK)
      .lineHeight(size + 12)
      .width('100%')
  }

  @Builder
  private listBlock(items: string[], numbered: boolean) {
    Column({ space: 7 }) {
      ForEach(items, (item: string, index: number) => {
        Row({ space: 6 }) {
          Text(numbered ? `${index + 1}.` : '•')
            .fontSize(15.5)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.FAINT)
            .lineHeight(27.5)
            .width(numbered ? 24 : 14)
            .alignSelf(ItemAlign.Start)
          Column() {
            this.inlineText(item)
          }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
        }.alignItems(VerticalAlign.Top).width('100%')
      }, (item: string, index: number) => `${index}-${item}`)
    }.width('100%')
  }

  @Builder
  private tableRow(cells: string[], header: boolean) {
    Row({ space: 10 }) {
      ForEach(cells, (cell: string, index: number) => {
        Text(ManualMarkdown.plainInline(cell))
          .fontSize(14)
          .fontWeight(header ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(Theme.INK)
          .lineHeight(26)
          .width(index === 0 && cells.length > 1 ? 78 : 220)
      }, (cell: string, index: number) => `${index}-${cell}`)
    }.padding({ left: 13, right: 13, top: 9, bottom: 9 })
  }

  @Builder
  private tableBlock(block: ManualBlock) {
    Scroll() {
      Column() {
        this.tableRow(block.items, true)
        ForEach(block.rows, (row: string[], index: number) => {
          Divider().color(Theme.BORDER)
          this.tableRow(row, false)
        }, (row: string[], index: number) => `${index}-${JSON.stringify(row)}`)
      }
        .backgroundColor(Theme.CARD)
        .borderRadius(12)
        .border({ width: 1, color: Theme.BORDER })
    }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
  }

  @Builder
  private manualBlock(block: ManualBlock) {
    if (block.kind === ManualBlockKind.TITLE) {
      Text(block.text).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.INK).width('100%')
    } else if (block.kind === ManualBlockKind.CHAPTER) {
      Text(block.text).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.INK).width('100%')
    } else if (block.kind === ManualBlockKind.SECTION) {
      Text(block.text).fontSize(16.5).fontWeight(FontWeight.Medium).fontColor(Theme.INK).width('100%')
    } else if (block.kind === ManualBlockKind.PARAGRAPH) {
      this.inlineText(block.text)
    } else if (block.kind === ManualBlockKind.BULLETS) {
      this.listBlock(block.items, false)
    } else if (block.kind === ManualBlockKind.NUMBERED) {
      this.listBlock(block.items, true)
    } else if (block.kind === ManualBlockKind.TABLE) {
      this.tableBlock(block)
    } else if (block.kind === ManualBlockKind.CODE) {
      Scroll() {
        Text(block.text)
          .fontSize(12.5)
          .fontFamily('monospace')
          .fontColor(Theme.INK)
          .padding(12)
          .backgroundColor('#F3EDE4')
          .borderRadius(10)
      }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
    }
  }

  build() {
    Column() {
      PageHeader({ title: '使用手册', onBack: this.onBack })
      Scroll() {
        Row({ space: 6 }) {
          ForEach(ManualMarkdown.SECTION_LABELS, (label: string, index: number) => {
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
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .width('100%')
      Stack({ alignContent: Alignment.Center }) {
        if (this.blocks.length > 0) {
          List({ scroller: this.manualScroller, space: 0 }) {
            ForEach(this.blocks, (block: ManualBlock, index: number) => {
              ListItem() {
                this.manualBlock(block)
              }
                .padding({
                  left: 20,
                  right: 20,
                  top: block.kind === ManualBlockKind.CHAPTER ? 18 : 6,
                  bottom: block.kind === ManualBlockKind.TITLE ? 10 : 6
                })
            }, (block: ManualBlock, index: number) => `${index}-${block.kind}`)
          }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .contentEndOffset(50)
            .onScrollIndex((start: number, _end: number, _center: number) => this.reportVisibleBlock(start))
            .onScrollStop(() => this.sectionSelection.releaseTarget())
        }
        if (this.loading) {
          LoadingProgress().width(40).height(40).color(Theme.ACCENT)
        }
        if (this.loadFailed) {
          Column({ space: 14 }) {
            Text('使用手册暂时无法读取').fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.INK)
            Text('请重新打开应用').fontSize(14).fontColor(Theme.SECONDARY)
          }
        }
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
