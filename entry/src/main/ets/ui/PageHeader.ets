import { VoiceDropTheme as Theme } from './VoiceDropTheme';
import { RemixIcon, RemixIconGlyph as RI } from './RemixIcon';

/** Shared title bar for every secondary page. */
@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop actionGlyph: string = '';
  @Prop actionLabel: string = '';
  @Prop actionFilled: boolean = true;
  onBack: () => void = () => {};
  onAction: () => void = () => {};

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
          .stateEffect(false)
          .onClick(this.onBack)
        Blank()
        if (this.actionGlyph.length > 0) {
          Button({ type: ButtonType.Normal }) {
            RemixIcon({
              glyph: this.actionGlyph,
              iconSize: this.actionFilled ? 22 : 25,
              color: this.actionFilled ? Color.White : Theme.SECONDARY
            })
          }
            .width(40)
            .height(40)
            .padding(0)
            .backgroundColor(this.actionFilled ? Theme.INK : Theme.CARD)
            .border({
              width: this.actionFilled ? 0 : 1,
              color: this.actionFilled ? Color.Transparent : Theme.BORDER,
              radius: 11
            })
            .borderRadius(11)
            .clip(true)
            .shadow(this.actionFilled ? { radius: 0, color: Color.Transparent } :
              { radius: 5, color: '#34291F22', offsetX: 0, offsetY: 2 })
            .stateEffect(false)
            .accessibilityText(this.actionLabel)
            .onClick(this.onAction)
        }
      }
        .width('100%')
        .padding({ left: 16, right: 16 })
    }
      .height(56)
      .width('100%')
  }
}
