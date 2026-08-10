import { describe, expect, it } from '@ohos/hypium';
import { SECONDARY_PAGES } from '../../../main/ets/pages/AppPage';

export default function appPageTest() {
  describe('AppPage', () => {
    it('keepsEverySecondaryPageInTheNativeNavigationInventory', 0, () => {
      expect(SECONDARY_PAGES.join(',')).assertEqual(
        'detail,communityDetail,shared,settings,style,wechat,account,about,privacy,usage,prompts,blocked,manual,feedback,books');
    });

    it('doesNotPutTheHomeRootInTheDestinationStack', 0, () => {
      expect(SECONDARY_PAGES.includes('home')).assertFalse();
      expect(SECONDARY_PAGES.length).assertEqual(15);
    });
  });
}
