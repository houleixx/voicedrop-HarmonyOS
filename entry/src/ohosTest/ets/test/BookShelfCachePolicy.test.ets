import { describe, expect, it } from '@ohos/hypium';
import { BookShelfCachePolicy } from '../../../main/ets/core/BookShelfCachePolicy';
import { DeviceLinkCrypto } from '../../../main/ets/data/DeviceLinkCrypto';

export default function bookShelfCachePolicyTest() {
  describe('BookShelfCachePolicy', () => {
    it('restoresOnlyTheExactIdentityGeneration', 0, () => {
      const first: string = BookShelfCachePolicy.identity('digest-a', 4);
      expect(BookShelfCachePolicy.canRestore(first, first)).assertTrue();
      expect(BookShelfCachePolicy.canRestore(first,
        BookShelfCachePolicy.identity('digest-b', 4))).assertFalse();
      expect(BookShelfCachePolicy.canRestore(first,
        BookShelfCachePolicy.identity('digest-a', 5))).assertFalse();
      expect(BookShelfCachePolicy.canRestore('', '')).assertFalse();
    });

    it('usesOnlyAnOpaqueDigestAndNormalizedGeneration', 0, () => {
      const scope: string = 'users/private-account-id/';
      const digest: string = DeviceLinkCrypto.stableDigestSync(`book-shelf:${scope}`);
      const identity: string = BookShelfCachePolicy.identity(digest, -3);
      expect(identity.startsWith('bookShelf.v1.')).assertTrue();
      expect(identity.endsWith('.g0')).assertTrue();
      expect(identity.includes(scope)).assertFalse();
      expect(digest.length).assertEqual(32);
      expect(BookShelfCachePolicy.identity(digest, 2.9).endsWith('.g2')).assertTrue();
    });

    it('rejectsResponsesAfterTheAccountIdentityChanges', 0, () => {
      const requestIdentity: string = BookShelfCachePolicy.identity('digest-a', 4);
      expect(BookShelfCachePolicy.shouldAcceptResponse(requestIdentity, requestIdentity)).assertTrue();
      expect(BookShelfCachePolicy.shouldAcceptResponse(requestIdentity,
        BookShelfCachePolicy.identity('digest-b', 4))).assertFalse();
      expect(BookShelfCachePolicy.shouldAcceptResponse(requestIdentity,
        BookShelfCachePolicy.identity('digest-a', 5))).assertFalse();
      expect(BookShelfCachePolicy.shouldAcceptResponse('', '')).assertFalse();
    });
  });
}
