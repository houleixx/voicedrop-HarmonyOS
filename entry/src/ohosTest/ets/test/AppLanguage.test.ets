import { describe, expect, it } from '@ohos/hypium';
import { AppLanguage } from '../../../main/ets/core/AppLanguage';
import { AppLocale } from '../../../main/ets/core/AppLocale';

export default function appLanguageTest() {
  describe('AppLanguage', () => {
    it('translatesKnownUiCopyAndFormatsEnglishDates', 0, () => {
      expect(AppLocale.resolve(AppLanguage.ENGLISH, '设置')).assertEqual('Settings');
      expect(AppLocale.resolve(AppLanguage.SIMPLIFIED_CHINESE, '设置')).assertEqual('设置');
      expect(AppLocale.dateTime(AppLanguage.ENGLISH, new Date(2026, 8, 1, 9, 5).getTime()))
        .assertEqual('2026-09-01 09:05');
      expect(AppLocale.resolve(AppLanguage.ENGLISH, 'AI生成')).assertEqual('AI-generated');
      expect(AppLocale.resolve(AppLanguage.ENGLISH, 'VoiceDrop 口述')).assertEqual('VoiceDrop Dictation');
      expect(AppLocale.resolve(AppLanguage.ENGLISH, '扩展成一本书')).assertEqual('Expand into a book');
      expect(AppLocale.resolve(AppLanguage.ENGLISH, '卡通解释图')).assertEqual('Cartoon explainer');
      expect(AppLocale.resolve(AppLanguage.ENGLISH, '并行写')).assertEqual('Write in parallel');
      expect(AppLocale.resolve(AppLanguage.ENGLISH, '每章一个写手，费曼式大白话，名词当场讲人话'))
        .assertEqual('A dedicated writer handles each chapter in plain language, explaining terms as they appear.');
      expect(AppLocale.bookWritingCreditsInsufficientForLanguage(AppLanguage.ENGLISH, '320', '12'))
        .assertEqual('Insufficient credits: writing a book costs 320; you have 12.');
    });
    it('usesHarmonyOsPreferredLanguageIds', 0, () => {
      expect(AppLanguage.choices.length).assertEqual(3);
      expect(AppLanguage.choices[0]).assertEqual('default');
      expect(AppLanguage.choices[1]).assertEqual('zh-Hans');
      expect(AppLanguage.choices[2]).assertEqual('en');
    });

    it('normalizesUnknownValuesToFollowSystem', 0, () => {
      expect(AppLanguage.normalized('fr')).assertEqual(AppLanguage.SYSTEM);
      expect(AppLanguage.label('fr')).assertEqual('跟随系统');
      expect(AppLanguage.label(AppLanguage.SIMPLIFIED_CHINESE)).assertEqual('简体中文');
      expect(AppLanguage.label(AppLanguage.ENGLISH)).assertEqual('English');
      expect(AppLanguage.description(AppLanguage.SYSTEM)).assertEqual('使用设备的系统语言');
      expect(AppLanguage.description(AppLanguage.SIMPLIFIED_CHINESE)).assertEqual('始终使用简体中文');
      expect(AppLanguage.description(AppLanguage.ENGLISH)).assertEqual('Always use English');
    });
  });
}
