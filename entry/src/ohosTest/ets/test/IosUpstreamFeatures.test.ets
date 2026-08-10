import { describe, expect, it } from '@ohos/hypium';
import { CommunitySearch, CommunitySearchLayout } from '../../../main/ets/core/CommunitySearch';
import { ManualText } from '../../../main/ets/core/ManualText';
import { ManualSectionSelection, ManualWebUi } from '../../../main/ets/core/ManualWebUi';
import { BookSeedBody, BookWritingService } from '../../../main/ets/data/BookWritingService';
import { FeedbackBody } from '../../../main/ets/data/SettingsStore';
import { CommunityPost } from '../../../main/ets/model/Models';

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
      expect(BookWritingService.message(401).includes('至少一篇文章')).assertTrue();
    });

    it('rendersBundledMarkdownAsReadableText', 0, () => {
      const text: string = ManualText.readable('# 手册\n\n**重点**与[链接](https://voicedrop.cn)');
      expect(text.includes('#')).assertFalse();
      expect(text.includes('重点')).assertTrue();
      expect(text.includes('https://voicedrop.cn')).assertTrue();
    });

    it('routesManualWebLinksAndBuildsChapterScripts', 0, () => {
      expect(ManualWebUi.isManualUrl('https://voicedrop.cn/help/manual/#ch3')).assertTrue();
      expect(ManualWebUi.isManualUrl('https://jianshuo.dev/voicedrop/help/manual/')).assertTrue();
      expect(ManualWebUi.shouldOpenExternally('https://apps.apple.com/cn/app/id6781565141')).assertTrue();
      expect(ManualWebUi.scrollScript(2).includes("getElementById('ch3')")).assertTrue();
      expect(ManualWebUi.SECTION_LABELS.length).assertEqual(8);
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
