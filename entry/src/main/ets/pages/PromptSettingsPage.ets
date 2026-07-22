import { PromptSettingsView } from '../components/PromptSettingsView';

@Component
export struct PromptSettingsPage {
  onBack: () => void = () => {};
  initialCode: string = '';

  build() {
    PromptSettingsView({ onBack: this.onBack, initialCode: this.initialCode })
  }
}
