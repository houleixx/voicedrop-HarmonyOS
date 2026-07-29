import { RecordingName } from '../core/RecordingName';

export interface RecordingRowPayload {
  name: string;
  uploaded?: string;
  hasArticles?: boolean;
  isEmpty?: boolean;
  hasTags?: boolean;
  title?: string;
  tags?: string[];
  phase?: string;
  blockReason?: string;
}

export class Recording {
  name: string = '';
  uploaded: string = '';
  hasArticles: boolean = false;
  isEmpty: boolean = false;
  hasTags: boolean = false;
  title: string = '';
  tags: string[] = [];
  phase: string = '';
  blockReason: string = '';
  saving: boolean = false;
  uploading: boolean = false;

  constructor(payload?: RecordingRowPayload) {
    if (payload) {
      this.name = payload.name;
      this.uploaded = payload.uploaded ?? '';
      this.hasArticles = payload.hasArticles ?? false;
      this.isEmpty = payload.isEmpty ?? false;
      this.hasTags = payload.hasTags ?? false;
      this.title = payload.title ?? '';
      this.tags = payload.tags ?? [];
      this.phase = payload.phase ?? '';
      this.blockReason = payload.blockReason ?? '';
    }
  }

  stem(): string { return RecordingName.stem(this.name); }
  articleKey(): string { return `articles/${this.stem()}.json`; }
  srtKey(): string { return `articles/${this.stem()}.srt`; }
  emptyKey(): string { return `articles/${this.stem()}.empty`; }
  tagsKey(): string { return `articles/${this.stem()}.tags`; }
  rowTitle(): string { return this.title.length > 0 ? this.title : RecordingName.rowTitle(this.name); }
  durationLabel(): string { return RecordingName.parse(this.name)?.duration ?? ''; }
  statusLabel(): string {
    if (this.saving) return '正在保存';
    if (this.uploading) return '正在上传';
    if (this.hasArticles) return '已成文';
    if (this.isEmpty) return '无语音';
    if (this.phase === 'asr') return '听录音';
    if (this.phase === 'mining') return '挖文章';
    if (this.blockReason === 'too-long') return '录音过长';
    if (this.blockReason === 'no-credit') return '余额不足';
    return '待处理';
  }
}

export interface MinedArticle {
  title: string;
  body: string;
  style?: number;
  wechatMediaId?: string;
}

export interface FollowupQuestion {
  id: string;
  articleIndex?: number;
  text: string;
  status: string;
  createdAt?: number;
}

export interface ArticleDoc {
  id?: string;
  transcript?: string;
  articles: MinedArticle[];
  tags?: string[];
  questions?: FollowupQuestion[];
  photos?: string[];
  owner?: string;
}

export class ArticleVersion {
  v: number = 0;
  articles: MinedArticle[] = [];
  savedAt?: string;
  createdAt?: string;
  source?: string;
}

export class ArticleHistory {
  head: number = 0;
  versions: ArticleVersion[] = [];
}

export interface CommunityPost {
  shareId: string;
  title: string;
  excerpt: string;
  author: string;
  avatar?: string;
  createdAt?: string;
  likes: number;
  replies: number;
  liked?: boolean;
  articleKey?: string;
  doc?: ArticleDoc;
  replyTo?: string;
  owner?: string;
  kind?: string;
  promptCode?: string;
  appliesTo?: string[];
  mine?: boolean;
  preview?: string;
  articles?: MinedArticle[];
  body?: string;
  transcript?: string;
  photos?: string[];
  firstSharedAt?: number;
  sharedAt?: number;
  updatedAt?: number;
  count?: number;
  hasPhoto?: boolean;
  coverPhotoKey?: string;
  /** Runtime-only aspect ratio used by the community masonry layout. */
  coverAspectRatio?: number;
}
