import { describe, expect, it } from '@ohos/hypium';
import { CommunityShareUi } from '../../../main/ets/core/CommunityShareUi';

export default function communityShareUiTest() {
  describe('CommunityShareUi', () => {
    it('ignoresAStaleShareLookupAfterAUserMutation', 0, () => {
      expect(CommunityShareUi.shouldApplyLookup(3, 3)).assertTrue();
      expect(CommunityShareUi.shouldApplyLookup(2, 3)).assertFalse();
    });

    it('usesTheCommunityVisibleToastForAnArticleShare', 0, () => {
      expect(CommunityShareUi.successMessage(false)).assertEqual('已在 VD 社区可见');
      expect(CommunityShareUi.successMessage(true)).assertEqual('登录后已自动续发社区回复');
    });
  });
}
