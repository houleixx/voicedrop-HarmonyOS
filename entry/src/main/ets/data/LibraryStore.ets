import { Api } from '../core/Api';
import { util } from '@kit.ArkTS';
import { ArticleDoc, ArticleHistory, ArticleVersion, Recording, RecordingRowPayload } from '../model/Models';
import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';

interface RecordingsResponse { recordings?: RecordingRowPayload[]; }
interface ShareResponse { url?: string; }
interface WhoamiResponse { scope?: string; }
interface XhsPackWire { title?: string; body?: string; tags?: string[]; photoKeys?: string[]; }
interface ArticleDocWire {
  id?: string; title?: string; body?: string; transcript?: string; articles?: import('../model/Models').MinedArticle[];
  tags?: string[]; questions?: import('../model/Models').FollowupQuestion[]; photos?: string[]; owner?: string;
}
interface LinkTargetWire {
  type?: string;
  owner?: string;
  stem?: string;
  title?: string;
  articles?: import('../model/Models').MinedArticle[];
  transcript?: string;
  photos?: string[];
}
export class ShareLinkTarget {
  type: string;
  owner: string;
  stem: string;
  title: string;
  doc?: ArticleDoc;
  constructor(type: string, owner: string, stem: string, title: string, doc?: ArticleDoc) {
    this.type = type; this.owner = owner; this.stem = stem; this.title = title; this.doc = doc;
  }
}
class StemRequest {
  stem: string;
  styleV?: number;
  constructor(stem: string, styleV?: number) { this.stem = stem; this.styleV = styleV; }
}
class HeadRequest {
  head: number;
  constructor(head: number) { this.head = head; }
}
class QuestionRequest {
  id: string;
  status: string;
  constructor(id: string, status: string) { this.id = id; this.status = status; }
}
export class XhsPack {
  title: string;
  body: string;
  tags: string[];
  photoKeys: string[];
  constructor(title: string = '', body: string = '', tags: string[] = [], photoKeys: string[] = []) {
    this.title = title; this.body = body; this.tags = tags; this.photoKeys = photoKeys;
  }
  clipboardText(): string {
    const hashtags: string = this.tags.map((tag: string) => `#${tag.trim()}`).filter((tag: string) => tag.length > 1).join(' ');
    return `${this.title}\n\n${this.body}${hashtags.length > 0 ? `\n\n${hashtags}` : ''}`.trim();
  }
}

