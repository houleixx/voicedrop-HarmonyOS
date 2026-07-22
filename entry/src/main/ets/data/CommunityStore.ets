import { Api } from '../core/Api';
import { CommunityPost } from '../model/Models';
import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';

interface CommunityFeedResponse { posts?: CommunityPost[]; order?: string[]; }
export class CommunityFeed {
  recommended: CommunityPost[];
  latest: CommunityPost[];
  constructor(recommended: CommunityPost[] = [], latest: CommunityPost[] = []) {
    this.recommended = recommended; this.latest = latest;
  }
}

class EngageBody {
  action: string;
  on?: boolean;
  constructor(action: string, on?: boolean) { this.action = action; this.on = on; }
}
class ReplyBody {
  replyTo: string;
  constructor(replyTo: string) { this.replyTo = replyTo; }
}
class CommunityIdResponse { shareId?: string; }
class CommunityPostsResponse { posts?: CommunityPost[]; }
class CommunityPostResponse { post?: CommunityPost; }
interface CommunityErrorResponse { error?: string; }
class FeedStatesBody {
  share_ids: string[];
  constructor(ids: string[]) { this.share_ids = ids; }
}
class FeedBody {
  share_id: string;
  constructor(id: string) { this.share_id = id; }
}
interface FeedStateWire { count?: number; fed?: boolean; }
interface FeedStatesResponse { states?: Record<string, FeedStateWire>; }
interface FeedSuanliWire { author?: number; feeder?: number; }
interface FeedResultWire { ok?: boolean; already?: boolean; error?: string; suanli?: FeedSuanliWire; }
export class CommunityFeedState {
  count: number; fed: boolean;
  constructor(count: number, fed: boolean) { this.count = count; this.fed = fed; }
}
export class CommunityFeedResult {
  ok: boolean; already: boolean; error: string; authorSuanli: number; feederSuanli: number;
  constructor(ok: boolean, already: boolean, error: string, authorSuanli: number, feederSuanli: number) {
    this.ok = ok; this.already = already; this.error = error; this.authorSuanli = authorSuanli; this.feederSuanli = feederSuanli;
  }
  needsWechatSignin(): boolean { return this.error === 'needs_wechat_signin' || this.error === 'needs_apple_signin'; }
}
export class CommunityShareResult {
  ok: boolean;
  shareId: string;
  code: number;
  error: string;
  constructor(ok: boolean, shareId: string, code: number, error: string) {
    this.ok = ok; this.shareId = shareId; this.code = code; this.error = error;
  }
  needsWechatSignin(): boolean {
    return (this.code === 401 && this.error === 'unauthorized') ||
      (this.code === 403 && (this.error === 'needs_wechat_signin' || this.error === 'needs_apple_signin'));
  }
}

export class CommunityStore {
  async feed(): Promise<CommunityFeed> {
    const response: HttpResponse = await httpClient.get(`${Api.RECO}/feed`, authStore.anonymousBearer());
    if (!response.ok()) throw new Error(`社区加载失败 HTTP ${response.code}`);
    const wire: CommunityFeedResponse = JSON.parse(response.text) as CommunityFeedResponse;
    const posts: CommunityPost[] = wire.posts ?? [];
    for (const post of posts) {
      this.normalize(post);
    }
    const order: string[] = wire.order ?? [];
    const byId: Map<string, CommunityPost> = new Map<string, CommunityPost>();
    posts.forEach((post: CommunityPost) => byId.set(post.shareId, post));
    const recommended: CommunityPost[] = [];
    order.forEach((id: string) => { const post: CommunityPost | undefined = byId.get(id); if (post) recommended.push(post); });
    return new CommunityFeed(recommended.length === posts.length ? recommended : posts.slice(), posts);
  }

  async engage(shareId: string, action: string, on?: boolean): Promise<void> {
    const body: EngageBody = new EngageBody(action, on);
    await httpClient.postJson(`${Api.RECO}/engage/${Api.path(shareId)}`, authStore.anonymousBearer(), body);
  }

  async report(shareId: string): Promise<boolean> {
    return (await httpClient.postJson(`${Api.FILES}/community/report/${Api.path(shareId)}`, authStore.bearer())).ok();
  }

