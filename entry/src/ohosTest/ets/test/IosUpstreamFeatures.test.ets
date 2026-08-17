import { describe, expect, it } from '@ohos/hypium';
import { CommunitySearch, CommunitySearchLayout } from '../../../main/ets/core/CommunitySearch';
import {
  ManualBlock,
  ManualBlockKind,
  ManualMarkdown,
  ManualSectionSelection
} from '../../../main/ets/core/ManualMarkdown';
import { BookSeedBody, BookWritingService } from '../../../main/ets/data/BookWritingService';
import { BooksService } from '../../../main/ets/data/BooksService';
import { FeedbackBody } from '../../../main/ets/data/SettingsStore';
import { CommunityPost } from '../../../main/ets/model/Models';
import { WechatShareContent } from '../../../main/ets/core/WechatShareContent';

export default function iosUpstreamFeaturesTest() {
  describe('IosUpstreamFeatures', () => {
    it('searchesCommunityTitleAuthorAndPreview', 0, () => {
      const posts: CommunityPost[] = [
        { shareId: 'a', title: '春天', excerpt: '旧摘要', preview: '海边散步', author: '小王', likes: 0, replies: 0 },
        { shareId: 'b', title: '冬天', excerpt: '炉火', author: '小李', likes: 0, replies: 0 }
      ];
      expect(CommunitySearch.filter(posts, '海边')[0].shareId).assertEqual('a');
      expect(CommunitySearch.filter(posts, '小李')[0].shareId).assertEqual('b');
      expect(CommunitySearch.filter(posts, '不存在').length).assertEqual(0);
    });

    it('keepsCommunityToolbarHeightStableWhileSearching', 0, () => {
      expect(CommunitySearchLayout.toolbarHeight(false))
        .assertEqual(CommunitySearchLayout.toolbarHeight(true));
    });

    it('keepsFeedbackAndBookSeedsWithinServerLimits', 0, () => {
      const longText: string = 'a'.repeat(21000);
      expect(new FeedbackBody(longText, ' 名字 ', ' HarmonyOS ').text.length).assertEqual(2000);
      expect(new BookSeedBody(longText).seed.length).assertEqual(20000);
      expect(BookWritingService.message(202).includes('开始写了')).assertTrue();
      expect(BookWritingService.message(401).includes('身份校验')).assertTrue();
      expect(BookWritingService.message(401).includes('文章')).assertFalse();
      const insufficient = BookWritingService.result(402,
        '{"error":"no-credit","need_suanli":320,"suanli":12.5}');
      expect(insufficient.accepted).assertFalse();
      expect(insufficient.message.includes('要 320 算力')).assertTrue();
      expect(insufficient.message.includes('现在有 12.5')).assertTrue();
      expect(BookWritingService.shouldLoadInvite(undefined)).assertFalse();
      expect(BookWritingService.shouldLoadInvite(320)).assertFalse();
      expect(BookWritingService.shouldLoadInvite(500)).assertFalse();
      expect(BookWritingService.shouldLoadInvite(319.9)).assertTrue();
      expect(BookWritingService.shortfall(319.9)).assertEqual(1);
    });

    it('parsesCurrentIosBookShelfContract', 0, () => {
      const books = new BooksService().parse('{"books":[{"slug":"a-book","title":"主标题：副标题","main":"主标题","sub":"副标题","cover":true,"coverAt":456,"chapters":7,"author":"作者","createdAt":123},{}]}');
      expect(books.length).assertEqual(1);
      expect(books[0].main).assertEqual('主标题');
      expect(books[0].chapters).assertEqual(7);
      expect(books[0].author).assertEqual('作者');
      expect(books[0].createdAt).assertEqual(123);
      expect(books[0].readerUrl()).assertEqual('https://voicedrop.cn/books/a-book/');
      expect(books[0].coverUrl()).assertEqual('https://voicedrop.cn/books/a-book/cover.jpg?v=456');
      expect(books[0].shareText()).assertEqual('《主标题：副标题》 — 作者\nhttps://voicedrop.cn/books/a-book/');
    });

    it('keepsServerBookOrderAndAcceptsLegacyCacheWithoutCreatedAt', 0, () => {
      const books = new BooksService().parse('{"books":[' +
        '{"slug":"new-book","title":"新书","main":"新书","createdAt":200},' +
        '{"slug":"legacy-book","title":"旧书","main":"旧书"}]}');
      expect(books.length).assertEqual(2);
      expect(books[0].slug).assertEqual('new-book');
      expect(books[0].createdAt).assertEqual(200);
      expect(books[1].slug).assertEqual('legacy-book');
      expect(books[1].createdAt).assertEqual(0);
      expect(books[1].coverAt).assertEqual(0);
      expect(books[1].coverUrl()).assertEqual('https://voicedrop.cn/books/legacy-book/cover.jpg');
    });

    it('buildsPublicArticleMiniProgramCardsWithoutCommunityVisibility', 0, () => {
      const url: string = 'https://jianshuo.dev/voicedrop/Abc_123456?s=2';
      expect(WechatShareContent.publicShareId(url)).assertEqual('Abc_123456');
      expect(WechatShareContent.publicMiniProgramPath(url, 2))
        .assertEqual('pages/shared-article/index?shareId=Abc_123456&section=2&fromShare=1');
      expect(WechatShareContent.publicShareId('https://evil.example/Abc_123456')).assertEqual('');
    });

    it('usesCleanFortyFourCharacterWechatExcerptsAndSectionLinks', 0, () => {
      const body: string = '<!-- style: v2 -->\n[[photo:photos/a.jpg]]\n' + '字'.repeat(45) + '\n 下一段';
      expect(WechatShareContent.excerpt(body, '兜底'))
        .assertEqual('字'.repeat(44) + '……');
      expect(WechatShareContent.excerpt(' [[photo:1]] ', '兜底')).assertEqual('兜底');
      expect(WechatShareContent.withSection('https://voicedrop.cn/abc123', 3))
        .assertEqual('https://voicedrop.cn/abc123?s=3');
      expect(WechatShareContent.communityMiniProgramPath('community1', 2))
        .assertEqual('pages/community-detail/index?shareId=community1&section=2&fromShare=1');
    });

    it('parsesBundledMarkdownIntoIosEquivalentNativeBlocks', 0, () => {
      const markdown: string = '# 手册\n\n## 第一章\n### 小节\n正文\n\n- 一项\n\n1. 一步'
        + '\n\n| 状态 | 意思 |\n|---|---|\n| 完成 | 好 |\n\n```\ncode\n```';
      const blocks: ManualBlock[] = ManualMarkdown.parse(markdown);
      expect(blocks[0].kind).assertEqual(ManualBlockKind.TITLE);
      expect(blocks[1].kind).assertEqual(ManualBlockKind.CHAPTER);
      expect(blocks[2].kind).assertEqual(ManualBlockKind.SECTION);
      expect(blocks[3].kind).assertEqual(ManualBlockKind.PARAGRAPH);
      expect(blocks[4].kind).assertEqual(ManualBlockKind.BULLETS);
      expect(blocks[5].kind).assertEqual(ManualBlockKind.NUMBERED);
      expect(blocks[6].kind).assertEqual(ManualBlockKind.TABLE);
      expect(blocks[7].kind).assertEqual(ManualBlockKind.CODE);
      expect(ManualMarkdown.chapterBlockIndexes(blocks).length).assertEqual(1);
      expect(ManualMarkdown.SECTION_LABELS.length).assertEqual(8);
      expect(ManualMarkdown.ASSET).assertEqual('help_manual.md');
    });

    it('parsesManualInlineBoldCodeAndLinks', 0, () => {
      const parts = ManualMarkdown.inline('**重点** `code` [链接](https://voicedrop.cn)');
      expect(parts[0].bold).assertTrue();
      expect(parts[2].code).assertTrue();
      expect(parts[4].url).assertEqual('https://voicedrop.cn');
    });

    it('keepsClickedManualChapterSelectedDuringSmoothScroll', 0, () => {
      const selection: ManualSectionSelection = new ManualSectionSelection();
      expect(selection.select(4)).assertEqual(4);
      expect(selection.report(0)).assertEqual(4);
      expect(selection.report(1)).assertEqual(4);
      expect(selection.report(2)).assertEqual(4);
      expect(selection.report(3)).assertEqual(4);
      expect(selection.report(4)).assertEqual(4);
      selection.releaseTarget();
      expect(selection.report(3)).assertEqual(3);
    });
  });
}
