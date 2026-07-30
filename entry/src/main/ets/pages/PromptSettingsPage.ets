import { PromptSettingsView } from '../components/PromptSettingsView';

@Component
export struct PromptSettingsPage {
  onBack: () => void = () => {};
  initialCode: string = '';

  build() {
    Column() {
      PromptSettingsView({ onBack: this.onBack, initialCode: this.initialCode })
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
  }
}
