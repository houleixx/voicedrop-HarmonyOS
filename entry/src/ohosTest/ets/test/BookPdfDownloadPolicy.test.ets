import { describe, expect, it } from '@ohos/hypium';
import { BookPdfDownloadPolicy } from '../../../main/ets/core/BookPdfDownloadPolicy';

export default function bookPdfDownloadPolicyTest(): void {
  describe('BookPdfDownloadPolicy', () => {
    it('acceptsOnlyTheExpectedPublicPdfEndpointForTheCurrentBook', 0, () => {
      const slug: string = 'my-book-2';
      const url: string = BookPdfDownloadPolicy.url(slug);
      expect(url).assertEqual('https://jianshuo.dev/agent/books/pdf/my-book-2');
      expect(BookPdfDownloadPolicy.isTrustedUrl(url, slug)).assertTrue();
      expect(BookPdfDownloadPolicy.isTrustedUrl('https://example.com/file.pdf', slug)).assertFalse();
      expect(BookPdfDownloadPolicy.url('../private')).assertEqual('');
    });

    it('makesAUsablePdfFileNameFromTheBookTitle', 0, () => {
      expect(BookPdfDownloadPolicy.fileName('  A/B: C  ', 'fallback')).assertEqual('A_B_ C.pdf');
      expect(BookPdfDownloadPolicy.fileName('', 'fallback')).assertEqual('fallback.pdf');
    });
  });
}
