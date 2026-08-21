import { describe, expect, it } from '@ohos/hypium';
import { BookShelfLoadingPolicy } from '../../../main/ets/core/BookShelfLoadingPolicy';

export default function bookShelfLoadingPolicyTest(): void {
  describe('BookShelfLoadingPolicy', () => {
    it('firstLoadWithoutCacheUsesExclusiveLoadingState', 0, () => {
      expect(BookShelfLoadingPolicy.shouldShowExclusiveLoading(true, 0)).assertTrue();
    });

    it('cachedBooksRemainVisibleDuringBackgroundRefresh', 0, () => {
      expect(BookShelfLoadingPolicy.shouldShowExclusiveLoading(true, 2)).assertFalse();
    });

    it('completedEmptyLoadShowsNormalShelf', 0, () => {
      expect(BookShelfLoadingPolicy.shouldShowExclusiveLoading(false, 0)).assertFalse();
    });
  });
}
