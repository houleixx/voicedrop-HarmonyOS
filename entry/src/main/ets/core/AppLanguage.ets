/** Maps the three user-facing choices to HarmonyOS app-preferred-language IDs. */
export class AppLanguage {
  static readonly SYSTEM: string = 'default';
  static readonly SIMPLIFIED_CHINESE: string = 'zh-Hans';
  static readonly ENGLISH: string = 'en';

  static readonly choices: string[] = [
    AppLanguage.SYSTEM,
    AppLanguage.SIMPLIFIED_CHINESE,
    AppLanguage.ENGLISH
  ];

  static normalized(value: string): string {
    return AppLanguage.choices.includes(value) ? value : AppLanguage.SYSTEM;
  }

  static label(value: string): string {
    switch (AppLanguage.normalized(value)) {
      case AppLanguage.SIMPLIFIED_CHINESE: return '简体中文';
      case AppLanguage.ENGLISH: return 'English';
      default: return '跟随系统';
    }
  }

  static description(value: string): string {
    switch (AppLanguage.normalized(value)) {
      case AppLanguage.SIMPLIFIED_CHINESE: return '始终使用简体中文';
      case AppLanguage.ENGLISH: return 'Always use English';
      default: return '使用设备的系统语言';
    }
  }
}
