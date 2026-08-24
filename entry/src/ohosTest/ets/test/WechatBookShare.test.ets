import { describe, expect, it } from '@ohos/hypium';
import { WechatBookShare } from '../../../main/ets/core/WechatBookShare';

export default function wechatBookShareTest() {
  describe('WechatBookShare', () => {
    it('buildsTheWechatBookCardTitle', 0, () => {
      expect(WechatBookShare.title(' 一本书 ', '短标题', ' 作者 ')).assertEqual('《一本书》 — 作者');
      expect(WechatBookShare.title('', '短标题', '')).assertEqual('《短标题》');
    });

    it('buildsTheMiniProgramReaderPathWithCoverMetadata', 0, () => {
      expect(WechatBookShare.miniProgramPath('sample-book', '一本书', '主标题', '张 三', true, 456))
        .assertEqual('pages/book-reader/index?slug=sample-book&title=%E4%B8%80%E6%9C%AC%E4%B9%A6' +
          '&main=%E4%B8%BB%E6%A0%87%E9%A2%98&author=%E5%BC%A0%20%E4%B8%89&cover=1&coverAt=456');
      expect(WechatBookShare.miniProgramPath(
        'sample-book', '一本书', '主标题', '', false, -1,
        'https://voicedrop.cn/books/sample-book/02.html?x=1'))
        .assertEqual('pages/book-reader/index?slug=sample-book&title=%E4%B8%80%E6%9C%AC%E4%B9%A6' +
          '&main=%E4%B8%BB%E6%A0%87%E9%A2%98&author=&cover=0&coverAt=0' +
          '&page=https%3A%2F%2Fvoicedrop.cn%2Fbooks%2Fsample-book%2F02.html%3Fx%3D1');
    });

    it('mapsTheBookMenuTargetsToWechatScenes', 0, () => {
      expect(WechatBookShare.isTimeline('friend')).assertFalse();
      expect(WechatBookShare.isTimeline('timeline')).assertTrue();
    });

    it('sharesOnlyTrustedCurrentBookPages', 0, () => {
      const root: string = 'https://voicedrop.cn/books/sample-book/';
      const chapter = WechatBookShare.target(root,
        'https://voicedrop.cn/books/sample-book/chapter-2.html', '第二章 · 出发', '一本书', '作者');
      expect(chapter.url).assertEqual('https://voicedrop.cn/books/sample-book/chapter-2.html');
      expect(chapter.title).assertEqual('第二章 · 出发');
      expect(chapter.isChapter).assertTrue();

      const cfChapter = WechatBookShare.target(root,
        'https://jianshuo.dev/voicedrop/books/sample-book/chapter-3.html',
        '第三章 · 海外', '一本书', '作者');
      expect(cfChapter.url).assertEqual('https://voicedrop.cn/books/sample-book/chapter-3.html');
      expect(cfChapter.title).assertEqual('第三章 · 海外');
      expect(cfChapter.isChapter).assertTrue();

      const outside = WechatBookShare.target(root, 'https://evil.example/books/sample-book/chapter-2.html',
        '伪造标题', '一本书', '作者');
      expect(outside.url).assertEqual(root);
      expect(outside.title).assertEqual('《一本书》 — 作者');
      expect(outside.isChapter).assertFalse();

      const otherBook = WechatBookShare.target(root,
        'https://voicedrop.cn/books/another-book/chapter-1.html', '另一本书', '一本书', '作者');
      expect(otherBook.url).assertEqual(root);
      expect(otherBook.title).assertEqual('《一本书》 — 作者');
      expect(otherBook.isChapter).assertFalse();

      const rootAnchor = WechatBookShare.target(root, `${root}#contents`, '目录', '一本书', '作者');
      expect(rootAnchor.url).assertEqual(root);
      expect(rootAnchor.isChapter).assertFalse();
    });
  });
}
