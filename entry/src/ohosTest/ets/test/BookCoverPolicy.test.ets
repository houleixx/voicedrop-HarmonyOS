import { describe, expect, it } from '@ohos/hypium';
import { BookCoverPolicy } from '../../../main/ets/core/BookCoverPolicy';
import { BookCoverDecoder } from '../../../main/ets/data/BookCoverStore';

function bytes(values: number[]): ArrayBuffer {
  const data: ArrayBuffer = new ArrayBuffer(values.length);
  new Uint8Array(data).set(values);
  return data;
}

export default function bookCoverPolicyTest() {
  describe('BookCoverPolicy', () => {
    it('keysPersistentFilesBySlugAndCoverVersion', 0, () => {
      expect(BookCoverPolicy.cacheKey('same-book', 100) !==
        BookCoverPolicy.cacheKey('same-book', 101)).assertTrue();
      expect(BookCoverPolicy.cacheKey('same-book', 100).endsWith('.jpg')).assertTrue();
    });

    it('usesFourAttemptsWithBoundedExponentialBackoff', 0, () => {
      expect(BookCoverPolicy.retryDelays().join(',')).assertEqual('0,2000,4000,8000');
      expect(BookCoverPolicy.shouldBypassNetworkCache(0)).assertFalse();
      expect(BookCoverPolicy.shouldBypassNetworkCache(1)).assertFalse();
      expect(BookCoverPolicy.shouldBypassNetworkCache(2)).assertTrue();
      expect(BookCoverPolicy.shouldBypassNetworkCache(3)).assertTrue();
    });

    it('acceptsResultsOnlyForTheVisibleCurrentRequest', 0, () => {
      expect(BookCoverPolicy.shouldApplyResult(false, 2, 2)).assertFalse();
      expect(BookCoverPolicy.shouldApplyResult(true, 1, 2)).assertFalse();
      expect(BookCoverPolicy.shouldApplyResult(true, 2, 2)).assertTrue();
    });

    it('rejectsHtmlAndTruncatedResponsesBeforeImageDecoding', 0, () => {
      expect(BookCoverPolicy.hasJpegSignature(bytes([0x3C, 0x68, 0x74, 0x6D, 0x6C])))
        .assertFalse();
      expect(BookCoverPolicy.hasJpegSignature(bytes([0xFF, 0xD8]))).assertFalse();
      expect(BookCoverPolicy.hasJpegSignature(bytes([0xFF, 0xD8, 0xFF, 0xE0]))).assertTrue();
    });

    it('allowsOnlyOneDisplayFailureRecoveryForEachRenderedCacheKey', 0, () => {
      expect(BookCoverPolicy.shouldRecoverDisplayFailure(false)).assertTrue();
      expect(BookCoverPolicy.shouldRecoverDisplayFailure(true)).assertFalse();
    });

    it('requiresARealImageKitDecodeBeforeCachingJpegBytes', 0, async () => {
      expect(await BookCoverDecoder.isDecodable(bytes([0xFF, 0xD8, 0xFF, 0xE0])))
        .assertFalse();
      expect(await BookCoverDecoder.isDecodable(bytes([0x3C, 0x68, 0x74, 0x6D, 0x6C])))
        .assertFalse();
    });
  });
}
