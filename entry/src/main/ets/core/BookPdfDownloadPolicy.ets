/** Keeps the public-book PDF endpoint and local file naming rules out of the page UI. */
export class BookPdfDownloadPolicy {
  static readonly PDF_ORIGIN: string = 'https://jianshuo.dev/agent/books/pdf/';

  static isValidSlug(slug: string): boolean {
    return /^[a-z0-9][a-z0-9-]{0,62}$/.test(slug);
  }

  static url(slug: string): string {
    return BookPdfDownloadPolicy.isValidSlug(slug)
      ? `${BookPdfDownloadPolicy.PDF_ORIGIN}${encodeURIComponent(slug)}` : '';
  }

  /** Do not turn arbitrary attachments in the reader into local downloads. */
  static isTrustedUrl(url: string, slug: string): boolean {
    return url === BookPdfDownloadPolicy.url(slug);
  }

  static fileName(title: string, slug: string): string {
    const fallback: string = BookPdfDownloadPolicy.isValidSlug(slug) ? slug : 'book';
    const cleaned: string = (title || fallback).trim().replace(/[\\/:*?"<>|\u0000-\u001F]/g, '_').substring(0, 96);
    return `${cleaned.length > 0 ? cleaned : fallback}.pdf`;
  }
}
