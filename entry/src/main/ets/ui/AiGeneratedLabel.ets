import { VoiceDropTheme as Theme } from './VoiceDropTheme';
import { AppLocale } from '../core/AppLocale';

/** Compact disclosure used beside metadata on AI-generated article pages. */
@Component
export struct AiGeneratedLabel {
  build() {
    Text(AppLocale.text('AI生成'))
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(Theme.ACCENT)
      .padding({ left: 7, right: 7, top: 2, bottom: 2 })
      .backgroundColor(Theme.ACCENT_SOFT)
      .border({ width: 0.5, color: '#EBC6B9' })
      .borderRadius(11)
      .accessibilityText(AppLocale.text('AI生成内容'))
  }
}