  async feedState(shareId: string): Promise<CommunityFeedState> {
    const response: HttpResponse = await httpClient.postJson(`${Api.AGENT}/feed/state`, authStore.bearer(),
      new FeedStatesBody([shareId]));
    if (!response.ok()) return new CommunityFeedState(0, false);
    const parsed: FeedStatesResponse = JSON.parse(response.text) as FeedStatesResponse;
    const state: FeedStateWire | undefined = parsed.states?.[shareId];
    return new CommunityFeedState(state?.count ?? 0, state?.fed ?? false);
  }

  async feedPost(shareId: string): Promise<CommunityFeedResult> {
    const response: HttpResponse = await httpClient.postJson(`${Api.AGENT}/feed`, authStore.bearer(), new FeedBody(shareId));
    try {
      const parsed: FeedResultWire = JSON.parse(response.text.length > 0 ? response.text : '{}') as FeedResultWire;
      return new CommunityFeedResult(parsed.ok ?? response.ok(), parsed.already ?? false, parsed.error ?? '',
        parsed.suanli?.author ?? 0, parsed.suanli?.feeder ?? 0);
    } catch (_) { return new CommunityFeedResult(false, false, '', 0, 0); }
  }

  async sharedShareId(articleKey: string): Promise<string> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/community/shared/${Api.path(articleKey)}`, authStore.bearer());
    return response.ok() ? (JSON.parse(response.text) as CommunityIdResponse).shareId ?? '' : '';
  }

  async share(articleKey: string, replyTo: string = ''): Promise<string> {
    return (await this.shareResult(articleKey, replyTo)).shareId;
  }

  async shareResult(articleKey: string, replyTo: string = ''): Promise<CommunityShareResult> {
    const body: Object | string = replyTo.length > 0 ? new ReplyBody(replyTo) : '';
    const response: HttpResponse = await httpClient.postJson(`${Api.FILES}/community/share/${Api.path(articleKey)}`,
      authStore.bearer(), body);
    try {
      if (response.ok()) {
        const id: string = (JSON.parse(response.text) as CommunityIdResponse).shareId ?? '';
        return new CommunityShareResult(id.length > 0, id, response.code, '');
      }
      return new CommunityShareResult(false, '', response.code,
        response.text.length > 0 ? (JSON.parse(response.text) as CommunityErrorResponse).error ?? '' : '');
    } catch (_) { return new CommunityShareResult(false, '', response.code, ''); }
  }

  async unshare(shareId: string): Promise<boolean> {
    return (await httpClient.postJson(`${Api.FILES}/community/unshare/${Api.path(shareId)}`, authStore.bearer())).ok();
  }

  async replies(shareId: string): Promise<CommunityPost[]> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/community/replies/${Api.path(shareId)}`, authStore.bearer());
    if (!response.ok()) return [];
    const posts: CommunityPost[] = (JSON.parse(response.text) as CommunityPostsResponse).posts ?? [];
    posts.forEach((post: CommunityPost) => this.normalize(post));
    return posts;
  }

  async get(shareId: string): Promise<CommunityPost | undefined> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/community/get/${Api.path(shareId)}`, authStore.bearer());
    if (!response.ok()) return undefined;
    const parsed: CommunityPostResponse = JSON.parse(response.text) as CommunityPostResponse;
    const post: CommunityPost = parsed.post ?? JSON.parse(response.text) as CommunityPost;
    this.normalize(post); return post;
  }

  private normalize(post: CommunityPost): void {
    post.title = post.title || '(无题)'; post.excerpt = post.excerpt ?? post.preview ?? '';
    post.author = post.author ?? ''; post.likes = post.likes ?? 0; post.replies = post.replies ?? 0;
    post.liked = post.liked ?? false; post.appliesTo = post.appliesTo ?? [];
    if (!post.doc && (post.articles || post.body !== undefined)) {
      const articles = post.articles ?? [{ title: post.title || '(无题)', body: post.body ?? '' }];
      post.doc = { owner: post.owner, transcript: post.transcript, articles: articles, photos: post.photos };
    }
  }
}

export const communityStore: CommunityStore = new CommunityStore();
