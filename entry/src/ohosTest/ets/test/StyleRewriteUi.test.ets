import { describe, expect, it } from '@ohos/hypium';
import { StyleRewriteUi } from '../../../main/ets/core/StyleRewriteUi';

export default function styleRewriteUiTest() {
  describe('StyleRewriteUi', () => {
    it('usesTheFirstLineLikeAndroid', 0, () => {
      expect(StyleRewriteUi.displayName('短标题\n后续完整说明')).assertEqual('短标题');
    });

    it('limitsTheDisplayedNameToSixteenCharacters', 0, () => {
      expect(StyleRewriteUi.displayName('一二三四五六七八九十一二三四五六七八'))
        .assertEqual('一二三四五六七八九十一二三四五六…');
    });

    it('showsTheStyleCharacterCount', 0, () => {
      expect(StyleRewriteUi.metadata('第一行\n第二行')).assertEqual('7 字');
    });

    it('showsTheShortSavedDateLikeAndroid', 0, () => {
      expect(StyleRewriteUi.metadata('范文', '2026-07-07T08:30:00Z')).assertEqual('2 字 · 7月7日');
      expect(StyleRewriteUi.shortDate('2026/12/03')).assertEqual('12月3日');
    });

    it('acceptsTheNumericTimestampReturnedByTheStyleApi', 0, () => {
      expect(StyleRewriteUi.metadata('范文', 1704067200000)).assertEqual('2 字 · 1月1日');
    });

    it('fallsBackSafelyForLegacyVersionsWithoutStyleText', 0, () => {
      expect(StyleRewriteUi.displayName(undefined, 'app')).assertEqual('app');
      expect(StyleRewriteUi.metadata(undefined, undefined, 'app')).assertEqual('3 字');
    });

    it('readsTheSelectedStyleFromLegacyArticleMarkersLikeAndroid', 0, () => {
      expect(StyleRewriteUi.articleStyleVersion(
        undefined, '<!-- style: 风格 v3 -->\n\n正文')).assertEqual(3);
      expect(StyleRewriteUi.articleStyleVersion(
        5, '<!-- style: 风格 v3 -->\n\n正文')).assertEqual(5);
    });

    it('describesTheSelectedStyleAction', 0, () => {
      expect(StyleRewriteUi.actionLabel(-1, false)).assertEqual('选一个版本');
      expect(StyleRewriteUi.actionLabel(2, false)).assertEqual('用 v2 重写本文');
      expect(StyleRewriteUi.actionLabel(1, true)).assertEqual('切换到 v1 风格');
    });

    it('dimsOnlyTheNavigationBarWithTheBlockingRewriteOverlay', 0, () => {
      expect(StyleRewriteUi.navigationBarColor(true)).assertEqual('#C8C5BF');
      expect(StyleRewriteUi.navigationBarColor(false)).assertEqual('#FAF6EF');
    });

    it('retriesARewriteArticleThatIsTemporarilyUnavailable', 0, () => {
      expect(StyleRewriteUi.shouldRetryArticleLoad(false, 0)).assertTrue();
      expect(StyleRewriteUi.shouldRetryArticleLoad(false, 1)).assertTrue();
      expect(StyleRewriteUi.shouldRetryArticleLoad(false, 2)).assertFalse();
      expect(StyleRewriteUi.shouldRetryArticleLoad(true, 0)).assertFalse();
      expect(StyleRewriteUi.articleReloadDelay(0)).assertEqual(0);
      expect(StyleRewriteUi.articleReloadDelay(1)).assertEqual(150);
      expect(StyleRewriteUi.articleReloadDelay(2)).assertEqual(350);
    });
  });
}
