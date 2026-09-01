import { promptAction } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { AppLanguage } from '../core/AppLanguage';
import { AppLocale } from '../core/AppLocale';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

@Component
export struct LanguageSettingsPage {
  onBack: () => void = () => {};
  onLanguageSaved: () => void = () => {};
  @State private selectedLanguage: string = AppLanguage.SYSTEM;
  @State private saving: boolean = false;

  aboutToAppear(): void {
    try {
      this.selectedLanguage = AppLanguage.normalized(i18n.System.getAppPreferredLanguage());
    } catch (_) {
      this.selectedLanguage = AppLanguage.SYSTEM;
    }
  }

  private async save(): Promise<void> {
    if (this.saving) return;
    this.saving = true;
    try {
      i18n.System.setAppPreferredLanguage(this.selectedLanguage);
      AppStorage.setOrCreate<string>('appDisplayLanguage', this.selectedLanguage);
      const revision: number = AppStorage.get<number>('appLanguageRevision') ?? 0;
      AppStorage.setOrCreate<number>('appLanguageRevision', revision + 1);
      this.onLanguageSaved();
    } catch (_) {
      promptAction.showToast({ message: AppLocale.text('语言设置失败，请重试') });
    } finally {
      this.saving = false;
    }
  }

  private isSelected(language: string): boolean {
    return this.selectedLanguage === language;
  }

  @Builder
  private languageOption(language: string) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(this.optionTitle(language))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.INK)
        Text(this.optionDescription(language))
          .fontSize(13)
          .lineHeight(19)
          .fontColor(Theme.SECONDARY)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Row() {
        if (this.isSelected(language)) {
          RemixIcon({ glyph: RI.CHECK, iconSize: 13, color: Theme.WHITE })
        }
      }
        .width(22)
        .height(22)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.isSelected(language) ? Theme.ACCENT : Color.Transparent)
        .border({ width: this.isSelected(language) ? 0 : 1.5, color: Theme.BORDER, radius: 11 })
        .borderRadius(11)
    }
      .width('100%')
      .constraintSize({ minHeight: 70 })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Color.Transparent)
      .onClick(() => this.selectedLanguage = language)
  }

  private optionTitle(language: string): string {
    switch (language) {
      case AppLanguage.SIMPLIFIED_CHINESE: return 'Simplified Chinese';
      case AppLanguage.ENGLISH: return 'English';
      default: return 'Follow System';
    }
  }

  private optionDescription(language: string): string {
    switch (language) {
      case AppLanguage.SIMPLIFIED_CHINESE: return 'zh-Hans';
      case AppLanguage.ENGLISH: return 'en';
      default: return "Use your device's system language";
    }
  }

  @Builder
  private optionDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(Theme.BORDER)
      .margin({ left: 16, right: 16 })
  }

  build() {
    Column() {
      PageHeader({
        title: 'Language',
        actionText: this.saving ? 'Saving' : 'Done',
        actionTextFilled: true,
        actionLabel: 'Save language',
        onBack: this.onBack,
        onAction: () => this.save()
      })
      Column({ space: 10 }) {
        Text("Choose VoiceDrop's display language. Tap Done in the top-right corner to apply it.")
          .fontSize(14)
          .lineHeight(20)
          .fontColor(Theme.SECONDARY)
          .width('100%')
          .padding({ left: 4 })
          .margin({ top: 14, bottom: 2 })
        Column() {
          this.languageOption(AppLanguage.SYSTEM)
          this.optionDivider()
          this.languageOption(AppLanguage.SIMPLIFIED_CHINESE)
          this.optionDivider()
          this.languageOption(AppLanguage.ENGLISH)
        }
          .width('100%')
          .backgroundColor(Theme.CARD)
          .border({ width: 0.5, color: Theme.BORDER, radius: 14 })
          .borderRadius(14)
          .clip(true)
      }
        .padding({ left: 16, right: 16 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      Blank()
    }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
  }
}
