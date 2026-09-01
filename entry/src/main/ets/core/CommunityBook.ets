import { ShelfBook } from '../data/BooksService';
import { CommunityPost } from '../model/Models';

/**
 * The recommendation feed can contain published books alongside normal
 * community posts. Book entries have no community snapshot to open: their
 * share id is the canonical `book-<slug>` reader route instead.
 */
export class CommunityBook {
  static fromPost(post: CommunityPost): ShelfBook | undefined {
    const prefix: string = 'book-';
    if (post.kind !== 'book' || !post.shareId.startsWith(prefix)) return undefined;
    const slug: string = post.shareId.substring(prefix.length).trim();
    if (slug.length === 0) return undefined;
    const title: string = post.title.trim() || slug;
    return new ShelfBook({
      slug: slug,
      title: title,
      main: title,
      sub: post.preview ?? post.excerpt,
      c: '#8A7A5A',
      c2: '#6E5F44',
      cover: (post.coverPhotoKey ?? '').length > 0,
      chapters: Math.max(0, post.count ?? 0),
      author: post.author,
      // A community feed does not provide book ownership; do not expose the
      // owner-only reader actions until the book reader verifies it itself.
      mine: false
    });
  }
}
