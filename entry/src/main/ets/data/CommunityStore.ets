import { Api } from '../core/Api';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { ClientReliability } from '../core/ClientReliability';
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
class EmptyCommunityShareBody {}
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
  private postCacheRoot: string = '';
  private postCacheEpoch: number = 0;
  private postCacheGenerations: Map<string, number> = new Map<string, number>();

  initialize(context: common.Context): void {
    this.postCacheRoot = `${context.cacheDir}/community-post-cache-v1`;
    try { fs.mkdirSync(this.postCacheRoot); } catch (_) {}
  }

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
    const feed: CommunityFeed = new CommunityFeed(recommended.length === posts.length ? recommended : posts.slice(), posts);
    authStore.storeCommunityFeedCache(response.text);
    return feed;
  }

  cachedFeed(): CommunityFeed {
    try {
      const raw: string = authStore.communityFeedCache();
      if (raw.length === 0) return new CommunityFeed();
      return this.feedFromWire(JSON.parse(raw) as CommunityFeedResponse);
    } catch (_) { return new CommunityFeed(); }
  }

  invalidateFeed(): void { authStore.clearCommunityFeedCache(); }

  async engage(shareId: string, action: string, on?: boolean): Promise<boolean> {
    const body: EngageBody = new EngageBody(action, on);
    const response: HttpResponse = await httpClient.postJson(`${Api.RECO}/engage/${Api.path(shareId)}`, authStore.anonymousBearer(), body);
    if (response.ok()) this.invalidateFeed();
    return response.ok();
  }

  async report(shareId: string): Promise<boolean> {
    const identity: string = authStore.bearer();
    const ok: boolean = (await httpClient.postJson(
      `${Api.FILES}/community/report/${Api.path(shareId)}`, identity,
      new EmptyCommunityShareBody())).ok();
    if (ok) {
      this.invalidatePost(shareId, identity);
      this.invalidateFeed();
    }
    return ok;
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
      const result: CommunityFeedResult = new CommunityFeedResult(parsed.ok ?? response.ok(), parsed.already ?? false, parsed.error ?? '',
        parsed.suanli?.author ?? 0, parsed.suanli?.feeder ?? 0);
      if (result.ok || result.already) this.invalidateFeed();
      return result;
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
    // HarmonyOS http.request rejects an empty string as extraData with
    // "parameter error". The backend accepts an empty JSON object for a
    // top-level article share; replies still carry their replyTo field.
    const body: Object = replyTo.length > 0 ? new ReplyBody(replyTo) : new EmptyCommunityShareBody();
    const identity: string = authStore.bearer();
    const response: HttpResponse = await httpClient.postJson(`${Api.FILES}/community/share/${Api.path(articleKey)}`,
      identity, body);
    try {
      if (response.ok()) {
        const id: string = (JSON.parse(response.text) as CommunityIdResponse).shareId ?? '';
        const result: CommunityShareResult = new CommunityShareResult(id.length > 0, id, response.code, '');
        if (result.ok) {
          this.invalidatePost(id, identity);
          if (replyTo.length > 0) this.invalidatePost(replyTo, identity);
          this.invalidateFeed();
        }
        return result;
      }
      return new CommunityShareResult(false, '', response.code,
        response.text.length > 0 ? (JSON.parse(response.text) as CommunityErrorResponse).error ?? '' : '');
    } catch (_) { return new CommunityShareResult(false, '', response.code, ''); }
  }

  async unshare(shareId: string): Promise<boolean> {
    const identity: string = authStore.bearer();
    const ok: boolean = (await httpClient.postJson(
      `${Api.FILES}/community/unshare/${Api.path(shareId)}`, identity,
      new EmptyCommunityShareBody())).ok();
    if (ok) {
      this.invalidatePost(shareId, identity);
      this.invalidateFeed();
    }
    return ok;
  }

  async replies(shareId: string): Promise<CommunityPost[]> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/community/replies/${Api.path(shareId)}`, authStore.bearer());
    if (!response.ok()) return [];
    const posts: CommunityPost[] = (JSON.parse(response.text) as CommunityPostsResponse).posts ?? [];
    posts.forEach((post: CommunityPost) => this.normalize(post));
    return posts;
  }

  async get(shareId: string): Promise<CommunityPost | undefined> {
    const identity: string = authStore.bearer();
    const cacheKey: string = ClientReliability.communityPostCacheKey(identity, shareId);
    const generation: number = (this.postCacheGenerations.get(cacheKey) ?? 0) + 1;
    const epoch: number = this.postCacheEpoch;
    this.postCacheGenerations.set(cacheKey, generation);
    const response: HttpResponse = await httpClient.get(
      `${Api.FILES}/community/get/${Api.path(shareId)}`, identity);
    if (!response.ok()) {
      if ((response.code === 404 || response.code === 410) &&
        ClientReliability.shouldApplyCacheResponse(identity, authStore.bearer(), epoch, this.postCacheEpoch,
          generation, this.postCacheGenerations.get(cacheKey) ?? 0)) {
        this.invalidatePost(shareId, identity);
      }
      return undefined;
    }
    const post: CommunityPost = this.postFromSnapshot(response.text);
    if (!ClientReliability.shouldApplyCacheResponse(identity, authStore.bearer(), epoch, this.postCacheEpoch,
      generation, this.postCacheGenerations.get(cacheKey) ?? 0)) return undefined;
    this.storePostSnapshot(shareId, response.text, identity);
    return post;
  }

  cachedPost(shareId: string, identity: string = authStore.bearer()): CommunityPost | undefined {
    try {
      const raw: string = this.readPostSnapshot(shareId, identity);
      return raw.length > 0 ? this.postFromSnapshot(raw) : undefined;
    } catch (_) { return undefined; }
  }

  cachePost(post: CommunityPost, identity: string = authStore.bearer()): void {
    if (!post.shareId) return;
    const cacheKey: string = ClientReliability.communityPostCacheKey(identity, post.shareId);
    this.postCacheGenerations.set(cacheKey, (this.postCacheGenerations.get(cacheKey) ?? 0) + 1);
    this.storePostSnapshot(post.shareId, JSON.stringify(post), identity);
  }

  invalidatePost(shareId: string, identity: string = authStore.bearer()): void {
    const cacheKey: string = ClientReliability.communityPostCacheKey(identity, shareId);
    this.postCacheGenerations.set(cacheKey, (this.postCacheGenerations.get(cacheKey) ?? 0) + 1);
    if (this.postCacheRoot.length === 0) return;
    try { fs.unlinkSync(this.postSnapshotPath(shareId, identity)); } catch (_) {}
  }

  clearPostSnapshots(): void {
    this.postCacheEpoch++;
    this.postCacheGenerations.clear();
    if (this.postCacheRoot.length === 0) return;
    try {
      for (const name of fs.listFileSync(this.postCacheRoot)) {
        try { fs.unlinkSync(`${this.postCacheRoot}/${name}`); } catch (_) {}
      }
    } catch (_) {}
  }

  private postFromSnapshot(raw: string): CommunityPost {
    const parsed: CommunityPostResponse = JSON.parse(raw) as CommunityPostResponse;
    const post: CommunityPost = parsed.post ?? JSON.parse(raw) as CommunityPost;
    this.normalize(post);
    return post;
  }

  private postSnapshotPath(shareId: string, identity: string = authStore.bearer()): string {
    return `${this.postCacheRoot}/${ClientReliability.communityPostCacheKey(identity, shareId)}`;
  }

  private readPostSnapshot(shareId: string, identity: string = authStore.bearer()): string {
    if (this.postCacheRoot.length === 0) return '';
    let file: fs.File | undefined;
    try {
      file = fs.openSync(this.postSnapshotPath(shareId, identity), fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(file.fd).size;
      const bytes: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, bytes);
      return new util.TextDecoder('utf-8').decodeWithStream(new Uint8Array(bytes));
    } catch (_) { return ''; }
    finally { if (file) try { fs.closeSync(file); } catch (_) {} }
  }

  private storePostSnapshot(shareId: string, raw: string, identity: string = authStore.bearer()): void {
    if (this.postCacheRoot.length === 0 || raw.length === 0) return;
    let file: fs.File | undefined;
    try {
      file = fs.openSync(this.postSnapshotPath(shareId, identity),
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      const encoded: Uint8Array = new util.TextEncoder().encodeInto(raw);
      const data: ArrayBuffer = new ArrayBuffer(encoded.byteLength);
      new Uint8Array(data).set(encoded);
      fs.writeSync(file.fd, data);
    } catch (_) {}
    finally { if (file) try { fs.closeSync(file); } catch (_) {} }
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

  private feedFromWire(wire: CommunityFeedResponse): CommunityFeed {
    const posts: CommunityPost[] = wire.posts ?? [];
    posts.forEach((post: CommunityPost) => this.normalize(post));
    const byId: Map<string, CommunityPost> = new Map<string, CommunityPost>();
    posts.forEach((post: CommunityPost) => byId.set(post.shareId, post));
    const recommended: CommunityPost[] = [];
    (wire.order ?? []).forEach((id: string) => { const post: CommunityPost | undefined = byId.get(id); if (post) recommended.push(post); });
    return new CommunityFeed(recommended.length === posts.length ? recommended : posts.slice(), posts);
  }
}

export const communityStore: CommunityStore = new CommunityStore();
