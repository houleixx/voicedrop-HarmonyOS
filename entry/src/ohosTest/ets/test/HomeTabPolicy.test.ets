import { describe, expect, it } from '@ohos/hypium';
import { HomeTabIndex, HomeTabPolicy } from '../../../main/ets/core/HomeTabPolicy';

export default function homeTabPolicyTest() {
  describe('HomeTabPolicy', () => {
    it('loadsCommunityOnlyOnTheFirstCommunityEntry', 0, () => {
      expect(HomeTabPolicy.shouldLoadCommunity(HomeTabIndex.Community, false, false)).assertTrue();
      expect(HomeTabPolicy.shouldLoadCommunity(HomeTabIndex.Community, true, false)).assertFalse();
      expect(HomeTabPolicy.shouldLoadCommunity(HomeTabIndex.Community, false, true)).assertFalse();
    });

    it('doesNotLoadCommunityForOtherHomeTabs', 0, () => {
      expect(HomeTabPolicy.shouldLoadCommunity(HomeTabIndex.Recordings, false, false)).assertFalse();
      expect(HomeTabPolicy.shouldLoadCommunity(HomeTabIndex.Books, false, false)).assertFalse();
    });
  });
}
