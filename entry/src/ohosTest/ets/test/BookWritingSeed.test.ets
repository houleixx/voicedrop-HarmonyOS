import { describe, expect, it } from '@ohos/hypium';
import { BookWritingArticleSeed, BookWritingSeed } from '../../../main/ets/core/BookWritingSeed';

export default function bookWritingSeedTest() {
  describe('BookWritingSeed', () => {
    it('usesAMarkerFreeArticleAsANonEditableSeed', 0, () => {
      const article = new BookWritingArticleSeed(' 春天 ', '<!-- style: v2 -->\n第一段\n[[photo:photos/a.jpg]]\n第二段');
      const seed = BookWritingSeed.compose('', article);
      expect(article.title).assertEqual('春天');
      expect(article.body).assertEqual('第一段\n\n第二段');
      expect(BookWritingSeed.canSubmit('', article)).assertTrue();
      expect(seed.includes('《春天》')).assertTrue();
      expect(seed.includes('[[photo:')).assertFalse();
      expect(seed.includes('第一段')).assertTrue();
    });

    it('keepsInstructionAndArticleTogetherWithinTheServerLimit', 0, () => {
      const article = new BookWritingArticleSeed('标题', '正'.repeat(21000));
      const seed = BookWritingSeed.compose('要求'.repeat(1000), article);
      expect(seed.length).assertEqual(20000);
      expect(seed.startsWith('写书要求：')).assertTrue();
      expect(BookWritingSeed.canSubmit('  ', undefined)).assertFalse();
      expect(BookWritingSeed.compose(' 想法 ', undefined)).assertEqual('想法');
    });
  });
}