export class LibraryStore {
  private cachedScopeToken: string = '';
  private cachedScope: string = '';
  async load(): Promise<Recording[]> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/recordings`, authStore.bearer());
    if (!response.ok()) throw new Error(`加载失败 HTTP ${response.code}`);
    const rows: RecordingRowPayload[] = (JSON.parse(response.text) as RecordingsResponse).recordings ?? [];
    return rows.filter((row: RecordingRowPayload) => row.name.endsWith('.m4a'))
      .map((row: RecordingRowPayload) => new Recording(row))
      .sort((left: Recording, right: Recording) => right.uploaded.localeCompare(left.uploaded) || right.name.localeCompare(left.name));
  }

  async enrichMissingMetadata(recordings: Recording[]): Promise<boolean> {
    let changed: boolean = false;
    for (let start: number = 0; start < recordings.length; start += 5) {
      const batch: Recording[] = recordings.slice(start, start + 5);
      await Promise.all(batch.map(async (recording: Recording) => {
        try {
          if (recording.hasArticles) {
            const doc: ArticleDoc | undefined = await this.fetchArticle(recording);
            if (doc) {
              recording.title = doc.articles?.[0]?.title ?? ''; recording.tags = doc.tags ?? []; changed = true;
            }
          } else if (recording.hasTags) {
            const response = await httpClient.getBytes(`${Api.FILES}/download/${Api.path(recording.tagsKey())}`, authStore.bearer());
            if (response.ok()) {
              const text: string = new util.TextDecoder('utf-8').decodeWithStream(new Uint8Array(response.data));
              recording.tags = (JSON.parse(text) as string[]).map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0);
              changed = true;
            }
          }
        } catch (_) {}
      }));
    }
    return changed;
  }

  async fetchArticle(recording: Recording): Promise<ArticleDoc | undefined> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/articles/${Api.path(recording.stem())}`, authStore.bearer());
    if (!response.ok()) return undefined;
    const doc: ArticleDoc = this.parseArticle(response.text);
    if (!doc.owner) doc.owner = await this.ownerScope();
    return doc;
  }

  async ownerScope(): Promise<string> {
    const token: string = authStore.bearer();
    if (token === this.cachedScopeToken && this.cachedScope.length > 0) return this.cachedScope;
    try {
      const response: HttpResponse = await httpClient.get(`${Api.FILES}/whoami`, token);
      if (!response.ok()) return '';
      const scope: string = ((JSON.parse(response.text) as WhoamiResponse).scope ?? '').trim();
      if (scope.length > 0) {
        this.cachedScopeToken = token; this.cachedScope = scope.endsWith('/') ? scope : `${scope}/`;
      }
      return this.cachedScope;
    } catch (_) { return ''; }
  }

  private parseArticle(text: string): ArticleDoc {
    const wire: ArticleDocWire = JSON.parse(text) as ArticleDocWire;
    const articles = wire.articles ?? (wire.body !== undefined ? [{ title: wire.title || '(无题)', body: wire.body }] : []);
    return { id: wire.id, transcript: wire.transcript, articles: articles, tags: wire.tags ?? [],
      questions: (wire.questions ?? []).filter((question) => Boolean(question.id && question.text)),
      photos: wire.photos ?? [], owner: wire.owner };
  }

  async saveArticle(recording: Recording, doc: ArticleDoc): Promise<boolean> {
    const response: HttpResponse = await httpClient.putJson(`${Api.FILES}/articles/${Api.path(recording.stem())}`, authStore.bearer(), doc);
    return response.ok();
  }

  async delete(recording: Recording): Promise<boolean> {
    const response: HttpResponse = await httpClient.delete(`${Api.FILES}/file/${Api.path(recording.name)}`, authStore.bearer());
    await Promise.all([
      httpClient.delete(`${Api.FILES}/file/${Api.path(recording.articleKey())}`, authStore.bearer()),
      httpClient.delete(`${Api.FILES}/file/${Api.path(recording.srtKey())}`, authStore.bearer()),
      httpClient.delete(`${Api.FILES}/file/${Api.path(recording.emptyKey())}`, authStore.bearer()),
      httpClient.delete(`${Api.FILES}/file/${Api.path(recording.tagsKey())}`, authStore.bearer())
    ]);
    return response.ok();
  }

  async deleteAccount(): Promise<boolean> {
    const response: HttpResponse = await httpClient.postJson(`${Api.FILES}/account/delete`, authStore.bearer());
    return response.ok();
  }

  async deleteArticle(recording: Recording): Promise<boolean> {
    const response: HttpResponse = await httpClient.delete(`${Api.FILES}/file/${Api.path(recording.articleKey())}`, authStore.bearer());
    await Promise.all([
      httpClient.delete(`${Api.FILES}/file/${Api.path(recording.srtKey())}`, authStore.bearer()),
      httpClient.delete(`${Api.FILES}/file/${Api.path(recording.emptyKey())}`, authStore.bearer()),
      httpClient.delete(`${Api.FILES}/file/${Api.path(recording.tagsKey())}`, authStore.bearer())
    ]);
    return response.ok() || response.code === 404;
  }

  async remine(recording: Recording, styleVersion?: number): Promise<boolean> {
    const response: HttpResponse = await httpClient.postJson(`${Api.AGENT}/restyle`, authStore.bearer(),
      new StemRequest(recording.stem(), styleVersion), 300000);
    return response.ok();
  }

  async versionHistory(recording: Recording): Promise<ArticleHistory> {
    const response: HttpResponse = await httpClient.get(
      `${Api.FILES}/articles/${Api.path(recording.stem())}/history`, authStore.bearer());
    if (!response.ok()) return new ArticleHistory();
    const history: ArticleHistory = JSON.parse(response.text) as ArticleHistory;
    history.versions = history.versions ?? [];
    if (history.versions.length > 0 && history.head === undefined) {
      history.head = history.versions[history.versions.length - 1].v;
    }
    return history;
  }

  async patchHead(recording: Recording, head: number): Promise<boolean> {
    return (await httpClient.patchJson(`${Api.FILES}/articles/${Api.path(recording.stem())}/head`,
      authStore.bearer(), new HeadRequest(head))).ok();
  }

  async patchQuestion(recording: Recording, id: string, status: string): Promise<boolean> {
    return (await httpClient.patchJson(`${Api.FILES}/articles/${Api.path(recording.stem())}/question`,
      authStore.bearer(), new QuestionRequest(id, status))).ok();
  }

  articleFromVersion(current: ArticleDoc, version: ArticleVersion): ArticleDoc {
    return {
      id: current.id,
      transcript: current.transcript,
      articles: version.articles ?? [],
      tags: current.tags,
      questions: current.questions,
      photos: current.photos,
      owner: current.owner
    };
  }

  async download(key: string): Promise<ArrayBuffer | undefined> {
    const response = await httpClient.getBytes(`${Api.FILES}/download/${Api.path(key)}`, authStore.bearer());
    return response.ok() ? response.data : undefined;
  }

  async shareUrl(recording: Recording, articleIndex: number): Promise<string> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/share/${Api.path(recording.articleKey())}`, authStore.bearer());
    if (!response.ok()) return '';
    const url: string = (JSON.parse(response.text) as ShareResponse).url ?? '';
    return url.length > 0 ? `${url}?s=${articleIndex}` : '';
  }

  async resolveShareLink(id: string): Promise<ShareLinkTarget | undefined> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/link/${Api.path(id)}`, authStore.bearer());
    if (!response.ok()) return undefined;
    try {
      const wire: LinkTargetWire = JSON.parse(response.text) as LinkTargetWire;
      const doc: ArticleDoc | undefined = wire.articles ? {
        transcript: wire.transcript, articles: wire.articles, photos: wire.photos, owner: wire.owner
      } : undefined;
      return new ShareLinkTarget(wire.type ?? '', wire.owner ?? '', wire.stem ?? '', wire.title ?? '', doc);
    } catch (_) { return undefined; }
  }

  async publishWechat(recording: Recording): Promise<HttpResponse> {
    return httpClient.postJson(`${Api.FILES}/wechat/${Api.path(recording.articleKey())}`, authStore.bearer());
  }

  async xhsPack(recording: Recording): Promise<XhsPack | undefined> {
    const response: HttpResponse = await httpClient.postJson(`${Api.AGENT}/xhs-pack`, authStore.bearer(),
      new StemRequest(recording.stem()), 120000);
    if (!response.ok()) return undefined;
    const wire: XhsPackWire = JSON.parse(response.text) as XhsPackWire;
    return new XhsPack(wire.title ?? '', wire.body ?? '', wire.tags ?? [], wire.photoKeys ?? []);
  }
}

export const libraryStore: LibraryStore = new LibraryStore();
