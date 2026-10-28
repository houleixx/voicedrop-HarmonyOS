import { describe, expect, it } from '@ohos/hypium';
import { BookShelfSearch, BookSearchRequestState } from '../../../main/ets/core/BookShelfSearch';
import { ShelfBook } from '../../../main/ets/data/BooksService';
export default function bookShelfSearchTest() {
  describe('BookShelfSearch', () => {
    it('combinesStrictOwnershipCategoryAndCaseInsensitiveSearch', 0, () => {
      const book: ShelfBook = new ShelfBook({ slug: 'a', title: '学习 AI', category: 'AI', mine: true });
      expect(BookShelfSearch.matchesFilter(book, '我的')).assertTrue();
      expect(BookShelfSearch.matchesFilter(new ShelfBook({ slug: 'b' }), '我的')).assertFalse();
      expect(BookShelfSearch.matchesFilter(book, '故事')).assertFalse();
      expect(BookShelfSearch.hit(book, ' ai ')).assertEqual('');
      expect(BookShelfSearch.filters([book]).join(',')).assertEqual('全部,我的,AI');
    });
    it('supportsVideoFilterAndLegacyBooks', 0, () => {
      const video: ShelfBook = new ShelfBook({ slug: 'a', video: true, category: 'AI' });
      const old: ShelfBook = new ShelfBook({ slug: 'b' });
      expect(video.video).assertTrue();
      expect(old.video).assertFalse();
      expect(BookShelfSearch.filters([video, old]).join(',')).assertEqual('全部,我的,视频,AI');
      expect(BookShelfSearch.matchesFilter(video, '视频')).assertTrue();
      expect(BookShelfSearch.matchesFilter(old, '视频')).assertFalse();
      expect(BookShelfSearch.validFilter([old], '视频')).assertEqual('全部');
      expect(BookShelfSearch.validFilter([video], '视频')).assertEqual('视频');
    });
    it('findsChapterBriefAndPreservesWriteEntryOnlyForBlankInput', 0, () => {
      const book: ShelfBook = new ShelfBook({ slug: 'a', title: '标题' });
      const entries = BookShelfSearch.parse('{"books":[{"slug":"a","toc":[{"t":"第一章","b":"章节摘要"}]}]}');
      expect(BookShelfSearch.hit(book, '摘要', entries[0])).assertEqual('第一章');
      expect(BookShelfSearch.showWrite('  ')).assertTrue();
      expect(BookShelfSearch.showWrite('摘要')).assertFalse();
    });
    it('deduplicatesAndRejectsOutdatedRequests', 0, () => {
      const state: BookSearchRequestState = new BookSearchRequestState(); state.invalidate('a');
      const first: number = state.begin('x'); expect(state.begin('xy')).assertEqual(-1);
      state.invalidate('b'); expect(state.finish(first, 'a', true)).assertFalse();
      const second: number = state.begin('y'); expect(state.finish(second, 'b', false)).assertTrue();
      expect(state.begin('yz')).assertEqual(-1); expect(state.begin('yz', true) > second).assertTrue();
    });
  });
}
