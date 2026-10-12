import { describe, expect, it } from '@ohos/hypium';
import { ReadingFontScale } from '../../../main/ets/core/ReadingFontScale';

export default function readingFontScaleTest(): void {
  describe('ReadingFontScale', () => {
    it('invalidStoredValuesFallBackToStandard', 0, () => {
      expect(ReadingFontScale.normalize(0)).assertEqual(1);
      expect(ReadingFontScale.normalize(2)).assertEqual(1);
      expect(ReadingFontScale.normalize(Number.NaN)).assertEqual(1);
      expect(ReadingFontScale.label(2)).assertEqual('标准');
    });
    it('fiveLevelsKeepTheirSavedValueAndLabel', 0, () => {
      expect(ReadingFontScale.VALUES.length).assertEqual(5);
      for (let i: number = 0; i < ReadingFontScale.VALUES.length; i++) {
        expect(ReadingFontScale.normalize(ReadingFontScale.VALUES[i])).assertEqual(ReadingFontScale.VALUES[i]);
        expect(ReadingFontScale.label(ReadingFontScale.VALUES[i])).assertEqual(ReadingFontScale.LABELS[i]);
      }
    });
    it('bookWebTextZoomUsesTheSameFiveLevels', 0, () => {
      const percentages: number[] = [90, 100, 115, 130, 150];
      for (let i: number = 0; i < percentages.length; i++) {
        expect(ReadingFontScale.percent(ReadingFontScale.VALUES[i])).assertEqual(percentages[i]);
      }
      expect(ReadingFontScale.percent(Number.NaN)).assertEqual(100);
      expect(ReadingFontScale.percent(10)).assertEqual(100);
    });
    it('onlyCommunityReadingUsesThePreference', 0, () => {
      expect(ReadingFontScale.forCommunity(true, false, 1.5)).assertEqual(1.5);
      expect(ReadingFontScale.forCommunity(true, true, 1.5)).assertEqual(1);
      expect(ReadingFontScale.forCommunity(false, false, 1.5)).assertEqual(1);
    });
  });
}
