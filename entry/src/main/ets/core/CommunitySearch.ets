import { CommunityPost } from '../model/Models';

export class CommunitySearch {
  static filter(posts: CommunityPost[], query: string): CommunityPost[] {
    const needle: string = query.trim().toLocaleLowerCase();
    if (needle.length === 0) return posts.slice();
    return posts.filter((post: CommunityPost) => [post.title, post.author, post.preview ?? post.excerpt]
      .some((value?: string) => (value ?? '').toLocaleLowerCase().includes(needle)));
  }
}

export class CommunitySearchLayout {
  static toolbarHeight(_searching: boolean): number {
    return 42;
  }
}
