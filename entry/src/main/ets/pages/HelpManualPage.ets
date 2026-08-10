import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { ManualText } from '../core/ManualText';

@Component
export struct HelpManualPage {
  onBack: () => void = () => {};
  @State private content: string = '正在载入使用手册…';

  aboutToAppear(): void { this.load(); }

  private async load(): Promise<void> {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const bytes: Uint8Array = await context.resourceManager.getRawFileContent('help_manual.md');
      const markdown: string = new util.TextDecoder('utf-8').decodeWithStream(bytes);
      this.content = ManualText.readable(markdown);
    } catch (_) { this.content = '使用手册暂时无法打开，请稍后重试。'; }
  }

  build() {
    Column() {
      PageHeader({ title: '使用手册', onBack: this.onBack })
      Scroll() {
        Text(this.content).fontSize(16).lineHeight(27).fontColor(Theme.INK)
          .width('100%').padding({ left: 20, right: 20, top: 8, bottom: 40 })
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
