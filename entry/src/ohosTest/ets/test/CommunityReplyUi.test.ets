import { describe, expect, it } from '@ohos/hypium';
import { CommunityReplyUi } from '../../../main/ets/core/CommunityReplyUi';

export default function communityReplyUiTest() {
  describe('CommunityReplyUi', () => {
    it('keepsTheArticleHeaderHeightStableWhenRecordingStarts', 0, () => {
      expect(CommunityReplyUi.headerHeight(true))
        .assertEqual(CommunityReplyUi.headerHeight(false));
    });

    it('explainsThatAnUploadedResponseWillPublishAfterMining', 0, () => {
      expect(CommunityReplyUi.savedMessage(true)).assertEqual('回应已保存，成文后自动发布');
    });

    it('explainsThatAFailedUploadWillResumeLater', 0, () => {
      expect(CommunityReplyUi.savedMessage(false)).assertEqual('回应已保存，网络恢复后继续上传');
    });

    it('keepsDiscardedCommunityResponsesOnTheArticleDetail', 0, () => {
      expect(CommunityReplyUi.shouldRemainOnDetail(true, false)).assertTrue();
      expect(CommunityReplyUi.shouldRemainOnDetail(true, true)).assertFalse();
      expect(CommunityReplyUi.shouldRemainOnDetail(false, false)).assertFalse();
    });
  });
}
