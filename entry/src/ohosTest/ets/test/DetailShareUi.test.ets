import { describe, expect, it } from '@ohos/hypium';
import { DetailShareUi } from '../../../main/ets/core/DetailShareUi';

export default function detailShareUiTest() {
  describe('DetailShareUi', () => {
    it('keepsRecordingChannelsInTheApprovedOrder', 0, () => {
      expect(DetailShareUi.targetIds('recording').join(','))
        .assertEqual('wechat,timeline,xhs,copy,system');
      expect(DetailShareUi.needsDivider('recording')).assertTrue();
    });

    it('doesNotOfferXiaohongshuForCommunity', 0, () => {
      expect(DetailShareUi.targetIds('community').join(','))
        .assertEqual('wechat,timeline,copy,system');
      expect(DetailShareUi.needsDivider('community')).assertFalse();
    });

    it('keepsBookSharingFocusedOnWechatAndLinks', 0, () => {
      expect(DetailShareUi.targetIds('book').join(','))
        .assertEqual('friend,timeline,copy,system');
      expect(DetailShareUi.needsDivider('book')).assertFalse();
    });

    it('keepsBookMoreMenuAtTwoTopLevelActions', 0, () => {
      expect(DetailShareUi.bookMenuIds().join(',')).assertEqual('revise,share');
    });

    it('keepsDetailMenusOnOneSharedAnchor', 0, () => {
      expect(DetailShareUi.MENU_TOP_OFFSET).assertEqual(64);
      expect(DetailShareUi.MENU_RIGHT_INSET).assertEqual(12);
    });
  });
}
