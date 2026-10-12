import { promptAction } from '@kit.ArkUI';
import { appPreferences } from '../data/AppPreferences';
import { ReadingFontScale } from '../core/ReadingFontScale';
import { AppLocale } from '../core/AppLocale';
import { RemixIcon, RemixIconGlyph as RI } from './RemixIcon';
import { VoiceDropTheme as Theme } from './VoiceDropTheme';

@CustomDialog
export struct ReadingFontSheet {
  controller?: CustomDialogController;
  @StorageLink('readingFontScale') private readingFontScale: number = 1;
  @StorageLink('safeAreaBottomPx') private safeAreaBottomPx: number = 0;
  @State private saving: boolean = false;

  private async select(index: number): Promise<void> {
    if (this.saving) return;
    this.saving = true;
    try {
      await appPreferences.setReadingFontScale(ReadingFontScale.VALUES[index]);
      this.controller?.close();
    } catch (_) {
      promptAction.showToast({ message: AppLocale.text('字号保存失败，请重试') });
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column() {
      Row() {
        Blank().width(44)
        Text(AppLocale.text('阅读字号'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.INK)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
        Button({ type: ButtonType.Normal }) {
          RemixIcon({ glyph: RI.CLOSE, iconSize: 24, color: Theme.SECONDARY })
        }
          .width(44)
          .height(44)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .accessibilityText(AppLocale.text('关闭'))
          .enabled(!this.saving)
          .onClick(() => this.controller?.close())
      }
        .height(56)
        .padding({ left: 8, right: 8 })
        .width('100%')
      Divider().strokeWidth(1).color(Theme.DIVIDER)
        .width('100%').padding({ left: 24, right: 24 })
      Scroll() {
        Column() {
          ForEach(ReadingFontScale.LABELS, (label: string, index: number) => {
            Button({ type: ButtonType.Normal }) {
              Row() {
                Text(AppLocale.text(label)).fontSize(17).fontColor(Theme.INK).layoutWeight(1)
                if (ReadingFontScale.VALUES[index] === this.readingFontScale) {
                  RemixIcon({ glyph: RI.CHECK, iconSize: 22, color: Theme.ACCENT })
                }
              }.width('100%').height(56).padding({ left: 24, right: 24 })
            }
              .width('100%')
              .padding(0)
              .backgroundColor(Color.Transparent)
              .accessibilitySelected(ReadingFontScale.VALUES[index] === this.readingFontScale)
              .enabled(!this.saving)
              .onClick(() => this.select(index))
            if (index < ReadingFontScale.LABELS.length - 1) {
              Divider().strokeWidth(1).color(Theme.DIVIDER)
                .width('100%').padding({ left: 24, right: 24 })
            }
          }, (label: string) => label)
        }.width('100%')
      }.width('100%').constraintSize({ maxHeight: 284 }).scrollBar(BarState.Off)
    }
      .width('100%')
      .padding({ bottom: 12 + this.getUIContext().px2vp(this.safeAreaBottomPx) })
      .backgroundColor(Theme.CARD)
      .borderRadius({ topLeft: 26, topRight: 26 })
  }
}
