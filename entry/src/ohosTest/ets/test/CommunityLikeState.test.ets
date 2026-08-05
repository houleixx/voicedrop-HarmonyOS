import { describe, expect, it } from '@ohos/hypium';
import { CommunityLikeState } from '../../../main/ets/core/CommunityLikeState';
import { CommunityLikePresentation } from '../../../main/ets/core/CommunityLikePresentation';

export default function communityLikeStateTest() {
  describe('CommunityLikeState', () => {
    it('togglesImmediatelyInBothDirections', 0, () => {
      expect(CommunityLikeState.toggled(false)).assertTrue();
      expect(CommunityLikeState.toggled(true)).assertFalse();
    });

    it('persistsAndRemovesLikedShareIds', 0, () => {
      const liked: string = CommunityLikeState.update('[]', 'share-a', true);
      expect(CommunityLikeState.contains(liked, 'share-a')).assertTrue();
      const unliked: string = CommunityLikeState.update(liked, 'share-a', false);
      expect(CommunityLikeState.contains(unliked, 'share-a')).assertFalse();
    });

    it('recoversFromInvalidStoredData', 0, () => {
      expect(CommunityLikeState.contains('invalid', 'share-a')).assertFalse();
      expect(CommunityLikeState.update('invalid', 'share-a', true)).assertEqual('["share-a"]');
    });

    it('updatesTheVisibleCountWhenLikeStateChanges', 0, () => {
      expect(CommunityLikeState.countAfterToggle(3, false, true)).assertEqual(4);
      expect(CommunityLikeState.countAfterToggle(4, true, false)).assertEqual(3);
      expect(CommunityLikeState.countAfterToggle(4, true, true)).assertEqual(4);
    });

    it('keepsALocalLikeAcrossAStaleFeedRefresh', 0, () => {
      expect(CommunityLikeState.reconciledLiked(false, true)).assertTrue();
      expect(CommunityLikeState.reconciledCount(3, false, true)).assertEqual(4);
      expect(CommunityLikeState.reconciledCount(4, true, true)).assertEqual(4);
    });

    it('replacesTheVisibleCardWhenLikeChanges', 0, () => {
      const before = { shareId: 'share-a', title: 'A', excerpt: '', author: 'A', likes: 3, liked: false };
      const after = CommunityLikePresentation.apply([before], 'share-a', true)[0];
      expect(after.likes).assertEqual(4);
      expect(after.liked).assertTrue();
      expect(after === before).assertFalse();
      expect(CommunityLikePresentation.cardKey(before) === CommunityLikePresentation.cardKey(after)).assertFalse();
    });
  });
}
