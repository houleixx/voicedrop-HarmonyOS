import { CommunityPost } from '../model/Models';
import { CommunityLikeState } from './CommunityLikeState';

/** Immutable list-card updates for ArkUI keyed ForEach rendering. */
export class CommunityLikePresentation {
  static cardKey(post: CommunityPost): string {
    return `${post.shareId}:${post.likes}:${post.liked ? '1' : '0'}`;
  }

  static apply(posts: CommunityPost[], shareId: string, liked: boolean): CommunityPost[] {
    return posts.map((post: CommunityPost) => {
      if (post.shareId !== shareId) return post;
      return CommunityLikePresentation.copy(post,
        CommunityLikeState.countAfterToggle(post.likes, post.liked ?? false, liked), liked);
    });
  }

  static applyTarget(posts: CommunityPost[], shareId: string, likes: number, liked: boolean): CommunityPost[] {
    return posts.map((post: CommunityPost) => {
      if (post.shareId !== shareId) return post;
      return CommunityLikePresentation.copy(post, likes, liked);
    });
  }

  private static copy(post: CommunityPost, likes: number, liked: boolean): CommunityPost {
    return {
      shareId: post.shareId,
      title: post.title,
      excerpt: post.excerpt,
      author: post.author,
      avatar: post.avatar,
      createdAt: post.createdAt,
      likes: likes,
      replies: post.replies,
      liked: liked,
      articleKey: post.articleKey,
      doc: post.doc,
      replyTo: post.replyTo,
      owner: post.owner,
      kind: post.kind,
      promptCode: post.promptCode,
      appliesTo: post.appliesTo,
      mine: post.mine,
      preview: post.preview,
      articles: post.articles,
      body: post.body,
      transcript: post.transcript,
      photos: post.photos,
      firstSharedAt: post.firstSharedAt,
      sharedAt: post.sharedAt,
      updatedAt: post.updatedAt,
      count: post.count,
      hasPhoto: post.hasPhoto,
      coverPhotoKey: post.coverPhotoKey,
      coverAspectRatio: post.coverAspectRatio
    };
  }
}
