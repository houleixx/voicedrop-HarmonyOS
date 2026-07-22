import { VoiceDropTheme as Theme } from './VoiceDropTheme';
import { RemixIcon, RemixIconGlyph as RI } from './RemixIcon';

/** Shared title bar for every secondary page. */
@Component
export struct PageHeader {
  @Prop title: string = '';
  onBack: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Text(this.title)
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.INK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '56%' })
      Row() {
        Button({ type: ButtonType.Normal }) {
          RemixIcon({ glyph: RI.ARROW_LEFT, iconSize: 25, color: Theme.INK })
        }
          .width(40)
          .height(40)
          .padding(0)
          .backgroundColor(Theme.CARD)
          .border({ width: 1, color: Theme.BORDER, radius: 11 })
          .borderRadius(11)
          .clip(true)
          .onClick(this.onBack)
        Blank()
      }
        .width('100%')
        .padding({ left: 12, right: 12 })
    }
      .height(56)
      .width('100%')
  }
}
