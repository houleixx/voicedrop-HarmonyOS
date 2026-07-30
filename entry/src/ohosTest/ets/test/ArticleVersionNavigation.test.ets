import { describe, expect, it } from '@ohos/hypium';
import { ArticleVersionNavigation, ArticleVersionHead } from '../../../main/ets/core/ArticleVersionNavigation';

export default function articleVersionNavigationTest() {
  describe('ArticleVersionNavigation', () => {
    it('usesVersionIdsInsteadOfArrayPositionsLikeAndroid', 0, () => {
      const versions: ArticleVersionHead[] = [{ v: 9 }, { v: 2 }, { v: 5 }];
      expect(ArticleVersionNavigation.target(5, versions, -1)).assertEqual(2);
      expect(ArticleVersionNavigation.target(5, versions, 1)).assertEqual(9);
    });

    it('hasNoTargetBeyondTheOldestOrNewestVersion', 0, () => {
      const versions: ArticleVersionHead[] = [{ v: 2 }, { v: 5 }, { v: 9 }];
      expect(ArticleVersionNavigation.target(2, versions, -1)).assertUndefined();
      expect(ArticleVersionNavigation.target(9, versions, 1)).assertUndefined();
    });
  });
}
