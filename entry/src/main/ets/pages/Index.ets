import { common, Permissions } from '@kit.AbilityKit';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { FrameNode, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { ArticleBody, ArticleBlock } from '../core/ArticleBody';
import { Api } from '../core/Api';
import { PhotoLoadPolicy } from '../core/PhotoLoadPolicy';
import { LibraryCommandEvent, LibraryCommandFeedback, LibraryCommandGestureAction, LibraryCommandTarget, LibraryCommandTone, LibraryCommandUi } from '../core/LibraryCommandUi';
import { PromptNode, PromptTree } from '../core/PromptTree';
import { RecordingListUi } from '../core/RecordingListUi';
import { RecordingName } from '../core/RecordingName';
import { isRecordingTooShort } from '../core/RecordingPolicy';
import { normalizeAmplitude } from '../core/RecordingUi';
import { Recording, ArticleDoc, ArticleHistory, ArticleVersion, FollowupQuestion, MinedArticle, CommunityPost } from '../model/Models';
import { authStore } from '../data/AuthStore';
import { appPreferences } from '../data/AppPreferences';
import { libraryStore, ShareLinkTarget, XhsPack } from '../data/LibraryStore';
import { communityStore, CommunityShareResult, CommunityFeed, CommunityFeedState, CommunityFeedResult } from '../data/CommunityStore';
import { settingsStore, StyleSettings, StyleHistory, StyleVersion, WechatSettings, AppConfig } from '../data/SettingsStore';
import { CapturedPhoto, photoService, UploadedPhoto } from '../data/PhotoService';
import { usageStore, UsageBalance, UsageSummary, UsageSummaryRow, UsageEntry, UsageLedgerPage } from '../data/UsageStore';
import { promptStore } from '../data/PromptStore';
import { ExportManager } from '../data/ExportManager';
import { appUpdateService, HarmonyRelease, UpdateCheckResult } from '../data/AppUpdateService';
import { referralService, InviteLink } from '../data/ReferralService';
import { DeviceLinkPending, DeviceLinkStore } from '../data/DeviceLinkStore';
import { DeviceLinkCrypto } from '../data/DeviceLinkCrypto';
import { WechatLogin } from '../data/WechatLogin';
import { WechatCommunityShare } from '../data/WechatCommunityShare';
import { WechatAuthResult, WechatAuthStore } from '../data/WechatAuthStore';
import { shareCollectService } from '../share/ShareCollectService';
import { voiceRecorder } from '../audio/VoiceRecorder';
import { uploader } from '../audio/Uploader';
import { audioPlayback } from '../audio/AudioPlayback';
import { AsrDictation } from '../audio/AsrDictation';
import { RealtimeInterviewer } from '../audio/RealtimeInterviewer';
import { ArticleEditSession, EditAnchor, StatusSession, LibraryCommandSession, CommandRef } from '../net/AgentSocket';
import { AboutPage } from './AboutPage';
import { AccountPage } from './AccountPage';
import { AppPage } from './AppPage';
import { COMMUNITY_TERMS, SUPPORT_EMAIL } from '../core/CommunityTerms';
import { CommunityLikeState } from '../core/CommunityLikeState';
import { BlockedAuthorsPage } from './BlockedAuthorsPage';
import { PrivacyPolicyPage, PRIVACY_TEXT } from './PrivacyPolicyPage';
import { PromptSettingsPage } from './PromptSettingsPage';
import { SettingsPage, SettingsTarget } from './SettingsPage';
import { SharedArticlePage } from './SharedArticlePage';
import { StyleSettingsPage } from './StyleSettingsPage';
import { UsagePage } from './UsagePage';
import { WechatSettingsPage } from './WechatSettingsPage';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { PageHeader } from '../ui/PageHeader';
import { ClientReliability } from '../core/ClientReliability';
import { ArticlePhotoView } from '../components/ArticlePhotoView';
import { RecordingSession } from '../components/RecordingSession';

interface CommandMessage {
  type: string;
  id?: string;
  text?: string;
  message?: string;
  summary?: string;
  state?: string;
  stems?: string[];
}
interface StatusMessage {
  type?: string;
  pairingId?: string;
  code?: string;
  pubkey?: string;
  stem?: string;
  status?: string;
}
interface PreviewDeltaValue { a?: number; field?: string; text?: string; }
interface EditSocketMessage {
  type?: string;
  article?: ArticleDoc;
  doc?: ArticleDoc;
  items?: PreviewDeltaValue[];
  ok?: boolean;
  queue?: EditQueueState[];
}
interface EditQueueState { id?: string; status?: string; }
interface PendingCommunityShareValue { articleKey: string; replyTo?: string; createdAt?: number; }
class IncomingShareDraft {
  mime: string;
  uris: string[];
  text: string;
  title: string;
  constructor(mime: string, uris: string[], text: string, title: string) {
    this.mime = mime; this.uris = uris; this.text = text; this.title = title;
  }
}

@Entry
@Component
struct Index {
  @StorageLink('safeAreaTopPx') private safeAreaTopPx: number = 0;
  @StorageLink('safeAreaBottomPx') private safeAreaBottomPx: number = 0;
  @StorageLink('windowWidthPx') private windowWidthPx: number = 0;
  @StorageLink('shareSequence') @Watch('onShareSequence') private shareSequence: number = 0;
  @StorageLink('wechatSequence') @Watch('onWechatSequence') private wechatSequence: number = 0;
  @StorageLink('foregroundSequence') @Watch('onForegroundSequence') private foregroundSequence: number = 0;
  @State private tab: number = 0;
  @State private recordings: Recording[] = [];
  @State private deletedRecordingNames: string[] = [];
  @State private posts: CommunityPost[] = [];
  @State private communityRecommended: CommunityPost[] = [];
  @State private communityLatest: CommunityPost[] = [];
  @State private communityFilter: string = 'recommended';
  @State private selectedTag: string = '';
  @State private selected?: Recording = undefined;
  @State private deletingRecordingName: string = '';
  @State private openRecordingSwipeName: string = '';
  @State private recordingSwipeRevision: number = 0;
  @State private article?: ArticleDoc = undefined;
  @State private detailLoading: boolean = false;
  @State private detailLoadError: string = '';
  @State private showDetailMenu: boolean = false;
  @State private loading: boolean = true;
  @State private libraryRefreshing: boolean = false;
  @State private communityRefreshing: boolean = false;
  @State private errorText: string = '';
  @State private recording: boolean = false;
  @State private recordingTransitioning: boolean = false;
  @State private recordingSeconds: number = 0;
  @State private recordingLevel: number = 0;
  @State private interviewActive: boolean = false;
  @State private interviewStatus: string = '';
  @State private capturedPhotos: CapturedPhoto[] = [];
  @State private showPrivacy: boolean = false;
  @State private consentPolicyExpanded: boolean = false;
  @State private editText: string = '';
  @State private selectedArticle: number = 0;
  @State private playing: boolean = false;
  @State private playbackLoading: boolean = false;
  @State private xhsPreparing: boolean = false;
  @State private playbackProgress: number = 0;
  @State private playbackDuration: number = 0;
  @State private history: ArticleHistory = new ArticleHistory();
  @State private communityShareId: string = '';
  @State private selectedPost?: CommunityPost = undefined;
  @State private selectedReplyParent?: CommunityPost = undefined;
  @State private communityReplies: CommunityPost[] = [];
  @State private communityDetailLoading: boolean = false;
  @State private communityDetailError: string = '';
  @State private postFed: boolean = false;
  @State private postLiked: boolean = false;
  @State private postFeedCount: number = 0;
  @State private postFeeding: boolean = false;
  @State private showCommunityMenu: boolean = false;
  @State private promptImporting: boolean = false;
  @State private wechatLoggedIn: boolean = false;
  @State private pendingReplyTarget: string = '';
  @State private showPromptMenu: boolean = false;
  @State private promptMenuNodes: PromptNode[] = [];
  @State private promptMenuTitle: string = '';
  @State private promptMenuNested: boolean = false;
  @State private promptTargetKind: string = '';
  @State private promptTargetValue: string = '';
  @State private promptTargetIndex: number = -1;
  @State private libraryCommand: string = '';
  @State private commandState: string = '';
  @State private commandStateTone: LibraryCommandTone = LibraryCommandTone.Hidden;
  @State private commandTalking: boolean = false;
  @State private commandCanceled: boolean = false;
  @State private commandTranscriptText: string = '';
  @State private showDirectEditor: boolean = false;
  @State private directTitle: string = '';
  @State private directBody: string = '';
  @State private showHistoryBrowser: boolean = false;
  @State private dictating: boolean = false;
  @State private dictationState: string = '';
  @State private holdEditPressed: boolean = false;
  @State private holdEditCanceled: boolean = false;
  @State private exporting: boolean = false;
  @State private showStyleRewrite: boolean = false;
  @State private styleRewriteHistory: StyleHistory = new StyleHistory();
  @State private restylePreviewActive: boolean = false;
  @State private restylePreviewText: string = '';
  @State private showArticleLines: boolean = false;
  @State private promptImportCode: string = '';
  @State private showIncomingShare: boolean = false;
  @State private incomingShareTitle: string = '';
  @State private incomingShareDescription: string = '';
  @State private incomingShareExcerpt: string = '';
  @State private importingShare: boolean = false;
  @State private appVersion: string = '0.1.0';
  @State private checkingUpdate: boolean = false;
  @State private autoShareCommunity: boolean = false;
  @State private savingAutoShare: boolean = false;
  @State private preparingInvite: boolean = false;
  @State private sharedArticle?: ArticleDoc = undefined;
  @State private sharedArticleIndex: number = 0;
  @State private generatedPhotoKeys: string[] = [];
  @State private processingPhotoKeys: string[] = [];
  @State private thumbnailFallbackKeys: string[] = [];
  private context?: common.UIAbilityContext;
  private timer: number = -1;
  private recordingMeterSampling: boolean = false;
  private statusSession?: StatusSession;
  private editSession?: ArticleEditSession;
  private pendingPhotoRefreshKeys: string[] = [];
  private commandSession?: LibraryCommandSession;
  private dictation?: AsrDictation;
  private commandHoldPressed: boolean = false;
  private commandLongPressed: boolean = false;
  private commandHoldStartY: number = 0;
  private commandHoldTimer: number = -1;
  private commandRecognizing: boolean = false;
  private commandFinalized: boolean = false;
  private interviewer?: RealtimeInterviewer;
  private dictationTarget: string = '';
  private dictationPrefix: string = '';
  private holdEditStartY: number = 0;
  private holdEditOriginalText: string = '';
  private holdEditShouldSend: boolean = false;
  private processingReplies: Set<string> = new Set<string>();
  private pendingLinkId: string = '';
  private pendingLinkPubkey: string = '';
  private linkDialogShowing: boolean = false;
  private settledLinkIds: Set<string> = new Set<string>();
  private restyleTitles: Map<number, string> = new Map<number, string>();
  private restyleBodies: Map<number, string> = new Map<number, string>();
  private incomingShare?: IncomingShareDraft;
  private defaultRecordTag: string = '';
  private recordingDetailOpenBlockedUntil: number = 0;
  private detailLoadSequence: number = 0;
  private initialized: boolean = false;
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();

  private navigateTo(target: AppPage): void {
    if (target === 'home') {
      this.navigateHome();
      return;
    }
    const paths: string[] = this.pathStack.getAllPathName();
    if (paths.length > 0 && paths[paths.length - 1] === target) return;
    this.pathStack.pushPath({ name: target });
  }

  private navigateBack(): void {
    if (this.pathStack.size() > 0) this.pathStack.pop();
  }

  private navigateHome(animated: boolean = true): void {
    this.pathStack.clear(animated);
  }

  private isCommunityDetailActive(): boolean {
    const paths: string[] = this.pathStack.getAllPathName();
    return paths.length > 0 && paths[paths.length - 1] === 'communityDetail';
  }

  private handleDestinationHidden(routeName: string): void {
    if (routeName === 'detail') {
      this.showDetailMenu = false;
      this.showPromptMenu = false;
      this.showDirectEditor = false;
      this.showHistoryBrowser = false;
      this.showStyleRewrite = false;
      this.editSession?.close();
      audioPlayback.stop().catch(() => {});
    }
    if (routeName === 'communityDetail') this.showCommunityMenu = false;
  }

  private safeAreaTop(): number {
    return this.getUIContext().px2vp(this.safeAreaTopPx);
  }

  private safeAreaBottom(): number {
    return this.getUIContext().px2vp(this.safeAreaBottomPx);
  }

  aboutToAppear(): void {
    this.getUIContext().getFont().registerFont({
      familyName: 'remixicon',
      familySrc: $rawfile('remixicon.ttf')
    });
    this.initialize();
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) clearInterval(this.timer);
    if (this.commandHoldTimer >= 0) clearTimeout(this.commandHoldTimer);
    this.commandHoldTimer = -1;
    this.statusSession?.close();
    this.editSession?.close();
    this.commandSession?.close();
    this.dictation?.stop();
    this.interviewer?.stop();
    audioPlayback.stop().catch(() => {});
  }

  private async initialize(): Promise<void> {
    this.context = getContext(this) as common.UIAbilityContext;
    await appPreferences.initialize(this.context);
    this.showPrivacy = !appPreferences.privacyAccepted();
    if (!this.showPrivacy) await this.activateBusiness();
  }

  private async activateBusiness(): Promise<void> {
    if (this.initialized || !this.context) return;
    await authStore.initialize(this.context);
    libraryStore.initialize(this.context);
    this.wechatLoggedIn = authStore.isWechatAuthenticated();
    await promptStore.initialize(this.context);
    await this.handleWechatCallback();
    voiceRecorder.initialize(this.context);
    uploader.initialize(this.context);
    photoService.initialize(this.context);
    this.restoreCachedHomeSnapshots();
    photoService.retryPending().then(async () => {
      // Uploading an audio file immediately kicks the miner. Do not let a recovered
      // recording overtake its session photos or the generated article will miss them.
      if (photoService.pendingCount() > 0) {
        promptAction.showToast({ message: '照片等待续传，关联录音已保留' });
        return;
      }
      const count: number = await uploader.drainPending();
      if (count > 0) { promptAction.showToast({ message: `已续传 ${count} 条录音` }); this.refreshLibrary(); }
    }).catch(() => {});
    audioPlayback.initialize(this.context);
    audioPlayback.setProgressHandler((playing: boolean, progress: number, duration: number) => {
      this.playing = playing;
      this.playbackProgress = progress;
      this.playbackDuration = duration;
    });
    this.appVersion = await appUpdateService.currentVersion();
    this.loadAppConfig().catch(() => {});
    await this.handleSharedWant();
    await this.refreshLibrary(this.recordings.length === 0);
    await this.handleDeepLink();
    this.runReferralOnLaunch().catch(() => {});
    this.startAgentSessions();
    this.recoverPendingLink().catch(() => {});
    if (appPreferences.shouldCheckUpdate(this.appVersion)) this.checkForUpdate(false).catch(() => {});
    this.initialized = true;
  }

  private startAgentSessions(): void {
    this.statusSession = new StatusSession((message: string | ArrayBuffer) => {
      if (typeof message === 'string') this.handleStatusMessage(message);
    });
    this.statusSession.connect().catch(() => {});
    this.commandSession = new LibraryCommandSession((message: string | ArrayBuffer) => {
      if (typeof message === 'string') this.handleCommandMessage(message);
    }, () => {});
    this.commandSession.setRefs(this.currentCommandRefs());
    this.commandSession.connect().catch(() => {});
  }

  private reconnectAgentSessions(): void {
    this.statusSession?.close();
    this.editSession?.close();
    this.commandSession?.close();
    this.statusSession = undefined;
    this.editSession = undefined;
    this.commandSession = undefined;
    this.applyCommandFeedback(new LibraryCommandFeedback());
    this.startAgentSessions();
  }

  private async applyAccountIdentityChange(clearPendingQueues: boolean): Promise<void> {
    if (clearPendingQueues) {
      await appPreferences.clearAccountQueues(this.recordings.map((recording: Recording) => recording.name));
    }
    this.recordings = [];
    this.posts = []; this.communityRecommended = []; this.communityLatest = [];
    libraryStore.clearArticleSnapshots();
    this.reconnectAgentSessions();
    this.navigateHome();
    await this.refreshLibrary();
  }

  private onForegroundSequence(): void {
    if (!this.initialized || this.pathStack.size() > 0) return;
    this.refreshLibrary(this.recordings.length === 0).catch(() => {});
    if (this.tab === 1) this.refreshCommunity().catch(() => {});
  }

  private onWechatSequence(): void {
    if (!this.initialized) return;
    this.handleWechatCallback().catch((error: Error) => promptAction.showToast({ message: `微信登录失败：${error.message}` }));
  }

  private async startWechatLogin(): Promise<void> {
    if (!this.context) return;
    try {
      if (!await WechatLogin.start(this.context)) promptAction.showToast({ message: '无法打开微信，请确认已安装微信' });
    } catch (error) { promptAction.showToast({ message: `无法打开微信：${String(error)}` }); }
  }

  private async handleWechatCallback(): Promise<void> {
    const code: string = String(AppStorage.get<string>('wechatCode') ?? '');
    const callbackMessage: string = String(AppStorage.get<string>('wechatMessage') ?? '');
    if (code.length === 0) {
      if (callbackMessage.length > 0) {
        AppStorage.setOrCreate<string>('wechatMessage', ''); promptAction.showToast({ message: callbackMessage });
      }
      return;
    }
    AppStorage.setOrCreate<string>('wechatCode', ''); AppStorage.setOrCreate<string>('wechatMessage', '');
    const result: WechatAuthResult = await WechatAuthStore.exchange(code);
    if (!result.ok) {
      promptAction.showToast({ message: `微信登录失败：${result.detail || result.error}` }); return;
    }
    const previousBearer: string = authStore.bearer();
    const anonId: string = await DeviceLinkCrypto.accountId(authStore.anonymousBearer());
    const switchingAccount: boolean = result.scope !== `users/${anonId}/`;
    let switched: boolean = false;
    if (switchingAccount) {
      const confirmation = await promptAction.showDialog({ title: '该微信已关联另一个云端空间',
        message: '是否切换到微信已绑定的云端空间？当前匿名空间会保存在本机，退出微信登录后自动恢复。',
        buttons: [{ text: '保留当前空间', color: '#666666' }, { text: '切换到微信空间', color: '#D92D20' }] });
      if (confirmation.index !== 1) return;
      switched = await authStore.switchToWechatAccount(result.session);
    } else switched = await authStore.storeSession(result.session);
    if (!switched) { promptAction.showToast({ message: '微信登录失败：无效会话' }); return; }
    if (ClientReliability.accountIdentityChanged(previousBearer, authStore.bearer())) {
      await this.applyAccountIdentityChange(switchingAccount);
    }
    this.wechatLoggedIn = true; this.navigateHome();
    promptAction.showToast({ message: result.scope === `users/${anonId}/` ? '已登录微信' : '已切换到微信空间' });
    await this.refreshLibrary();
  }

  private async handleStatusMessage(raw: string): Promise<void> {
    try {
      const message: StatusMessage = JSON.parse(raw) as StatusMessage;
      if (message.type === 'link_request' && message.pairingId && message.code && message.pubkey) {
        await this.presentLinkRequest(new DeviceLinkPending(message.pairingId, message.code, message.pubkey));
        return;
      }
      if (message.type === 'link_release' && message.pairingId) {
        await this.releaseLink(message.pairingId); return;
      }
      if (message.type === 'status_update' && message.stem && message.status) {
        await this.updateRecordingStatus(message.stem, message.status);
      }
    } catch (_) {}
  }

  private async updateRecordingStatus(stem: string, status: string): Promise<void> {
    const target: Recording | undefined = this.recordings.find(
      (recording: Recording) => recording.stem() === stem);
    if (!target) return;
    this.recordings = RecordingListUi.applyStatus(this.recordings, stem, status);
    this.commandSession?.setRefs(this.currentCommandRefs());
    libraryStore.storeRecordingsSnapshot(this.recordings);
    if (status === 'ready') {
      await this.loadReadyRecordingMetadata(stem);
      this.publishReadyReplies();
    }
  }

  private async loadReadyRecordingMetadata(stem: string): Promise<void> {
    const retryDelays: number[] = [0, 400, 1200, 2400];
    for (const delay of retryDelays) {
      if (delay > 0) await new Promise<void>((resolve: () => void) => setTimeout(resolve, delay));
      const current: Recording | undefined = this.recordings.find(
        (recording: Recording) => recording.stem() === stem);
      if (!current || !current.hasArticles) return;
      const doc: ArticleDoc | undefined = await libraryStore.fetchArticle(current);
      const title: string = doc?.articles?.[0]?.title?.trim() ?? '';
      if (doc && title.length > 0) {
        this.recordings = RecordingListUi.applyArticleMetadata(this.recordings, stem, title, doc.tags ?? []);
        libraryStore.storeRecordingsSnapshot(this.recordings);
        this.commandSession?.setRefs(this.currentCommandRefs());
        return;
      }
    }
    await this.refreshLibrary(false, false);
  }

  private async presentLinkRequest(pending: DeviceLinkPending): Promise<void> {
    if (this.settledLinkIds.has(pending.pairingId) || this.linkDialogShowing) return;
    this.pendingLinkId = pending.pairingId; this.pendingLinkPubkey = pending.pubkey; this.linkDialogShowing = true;
    try {
      const result = await promptAction.showDialog({ title: '设备登录请求',
        message: `有新设备想登录当前账号。\n\n验证码：${pending.code}\n\n如果不是你本人操作，请选择“不是我”。`,
        buttons: [{ text: '不是我', color: '#D92D20' }, { text: '是我', color: '#16825D' }] });
      if (result.index === 0) {
        this.settledLinkIds.add(pending.pairingId); await DeviceLinkStore.reject(pending.pairingId);
        this.pendingLinkId = ''; this.pendingLinkPubkey = '';
      } else {
        promptAction.showToast({ message: `请在新设备输入验证码 ${pending.code}` });
        if (pending.released) await this.releaseLink(pending.pairingId);
      }
    } finally { this.linkDialogShowing = false; }
  }

  private async releaseLink(pairingId: string): Promise<void> {
    if (this.settledLinkIds.has(pairingId)) return;
    let publicKey: string = pairingId === this.pendingLinkId ? this.pendingLinkPubkey : '';
    if (!publicKey) {
      const pending: DeviceLinkPending | undefined = await DeviceLinkStore.pending();
      if (pending?.pairingId === pairingId) publicKey = pending.pubkey;
    }
    if (!publicKey) { promptAction.showToast({ message: '登录请求已失效' }); return; }
    this.settledLinkIds.add(pairingId);
    const ok: boolean = await DeviceLinkStore.complete(pairingId, publicKey);
    this.pendingLinkId = ''; this.pendingLinkPubkey = '';
    promptAction.showToast({ message: ok ? '已安全发送账号' : '账号发送失败' });
  }

  private async recoverPendingLink(): Promise<void> {
    const pending: DeviceLinkPending | undefined = await DeviceLinkStore.pending();
    if (!pending) return;
    await this.presentLinkRequest(pending);
  }

  private onShareSequence(): void {
    if (!this.initialized) return;
    this.handleDeepLink().catch(() => {});
    this.handleSharedWant().catch(() => {});
    this.recoverPendingLink().catch(() => {});
  }

  private async handleDeepLink(): Promise<void> {
    const raw: string = AppStorage.get<string>('launchUri') ?? '';
    if (!raw) return;
    AppStorage.set<string>('launchUri', '');
    let route: string = ''; let value: string = '';
    if (raw.startsWith('voicedrop://')) {
      const rest: string = raw.substring('voicedrop://'.length); const queryAt: number = rest.indexOf('?');
      const clean: string = queryAt >= 0 ? rest.substring(0, queryAt) : rest;
      const slash: number = clean.indexOf('/'); route = (slash >= 0 ? clean.substring(0, slash) : clean).toLowerCase();
      value = slash >= 0 ? decodeURIComponent(clean.substring(slash + 1)) : '';
      if (route === 'prompt-import') value = this.queryValue(raw, 'code');
    } else if (/^https?:\/\/(www\.)?voicedrop\.cn\/?$/i.test(raw)) route = 'recordings';
    else {
      const inviteMatch: RegExpMatchArray | null = raw.match(/^https?:\/\/(?:www\.)?(?:voicedrop\.cn\/|jianshuo\.dev\/voicedrop\/)(?:i\/)([A-Za-z0-9_-]{6,16})(?:[?#].*)?$/i);
      if (inviteMatch) { route = 'invite'; value = inviteMatch[1]; }
      const promptMatch: RegExpMatchArray | null = raw.match(/^https?:\/\/(?:www\.)?(?:voicedrop\.cn\/|jianshuo\.dev\/voicedrop\/)([1-9][0-9]{6})(?:[?#].*)?$/i);
      if (!route && promptMatch) { route = 'prompt'; value = promptMatch[1]; }
      const shareMatch: RegExpMatchArray | null = raw.match(/^https?:\/\/(?:www\.)?(?:voicedrop\.cn\/|jianshuo\.dev\/voicedrop\/)([A-Za-z0-9_-]{6,16})(?:[?#].*)?$/i);
      if (!route && shareMatch && !['privacy', 'welcome', 'help'].includes(shareMatch[1].toLowerCase())) {
        route = 'share'; value = shareMatch[1];
      }
      if (!route && /^https?:\/\/(?:www\.)?(?:voicedrop\.cn\/|jianshuo\.dev\/voicedrop(?:\/|$))/i.test(raw)) route = 'web';
    }
    if (!route || route === 'recordings' || route === 'home') { this.navigateHome(); this.tab = 0; return; }
    if (route === 'community') { this.navigateHome(); this.tab = 1; await this.refreshCommunity(); return; }
    if (route === 'settings' || route === 'setting') { this.navigateTo('settings'); return; }
    if (route === 'usage' || route === 'billing') { this.navigateTo('usage'); return; }
    if (route === 'prompt' || route === 'prompt-import') {
      if (/^[1-9][0-9]{6}$/.test(value)) { this.promptImportCode = value; this.navigateTo('prompts'); }
      return;
    }
    if (route === 'link') { await this.recoverPendingLink(); return; }
    if ((route === 'i' || route === 'invite') && /^[A-Za-z0-9_-]{6,16}$/.test(value)) {
      await this.claimReferral('link', value); this.navigateHome(); this.tab = 0; return;
    }
    if (route === 'share' && value) { await this.openShareLink(value, raw); return; }
    if (route === 'web') { await this.openExternalUrl(raw); return; }
    if (route === 'article' && value) {
      const recording: Recording | undefined = this.recordings.find((item: Recording) => item.stem() === value);
      if (recording) await this.openRecording(recording); else promptAction.showToast({ message: '没有找到这篇文章' });
      return;
    }
    if (route === 'record' && !this.recording) {
      this.defaultRecordTag = this.queryValue(raw, 'tag'); this.selectedTag = '';
      this.navigateHome(); this.tab = 0; await this.toggleRecording();
    }
  }

  private queryValue(raw: string, name: string): string {
    const queryAt: number = raw.indexOf('?'); if (queryAt < 0) return '';
    const query: string = raw.substring(queryAt + 1).split('#')[0];
    for (const part of query.split('&')) {
      const equal: number = part.indexOf('='); const key: string = equal < 0 ? part : part.substring(0, equal);
      if (key === name) {
        try { return decodeURIComponent(equal < 0 ? '' : part.substring(equal + 1)).trim(); } catch (_) { return ''; }
      }
    }
    return '';
  }

  private async handleSharedWant(): Promise<void> {
    if (!authStore.bearer()) return;
    const text: string = AppStorage.get<string>('sharedText') ?? '';
    const title: string = AppStorage.get<string>('sharedTitle') ?? '';
    const mime: string = AppStorage.get<string>('sharedMime') ?? '';
    const rawUris: string = AppStorage.get<string>('sharedUris') ?? '[]';
    let uris: string[] = [];
    try { uris = JSON.parse(rawUris) as string[]; } catch (_) {}
    if (text.trim().length === 0 && uris.length === 0) return;
    AppStorage.set<string>('sharedText', '');
    AppStorage.set<string>('sharedTitle', '');
    AppStorage.set<string>('sharedMime', '');
    AppStorage.set<string>('sharedUris', '[]');
    const draft: IncomingShareDraft = new IncomingShareDraft(mime, uris.slice(), text, title);
    this.incomingShare = draft;
    const kind: string = this.incomingShareKind(draft);
    if (kind === 'audio') {
      this.incomingShareTitle = '从这段录音成文';
      this.incomingShareDescription = '转写和成文会一步完成，确认后开始上传音频。';
    } else if (kind === 'image') {
      this.incomingShareTitle = '看图写一篇';
      this.incomingShareDescription = `${uris.length} 张图片，确认后开始上传并生成文章。`;
    } else {
      this.incomingShareTitle = '加入风格数据集';
      const count: number = text.trim().length;
      const source: string = uris.length > 0 ? `${uris.length} 个文档${count > 0 ? '和分享文字' : ''}` : `${count} 字分享文字`;
      this.incomingShareDescription = `${source}将作为写作语料；可读取内容少于 300 字时不会开始提取文风。`;
    }
    this.incomingShareExcerpt = this.incomingSharePreview(draft);
    this.showIncomingShare = true;
  }

  private incomingShareKind(draft: IncomingShareDraft): string {
    const lower: string = draft.mime.toLowerCase();
    if (lower.startsWith('audio/') || (draft.uris.length > 0 && /\.(m4a|mp3|aac|wav|flac|ogg)(\?|$)/i.test(draft.uris[0]))) return 'audio';
    if (lower.startsWith('image/') || (draft.uris.length > 0 && /\.(jpe?g|png|webp|heic|gif)(\?|$)/i.test(draft.uris[0]))) return 'image';
    return 'dataset';
  }

  private incomingSharePreview(draft: IncomingShareDraft): string {
    const text: string = draft.text.trim();
    if (text.length > 0) return text.length > 220 ? `${text.substring(0, 220)}…` : text;
    if (draft.uris.length > 0) {
      return draft.uris.slice(0, 4).map((uri: string) => {
        const clean: string = uri.split('?')[0];
        try { return decodeURIComponent(clean.substring(clean.lastIndexOf('/') + 1)) || '分享文件'; }
        catch (_) { return clean.substring(clean.lastIndexOf('/') + 1) || '分享文件'; }
      }).join('\n');
    }
    return draft.title;
  }

  private cancelIncomingShare(): void {
    if (this.importingShare) return;
    this.showIncomingShare = false;
    this.incomingShare = undefined;
    this.incomingShareExcerpt = '';
  }

  private async confirmIncomingShare(): Promise<void> {
    const draft: IncomingShareDraft | undefined = this.incomingShare;
    if (!draft || this.importingShare) return;
    this.importingShare = true;
    try {
      const result = await shareCollectService.collectIncoming(draft.mime, draft.uris, draft.text, draft.title);
      promptAction.showToast({ message: result.message });
      if (result.ok) {
        this.showIncomingShare = false;
        this.incomingShare = undefined;
        await this.refreshLibrary();
      }
    } catch (error) {
      promptAction.showToast({ message: `分享导入失败：${String(error)}` });
    } finally { this.importingShare = false; }
  }

  private async exportAllData(): Promise<void> {
    if (!this.context || this.exporting) return;
    this.exporting = true;
    try {
      const path: string = await new ExportManager(this.context).create(this.recordings);
      const name: string = path.substring(path.lastIndexOf('/') + 1);
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [name]; options.fileSuffixChoices = ['ZIP 压缩包|.zip'];
      const uris: string[] = await new picker.DocumentViewPicker(this.context).save(options);
      if (uris.length === 0) { promptAction.showToast({ message: '已取消保存' }); return; }
      const destination: fs.File = fs.openSync(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        fs.copyFileSync(path, destination.fd);
      } finally {
        fs.closeSync(destination);
      }
      promptAction.showToast({ message: '录音、文章、字幕和图片已导出' });
    } catch (error) { promptAction.showToast({ message: `导出失败：${String(error)}` }); }
    finally { this.exporting = false; }
  }

  private async checkForUpdate(manual: boolean): Promise<void> {
    if (this.checkingUpdate) {
      if (manual) promptAction.showToast({ message: '正在检查更新…' });
      return;
    }
    this.checkingUpdate = true;
    if (manual) promptAction.showToast({ message: '正在检查更新…' });
    try {
      const result: UpdateCheckResult = await appUpdateService.check();
      this.appVersion = result.currentVersion;
      await appPreferences.markUpdateChecked(result.currentVersion);
      if (result.status === 'no_update') {
        if (manual) promptAction.showToast({ message: '已是最新版本' });
        return;
      }
      if (result.status === 'unavailable') {
        if (manual) promptAction.showToast({ message: 'HarmonyOS 更新渠道尚未发布' });
        return;
      }
      if (result.status === 'rate_limited') {
        if (manual) promptAction.showToast({ message: '检查太频繁，请稍后再试' });
        return;
      }
      const release: HarmonyRelease | undefined = result.release;
      if (result.status !== 'available' || !release) {
        if (manual) promptAction.showToast({ message: '检查更新失败' });
        return;
      }
      if (appPreferences.ignoredUpdateTag() === release.tag) {
        if (manual) promptAction.showToast({ message: `已忽略此版本：${release.tag}` });
        return;
      }
      const size: string = release.size > 0 ? `\n签名 HAP 约 ${this.formatFileSize(release.size)}` : '';
      const notes: string = release.notes.trim().length > 0 ? `\n\n${release.notes.trim().substring(0, 500)}` : '';
      const choice = await promptAction.showDialog({ title: '发现 HarmonyOS 新版本',
        message: `${release.tag}\n当前版本 ${result.currentVersion}${size}${notes}\n\n将打开发布页，由系统完成下载与安装。`,
        buttons: [{ text: '忽略此版本', color: '#666666' }, { text: '打开发布页', color: '#16825D' }] });
      if (choice.index === 0) await appPreferences.ignoreUpdate(release.tag);
      else await this.openExternalUrl(release.pageUrl || release.downloadUrl);
    } catch (_) {
      if (manual) promptAction.showToast({ message: '检查更新失败' });
    } finally { this.checkingUpdate = false; }
  }

  private formatFileSize(bytes: number): string {
    if (bytes >= 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  }

  private async openExternalUrl(url: string): Promise<void> {
    if (!this.context || !/^https:\/\//i.test(url)) return;
    try {
      await this.context.startAbility({ action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'], uri: url });
    } catch (_) { promptAction.showToast({ message: '无法打开更新发布页' }); }
  }

  private async loadAppConfig(): Promise<void> {
    const config: AppConfig = await settingsStore.loadConfig();
    this.autoShareCommunity = config.autoShareCommunity ?? appPreferences.autoShareCommunity();
    await appPreferences.setBoolean('autoShareCommunity', this.autoShareCommunity);
  }

  private async setAutoShareCommunity(value: boolean): Promise<void> {
    if (this.savingAutoShare) return;
    const previous: boolean = this.autoShareCommunity;
    this.autoShareCommunity = value; this.savingAutoShare = true;
    try {
      if (!await settingsStore.saveConfig(value)) {
        this.autoShareCommunity = previous; promptAction.showToast({ message: '自动分享配置保存失败' }); return;
      }
      await appPreferences.setBoolean('autoShareCommunity', value);
      promptAction.showToast({ message: value ? '已开启自动分享到社区' : '已关闭自动分享到社区' });
    } catch (_) {
      this.autoShareCommunity = previous; promptAction.showToast({ message: '自动分享配置保存失败' });
    } finally { this.savingAutoShare = false; }
  }

  private async shareInvite(): Promise<void> {
    if (!this.context || this.preparingInvite) return;
    this.preparingInvite = true;
    promptAction.showToast({ message: '正在准备邀请链接…' });
    try {
      const invite: InviteLink | undefined = await referralService.inviteLink();
      if (!invite) { promptAction.showToast({ message: '邀请链接暂不可用' }); return; }
      const reward: string = invite.suanliInviter > 0 && invite.suanliInviter === invite.suanliFriend
        ? `，咱俩各得 ${invite.suanliInviter} 算力` : '';
      const text: string = `我在用 VoiceDrop，动动嘴就能写出好文章${reward}：${invite.url}`;
      await this.showTextShare(text, '邀请好友使用 VoiceDrop');
    } catch (_) { promptAction.showToast({ message: '无法打开系统分享面板' }); }
    finally { this.preparingInvite = false; }
  }

  private async showTextShare(text: string, title: string): Promise<void> {
    if (!this.context) throw new Error('ability context unavailable');
    const record: systemShare.SharedRecord = { utd: 'general.plain-text', content: text, title: title };
    const data: systemShare.SharedData = new systemShare.SharedData(record);
    await new systemShare.ShareController(data).show(this.context, {
      previewMode: systemShare.SharePreviewMode.DEFAULT
    });
  }

  private async openShareLink(id: string, fallbackUrl: string): Promise<void> {
    try {
      const target: ShareLinkTarget | undefined = await libraryStore.resolveShareLink(id);
      if (!target) { await this.openExternalUrl(fallbackUrl); return; }
      const own: Recording | undefined = target.stem.length > 0
        ? this.recordings.find((item: Recording) => item.stem() === target.stem) : undefined;
      if (own) { await this.openRecording(own); return; }
      if (target.type === 'community') {
        const post: CommunityPost | undefined = await communityStore.get(id);
        if (post) { await this.openCommunityPost(post); return; }
      }
      if (target.doc && target.doc.articles.length > 0) {
        this.sharedArticle = target.doc;
        const sectionMatch: RegExpMatchArray | null = fallbackUrl.match(/[?&]s=(\d+)/);
        this.sharedArticleIndex = Math.min(target.doc.articles.length - 1, Math.max(0, Number(sectionMatch?.[1] ?? 0)));
        this.navigateTo('shared'); return;
      }
      await this.openExternalUrl(fallbackUrl);
    } catch (_) { await this.openExternalUrl(fallbackUrl); }
  }

  private async claimReferral(source: string, token: string = ''): Promise<void> {
    if (appPreferences.referralDone() || !appPreferences.referralWithinWindow()) return;
    const reason: string = await referralService.claim(source, token);
    if (['attributed', 'not-new', 'device-used', 'disabled'].includes(reason)) await appPreferences.markReferralDone();
    if (reason === 'attributed') promptAction.showToast({ message: '邀请奖励已领取' });
  }

  private async runReferralOnLaunch(): Promise<void> {
    if (appPreferences.referralDone() || !appPreferences.referralWithinWindow()) return;
    await this.claimReferral('hello');
    if (appPreferences.referralDone()) return;
    try {
      const board = pasteboard.getSystemPasteboard();
      if (!board.hasDataSync()) return;
      const token: string = referralService.shareToken(board.getDataSync().getPrimaryText());
      if (token.length > 0) await this.claimReferral('clipboard', token);
    } catch (_) {}
  }

  private async refreshLibrary(showLoading: boolean = true, showFailure: boolean = showLoading): Promise<void> {
    if (showLoading) this.loading = true;
    this.errorText = '';
    try {
      const remote: Recording[] = await libraryStore.load();
      const staleDeleted: Recording[] = remote.filter((recording: Recording) =>
        this.deletedRecordingNames.includes(recording.name));
      this.recordings = RecordingListUi.afterRefresh(
        uploader.pendingRecordings(), remote, this.deletedRecordingNames,
        this.recordings.filter((recording: Recording) => recording.saving), this.recordings);
      this.commandSession?.setRefs(this.currentCommandRefs());
      staleDeleted.forEach((recording: Recording) => libraryStore.delete(recording).catch(() => false));
      libraryStore.enrichMissingMetadata(remote).then((changed: boolean) => {
        if (changed) {
          this.recordings = this.recordings.slice();
          libraryStore.storeRecordingsSnapshot(this.recordings);
        }
      }).catch(() => {});
      this.publishReadyReplies();
      this.drainPendingCommunityShare().catch(() => {});
    } catch (error) {
      this.errorText = ClientReliability.libraryErrorText(error as Object, this.recordings.length > 0, showFailure);
    } finally {
      if (showLoading) this.loading = false;
    }
  }

  private async refreshCommunity(showLoading: boolean = true): Promise<void> {
    if (showLoading) this.loading = true;
    try {
      const blocked: string[] = appPreferences.blockedAuthors();
      const feed: CommunityFeed = await communityStore.feed();
      this.applyCommunityFeed(feed, blocked);
    }
    catch (error) { this.errorText = `暂时无法加载社区：${String(error)}`; }
    finally { if (showLoading) this.loading = false; }
  }

  /** Show last successful account-scoped home data before the network refresh completes. */
  private restoreCachedHomeSnapshots(): void {
    const cachedRecordings: Recording[] = libraryStore.cachedRecordings();
    this.recordings = RecordingListUi.afterRefresh(
      uploader.pendingRecordings(), cachedRecordings, this.deletedRecordingNames);

    const blocked: string[] = appPreferences.blockedAuthors();
    const cachedFeed: CommunityFeed = communityStore.cachedFeed();
    this.applyCommunityFeed(cachedFeed, blocked);
    if (this.recordings.length > 0 || this.communityLatest.length > 0) this.loading = false;
  }

  private async pullRefreshLibrary(): Promise<void> {
    if (this.libraryRefreshing) return;
    this.libraryRefreshing = true;
    try {
      await photoService.retryPending();
      if (photoService.pendingCount() === 0) await uploader.drainPending();
      await this.refreshLibrary(false, true);
    }
    finally { this.libraryRefreshing = false; }
  }

  private async pullRefreshCommunity(): Promise<void> {
    if (this.communityRefreshing) return;
    this.communityRefreshing = true;
    try { await this.refreshCommunity(false); }
    finally { this.communityRefreshing = false; }
  }

  private updateCommunityFilter(): void {
    if (this.communityFilter === 'latest') this.posts = this.communityLatest.slice();
    else if (this.communityFilter === 'replies') this.posts = this.communityRecommended.filter((post: CommunityPost) => (post.replyTo ?? '').length > 0);
    else this.posts = this.communityRecommended.slice();
  }

  /**
   * Keep stable card instances while replacing a disk snapshot with its fresh network copy.
   * Image aspect ratios are runtime presentation state, so carry them across an unchanged cover.
   */
  private applyCommunityFeed(feed: CommunityFeed, blocked: string[]): void {
    const recommended: CommunityPost[] = this.mergeCommunityPresentation(
      feed.recommended.filter((post: CommunityPost) => !blocked.includes(post.author)), this.communityRecommended);
    const latest: CommunityPost[] = this.mergeCommunityPresentation(
      feed.latest.filter((post: CommunityPost) => !blocked.includes(post.author)), this.communityLatest);
    const visible: CommunityPost[] = this.communityFilter === 'latest' ? latest.slice() :
      (this.communityFilter === 'replies' ? recommended.filter((post: CommunityPost) => (post.replyTo ?? '').length > 0) : recommended.slice());
    if (!this.sameCommunityCards(this.communityRecommended, recommended)) this.communityRecommended = recommended;
    if (!this.sameCommunityCards(this.communityLatest, latest)) this.communityLatest = latest;
    if (!this.sameCommunityCards(this.posts, visible)) this.posts = visible;
  }

  private mergeCommunityPresentation(next: CommunityPost[], previous: CommunityPost[]): CommunityPost[] {
    const byId: Map<string, CommunityPost> = new Map<string, CommunityPost>();
    previous.forEach((post: CommunityPost) => byId.set(post.shareId, post));
    next.forEach((post: CommunityPost) => {
      const cached: CommunityPost | undefined = byId.get(post.shareId);
      if (cached && cached.coverPhotoKey === post.coverPhotoKey && post.coverAspectRatio === undefined) {
        post.coverAspectRatio = cached.coverAspectRatio;
      }
    });
    return next;
  }

  private sameCommunityCards(left: CommunityPost[], right: CommunityPost[]): boolean {
    if (left.length !== right.length) return false;
    return left.every((post: CommunityPost, index: number) => {
      const candidate: CommunityPost = right[index];
      return post.shareId === candidate.shareId && post.title === candidate.title && post.excerpt === candidate.excerpt &&
        post.author === candidate.author && post.likes === candidate.likes && post.replies === candidate.replies &&
        post.liked === candidate.liked && post.replyTo === candidate.replyTo && post.kind === candidate.kind &&
        post.coverPhotoKey === candidate.coverPhotoKey && post.updatedAt === candidate.updatedAt;
    });
  }

  private selectCommunityFilter(value: string): void {
    this.communityFilter = value; this.updateCommunityFilter();
  }

  private recordingStatusColor(recording: Recording): string {
    if (recording.isEmpty) return '#B9B2A8';
    return recording.hasArticles ? Theme.GREEN : Theme.AMBER;
  }

  private async openRecording(recording: Recording): Promise<void> {
    if (this.recording || this.recordingTransitioning || Date.now() < this.recordingDetailOpenBlockedUntil) return;
    if (recording.saving) {
      promptAction.showToast({ message: '录音正在保存，请稍候' });
      return;
    }
    this.selected = recording;
    this.generatedPhotoKeys = [];
    this.processingPhotoKeys = [];
    this.pendingPhotoRefreshKeys = [];
    const detailLoadSequence: number = ++this.detailLoadSequence;
    this.detailLoading = true;
    this.detailLoadError = '';
    this.showDetailMenu = false;
    this.article = recording.hasArticles ? libraryStore.cachedArticle(recording) : undefined;
    this.warmArticlePhotos(this.article);
    this.navigateTo('detail');
    this.selectedArticle = 0;
    try {
      if (recording.hasArticles) {
        const fresh: ArticleDoc | undefined = await libraryStore.fetchArticle(recording);
        if (fresh && this.selected?.stem() === recording.stem()) {
          this.article = fresh;
          this.warmArticlePhotos(fresh);
        }
        this.history = await libraryStore.versionHistory(recording);
        this.communityShareId = await communityStore.sharedShareId(recording.articleKey());
      } else {
        this.history = new ArticleHistory();
        this.communityShareId = '';
      }
    } catch (_) {
      if (!this.article && this.selected?.stem() === recording.stem()) {
        this.detailLoadError = '文章加载失败，请检查网络后重试';
      }
    } finally {
      if (detailLoadSequence === this.detailLoadSequence) this.detailLoading = false;
    }
    if (detailLoadSequence !== this.detailLoadSequence) return;
    this.editSession?.close();
    this.editSession = new ArticleEditSession(recording.stem(), (message: string | ArrayBuffer) => {
      if (typeof message === 'string') this.handleArticleEditMessage(message, recording);
    });
    this.editSession.connect().catch(() => {});
  }

  private handleArticleEditMessage(raw: string, recording: Recording): void {
    try {
      const message: EditSocketMessage = JSON.parse(raw) as EditSocketMessage;
      const updated: ArticleDoc | undefined = message.article ?? message.doc;
      if ((message.type === 'updated' || message.type === 'snapshot') && updated) {
        updated.owner = updated.owner ?? this.article?.owner;
        const introduced: string[] = PhotoLoadPolicy.introducedKeys(
          photoService.articlePhotoKeys(this.article), photoService.articlePhotoKeys(updated));
        this.generatedPhotoKeys = Array.from(new Set<string>(this.generatedPhotoKeys.concat(introduced)));
        const refreshKeys: string[] = message.type === 'updated' ? this.pendingPhotoRefreshKeys.slice() : [];
        if (message.type === 'updated') this.pendingPhotoRefreshKeys = [];
        this.processingPhotoKeys = PhotoLoadPolicy.processingKeys(this.processingPhotoKeys, refreshKeys);
        libraryStore.cacheArticle(recording, updated, refreshKeys).catch(() => {});
        this.article = updated;
        this.warmArticlePhotos(updated, refreshKeys);
      }
      const snapshotResolved: boolean = (message.queue ?? []).some((item: EditQueueState) =>
        item.status === 'done' || item.status === 'error');
      if (ClientReliability.isEditTerminal(message.type ?? '', snapshotResolved)) {
        this.refreshResolvedArticle(recording).catch(() => {});
      }
      if (message.type === 'preview-reset') {
        this.restyleTitles.clear(); this.restyleBodies.clear(); this.restylePreviewText = '正在重新整理新稿…'; return;
      }
      if (message.type === 'preview-delta') {
        for (const item of message.items ?? []) {
          const index: number = Math.max(0, item.a ?? 0); const text: string = item.text ?? '';
          if (item.field === 'title') this.restyleTitles.set(index, (this.restyleTitles.get(index) ?? '') + text);
          else if (item.field === 'body') this.restyleBodies.set(index, (this.restyleBodies.get(index) ?? '') + text);
        }
        this.renderRestylePreview(); return;
      }
      if (message.type === 'preview-done') this.finishRestyle(recording, message.ok ?? true);
    } catch (_) {}
  }

  private async refreshResolvedArticle(recording: Recording): Promise<void> {
    const fresh: ArticleDoc | undefined = await libraryStore.fetchArticle(recording);
    if (!fresh || this.selected?.stem() !== recording.stem()) return;
    fresh.owner = fresh.owner ?? this.article?.owner;
    this.article = fresh;
    this.warmArticlePhotos(fresh);
    this.selectedArticle = Math.min(this.selectedArticle, Math.max(0, fresh.articles.length - 1));
    this.history = await libraryStore.versionHistory(recording);
  }

  private renderRestylePreview(): void {
    const unique: Set<number> = new Set<number>();
    this.restyleTitles.forEach((_value: string, key: number) => unique.add(key));
    this.restyleBodies.forEach((_value: string, key: number) => unique.add(key));
    const indexes: number[] = [];
    unique.forEach((key: number) => indexes.push(key)); indexes.sort((a: number, b: number) => a - b);
    this.restylePreviewText = indexes.map((index: number) => {
      const title: string = this.restyleTitles.get(index) ?? ''; const body: string = this.restyleBodies.get(index) ?? '';
      return `${title}${title && body ? '\n\n' : ''}${body}`;
    }).join('\n\n').trim() || '正在整理新稿…';
  }

  private async openStyleRewrite(): Promise<void> {
    this.styleRewriteHistory = await settingsStore.loadStyleHistory(); this.showStyleRewrite = true;
  }

  private generatedStyleVersion(styleVersion: number): ArticleVersion | undefined {
    return this.history.versions.find((version: ArticleVersion) =>
      (version.articles ?? []).some((article: MinedArticle) => article.style === styleVersion));
  }

  private async requestStyleRewrite(styleVersion: number): Promise<void> {
    if (!this.selected) return;
    const generated: ArticleVersion | undefined = this.generatedStyleVersion(styleVersion);
    this.showStyleRewrite = false;
    if (generated) { await this.selectHistoryVersion(generated); promptAction.showToast({ message: `已切换到 v${styleVersion} 文风` }); return; }
    this.restyleTitles.clear(); this.restyleBodies.clear(); this.restylePreviewText = '新稿生成后会在这里实时出现'; this.restylePreviewActive = true;
    const ok: boolean = await libraryStore.remine(this.selected, styleVersion);
    if (this.restylePreviewActive) await this.finishRestyle(this.selected, ok);
  }

  private async finishRestyle(recording: Recording, ok: boolean): Promise<void> {
    if (!this.restylePreviewActive) return;
    this.restylePreviewActive = false; this.restyleTitles.clear(); this.restyleBodies.clear();
    if (!ok) { promptAction.showToast({ message: '换文风请求失败' }); return; }
    const updated: ArticleDoc | undefined = await libraryStore.fetchArticle(recording);
    if (updated) {
      this.article = updated; this.warmArticlePhotos(updated);
      this.selectedArticle = 0; this.history = await libraryStore.versionHistory(recording);
    }
    else promptAction.showToast({ message: '新文风文章暂不可读' });
  }

  private updateRecordingMeter(): void {
    if (!this.recording || this.recordingMeterSampling) return;
    this.recordingSeconds = voiceRecorder.elapsedSeconds();
    this.recordingMeterSampling = true;
    voiceRecorder.sampleAmplitude()
      .then((amplitude: number) => {
        if (this.recording) this.recordingLevel = normalizeAmplitude(amplitude);
      })
      .catch(() => {})
      .finally(() => this.recordingMeterSampling = false);
  }

  private async toggleRecording(): Promise<void> {
    if (!this.context || this.recordingTransitioning) return;
    if (this.recording) {
      this.beginRecordingStop();
      return;
    }
    this.recordingTransitioning = true;
    try {
      const manager = abilityAccessCtrl.createAtManager();
      const result = await manager.requestPermissionsFromUser(
        this.context, ['ohos.permission.MICROPHONE'] as Permissions[]);
      if (result.authResults[0] !== 0) {
        promptAction.showToast({ message: '需要麦克风权限才能录音' });
        return;
      }
      this.navigateHome(false);
      if (this.defaultRecordTag.length === 0 && this.selectedTag.length > 0) this.defaultRecordTag = this.selectedTag;
      await voiceRecorder.start();
      this.interviewer = undefined;
      this.interviewActive = false;
      this.interviewStatus = '';
      this.capturedPhotos = [];
      this.recordingSeconds = 0;
      this.recordingLevel = 0;
      this.recording = true;
      this.updateRecordingMeter();
      this.timer = setInterval(() => this.updateRecordingMeter(), 500);
    } catch (error) {
      promptAction.showToast({ message: `录音启动失败：${String(error)}` });
    } finally {
      this.recordingTransitioning = false;
    }
  }

  private beginRecordingStop(): void {
    this.recordingTransitioning = true;
    this.recordingDetailOpenBlockedUntil = Date.now() + 1200;
    if (this.timer >= 0) clearInterval(this.timer);
    this.timer = -1;

    const savingName: string = voiceRecorder.pendingRecordingName();
    const elapsedSeconds: number = voiceRecorder.elapsedSeconds();
    const photos: CapturedPhoto[] = this.capturedPhotos.slice();
    const replyTarget: string = this.pendingReplyTarget;
    const tag: string = this.defaultRecordTag;
    const interviewer: RealtimeInterviewer | undefined = this.interviewer;

    this.recordingLevel = 0;
    this.recordingMeterSampling = false;
    this.interviewer = undefined;
    this.interviewActive = false;
    this.interviewStatus = '';
    this.capturedPhotos = [];
    this.pendingReplyTarget = '';
    this.defaultRecordTag = '';

    if (!isRecordingTooShort(elapsedSeconds) && savingName.length > 0) {
      const saving: Recording = new Recording({ name: savingName });
      saving.saving = true;
      saving.tags = tag.length > 0 ? [tag] : [];
      this.recordings = RecordingListUi.beginSaving(this.recordings, saving);
    }
    this.finishRecordingStop(interviewer, savingName, photos, replyTarget, tag).catch(() => {});
  }

  private async finishRecordingStop(
    interviewer: RealtimeInterviewer | undefined,
    savingName: string,
    photos: CapturedPhoto[],
    replyTarget: string,
    tag: string
  ): Promise<void> {
    try {
      await interviewer?.stop();
      const path: string = await voiceRecorder.stop();
      if (isRecordingTooShort(voiceRecorder.durationSeconds())) {
        try { fs.unlinkSync(path); } catch (_) {}
        await photoService.discardCaptured(photos);
        this.recordings = RecordingListUi.cancelSaving(this.recordings, savingName);
        if (replyTarget.length > 0) {
          promptAction.showToast({ message: '时间太短，不足以产生文章' });
        } else {
          await promptAction.showDialog({
            title: '录音太短',
            message: '时间太短，不足以产生文章，这条录音不会上传。',
            buttons: [{ text: '知道了', color: '#D92D20' }]
          });
        }
        return;
      }

      const audioName: string = path.substring(path.lastIndexOf('/') + 1);
      if (replyTarget.length > 0) await appPreferences.savePendingReply(audioName, replyTarget);
      const tags: string[] = tag.length > 0 ? [tag] : [];
      uploader.prepare(path, tags);
      const pending: Recording = uploader.pendingRecordings().find(
        (recording: Recording) => recording.name === audioName) ?? new Recording({ name: audioName });
      pending.uploading = true;
      pending.tags = tags;
      this.recordings = RecordingListUi.finishSaving(this.recordings, savingName, pending);
      this.commandSession?.setRefs(this.currentCommandRefs());
      this.continueRecordingUpload(path, audioName, photos);
    } catch (error) {
      this.recordings = RecordingListUi.cancelSaving(this.recordings, savingName);
      await photoService.discardCaptured(photos);
      promptAction.showToast({ message: `录音保存失败：${String(error)}` });
    } finally {
      this.navigateHome(false);
      this.recordingDetailOpenBlockedUntil = Date.now() + 600;
      setTimeout(() => {
        this.recording = false;
        this.recordingTransitioning = false;
      }, 180);
    }
  }

  private async continueRecordingUpload(path: string, audioName: string, photos: CapturedPhoto[]): Promise<void> {
    try {
      const uploadedPhotoCount: number = await photoService.uploadCaptured(photos);
      if (uploadedPhotoCount !== photos.length) {
        promptAction.showToast({ message: '照片上传失败，录音已保留，稍后自动续传' });
        return;
      }
      const uploaded: boolean = await uploader.upload(path);
      if (!uploaded) promptAction.showToast({ message: '上传失败，录音已保留' });
      if (uploaded) {
        this.recordings = RecordingListUi.applyStatus(this.recordings,
          audioName.endsWith('.m4a') ? audioName.substring(0, audioName.length - 4) : audioName, 'asr');
        this.commandSession?.setRefs(this.currentCommandRefs());
        libraryStore.storeRecordingsSnapshot(this.recordings);
      }
    } catch (error) {
      promptAction.showToast({ message: `上传失败，录音已保留：${String(error)}` });
    }
  }

  private async toggleInterview(): Promise<void> {
    if (!this.recording) return;
    if (!this.interviewer) {
      this.interviewer = new RealtimeInterviewer((active: boolean, status: string) => {
        this.interviewActive = active; this.interviewStatus = status;
      });
    }
    try {
      if (this.interviewer.isActive()) await this.interviewer.stop();
      else await this.interviewer.start();
    } catch (error) {
      this.interviewActive = false;
      this.interviewStatus = '';
      promptAction.showToast({ message: `AI 采访启动失败，普通录音继续：${String(error)}` });
    }
  }

  private async addRecordingPhotos(): Promise<void> {
    if (!this.recording) return;
    try {
      const remaining: number = Math.max(0, 9 - this.capturedPhotos.length);
      if (remaining === 0) { promptAction.showToast({ message: '每段录音最多添加 9 张照片' }); return; }
      const added: CapturedPhoto[] = await photoService.pickForRecording(voiceRecorder.sessionTimestamp(), this.recordingSeconds, remaining);
      this.capturedPhotos = this.capturedPhotos.concat(added);
      if (added.length > 0) promptAction.showToast({ message: `已加入 ${added.length} 张照片` });
    } catch (error) { promptAction.showToast({ message: `照片读取失败：${String(error)}` }); }
  }

  private async removeRecordingPhoto(photo: CapturedPhoto): Promise<void> {
    await photoService.removeCaptured(photo);
    this.capturedPhotos = this.capturedPhotos.filter((value: CapturedPhoto) => value.key !== photo.key);
  }

  private publishReadyReplies(): void {
    for (const recording of this.recordings) {
      const replyTo: string = appPreferences.pendingReply(recording.name);
      if (!recording.hasArticles || replyTo.length === 0 || this.processingReplies.has(recording.name)) continue;
      this.processingReplies.add(recording.name);
      communityStore.share(recording.articleKey(), replyTo).then(async (shareId: string) => {
        if (shareId.length > 0) {
          await appPreferences.clearPendingReply(recording.name);
          promptAction.showToast({ message: '语音回复已发布到 VD 社区' });
        }
      }).finally(() => this.processingReplies.delete(recording.name));
    }
  }

  private async drainPendingCommunityShare(): Promise<void> {
    if (!authStore.isWechatAuthenticated()) return;
    const raw: string = appPreferences.pendingCommunityShare();
    if (!raw) return;
    try {
      const pending: PendingCommunityShareValue = JSON.parse(raw) as PendingCommunityShareValue;
      if (!pending.articleKey) { await appPreferences.clearPendingCommunityShare(); return; }
      const result: CommunityShareResult = await communityStore.shareResult(pending.articleKey, pending.replyTo ?? '');
      if (result.ok) {
        await appPreferences.clearPendingCommunityShare();
        promptAction.showToast({ message: pending.replyTo ? '登录后已自动续发社区回复' : '登录后已自动续发社区文章' });
      }
    } catch (_) {}
  }

  private async acceptPrivacy(): Promise<void> {
    await appPreferences.acceptPrivacy();
    this.showPrivacy = false;
    this.consentPolicyExpanded = false;
    await this.activateBusiness();
  }

  @Builder
  private topBar(title: string, back: boolean = false) {
    if (back) {
      PageHeader({ title: title, onBack: () => this.navigateBack() })
    } else {
      Row() {
        Image($rawfile('voicedrop-brand-waveform.svg'))
          .width(19.5).height(16).objectFit(ImageFit.Fill)
        Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.SECONDARY).margin({ left: 4 })
        Blank()
        Button({ type: ButtonType.Normal }) { RemixIcon({ glyph: RI.SETTINGS, iconSize: 21, color: Theme.SECONDARY }) }
          .backgroundColor(Theme.CARD).width(40).height(40)
          .border({ width: 1, color: Theme.BORDER, radius: 11 }).borderRadius(11).clip(true)
          .onClick(() => this.navigateTo('settings'))
      }.height(56).width('100%').padding({ left: 18, right: 12, top: 8 })
    }
  }

  @Builder
  private microphoneIcon(iconSize: number, color: string) {
    Image(color === Theme.WHITE ? $r('app.media.mic_android_white') : $r('app.media.mic_android_accent'))
      .width(iconSize).height(iconSize).objectFit(ImageFit.Contain)
  }

  @Builder
  private recordingDeleteAction(recording: Recording) {
    Button(this.deletingRecordingName === recording.name ? '删除中…' : '删除')
      .width(80)
      .height('100%')
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor(Theme.WHITE)
      .backgroundColor(Theme.ACCENT_STRONG)
      .borderRadius(18)
      .margin({ left: 10 })
      .enabled(this.deletingRecordingName.length === 0 && !recording.saving)
      .onClick(() => {
        this.closeOpenRecordingSwipe();
        this.deleteRecordingWithConfirmation(recording, false);
      })
  }

  private closeOpenRecordingSwipe(): void {
    if (this.openRecordingSwipeName.length === 0) return;
    const node: FrameNode | null = this.getUIContext().getFrameNodeById(
      this.recordingSwipeItemId(this.openRecordingSwipeName));
    if (node) {
      try {
        ListItemSwipeActionManager.collapse(node);
        this.openRecordingSwipeName = '';
        return;
      } catch (_) {}
    }
    this.openRecordingSwipeName = '';
    this.recordingSwipeRevision++;
  }

  private recordingSwipeItemId(recordingName: string): string {
    return `recording-swipe-${recordingName}`;
  }

  @Builder
  private recordingRowIcon(recording: Recording) {
    Stack({ alignContent: Alignment.TopStart }) {
      Row({ space: 4 }) {
        Column().width(3).height(11).borderRadius(1.5)
          .backgroundColor(recording.isEmpty ? '#D1C8BD' : Theme.ACCENT_STRONG)
        Column().width(3).height(19).borderRadius(1.5)
          .backgroundColor(recording.isEmpty ? '#D1C8BD' : Theme.ACCENT_STRONG)
        Column().width(3).height(14).borderRadius(1.5)
          .backgroundColor(recording.isEmpty ? '#D1C8BD' : Theme.ACCENT_STRONG)
      }.width(44).height(44).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
        .backgroundColor(recording.isEmpty ? '#F4F0EB' : '#FBEAE7').borderRadius(14)
      if (this.commandTalking && this.commandRefNumber(recording) > 0) {
        Text(`${this.commandRefNumber(recording)}`)
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Theme.WHITE)
          .width(24).height(24).textAlign(TextAlign.Center)
          .backgroundColor(Theme.ACCENT_STRONG).borderRadius(12)
      }
    }.width(44).height(44).margin({ right: 14 })
  }

  @Builder
  private libraryPage() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
      this.topBar('VoiceDrop 口述')
      Row() {
        Text('我的录音').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
          .padding({ left: 0, right: 14, top: 6, bottom: 6 })
        Text('VD社区').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.FAINT)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 }).onClick(() => {
            this.tab = 1; this.refreshCommunity(false).catch(() => {});
          })
        Blank()
      }.width('100%').padding({ left: 18, right: 18 })
      Row() { Blank().width(78).height(3).backgroundColor(Theme.ACCENT_STRONG).borderRadius(2) }
        .width('100%').padding({ left: 18 }).margin({ bottom: 10 })
      if (this.homeTags().length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            Button('全部').fontSize(13).fontColor(this.selectedTag.length === 0 ? Theme.WHITE : Theme.SECONDARY)
              .backgroundColor(this.selectedTag.length === 0 ? Theme.ACCENT : Theme.CARD)
              .border({ width: 1, color: this.selectedTag.length === 0 ? Theme.ACCENT : Theme.BORDER }).onClick(() => this.selectedTag = '')
            ForEach(this.homeTags(), (tag: string) =>
              Button(`#${tag}`).fontSize(13).fontColor(this.selectedTag === tag ? Theme.WHITE : Theme.SECONDARY)
                .backgroundColor(this.selectedTag === tag ? Theme.ACCENT : Theme.CARD)
                .border({ width: 1, color: this.selectedTag === tag ? Theme.ACCENT : Theme.BORDER }).onClick(() => this.selectedTag = tag),
              (tag: string) => tag)
          }.padding({ left: 16, right: 16 })
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).height(44).width('100%')
      }
      if (this.loading) {
        Column() {
          LoadingProgress().width(34).height(34)
        }.layoutWeight(1).width('100%')
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else if (this.visibleRecordings().length === 0) {
        Refresh({ refreshing: this.libraryRefreshing }) {
          List() {
            ListItem() {
              Column() {
                Text(this.selectedTag ? `「${this.selectedTag}」标签下还没有文章` : '轻点下方按钮开始第一条录音')
                  .fontSize(16).fontColor(Theme.SECONDARY).textAlign(TextAlign.Center)
              }.width('100%').height(180)
                .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            }
          }.width('100%').height('100%').padding({ left: 14, right: 14, top: 6, bottom: 16 })
        }.layoutWeight(1).width('100%').onRefreshing(() => this.pullRefreshLibrary())
      } else {
        Refresh({ refreshing: this.libraryRefreshing }) {
          List({ space: 10 }) {
            ForEach(this.visibleRecordings(), (item: Recording) => {
              ListItem() {
                Row() {
                  this.recordingRowIcon(item)
                  Column({ space: 7 }) {
                    Text(item.rowTitle()).fontSize(16).fontWeight(FontWeight.Bold)
                      .fontColor(item.isEmpty ? '#6F6A63' : Theme.INK)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row({ space: 10 }) {
                      Text(item.durationLabel()).fontSize(13).fontColor(item.isEmpty ? '#B9B2A8' : Theme.FAINT)
                      Text('•').fontSize(13).fontColor(this.recordingStatusColor(item))
                      Text(item.statusLabel()).fontSize(13).fontColor(this.recordingStatusColor(item))
                      ForEach(item.tags.slice(0, 2), (tag: string) => Text(`#${tag}`).fontSize(12).fontColor(Theme.SECONDARY))
                    }
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 24, color: Theme.FAINT })
                }.padding({ left: 16, right: 16, top: 15, bottom: 15 }).width('100%')
                  .backgroundColor(Theme.CARD).borderRadius(18).border({ width: 1, color: Theme.BORDER })
              }
                .id(this.recordingSwipeItemId(item.name))
                .swipeAction({
                  end: {
                    builder: () => this.recordingDeleteAction(item),
                    actionAreaDistance: 80,
                    onStateChange: (state: SwipeActionState) => {
                      if (state === SwipeActionState.EXPANDED) {
                        this.openRecordingSwipeName = item.name;
                      } else if (state === SwipeActionState.COLLAPSED && this.openRecordingSwipeName === item.name) {
                        this.openRecordingSwipeName = '';
                      }
                    }
                  },
                  edgeEffect: SwipeEdgeEffect.Spring
                })
                .onClick(() => this.openRecording(item))
            }, (item: Recording) => `${RecordingListUi.rowRenderKey(item)}-${this.recordingSwipeRevision}`)
          }.width('100%').height('100%').padding({ left: 16, right: 16, bottom: 8 })
            .onScrollStart(() => this.closeOpenRecordingSwipe())
        }.layoutWeight(1).width('100%')
          .onOffsetChange((offset: number) => {
            if (offset > 0) this.closeOpenRecordingSwipe();
          })
          .onRefreshing(() => this.pullRefreshLibrary())
      }
      if (this.errorText.length > 0) Text(this.errorText).fontSize(13).fontColor('#B42318').padding(12)
      if (this.pendingReplyTarget.length > 0) {
        Row() {
          Text('正在准备语音回复，点击下面开始录音').fontSize(13).fontColor('#8A4B08').layoutWeight(1)
          Button('取消').fontSize(12).backgroundColor(Color.Transparent).fontColor('#8A4B08')
            .onClick(() => this.pendingReplyTarget = '')
        }.padding({ left: 18, right: 18, top: 8 }).width('100%')
      }
      if (this.commandState.length > 0) {
        Row() {
          Text(this.commandState).fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.commandStateTone === LibraryCommandTone.Error ? '#B42318' :
              (this.commandStateTone === LibraryCommandTone.Active ? Theme.INK : Theme.SECONDARY))
            .textAlign(TextAlign.Center).padding({ left: 18, right: 18, top: 9, bottom: 9 })
            .backgroundColor(this.commandStateTone === LibraryCommandTone.Error ? '#FFEBE8' : Theme.ACCENT_SOFT)
            .borderRadius(14).layoutWeight(1)
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      }
      }.width('100%').height('100%').backgroundColor(Theme.BG)
      if (!this.recording) {
        Column() {
          this.recordingFab()
        }.width('100%').margin({ bottom: this.safeAreaBottom() + 20 }).hitTestBehavior(HitTestMode.Transparent)
      }
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder
  private recordingFab() {
    Column({ space: -3 }) {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(66).height(66)
            .backgroundColor(Theme.CARD)
            .borderRadius(33)
            .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 0 })
          Row() { this.microphoneIcon(27, Theme.WHITE) }
            .width(60).height(60).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
            .backgroundColor(Theme.ACCENT_STRONG).borderRadius(30)
        }
          .width(82).height(82)
          .enabled(!this.recordingTransitioning)
          .onTouch((event: TouchEvent) => this.handleRecordFabTouch(event))
      }.justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center).width('100%').hitTestBehavior(HitTestMode.Transparent)
      Text(LibraryCommandUi.recordButtonLabel(this.commandTalking, this.commandCanceled))
        .fontSize(12).fontColor(this.commandTalking ? Theme.ACCENT_STRONG : Theme.SECONDARY).letterSpacing(1)
        .hitTestBehavior(HitTestMode.Transparent)
    }.alignItems(HorizontalAlign.Center).width('100%').hitTestBehavior(HitTestMode.Transparent)
  }

  private homeTags(): string[] {
    const seen: Set<string> = new Set<string>(); const result: string[] = [];
    this.recordings.forEach((recording: Recording) => recording.tags.forEach((tag: string) => {
      const clean: string = tag.trim(); if (clean.length > 0 && !seen.has(clean)) { seen.add(clean); result.push(clean); }
    }));
    return result;
  }

  private visibleRecordings(): Recording[] {
    return this.selectedTag.length === 0 ? this.recordings :
      this.recordings.filter((recording: Recording) => recording.tags.includes(this.selectedTag));
  }

  private currentCommandRefs(): CommandRef[] {
    const targets: LibraryCommandTarget[] = this.visibleRecordings().map((recording: Recording) =>
      new LibraryCommandTarget(recording.stem(), recording.rowTitle(), recording.uploading || recording.saving));
    return LibraryCommandUi.commandRefs(targets).map((ref) => new CommandRef(ref.number, ref.stem, ref.title));
  }

  private commandRefNumber(recording: Recording): number {
    const refs: CommandRef[] = this.currentCommandRefs();
    const target: CommandRef | undefined = refs.find((ref: CommandRef) => ref.stem === recording.stem());
    return target?.n ?? 0;
  }

  private applyCommandFeedback(feedback: LibraryCommandFeedback): void {
    this.commandState = feedback.text;
    this.commandStateTone = feedback.tone;
  }

  private async sendLibraryCommandText(value: string): Promise<void> {
    const text: string = value.trim();
    if (text.length === 0) { this.applyCommandFeedback(new LibraryCommandFeedback()); return; }
    if (!this.commandSession) {
      this.applyCommandFeedback(new LibraryCommandFeedback('指令服务暂不可用，请稍后重试', LibraryCommandTone.Error));
      return;
    }
    const sent: boolean = await this.commandSession.instruct(`${Date.now()}`, text, this.currentCommandRefs());
    this.applyCommandFeedback(sent
      ? new LibraryCommandFeedback('正在执行图库指令…', LibraryCommandTone.Active)
      : new LibraryCommandFeedback('发送失败，请稍后重试', LibraryCommandTone.Error));
  }

  private commandTouchY(event: TouchEvent): number {
    if (event.touches.length > 0) return event.touches[0].screenY;
    if (event.changedTouches.length > 0) return event.changedTouches[0].screenY;
    return this.commandHoldStartY;
  }

  private handleRecordFabTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      if (this.recordingTransitioning || this.commandTalking || this.commandRecognizing) return;
      this.commandHoldPressed = true;
      this.commandLongPressed = false;
      this.commandCanceled = false;
      this.commandHoldStartY = this.commandTouchY(event);
      if (this.commandHoldTimer >= 0) clearTimeout(this.commandHoldTimer);
      this.commandHoldTimer = setTimeout(() => {
        this.commandHoldTimer = -1;
        if (!this.commandHoldPressed) return;
        this.commandLongPressed = true;
        this.commandTalking = true;
        this.applyCommandFeedback(LibraryCommandUi.dictationFeedback('', false));
        this.startLibraryCommandTalk();
      }, 300);
      return;
    }
    if (event.type === TouchType.Move && this.commandHoldPressed && this.commandLongPressed) {
      this.commandCanceled = this.commandHoldStartY - this.commandTouchY(event) >= 64;
      this.applyCommandFeedback(LibraryCommandUi.dictationFeedback(this.commandTranscriptText, this.commandCanceled));
      return;
    }
    if (event.type !== TouchType.Up && event.type !== TouchType.Cancel) return;
    const action: LibraryCommandGestureAction = LibraryCommandUi.gestureAction(
      this.commandLongPressed, this.commandCanceled, event.type === TouchType.Cancel);
    this.commandHoldPressed = false;
    this.commandLongPressed = false;
    if (this.commandHoldTimer >= 0) clearTimeout(this.commandHoldTimer);
    this.commandHoldTimer = -1;
    if (action === LibraryCommandGestureAction.Send || action === LibraryCommandGestureAction.Cancel) {
      this.finishLibraryCommandTalk(action === LibraryCommandGestureAction.Cancel);
    } else if (action === LibraryCommandGestureAction.Record) {
      this.toggleRecording();
    }
  }

  private async startLibraryCommandTalk(): Promise<void> {
    if (!this.context || !this.commandTalking) return;
    if (this.dictating) await this.dictation?.stop();
    const manager = abilityAccessCtrl.createAtManager();
    const permission = await manager.requestPermissionsFromUser(this.context, ['ohos.permission.MICROPHONE'] as Permissions[]);
    if (permission.authResults[0] !== 0) {
      this.commandTalking = false;
      this.commandHoldPressed = false;
      this.applyCommandFeedback(new LibraryCommandFeedback('需要麦克风权限才能使用语音指令', LibraryCommandTone.Error));
      return;
    }
    if (!this.commandTalking) return;
    this.commandTranscriptText = '';
    this.commandFinalized = false;
    this.commandRecognizing = false;
    this.dictationTarget = 'command';
    this.dictation = new AsrDictation((text: string, finalResult: boolean) => {
      if (this.dictationTarget !== 'command') return;
      this.commandTranscriptText = text;
      if (this.commandTalking) {
        this.applyCommandFeedback(LibraryCommandUi.dictationFeedback(text, this.commandCanceled));
      }
      if (finalResult && this.commandRecognizing) this.finalizeLibraryCommandTalk();
    }, (state: string) => {
      if (this.dictationTarget !== 'command') return;
      if (state.includes('失败') || state.includes('关闭')) {
        this.dictating = false;
        this.commandTalking = false;
        this.commandRecognizing = false;
        this.applyCommandFeedback(new LibraryCommandFeedback(state.length > 0 ? state : '听写失败', LibraryCommandTone.Error));
      } else if (state.length === 0 && this.commandRecognizing) {
        this.finalizeLibraryCommandTalk();
      } else if (this.commandTalking && this.commandTranscriptText.length === 0) {
        this.applyCommandFeedback(LibraryCommandUi.dictationFeedback('', this.commandCanceled));
      }
    });
    this.dictating = true;
    try { await this.dictation.start(); }
    catch (error) {
      this.dictating = false;
      this.commandTalking = false;
      this.applyCommandFeedback(new LibraryCommandFeedback(`听写启动失败：${String(error)}`, LibraryCommandTone.Error));
    }
  }

  private async finishLibraryCommandTalk(cancel: boolean): Promise<void> {
    this.commandTalking = false;
    this.commandCanceled = false;
    if (cancel) {
      this.commandRecognizing = false;
      this.commandFinalized = true;
      this.commandTranscriptText = '';
      this.dictating = false;
      this.dictationTarget = '';
      await this.dictation?.stop();
      this.applyCommandFeedback(new LibraryCommandFeedback());
      return;
    }
    this.commandRecognizing = true;
    this.applyCommandFeedback(new LibraryCommandFeedback('正在识别…', LibraryCommandTone.Active));
    if (this.dictation?.isRunning()) await this.dictation.finish();
    else await this.finalizeLibraryCommandTalk();
  }

  private async finalizeLibraryCommandTalk(): Promise<void> {
    if (this.commandFinalized) return;
    this.commandFinalized = true;
    const text: string = this.commandTranscriptText.trim();
    this.commandRecognizing = false;
    this.dictating = false;
    this.dictationTarget = '';
    this.commandTranscriptText = '';
    await this.sendLibraryCommandText(text);
  }

  private async toggleDictation(target: string): Promise<void> {
    if (this.dictating) {
      if (this.dictationTarget === target) await this.dictation?.finish();
      else { await this.dictation?.stop(); this.dictating = false; }
      return;
    }
    if (!this.context) return;
    const manager = abilityAccessCtrl.createAtManager();
    const permission = await manager.requestPermissionsFromUser(this.context, ['ohos.permission.MICROPHONE'] as Permissions[]);
    if (permission.authResults[0] !== 0) { promptAction.showToast({ message: '需要麦克风权限才能听写' }); return; }
    this.dictationTarget = target; this.dictationPrefix = target === 'edit' ? this.editText : this.libraryCommand;
    if (this.dictationPrefix.length > 0 && !this.dictationPrefix.endsWith(' ')) this.dictationPrefix += ' ';
    this.dictation = new AsrDictation((text: string, finalResult: boolean) => {
      if (target === 'edit') this.editText = this.dictationPrefix + text; else this.libraryCommand = this.dictationPrefix + text;
      if (finalResult) {
        this.dictating = false; this.dictationState = '听写完成';
        if (target === 'edit' && this.holdEditShouldSend) { this.holdEditShouldSend = false; this.sendEdit(); }
      }
    }, (state: string) => {
      this.dictationState = state;
      if (state.length === 0 || state.includes('失败') || state.includes('关闭')) this.dictating = false;
    });
    this.dictating = true;
    try { await this.dictation.start(); }
    catch (error) { this.dictating = false; this.dictationState = `听写启动失败：${String(error)}`; }
  }

  private touchY(event: TouchEvent): number {
    if (event.touches.length > 0) return event.touches[0].screenY;
    if (event.changedTouches.length > 0) return event.changedTouches[0].screenY;
    return this.holdEditStartY;
  }

  private handleEditHold(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.holdEditPressed = true; this.holdEditCanceled = false; this.holdEditShouldSend = false;
      this.holdEditStartY = this.touchY(event); this.holdEditOriginalText = this.editText;
      this.startEditHold();
    } else if (event.type === TouchType.Move && this.holdEditPressed) {
      this.holdEditCanceled = this.holdEditStartY - this.touchY(event) >= 64;
    } else if (event.type === TouchType.Up) {
      this.finishEditHold(false);
    } else if (event.type === TouchType.Cancel) {
      this.finishEditHold(true);
    }
  }

  private async startEditHold(): Promise<void> {
    if (this.dictating) await this.dictation?.stop();
    await this.toggleDictation('edit');
    if (!this.holdEditPressed && this.dictating) await this.finishEditHold(false);
  }

  private async finishEditHold(aborted: boolean): Promise<void> {
    const cancel: boolean = aborted || this.holdEditCanceled;
    this.holdEditPressed = false; this.holdEditCanceled = false;
    if (cancel) {
      this.holdEditShouldSend = false; this.editText = this.holdEditOriginalText;
      await this.dictation?.stop(); this.dictating = false; this.dictationState = '已取消语音修改';
    } else if (this.dictating) {
      this.holdEditShouldSend = true; await this.dictation?.finish();
    }
  }

  private handleCommandMessage(raw: string): void {
    try {
      const message: CommandMessage = JSON.parse(raw) as CommandMessage;
      if (message.type === 'confirm' && message.id) {
        const id: string = message.id; const summary: string = message.summary ?? message.text ?? message.message ?? '确认执行这条图库指令？';
        promptAction.showDialog({ title: '确认操作', message: summary,
          buttons: [{ text: '取消', color: '#666666' }, { text: '删除', color: '#D92D20' }]
        }).then((result) => result.index === 1 ? this.commandSession?.confirm(id) : this.commandSession?.cancel(id));
        return;
      }
      const event: LibraryCommandEvent = new LibraryCommandEvent(message.type, message.state, message.text, message.message);
      const feedback: LibraryCommandFeedback = LibraryCommandUi.feedbackForEvent(event);
      this.applyCommandFeedback(feedback);
      if (ClientReliability.commandMessageRequiresRefresh(message.type ?? '')) this.refreshLibrary();
      if (feedback.visible() && (message.type === 'reply' || message.type === 'error')) {
        promptAction.showToast({ message: feedback.text });
      }
    } catch (_) {
      this.applyCommandFeedback(new LibraryCommandFeedback('收到无法识别的图库指令响应', LibraryCommandTone.Error));
    }
  }

  private communityCardColor(post: CommunityPost): string {
    if ((post.coverPhotoKey ?? '').length > 0) return Theme.CARD;
    let hash: number = 0;
    for (let index: number = 0; index < post.shareId.length; index++) {
      hash = (hash * 31 + post.shareId.charCodeAt(index)) & 0x7fffffff;
    }
    const colors: string[] = [Theme.TEXT_CARD_WARM, Theme.TEXT_CARD_NEUTRAL, Theme.TEXT_CARD_SAGE];
    return colors[hash % colors.length];
  }

  private communityColumnPosts(column: number): CommunityPost[] {
    return this.posts.filter((_post: CommunityPost, index: number) => index % 2 === column);
  }

  @Builder
  private communityCard(post: CommunityPost) {
    Column() {
      if ((post.coverPhotoKey ?? '').length > 0) {
        Image(this.communityPhotoUrl(post.coverPhotoKey ?? ''))
          .alt(ArticleBody.photoUrl(post.coverPhotoKey ?? ''))
          .width('100%').height(this.communityPhotoHeight(post))
          .objectFit(ImageFit.Cover)
          .onComplete((event) => {
            if (event) this.updateCommunityPhotoRatio(post, event.width, event.height);
          })
          .onError(() => this.fallbackCommunityPhoto(post.coverPhotoKey ?? ''))
      }
      Column({ space: 8 }) {
        if (post.kind === 'prompt') Text('提示词').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#6F5529')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 }).backgroundColor('#F4DFAC').borderRadius(10)
        Text(post.title || '(无题)').fontSize((post.coverPhotoKey ?? '').length > 0 ? 15 : 16)
          .fontColor(Theme.INK).maxLines((post.coverPhotoKey ?? '').length > 0 ? 2 : 3)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        if ((post.coverPhotoKey ?? '').length === 0 && post.excerpt.length > 0) {
          Text(post.excerpt).fontSize(13).fontColor(Theme.COMMUNITY_PREVIEW).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }
        Row({ space: 5 }) {
          Text((post.author || '匿名').substring(0, 1)).fontSize(10).fontWeight(FontWeight.Bold)
            .fontColor(Theme.WHITE).width(20).height(20).textAlign(TextAlign.Center)
            .backgroundColor(Theme.AMBER).borderRadius(10)
          Text(post.author || '匿名').fontSize(12).fontColor(Theme.SECONDARY).maxLines(1).layoutWeight(1)
          RemixIcon({ glyph: post.liked ? RI.HEART_FILL : RI.HEART, iconSize: 12, color: Theme.ACCENT })
          Text(`${post.likes}`).fontSize(12).fontColor(Theme.ACCENT)
          if (post.replies > 0) {
            RemixIcon({ glyph: RI.CHAT, iconSize: 12, color: Theme.SECONDARY })
            Text(`${post.replies}`).fontSize(12).fontColor(Theme.SECONDARY)
          }
        }
      }.padding({ left: 12, right: 12, top: 11, bottom: 12 }).alignItems(HorizontalAlign.Start).width('100%')
    }.width('100%').backgroundColor(this.communityCardColor(post)).borderRadius(12)
      .border({ width: 1, color: Theme.BORDER, radius: 12 }).clip(true)
      .onClick(() => this.openCommunityPost(post))
      .gesture(LongPressGesture().onAction(() => { if (post.mine) this.unshareCommunityPost(post); }))
  }

  @Builder
  private communityPage() {
    Column() {
      this.topBar('VoiceDrop 口述')
      Row() {
        Text('我的录音').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.FAINT)
          .padding({ left: 0, right: 14, top: 6, bottom: 6 }).onClick(() => this.tab = 0)
        Text('VD社区').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        Blank()
      }.width('100%').padding({ left: 18, right: 18 })
      Row() { Blank().width(72).height(3).backgroundColor(Theme.ACCENT_STRONG).borderRadius(2) }
        .width('100%').padding({ left: 124 }).margin({ bottom: 1 })
      Row({ space: 12 }) {
        Text('推荐').fontSize(15).fontWeight(this.communityFilter === 'recommended' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.communityFilter === 'recommended' ? Theme.INK : Theme.SECONDARY)
          .padding({ left: 4, right: 4, top: 4, bottom: 4 })
          .onClick(() => this.selectCommunityFilter('recommended'))
        Text('最新').fontSize(15).fontWeight(this.communityFilter === 'latest' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.communityFilter === 'latest' ? Theme.INK : Theme.SECONDARY)
          .padding({ left: 4, right: 4, top: 4, bottom: 4 })
          .onClick(() => this.selectCommunityFilter('latest'))
        Text('回应').fontSize(15).fontWeight(this.communityFilter === 'replies' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.communityFilter === 'replies' ? Theme.INK : Theme.SECONDARY)
          .padding({ left: 4, right: 4, top: 4, bottom: 4 })
          .onClick(() => this.selectCommunityFilter('replies'))
        Blank()
      }.height(38).padding({ left: 14, right: 14 }).width('100%')
      if (this.posts.length === 0) {
        Column() {
          LoadingProgress().width(34).height(34)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        Refresh({ refreshing: this.communityRefreshing }) {
          Scroll() {
            Row({ space: 8 }) {
              Column({ space: 8 }) {
                ForEach(this.communityColumnPosts(0), (post: CommunityPost) => this.communityCard(post),
                  (post: CommunityPost) => post.shareId)
              }.layoutWeight(1)
              Column({ space: 8 }) {
                ForEach(this.communityColumnPosts(1), (post: CommunityPost) => this.communityCard(post),
                  (post: CommunityPost) => post.shareId)
              }.layoutWeight(1)
            }.alignItems(VerticalAlign.Top).padding({ left: 16, right: 16, bottom: 24 }).width('100%')
          }.width('100%').height('100%').scrollBar(BarState.Off)
        }.layoutWeight(1).width('100%').onRefreshing(() => this.pullRefreshCommunity())
      }
    }.width('100%').height('100%').backgroundColor(Theme.COMMUNITY_BG)
  }

  private async openCommunityPost(post: CommunityPost): Promise<void> {
    const shareId: string = post.shareId;
    this.showCommunityMenu = false;
    this.selectedPost = post;
    this.selectedReplyParent = undefined;
    this.communityReplies = [];
    this.communityDetailLoading = true;
    this.communityDetailError = '';
    this.postLiked = appPreferences.likedCommunityPost(shareId);
    this.postFed = false; this.postFeedCount = 0; this.postFeeding = false;
    this.navigateTo('communityDetail');
    communityStore.engage(shareId, 'view').catch(() => {});
    communityStore.feedState(shareId).then((state: CommunityFeedState) => {
      if (this.selectedPost?.shareId === shareId) { this.postFed = state.fed; this.postFeedCount = state.count; }
    }).catch(() => {});
    try {
      const full: CommunityPost | undefined = await communityStore.get(shareId);
      if (this.selectedPost?.shareId !== shareId) return;
      if (!full) {
        this.communityDetailError = '文章加载失败，请稍后重试';
        return;
      }
      this.selectedPost = full;
      const replies: CommunityPost[] =
        full.kind === 'prompt' ? [] : await communityStore.replies(shareId);
      const parentId: string = full.replyTo ?? '';
      const parent: CommunityPost | undefined =
        parentId.length > 0 ? await communityStore.get(parentId) : undefined;
      if (this.selectedPost?.shareId !== shareId) return;
      this.communityReplies = replies;
      this.selectedReplyParent = parent;
    } catch (_) {
      if (this.selectedPost?.shareId === shareId) {
        this.communityDetailError = '文章加载失败，请检查网络后重试';
      }
    } finally {
      if (this.selectedPost?.shareId === shareId) this.communityDetailLoading = false;
    }
  }

  private retryCommunityDetail(): void {
    if (this.selectedPost) this.openCommunityPost(this.selectedPost).catch(() => {});
  }

  private communityPhotoUrl(key: string): string {
    if (key.length === 0) return '';
    return this.thumbnailFallbackKeys.includes(key) ? ArticleBody.photoUrl(key) : ArticleBody.photoThumbnailUrl(key);
  }

  private fallbackCommunityPhoto(key: string): void {
    if (key.length === 0 || this.thumbnailFallbackKeys.includes(key)) return;
    this.thumbnailFallbackKeys = this.thumbnailFallbackKeys.concat(key);
    // Rebuild the cards so this image immediately retries on the original URL.
    this.posts = this.posts.slice();
  }

  /** Mirrors Android CommunityFeedView: square placeholder, then the decoded thumbnail's true aspect ratio. */
  private updateCommunityPhotoRatio(post: CommunityPost, width: number, height: number): void {
    if (width <= 0 || height <= 0) return;
    const ratio: number = Math.max(0.55, Math.min(2.1, width / height));
    if (Math.abs((post.coverAspectRatio ?? 1) - ratio) < 0.01) return;
    post.coverAspectRatio = ratio;
    // Keys stay shareId-only, so this updates geometry without recreating the card or image.
    this.posts = this.posts.slice();
  }

  private communityPhotoHeight(post: CommunityPost): number {
    const windowWidth: number = this.windowWidthPx > 0 ? this.getUIContext().px2vp(this.windowWidthPx) : 440;
    const columnWidth: number = Math.max(1, (windowWidth - 40) / 2);
    return Math.max(90, Math.min(330, columnWidth / (post.coverAspectRatio ?? 1)));
  }

  private async unshareCommunityPost(post: CommunityPost): Promise<void> {
    if (!post.mine) return;
    const result = await promptAction.showDialog({ title: '取消分享？', message: '取消后，这篇内容将从 VD 社区隐藏。',
      buttons: [{ text: '取消', color: '#666666' }, { text: '取消分享', color: '#D92D20' }] });
    if (result.index !== 1) return;
    if (await communityStore.unshare(post.shareId)) {
      promptAction.showToast({ message: '已取消分享' }); await this.refreshCommunity();
    } else promptAction.showToast({ message: '取消分享失败，请稍后重试' });
  }

  private async importSelectedCommunityPrompt(): Promise<void> {
    const code: string = this.selectedPost?.promptCode ?? '';
    if (!code || this.promptImporting || PromptTree.containsImport(promptStore.items(), code)) return;
    this.promptImporting = true;
    const error: string = await promptStore.importCode(code);
    this.promptImporting = false;
    promptAction.showToast({ message: error.length > 0 ? error : '已加入你的提示词' });
  }

  private communityAuthor(post?: CommunityPost): string {
    const author: string = post?.author?.trim() ?? '';
    return author.length > 0 ? author : '匿名作者';
  }

  private communityDate(post?: CommunityPost): string {
    if (!post) return '';
    let timestamp: number = post.firstSharedAt ?? post.sharedAt ?? post.updatedAt ?? 0;
    if (timestamp > 0 && timestamp < 100000000000) timestamp *= 1000;
    const createdAt: string = post.createdAt ?? '';
    if (timestamp <= 0 && createdAt.length > 0) {
      timestamp = new Date(createdAt).getTime();
    }
    if (timestamp <= 0 || Number.isNaN(timestamp)) return '';
    const date: Date = new Date(timestamp);
    const now: Date = new Date();
    if (date.getFullYear() === now.getFullYear()) return `${date.getMonth() + 1}月${date.getDate()}日`;
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
  }

  @Builder
  private articleBlock(block: ArticleBlock, editable: boolean = false, blockIndex: number = -1) {
    if (block.kind === 'photo') {
      if (editable) {
        ArticlePhotoView({
          url: this.blockPhotoUrl(block.value),
          intent: this.isGeneratedPhoto(block.value) ? 'generated' : 'original',
          onLoaded: () => this.cacheArticlePhotoToken(block.value)
        })
          .gesture(LongPressGesture().onAction(() => this.openPromptMenu(block, blockIndex)))
      } else {
        ArticlePhotoView({
          url: this.blockPhotoUrl(block.value), intent: 'original',
          onLoaded: () => this.cacheArticlePhotoToken(block.value)
        })
      }
    } else {
      if (editable) {
        Row({ space: 8 }) {
          if (this.showArticleLines) Text(`L${this.articleLine(blockIndex)}`).fontSize(11).fontColor('#A06A24').width(34)
          Text(block.value).fontSize(17).lineHeight(30).fontColor(Theme.INK).layoutWeight(1).copyOption(CopyOptions.LocalDevice)
        }.width('100%').alignItems(VerticalAlign.Top).gesture(LongPressGesture().onAction(() => this.openPromptMenu(block, blockIndex)))
      } else {
        Text(block.value).fontSize(17).lineHeight(30).fontColor(Theme.INK).width('100%').copyOption(CopyOptions.LocalDevice)
      }
    }
  }

  private blockPhotoUrl(token: string): string {
    const communityDetail: boolean = this.isCommunityDetailActive();
    const doc: ArticleDoc | undefined = communityDetail ? this.selectedPost?.doc : this.article;
    if (!doc) return '';
    const key: string | undefined = ArticleBody.resolvePhotoKey(token, doc.photos);
    if (!key) return '';
    const owner: string = (doc.owner ?? '').replace(/\/+$/, '');
    const fullKey: string = owner.length > 0 && !key.startsWith('users/') ? `${owner}/${key}` : key;
    return communityDetail ? ArticleBody.photoUrl(fullKey) : photoService.articlePhotoSource(fullKey);
  }

  private isGeneratedPhoto(token: string): boolean {
    if (!this.article) return false;
    const key: string | undefined = ArticleBody.resolvePhotoKey(token, this.article.photos);
    if (!key) return false;
    const owner: string = (this.article.owner ?? '').replace(/\/+$/, '');
    const fullKey: string = owner.length > 0 && !key.startsWith('users/') ? `${owner}/${key}` : key;
    return this.generatedPhotoKeys.includes(fullKey) || this.processingPhotoKeys.includes(fullKey);
  }

  private warmArticlePhotos(doc?: ArticleDoc, refreshKeys: string[] = []): void {
    if (!doc) return;
    photoService.cacheArticlePhotos(doc, refreshKeys).catch(() => {});
  }

  private cacheArticlePhotoToken(token: string): void {
    const doc: ArticleDoc | undefined = this.isCommunityDetailActive() ? this.selectedPost?.doc : this.article;
    if (!doc) return;
    const key: string | undefined = ArticleBody.resolvePhotoKey(token, doc.photos);
    if (!key) return;
    const owner: string = (doc.owner ?? '').replace(/\/+$/, '');
    const fullKey: string = owner.length > 0 && !key.startsWith('users/') ? `${owner}/${key}` : key;
    if (this.processingPhotoKeys.includes(fullKey)) {
      this.processingPhotoKeys = this.processingPhotoKeys.filter((item: string) => item !== fullKey);
    }
    photoService.cacheArticlePhoto(fullKey).catch(() => {});
  }

  private articleLine(blockIndex: number): number {
    if (!this.article) return 1;
    return ArticleBody.visibleLine(ArticleBody.blocks(this.article.articles[this.selectedArticle].body), blockIndex);
  }

  private openPromptMenu(block: ArticleBlock, blockIndex: number): void {
    if (!this.editSession || !this.article) return;
    const anchor: string = block.kind === 'photo' ? 'image' : 'text';
    const nodes: PromptNode[] = PromptTree.menu(promptStore.items(), anchor);
    if (nodes.length === 0) { promptAction.showToast({ message: '请先在设置中添加快捷提示词' }); return; }
    this.promptMenuNodes = nodes; this.promptMenuNested = false;
    this.promptMenuTitle = block.kind === 'photo' ? '修改这张图片' : '改写这段文字';
    this.promptTargetKind = block.kind; this.promptTargetValue = block.value;
    this.promptTargetIndex = blockIndex; this.showPromptMenu = true;
  }

  private openPromptGroup(group: PromptNode): void {
    this.promptMenuNodes = group.children.map((node: PromptNode) => node.copy());
    this.promptMenuTitle = group.label; this.promptMenuNested = true;
  }

  private showPromptRoot(): void {
    const anchor: string = this.promptTargetKind === 'photo' ? 'image' : 'text';
    this.promptMenuNodes = PromptTree.menu(promptStore.items(), anchor);
    this.promptMenuTitle = this.promptTargetKind === 'photo' ? '修改这张图片' : '改写这段文字';
    this.promptMenuNested = false;
  }

  private systemPromptMenuNodes(): PromptNode[] {
    return this.promptMenuNodes.filter((node: PromptNode) => node.origin === 'system');
  }

  private customPromptMenuNodes(): PromptNode[] {
    return this.promptMenuNodes.filter((node: PromptNode) => node.origin !== 'system');
  }

  private copyPromptTarget(): void {
    pasteboard.getSystemPasteboard().setData(pasteboard.createPlainTextData(this.promptTargetValue));
    this.showPromptMenu = false; promptAction.showToast({ message: '已拷贝' });
  }

  private editPromptTarget(): void {
    this.showPromptMenu = false; this.beginDirectEdit();
  }

  private async applyPrompt(action: PromptNode): Promise<void> {
    if (!this.editSession || !this.article) return;
    this.showPromptMenu = false;
    let instruction: string = action.prompt;
    let anchor: EditAnchor;
    if (this.promptTargetKind === 'photo') {
      instruction = instruction.replace(/\{\{KEY\}\}/g, this.promptTargetValue);
      const articlePhotos: string[] = this.article.photos ?? [];
      const key: string = ArticleBody.resolvePhotoKey(this.promptTargetValue, articlePhotos) ?? this.promptTargetValue;
      anchor = EditAnchor.forImage(key);
      const owner: string = (this.article.owner ?? '').replace(/\/+$/, '');
      const fullKey: string = owner.length > 0 && !key.startsWith('users/') ? `${owner}/${key}` : key;
      if (!this.pendingPhotoRefreshKeys.includes(fullKey)) this.pendingPhotoRefreshKeys.push(fullKey);
    } else {
      const blocks: ArticleBlock[] = ArticleBody.blocks(this.article.articles[this.selectedArticle].body);
      const line: number = ArticleBody.visibleLine(blocks, this.promptTargetIndex);
      const quote: string = this.promptTargetValue.trim().replace(/\s+/g, ' ').substring(0, 24);
      instruction = instruction.replace(/\{\{LINE\}\}/g, `${line}`).replace(/\{\{QUOTE\}\}/g, quote);
      anchor = EditAnchor.forLine(line, this.promptTargetValue);
    }
    await this.editSession.sendEdit(`${Date.now()}`, instruction, this.selectedArticle, anchor, action.id);
    promptAction.showToast({ message: `已发送“${action.label}”` });
  }

  @Builder
  private configuredPromptRow(node: PromptNode) {
    Row() {
      Text(node.label).fontSize(16).fontWeight(node.isGroup() ? FontWeight.Bold : FontWeight.Normal)
        .fontColor('#252525').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      if (node.isGroup()) RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 21, color: Theme.FAINT })
    }.height(48).padding({ left: 18, right: 14 }).width('100%')
      .onClick(() => node.isGroup() ? this.openPromptGroup(node) : this.applyPrompt(node))
  }

  @Builder
  private configuredPromptList(nodes: PromptNode[]) {
    Column() {
      ForEach(nodes, (node: PromptNode, index: number) => {
        if (index > 0) Divider().color('#E4E1DB').margin({ left: 18, right: 18 })
        this.configuredPromptRow(node)
      }, (node: PromptNode) => node.id)
    }.width('100%')
  }

  @Builder
  private detailBackButton() {
    Button({ type: ButtonType.Normal }) {
      RemixIcon({ glyph: RI.ARROW_LEFT, iconSize: 25, color: Theme.INK })
    }
      .width(40).height(40).padding(0)
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: Theme.BORDER, radius: 11 })
      .borderRadius(11).clip(true)
      .shadow({ radius: 5, color: '#34291F22', offsetX: 0, offsetY: 2 })
      .onClick(() => {
        this.showDetailMenu = false;
        this.navigateBack();
      })
  }

  @Builder
  private detailLoadingHeader() {
    Row() {
      this.detailBackButton()
      Blank()
    }.height(64).padding({ left: 16, right: 12, top: 8, bottom: 8 }).width('100%')
  }

  @Builder
  private detailToolbar() {
    Row() {
      this.detailBackButton()
      Blank()
      Button({ type: ButtonType.Normal }) {
        if (this.playing) {
          Text('■').fontSize(17).fontColor(Theme.WHITE)
        } else {
          RemixIcon({ glyph: RI.PLAY, iconSize: 25, color: Theme.WHITE })
        }
      }
        .width(44).height(44).padding(0).borderRadius(22)
        .backgroundColor(this.playing ? Theme.INK : Theme.ACCENT_STRONG)
        .enabled(!this.playbackLoading)
        .opacity(this.playbackLoading ? 0.55 : 1)
        .shadow({ radius: 5, color: '#34291F2B', offsetX: 0, offsetY: 2 })
        .onClick(() => this.togglePlayback())
      Button({ type: ButtonType.Normal }) {
        RemixIcon({ glyph: RI.IMAGE, iconSize: 25, color: Theme.INK })
      }
        .width(40).height(40).padding(0).margin({ left: 4 })
        .backgroundColor(Theme.CARD)
        .border({ width: 1, color: Theme.BORDER, radius: 11 })
        .borderRadius(11).clip(true)
        .shadow({ radius: 5, color: '#34291F22', offsetX: 0, offsetY: 2 })
        .onClick(() => this.insertPhotos())
      Row() {
        Button({ type: ButtonType.Normal }) {
          RemixIcon({
            glyph: RI.ARROW_GO_BACK,
            iconSize: 25,
            color: this.canUndo() ? Theme.INK : Theme.FAINT
          })
        }
          .width(39).height(40).padding(0).backgroundColor(Color.Transparent)
          .enabled(this.canUndo()).onClick(() => this.shiftHistory(-1))
        Divider().vertical(true).height(24).color(Theme.BORDER)
        Button({ type: ButtonType.Normal }) {
          RemixIcon({
            glyph: RI.ARROW_GO_FORWARD,
            iconSize: 25,
            color: this.canRedo() ? Theme.INK : Theme.FAINT
          })
        }
          .width(39).height(40).padding(0).backgroundColor(Color.Transparent)
          .enabled(this.canRedo()).onClick(() => this.shiftHistory(1))
      }
        .height(40).margin({ left: 4 })
        .backgroundColor(Theme.CARD)
        .border({ width: 1, color: Theme.BORDER, radius: 11 })
        .borderRadius(11).clip(true)
        .shadow({ radius: 5, color: '#34291F22', offsetX: 0, offsetY: 2 })
      Button({ type: ButtonType.Normal }) {
        RemixIcon({ glyph: RI.MORE, iconSize: 24, color: Theme.SECONDARY })
      }
        .width(40).height(40).padding(0).margin({ left: 4 })
        .backgroundColor(Theme.CARD)
        .border({ width: 1, color: Theme.BORDER, radius: 11 })
        .borderRadius(11).clip(true)
        .shadow({ radius: 5, color: '#34291F22', offsetX: 0, offsetY: 2 })
        .onClick(() => this.showDetailMenu = !this.showDetailMenu)
    }.height(64).padding({ left: 16, right: 12, top: 8, bottom: 8 }).width('100%')
  }

  private detailSubtitle(): string {
    if (!this.selected) return '';
    const parsed = RecordingName.parse(this.selected.name);
    if (!parsed) return '';
    return `${parsed.month}月${parsed.day}日${parsed.hhmm.length > 0 ? ` ${parsed.hhmm}` : ''}`;
  }

  private detailVoiceLabel(): string {
    if (this.holdEditPressed) {
      return this.holdEditCanceled ? '上滑取消 · 松开放弃' : '松开 发送 · 上滑取消';
    }
    if (this.dictating) return '正在识别…';
    return this.pendingQuestion() ? '按住 说话 回答' : '按住 说话 修改';
  }

  @Builder
  private detailVoiceButton() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 9 }) {
        RemixIcon({
          glyph: RI.MIC,
          iconSize: 23,
          color: this.holdEditCanceled ? Theme.ACCENT_STRONG : Theme.INK
        })
        Text(this.detailVoiceLabel())
          .fontSize(17).fontWeight(FontWeight.Bold)
          .fontColor(this.holdEditCanceled ? Theme.ACCENT_STRONG : Theme.INK)
      }.justifyContent(FlexAlign.Center).width('100%')
    }
      .height(58).width('100%').padding(0)
      .backgroundColor(this.holdEditCanceled ? '#FFE5E5' : '#FFFBF7')
      .border({ width: 1, color: '#E8DED0', radius: 16 })
      .borderRadius(16).clip(true)
      .shadow({ radius: 9, color: '#34291F22', offsetX: 0, offsetY: 3 })
      .stateEffect(false)
      .onTouch((event: TouchEvent) => this.handleEditHold(event))
  }

  @Builder
  private detailPage() {
    Column() {
      if (this.detailLoading) {
        this.detailLoadingHeader()
        Column({ space: 14 }) {
          LoadingProgress().width(40).height(40).color(Theme.ACCENT_STRONG)
          Text('正在加载...').fontSize(16).fontColor(Theme.SECONDARY)
        }.height(180).margin({ top: 50 }).width('100%').justifyContent(FlexAlign.Center)
        Blank()
      } else if (this.detailLoadError.length > 0 && !this.article) {
        this.detailLoadingHeader()
        Column({ space: 14 }) {
          Text(this.detailLoadError).fontSize(16).fontColor(Theme.SECONDARY)
          Button('重新加载').fontSize(14).height(38).backgroundColor(Theme.ACCENT_STRONG)
            .onClick(() => {
              if (this.selected) this.openRecording(this.selected);
            })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (!this.article || this.article.articles.length === 0) {
        this.detailLoadingHeader()
        Column({ space: 14 }) {
          LoadingProgress().width(36).height(36).color(Theme.ACCENT_STRONG)
          Text(this.selected?.statusLabel() ?? '正在处理').fontSize(18).fontColor(Theme.INK)
          Text('转写和文章生成完成后会自动刷新').fontSize(14).fontColor(Theme.SECONDARY)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        this.detailToolbar()
        if (this.playing || this.playbackDuration > 0) {
          Row({ space: 10 }) {
            Text(this.timeLabel(this.playbackProgress)).fontSize(12).fontColor(Theme.SECONDARY)
            Slider({ value: this.playbackProgress, min: 0, max: Math.max(1, this.playbackDuration) })
              .selectedColor(Theme.ACCENT_STRONG).trackColor(Theme.BORDER)
              .layoutWeight(1).onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.End) audioPlayback.seek(value);
              })
            Text(this.timeLabel(this.playbackDuration)).fontSize(12).fontColor(Theme.SECONDARY)
          }.padding({ left: 22, right: 22, bottom: 4 }).width('100%')
        }
        Scroll() {
          Column({ space: 12 }) {
            Text(this.article.articles[this.selectedArticle].title)
              .fontSize(28).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
              .lineHeight(39).width('100%')
            Row({ space: 4 }) {
              Text(this.detailSubtitle()).fontSize(14).fontColor(Theme.FAINT)
              Button(`✎  ${this.article.articles[this.selectedArticle].style === undefined ?
                '选风格' : `v${this.article.articles[this.selectedArticle].style} 风格`}  ›`)
                .fontSize(13).fontColor(Theme.FAINT).height(28).padding({ left: 6, right: 6 })
                .backgroundColor(Color.Transparent).onClick(() => this.openStyleRewrite())
            }.width('100%').margin({ bottom: 6 })
            if (this.article.articles.length > 1) {
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.article.articles, (article: MinedArticle, index: number) => {
                    Button(article.title)
                      .height(32).fontSize(13).fontWeight(FontWeight.Bold)
                      .fontColor(this.selectedArticle === index ? Theme.WHITE : Theme.SECONDARY)
                      .backgroundColor(this.selectedArticle === index ? Theme.ACCENT_STRONG : Color.Transparent)
                      .borderRadius(16).padding({ left: 14, right: 14 })
                      .onClick(() => this.selectedArticle = index)
                  })
                }
              }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
                .margin({ bottom: 8 })
            }
            ForEach(ArticleBody.blocks(this.article.articles[this.selectedArticle].body),
              (block: ArticleBlock, index: number) => this.articleBlock(block, true, index))
            if ((this.article.transcript ?? '').length > 0) {
              Text('原始转写')
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
                .margin({ top: 24 }).width('100%')
              Text(this.article.transcript ?? '')
                .fontSize(15).lineHeight(25).fontColor(Theme.SECONDARY).width('100%')
            }
          }
            .padding({ left: 22, right: 22, top: 12, bottom: 28 })
            .alignItems(HorizontalAlign.Start).width('100%')
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        if (this.pendingQuestion()) {
          Column({ space: 8 }) {
            Row() {
              Text('追问').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#A85D00').layoutWeight(1)
              Button('跳过').fontSize(12).height(30).backgroundColor(Color.Transparent).fontColor(Theme.SECONDARY)
                .onClick(() => this.skipQuestion())
            }.width('100%')
            Text(this.pendingQuestion()?.text ?? '')
              .fontSize(16).fontWeight(FontWeight.Medium).lineHeight(24).fontColor(Theme.INK).width('100%')
            Text('在下方按住说话回答，内容会被织入正文最合适的位置。')
              .fontSize(12).fontColor(Theme.SECONDARY).width('100%')
          }
            .padding(12).margin({ left: 20, right: 20, bottom: 8 })
            .backgroundColor('#FFFBF7')
            .border({ width: 1, color: '#FFD6AD', radius: 14 })
            .borderRadius(14).alignItems(HorizontalAlign.Start)
        }
        Column() {
          this.detailVoiceButton()
        }
          .padding({ left: 20, right: 20, top: 6, bottom: 12 + this.safeAreaBottom() })
          .width('100%')
      }
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }

  private timeLabel(milliseconds: number): string {
    const total: number = Math.max(0, Math.floor(milliseconds / 1000));
    return `${Math.floor(total / 60)}:${(total % 60).toString().padStart(2, '0')}`;
  }

  private async togglePlayback(): Promise<void> {
    if (!this.selected || this.playbackLoading) return;
    this.playbackLoading = !audioPlayback.isPlaying();
    try {
      await audioPlayback.toggle(this.selected.name);
    } catch (error) {
      promptAction.showToast({ message: `播放失败：${String(error)}` });
    } finally { this.playbackLoading = false; }
  }

  private historyIndex(): number {
    return this.history.versions.findIndex((version: ArticleVersion) => version.v === this.history.head);
  }

  private canUndo(): boolean { return this.historyIndex() > 0; }
  private canRedo(): boolean {
    const index: number = this.historyIndex();
    return index >= 0 && index < this.history.versions.length - 1;
  }

  private async shiftHistory(delta: number): Promise<void> {
    if (!this.selected || !this.article) return;
    const targetIndex: number = this.historyIndex() + delta;
    if (targetIndex < 0 || targetIndex >= this.history.versions.length) return;
    const target: ArticleVersion = this.history.versions[targetIndex];
    const oldArticle: ArticleDoc = this.article;
    const oldHead: number = this.history.head;
    this.article = libraryStore.articleFromVersion(this.article, target);
    this.history.head = target.v;
    this.history = this.history;
    if (!await libraryStore.patchHead(this.selected, target.v)) {
      this.article = oldArticle;
      this.history.head = oldHead;
      this.history = this.history;
      promptAction.showToast({ message: '版本切换失败' });
    } else {
      await libraryStore.cacheArticle(this.selected, this.article);
      this.warmArticlePhotos(this.article);
    }
  }

  private beginDirectEdit(): void {
    if (!this.article || this.article.articles.length <= this.selectedArticle) return;
    this.directTitle = this.article.articles[this.selectedArticle].title;
    this.directBody = this.article.articles[this.selectedArticle].body;
    this.showDirectEditor = true;
  }

  private async saveDirectEdit(): Promise<void> {
    if (!this.selected || !this.article || this.directTitle.trim().length === 0) return;
    const previousTitle: string = this.article.articles[this.selectedArticle].title;
    const previousBody: string = this.article.articles[this.selectedArticle].body;
    this.article.articles[this.selectedArticle].title = this.directTitle.trim();
    this.article.articles[this.selectedArticle].body = this.directBody;
    if (await libraryStore.saveArticle(this.selected, this.article)) {
      this.warmArticlePhotos(this.article);
      this.showDirectEditor = false;
      this.history = await libraryStore.versionHistory(this.selected);
      promptAction.showToast({ message: '文章已保存' });
    } else {
      this.article.articles[this.selectedArticle].title = previousTitle;
      this.article.articles[this.selectedArticle].body = previousBody;
      promptAction.showToast({ message: '文章保存失败' });
    }
    this.article = this.article;
  }

  private async selectHistoryVersion(version: ArticleVersion): Promise<void> {
    if (!this.selected || !this.article) return;
    if (await libraryStore.patchHead(this.selected, version.v)) {
      this.article = libraryStore.articleFromVersion(this.article, version);
      this.history.head = version.v; this.history = this.history; this.showHistoryBrowser = false;
      await libraryStore.cacheArticle(this.selected, this.article);
      this.warmArticlePhotos(this.article);
    } else promptAction.showToast({ message: '版本切换失败' });
  }

  private async toggleCommunityShare(): Promise<void> {
    if (!this.selected) return;
    if (this.communityShareId.length > 0) {
      if (await communityStore.unshare(this.communityShareId)) {
        this.communityShareId = '';
        promptAction.showToast({ message: '已从 VD 社区隐藏' });
      }
      return;
    }
    if (!appPreferences.communityTermsAccepted()) {
      const accepted: boolean = await this.confirmCommunityTerms();
      if (!accepted) return;
    }
    const result: CommunityShareResult = await communityStore.shareResult(this.selected.articleKey());
    if (result.ok) {
      this.communityShareId = result.shareId;
      promptAction.showToast({ message: '已在 VD 社区可见' });
    } else if (result.needsWechatSignin()) {
      if (result.code === 401) await authStore.signOutWechat();
      await appPreferences.savePendingCommunityShare(this.selected.articleKey());
      this.navigateTo('account');
      promptAction.showToast({ message: '已保存分享请求，微信登录后会自动续发' });
    } else {
      promptAction.showToast({ message: result.error ? `分享社区失败：${result.error}` : '分享社区失败，请稍后再试' });
    }
  }

  private async confirmCommunityTerms(): Promise<boolean> {
    const result = await promptAction.showDialog({
      title: '社区公约',
      message: COMMUNITY_TERMS,
      buttons: [{ text: '取消', color: '#666666' }, { text: '同意并继续', color: '#111111' }]
    });
    if (result.index !== 1) return false;
    await appPreferences.setBoolean('communityTermsAccepted', true);
    return true;
  }

  private beginCommunityReply(): void {
    if (!this.selectedPost) return;
    this.pendingReplyTarget = this.selectedPost.shareId;
    this.tab = 0;
    this.navigateHome();
    promptAction.showToast({ message: '点击开始录音，文章生成后会自动作为回复发布' });
  }

  private async runCommunityMenuAction(action: string): Promise<void> {
    this.showCommunityMenu = false;
    if (action === 'reply') {
      this.beginCommunityReply();
    } else if (action === 'wechat') {
      await this.shareSelectedCommunityPostToWechat();
    } else if (action === 'share') {
      await this.shareSelectedCommunityPost();
    } else if (action === 'report') {
      await this.reportSelectedCommunityPost();
    } else if (action === 'block') {
      await this.blockSelectedAuthor();
    }
  }

  private async shareSelectedCommunityPostToWechat(): Promise<void> {
    if (!this.selectedPost || !this.context) return;
    try {
      const message: string = await WechatCommunityShare.send(
        this.context, this.selectedPost.shareId, this.selectedPost.title || 'VoiceDrop 文章');
      promptAction.showToast({ message: message });
    } catch (error) {
      promptAction.showToast({ message: `微信分享失败：${String(error)}` });
    }
  }

  private async reportSelectedCommunityPost(): Promise<void> {
    if (!this.selectedPost) return;
    const post: CommunityPost = this.selectedPost;
    const result = await promptAction.showDialog({
      title: '举报这篇分享？',
      message: '举报后这篇会立即从社区下架，并在 24 小时内由人工审核处理。',
      buttons: [{ text: '取消', color: '#666666' }, { text: '举报并下架', color: Theme.ACCENT_STRONG }]
    });
    if (result.index !== 1) return;
    if (await communityStore.report(post.shareId)) {
      promptAction.showToast({ message: '已举报，内容已下架待审核' });
      this.navigateHome();
      await this.refreshCommunity();
    } else {
      promptAction.showToast({ message: '举报失败，请稍后重试' });
    }
  }

  private async regenerateArticle(): Promise<void> {
    if (!this.selected) return;
    if (await libraryStore.remine(this.selected)) {
      promptAction.showToast({ message: '已开始重新生成文章' });
      this.navigateHome();
      await this.refreshLibrary();
    } else {
      promptAction.showToast({ message: '重新生成失败' });
    }
  }

  private deleteRecordingWithConfirmation(recording?: Recording, returnHome: boolean = true): void {
    const target: Recording | undefined = recording ?? this.selected;
    if (!target || this.deletingRecordingName.length > 0) return;
    promptAction.showDialog({
      title: '删除这条录音？',
      message: RecordingListUi.deleteMessage,
      buttons: [{ text: '取消', color: '#666666' }, { text: '删除', color: '#D92D20' }]
    }).then(async (result) => {
      if (result.index !== 1) return;
      this.deletingRecordingName = target.name;
      try {
        uploader.discardPending(target.name);
        if (returnHome) await audioPlayback.stop();
        const ok: boolean = await libraryStore.delete(target);
        promptAction.showToast({ message: ok ? '已删除' : '删除失败' });
        if (ok) {
          if (!this.deletedRecordingNames.includes(target.name)) {
            this.deletedRecordingNames = this.deletedRecordingNames.concat(target.name);
          }
          this.recordings = RecordingListUi.afterSuccessfulDelete(this.recordings, target.name);
          libraryStore.storeRecordingsSnapshot(this.recordings);
          if (returnHome) this.navigateHome();
        }
      } catch (_) {
        promptAction.showToast({ message: '删除失败' });
      } finally {
        this.deletingRecordingName = '';
      }
    });
  }

  private hasWechatDraft(): boolean {
    return Boolean(this.article?.articles.some((article: MinedArticle) =>
      (article.wechatMediaId ?? '').trim().length > 0));
  }

  private async shareRecordingToWechat(): Promise<void> {
    if (!this.context || !this.article) return;
    if (this.communityShareId.length === 0) {
      promptAction.showToast({ message: '请先在更多菜单开启“VD 社区可见”，再分享到微信' });
      return;
    }
    const title: string = this.article.articles[this.selectedArticle]?.title ?? this.selected?.rowTitle() ?? 'VoiceDrop 文章';
    try {
      const message: string = await WechatCommunityShare.send(this.context, this.communityShareId, title);
      promptAction.showToast({ message: message });
    } catch (error) {
      promptAction.showToast({ message: `微信分享失败：${String(error)}` });
    }
  }

  private async runDetailMenuAction(action: string): Promise<void> {
    this.showDetailMenu = false;
    if (action === 'publish') {
      await this.publishWechat();
    } else if (action === 'community') {
      await this.toggleCommunityShare();
    } else if (action === 'xhs') {
      await this.shareToXhs();
    } else if (action === 'wechat') {
      await this.shareRecordingToWechat();
    } else if (action === 'share') {
      await this.shareRecording();
    } else if (action === 'delete') {
      this.deleteRecordingWithConfirmation(this.selected, true);
    }
  }

  @Builder
  private detailMenuRow(label: string, glyph: string, action: string, danger: boolean = false) {
    Row() {
      Text(label)
        .fontSize(17).fontWeight(FontWeight.Normal)
        .fontColor(danger ? Theme.ACCENT_STRONG : Theme.INK)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      RemixIcon({ glyph: glyph, iconSize: 25, color: Theme.ACCENT_STRONG })
    }
      .height(58).padding({ left: 18, right: 16 }).width('100%')
      .onClick(() => this.runDetailMenuAction(action))
  }

  @Builder
  private detailMoreMenu() {
    Column() {
      this.detailMenuRow(this.hasWechatDraft() ? '更新公众号草稿' : '发布公众号草稿',
        RI.SEND_PLANE, 'publish')
      Divider().color('#E0D8CC')
      this.detailMenuRow(this.communityShareId.length > 0 ? '从 VD 社区隐藏' : 'VD 社区可见',
        RI.TEAM, 'community')
      Divider().color('#E0D8CC')
      this.detailMenuRow(this.xhsPreparing ? '正在生成小红书…' : '分享到小红书',
        RI.FILE_TEXT, 'xhs')
      Divider().color('#E0D8CC')
      this.detailMenuRow('分享到微信', RI.SHARE_FORWARD, 'wechat')
      Divider().color('#E0D8CC')
      this.detailMenuRow('分享', RI.SHARE_FORWARD, 'share')
      Divider().height(8).color('#E9E5DC')
      this.detailMenuRow('删除', RI.DELETE, 'delete', true)
    }
      .padding({ top: 3, bottom: 3 }).width(260)
      .backgroundColor('#FCFFFFFF')
      .border({ width: 1, color: '#ECE7DE', radius: 18 })
      .borderRadius(18).clip(true)
      .shadow({ radius: 18, color: '#2B2A2529', offsetX: 0, offsetY: 8 })
  }

  @Builder
  private communityDetailHeader() {
    Row() {
      Button({ type: ButtonType.Normal }) {
        RemixIcon({ glyph: RI.ARROW_LEFT, iconSize: 27, color: Theme.INK })
      }
        .width(44).height(44).padding(0).backgroundColor(Theme.CARD)
        .border({ width: 1, color: Theme.BORDER, radius: 12 }).borderRadius(12)
        .shadow({ radius: 7, color: '#19000000', offsetX: 0, offsetY: 2 })
        .onClick(() => {
          this.showCommunityMenu = false;
          this.navigateBack();
        })
      Blank()
      Button({ type: ButtonType.Normal }) {
        RemixIcon({
          glyph: this.postFed ? RI.FLASHLIGHT_FILL : RI.FLASHLIGHT,
          iconSize: 24,
          color: this.postFed ? Theme.AMBER : Theme.INK
        })
      }
        .width(36).height(48).padding(0).backgroundColor(Color.Transparent)
        .stateEffect(false)
        .enabled(!this.communityDetailLoading && !this.postFed && !this.postFeeding)
        .opacity(this.communityDetailLoading || this.postFeeding ? 0.45 : 1)
        .onClick(() => this.feedSelectedPost())
      Button({ type: ButtonType.Normal }) {
        RemixIcon({
          glyph: this.postLiked ? RI.HEART_FILL : RI.HEART,
          iconSize: 24,
          color: this.postLiked ? Theme.ACCENT_STRONG : Theme.INK
        })
      }
        .width(36).height(48).padding(0).backgroundColor(Color.Transparent)
        .stateEffect(false)
        .enabled(!this.communityDetailLoading)
        .opacity(this.communityDetailLoading ? 0.45 : 1)
        .onClick(() => this.togglePostLike())
      Stack({ alignContent: Alignment.Center }) {
        Button({ type: ButtonType.Normal }) {
          RemixIcon({ glyph: RI.MORE, iconSize: 24, color: Theme.SECONDARY })
        }
          .width(34).height(34).padding(0).backgroundColor(Theme.CARD)
          .border({ width: 1, color: Theme.BORDER, radius: 11 }).borderRadius(11)
          .shadow({ radius: 7, color: '#19000000', offsetX: 0, offsetY: 2 })
          .enabled(!this.communityDetailLoading)
          .opacity(this.communityDetailLoading ? 0.45 : 1)
          .onClick(() => this.showCommunityMenu = !this.showCommunityMenu)
      }
        .width(56).height(48)
    }
      .height(64)
      .width('100%')
      .padding({ left: 16, right: 5, top: 8, bottom: 8 })
  }

  @Builder
  private communityDetailPage() {
    Column() {
      this.communityDetailHeader()
      if (this.communityDetailLoading) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(34)
            .height(34)
            .color(Theme.ACCENT)
          Text('正在加载文章')
            .fontSize(15)
            .fontColor(Theme.SECONDARY)
        }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
      } else if (this.communityDetailError.length > 0) {
        Column({ space: 14 }) {
          RemixIcon({ glyph: RI.INFORMATION, iconSize: 30, color: Theme.FAINT })
          Text(this.communityDetailError)
            .fontSize(15)
            .fontColor(Theme.SECONDARY)
          Button('重新加载')
            .fontSize(14)
            .fontColor(Theme.WHITE)
            .height(38)
            .backgroundColor(Theme.ACCENT)
            .onClick(() => this.retryCommunityDetail())
        }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
          if (this.selectedPost?.kind === 'prompt') {
            Text('社区提示词').fontSize(12).fontWeight(FontWeight.Bold).fontColor(Theme.PROMPT_TEXT)
              .padding({ left: 9, right: 9, top: 4, bottom: 4 })
              .backgroundColor(Theme.PROMPT_BG).borderRadius(12).margin({ bottom: 10 })
          }
          Text(this.selectedPost?.title ?? '(无题)')
            .fontSize(27).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
            .lineHeight(38).width('100%')
          Row({ space: 8 }) {
            Text(this.communityAuthor(this.selectedPost))
              .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG)
            if (this.communityDate(this.selectedPost).length > 0) {
              Text(this.communityDate(this.selectedPost)).fontSize(14).fontColor(Theme.FAINT)
            }
          }.width('100%').margin({ top: 9, bottom: 14 })
          if (this.selectedReplyParent) {
            Row({ space: 5 }) {
              RemixIcon({ glyph: RI.CHAT, iconSize: 15, color: Theme.ACCENT_STRONG })
              Text('回应').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG)
              Text(this.selectedReplyParent!.title || '原文')
                .fontSize(13).fontColor(Theme.ACCENT_STRONG).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 15, color: Theme.ACCENT_STRONG })
            }
              .height(32).padding({ left: 10, right: 8 }).margin({ bottom: 14 })
              .backgroundColor('#FFF1ED').borderRadius(18).constraintSize({ maxWidth: '100%' })
              .onClick(() => this.openCommunityPost(this.selectedReplyParent!))
          }
          if (this.selectedPost?.kind === 'prompt') {
            Column({ space: 12 }) {
              if ((this.selectedPost?.promptCode ?? '').length > 0) {
                Text('一条 VoiceDrop 提示词 · 分享码')
                  .fontSize(13).fontColor(Theme.SECONDARY).width('100%').textAlign(TextAlign.Center)
                Text(this.selectedPost?.promptCode ?? '')
                  .fontSize(36).fontWeight(FontWeight.Bold).letterSpacing(5)
                  .fontColor(Theme.INK).width('100%').textAlign(TextAlign.Center)
              }
              Text(this.selectedPost?.doc?.articles?.[0]?.body || '这条提示词暂不可读，请稍后刷新。')
                .fontSize(16).lineHeight(27).fontColor(Theme.INK).padding(15)
                .backgroundColor('#F0ECE5').borderRadius(12).width('100%')
                .copyOption(CopyOptions.LocalDevice)
              Text('怎么用').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
                .margin({ top: 10 }).width('100%')
              Text(`收下后可在提示词设置中编辑，并用于${(this.selectedPost?.appliesTo ?? []).includes('image') ? '图片' : '文字'}处理。`)
                .fontSize(14).lineHeight(22).fontColor(Theme.SECONDARY).width('100%')
              Button(PromptTree.containsImport(promptStore.items(), this.selectedPost?.promptCode ?? '') ? '已收下' :
                (this.promptImporting ? '正在导入…' : '收下这条提示词'))
                .enabled(!PromptTree.containsImport(promptStore.items(), this.selectedPost?.promptCode ?? '') && !this.promptImporting)
                .width('100%').height(50).backgroundColor(Theme.ACCENT)
                .onClick(() => this.importSelectedCommunityPrompt())
            }.width('100%')
          } else if (this.selectedPost?.doc && this.selectedPost!.doc!.articles.length > 0) {
            Column({ space: 12 }) {
              ForEach(ArticleBody.blocks(this.selectedPost!.doc!.articles[0].body),
                (block: ArticleBlock) => this.articleBlock(block))
            }.width('100%')
          } else {
            Text(this.selectedPost?.excerpt ?? '')
              .fontSize(17).lineHeight(30).fontColor(Theme.INK).width('100%')
          }
          if (this.communityReplies.length > 0) {
            Row({ space: 12 }) {
              Divider().color('#DDD5C7').layoutWeight(1)
              Text(`${this.communityReplies.length} 篇回应`)
                .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#A79F93').letterSpacing(1)
              Divider().color('#DDD5C7').layoutWeight(1)
            }.width('100%').margin({ top: 30, bottom: 2 })
            ForEach(this.communityReplies, (reply: CommunityPost) => {
              Row() {
                Column().width(3).height('100%').backgroundColor('#E8C7B8').borderRadius(2)
                Column({ space: 8 }) {
                  Row() {
                    Text(this.communityAuthor(reply)).fontSize(13).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.ACCENT_STRONG)
                    Text(`  续文${this.communityDate(reply).length > 0 ? ` · ${this.communityDate(reply)}` : ''}`)
                      .fontSize(12).fontColor('#9A9387')
                  }.width('100%')
                  Text(reply.title || reply.excerpt)
                    .fontSize(18).fontWeight(FontWeight.Bold).lineHeight(27).fontColor(Theme.INK).width('100%')
                }.padding({ left: 16 }).layoutWeight(1).alignItems(HorizontalAlign.Start)
              }
                .padding({ top: 24 }).width('100%').alignItems(VerticalAlign.Top)
                .onClick(() => this.openCommunityPost(reply))
            }, (reply: CommunityPost) => reply.shareId)
          }
          }
            .padding({ left: 22, right: 22, top: 12, bottom: 40 })
            .alignItems(HorizontalAlign.Start)
            .width('100%')
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }

  @Builder
  private communityMenuRow(label: string, glyph: string, action: string, danger: boolean = false) {
    Row() {
      Text(label)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(danger ? Theme.ACCENT_STRONG : Theme.INK)
        .layoutWeight(1)
      RemixIcon({
        glyph: glyph,
        iconSize: 25,
        color: Theme.ACCENT_STRONG
      })
    }
      .height(57)
      .padding({ left: 20, right: 20 })
      .width('100%')
      .onClick(() => this.runCommunityMenuAction(action))
  }

  @Builder
  private communityMoreMenu() {
    Column() {
      if (this.selectedPost?.kind !== 'prompt') {
        this.communityMenuRow('写回应', RI.MIC, 'reply')
        Divider().color('#E7E0D5')
      }
      this.communityMenuRow('分享到微信', RI.SHARE_BOX, 'wechat')
      Divider().color('#E7E0D5')
      this.communityMenuRow('分享', RI.SHARE_BOX, 'share')
      Divider().color('#E7E0D5')
      this.communityMenuRow('举报', RI.FLAG, 'report', true)
      Divider().color('#E7E0D5')
      this.communityMenuRow('屏蔽此用户', RI.HAND_HEART, 'block', true)
    }
      .padding({ top: 3, bottom: 3 })
      .width(292)
      .backgroundColor('#FCFFFFFF')
      .border({ width: 1, color: '#ECE7DE', radius: 18 })
      .borderRadius(18)
      .clip(true)
      .shadow({ radius: 18, color: '#2B2A2521', offsetX: 0, offsetY: 8 })
  }

  private async sendEdit(): Promise<void> {
    if (!this.editSession || this.editText.trim().length === 0) return;
    const answer: string = this.editText.trim();
    const question: FollowupQuestion | undefined = this.pendingQuestion();
    const text: string = question ? `【回答追问】问题：「${question.text}」我的口述回答：「${answer}」把回答里的信息织进正文最相关的段落——只用回答里出现的事实，不照抄问题本身、不动无关段落。` : answer;
    this.editText = '';
    await this.editSession.sendEdit(`${Date.now()}`, text, this.selectedArticle);
    if (question && this.selected) {
      question.status = 'answered'; this.article = this.article;
      libraryStore.patchQuestion(this.selected, question.id, 'answered').catch(() => {});
    }
    promptAction.showToast({ message: question ? '追问回答已发送' : '修改要求已发送' });
  }

  private pendingQuestion(): FollowupQuestion | undefined {
    return this.article?.questions?.find((question: FollowupQuestion) =>
      (question.articleIndex ?? 0) === this.selectedArticle && question.status === 'pending');
  }

  private async skipQuestion(): Promise<void> {
    const question: FollowupQuestion | undefined = this.pendingQuestion();
    if (!question || !this.selected) return;
    question.status = 'skipped'; this.article = this.article;
    const ok: boolean = await libraryStore.patchQuestion(this.selected, question.id, 'skipped');
    promptAction.showToast({ message: ok ? '已跳过追问' : '跳过状态同步失败' });
  }

  private togglePostLike(): void {
    if (!this.selectedPost) return;
    const next: boolean = CommunityLikeState.toggled(this.postLiked);
    this.postLiked = next;
    this.selectedPost.liked = next;
    this.selectedPost.likes = Math.max(0, this.selectedPost.likes + (next ? 1 : -1));
    const shareId: string = this.selectedPost.shareId;
    appPreferences.setLikedCommunityPost(shareId, next).catch(() => {});
    communityStore.engage(shareId, 'like', next).catch(() => {});
  }

  private async shareSelectedCommunityPost(): Promise<void> {
    if (!this.selectedPost) return;
    const url: string = Api.sharePage(this.selectedPost.shareId);
    try {
      await this.showTextShare(url, this.selectedPost.title || 'VoiceDrop 社区文章');
    } catch (_) {
      await pasteboard.getSystemPasteboard().setData(pasteboard.createPlainTextData(url));
      promptAction.showToast({ message: '分享链接已复制' });
    }
  }

  private async feedSelectedPost(): Promise<void> {
    if (!this.selectedPost || this.postFed || this.postFeeding) return;
    this.postFeeding = true;
    try {
      const result: CommunityFeedResult = await communityStore.feedPost(this.selectedPost.shareId);
      if (result.ok || result.already) {
        this.postFed = true;
        if (!result.already) this.postFeedCount++;
        const message: string = result.already ? '已经投过这条了' :
          `已投币：你 +${result.feederSuanli}，作者 +${result.authorSuanli} 算力`;
        promptAction.showToast({ message: message });
      } else if (result.error === 'cannot_feed_own') promptAction.showToast({ message: '不能给自己的内容投币' });
      else if (result.error === 'pool_exhausted') promptAction.showToast({ message: '今日算力池已发完，明天再来' });
      else if (result.needsWechatSignin()) { promptAction.showToast({ message: '投币需要先用微信登录' }); this.navigateTo('account'); }
      else promptAction.showToast({ message: '投币失败，请稍后再试' });
    } catch (error) { promptAction.showToast({ message: `投币失败：${String(error)}` }); }
    finally { this.postFeeding = false; }
  }

  private async blockSelectedAuthor(): Promise<void> {
    if (!this.selectedPost || this.selectedPost.author.trim().length === 0) return;
    const author: string = this.selectedPost.author;
    const result = await promptAction.showDialog({
      title: '屏蔽此用户？',
      message: `屏蔽后，你将不再看到 ${author} 的任何社区内容。可在「设置」>「关于」>「已屏蔽用户」中取消屏蔽。`,
      buttons: [{ text: '取消', color: '#666666' }, { text: '屏蔽', color: Theme.ACCENT_STRONG }]
    });
    if (result.index !== 1) return;
    await appPreferences.setAuthorBlocked(author, true);
    promptAction.showToast({ message: '已屏蔽，TA 的内容将不再显示' });
    this.navigateHome();
    await this.refreshCommunity();
  }

  private async shareRecording(): Promise<void> {
    if (!this.selected || !this.article || !this.context) return;
    const url: string = await libraryStore.shareUrl(this.selected, this.selectedArticle);
    if (url.length === 0) { promptAction.showToast({ message: '无法生成分享链接' }); return; }
    const articleText: string = ArticleBody.shareText(this.article.articles);
    const text: string = `${articleText}\n\n${url}`.trim();
    const title: string = this.article.articles[Math.min(this.selectedArticle, this.article.articles.length - 1)]?.title ??
      this.selected.rowTitle();
    try {
      await this.showTextShare(text, title);
    } catch (_) {
      await pasteboard.getSystemPasteboard().setData(pasteboard.createPlainTextData(text));
      promptAction.showToast({ message: '无法打开分享面板，文章和链接已复制' });
    }
  }

  private async publishWechat(): Promise<void> {
    if (!this.selected) return;
    const response = await libraryStore.publishWechat(this.selected);
    if (response.code === 409) this.navigateTo('wechat');
    else promptAction.showToast({ message: response.ok() ? '已发送到公众号草稿箱' : `发布失败 HTTP ${response.code}` });
  }

  private async shareToXhs(): Promise<void> {
    if (!this.selected || !this.context || this.xhsPreparing) return;
    this.xhsPreparing = true;
    promptAction.showToast({ message: '正在生成小红书文案…' });
    try {
      const pack: XhsPack | undefined = await libraryStore.xhsPack(this.selected);
      if (!pack || pack.clipboardText().length === 0) {
        promptAction.showToast({ message: '小红书文案生成失败，稍后再试' }); return;
      }
      const text: string = pack.clipboardText();
      await pasteboard.getSystemPasteboard().setData(pasteboard.createPlainTextData(text));
      promptAction.showToast({ message: '文案已复制，请在分享面板中选择小红书' });
      await this.showTextShare(text, pack.title || 'VoiceDrop 小红书文案');
    } catch (error) { promptAction.showToast({ message: `小红书文案生成失败：${String(error)}` }); }
    finally { this.xhsPreparing = false; }
  }

  private async insertPhotos(): Promise<void> {
    if (!this.selected || !this.editSession) return;
    try {
      const photos: UploadedPhoto[] = await photoService.pickAndUpload(this.selected.name);
      if (photos.length === 0) return;
      const markers: string = photos.map((photo: UploadedPhoto) => `[[photo:${photo.key}]]`).join('、');
      await this.editSession.sendEdit(`${Date.now()}`, `请把这些图片插入文章最合适的位置：${markers}。正文其他内容不要改。`, this.selectedArticle);
      promptAction.showToast({ message: `${photos.length} 张图片已上传，正在插入文章` });
    } catch (error) {
      promptAction.showToast({ message: `插图失败：${String(error)}` });
    }
  }

  @Builder
  private stylePage() {
    StyleSettingsPage({ onBack: () => this.navigateBack() })
  }

  @Builder
  private wechatPage() {
    WechatSettingsPage({ onBack: () => this.navigateBack() })
  }

  @Builder
  private accountPage() {
    AccountPage({
      loggedIn: this.wechatLoggedIn,
      recordingNames: this.recordings.map((recording: Recording) => recording.name),
      recordingCount: this.recordings.length,
      articleCount: this.recordings.filter((recording: Recording) => recording.hasArticles).length,
      onBack: () => this.navigateBack(),
      onWechatLogin: () => this.startWechatLogin(),
      onWechatSignOut: async () => {
        const previousScope: string = authStore.storageScope();
        await authStore.signOutWechat();
        this.wechatLoggedIn = false;
        await this.applyAccountIdentityChange(previousScope !== authStore.storageScope());
        promptAction.showToast({ message: '已退出微信登录，已恢复原账号' });
      },
      onAccountChanged: () => { this.applyAccountIdentityChange(false).catch(() => {}); },
      onDeleted: () => { this.applyAccountIdentityChange(false).catch(() => {}); }
    })
  }

  private async openSupportEmail(): Promise<void> {
    if (!this.context) return;
    try {
      await this.context.startAbility({ action: 'ohos.want.action.viewData',
        uri: `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent('VoiceDrop 反馈与投诉')}` });
    } catch (_) { promptAction.showToast({ message: '无法打开邮件客户端' }); }
  }

  @Builder
  private secondaryPageContent(page: string) {
    if (page === 'detail') this.detailPage()
    else if (page === 'communityDetail') this.communityDetailPage()
    else if (page === 'shared') SharedArticlePage({
      article: this.sharedArticle,
      selectedIndex: $sharedArticleIndex,
      onBack: () => this.navigateBack()
    })
    else if (page === 'settings') SettingsPage({
      onBack: () => this.navigateBack(),
      onNavigate: (target: SettingsTarget) => this.navigateTo(target),
      onInvite: () => this.shareInvite(),
      onAutoShareChange: (value: boolean) => this.setAutoShareCommunity(value),
      onExport: () => this.exportAllData(),
      wechatAuthenticated: authStore.isWechatAuthenticated(),
      autoShareCommunity: this.autoShareCommunity,
      savingAutoShare: this.savingAutoShare,
      preparingInvite: this.preparingInvite,
      exporting: this.exporting
    })
    else if (page === 'style') this.stylePage()
    else if (page === 'wechat') this.wechatPage()
    else if (page === 'account') this.accountPage()
    else if (page === 'prompts') PromptSettingsPage({ onBack: () => this.navigateBack(), initialCode: this.promptImportCode })
    else if (page === 'blocked') BlockedAuthorsPage({ onBack: () => this.navigateBack() })
    else if (page === 'privacy') PrivacyPolicyPage({ onBack: () => this.navigateBack() })
    else if (page === 'usage') UsagePage({ onBack: () => this.navigateBack() })
    else if (page === 'about') AboutPage({
      onBack: () => this.navigateBack(),
      onPrivacy: () => this.navigateTo('privacy'),
      onBlockedAuthors: () => this.navigateTo('blocked'),
      onContact: () => this.openSupportEmail(),
      appVersion: this.appVersion,
      blockedAuthorCount: appPreferences.blockedAuthors().length
    })
    else Column({ space: 8 }) {
      Text('页面不存在').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
      Text(page).fontSize(13).fontColor(Theme.SECONDARY)
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder
  private navigationDestination(routeName: string) {
    NavDestination() {
      Column() {
        this.secondaryPageContent(routeName)
      }
        .width('100%')
        .height('100%')
        .padding({ top: this.safeAreaTop() })
        .backgroundColor(Theme.BG)
    }
      .hideTitleBar(true)
      // Keep NavDestination's default back handling so the system back gesture
      // and the page header both pop the same native stack.
      .onHidden(() => this.handleDestinationHidden(routeName))
  }

  @Builder
  private homeRoot() {
    if (this.tab === 0) this.libraryPage()
    else this.communityPage()
  }

  build() {
    Stack() {
      Navigation(this.pathStack) {
        Column() {
          this.homeRoot()
        }
          .width('100%')
          .height('100%')
          .padding({ top: this.safeAreaTop() })
          .backgroundColor(this.tab === 1 ? Theme.COMMUNITY_BG : Theme.BG)
      }
        .width('100%')
        .height('100%')
        .mode(NavigationMode.Stack)
        .hideTitleBar(true)
        .recoverable(false)
        .navDestination(this.navigationDestination)
      if (this.recording) {
        RecordingSession({
          recordingSeconds: this.recordingSeconds,
          activeLevel: this.recordingLevel,
          interviewActive: this.interviewActive,
          interviewStatus: this.interviewStatus,
          capturedPhotos: this.capturedPhotos,
          transitioning: this.recordingTransitioning,
          showInterview: !appPreferences.classicRecorder(),
          safeAreaTop: this.safeAreaTop(),
          safeAreaBottom: this.safeAreaBottom(),
          onStop: () => this.toggleRecording().catch(() => {}),
          onAddPhoto: () => this.addRecordingPhotos().catch(() => {}),
          onToggleInterview: () => this.toggleInterview().catch(() => {}),
          onRemovePhoto: (photo: CapturedPhoto) => this.removeRecordingPhoto(photo).catch(() => {})
        })
          .zIndex(100)
          // Recording is a full-screen session overlay, not a secondary page.
          // Keep it out of Navigation's horizontal page transition.
          .transition(TransitionEffect.IDENTITY)
      }
      if (this.showPromptMenu) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.showPromptMenu = false)
          Column() {
            Row() {
              Text(this.promptMenuTitle).fontSize(19).fontWeight(FontWeight.Bold).layoutWeight(1)
              Button('取消').fontSize(14).backgroundColor(Color.Transparent).fontColor('#666666').onClick(() => this.showPromptMenu = false)
            }.height(54).padding({ left: 18, right: 10 }).width('100%')
            if (this.promptMenuNested) {
              Row() { Text('返回').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#777777') }
                .height(48).padding({ left: 18, right: 18 }).width('100%').onClick(() => this.showPromptRoot())
              Divider().color('#D8D4CC')
              Scroll() { this.configuredPromptList(this.promptMenuNodes) }.constraintSize({ maxHeight: 360 }).width('100%')
            } else {
              if (this.systemPromptMenuNodes().length > 0) this.configuredPromptList(this.systemPromptMenuNodes())
              if (this.systemPromptMenuNodes().length > 0 && this.customPromptMenuNodes().length > 0) Divider().color('#D8D4CC')
              if (this.customPromptMenuNodes().length > 0) {
                Scroll() { this.configuredPromptList(this.customPromptMenuNodes()) }.constraintSize({ maxHeight: 300 }).width('100%')
              }
              if (this.promptTargetKind !== 'photo') {
                Divider().color('#D8D4CC')
                Row() {
                  Text('拷贝').fontSize(16).fontColor('#252525').layoutWeight(1).onClick(() => this.copyPromptTarget())
                  Text('编辑全文').fontSize(16).fontColor('#252525').onClick(() => this.editPromptTarget())
                }.height(50).padding({ left: 18, right: 18 }).width('100%')
              }
            }
          }.padding({ bottom: 18 }).backgroundColor('#FCFCFB')
            .borderRadius({ topLeft: 14, topRight: 14 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#55000000')
      }
      if (this.showDetailMenu) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column()
            .width('100%')
            .height('100%')
            .onClick(() => this.showDetailMenu = false)
          Column() {
            this.detailMoreMenu()
          }
            .margin({ top: this.safeAreaTop() + 68, right: 10 })
            .zIndex(1)
        }
          .width('100%')
          .height('100%')
          .zIndex(120)
      }
      if (this.showCommunityMenu) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column()
            .width('100%')
            .height('100%')
            .onClick(() => this.showCommunityMenu = false)
          Column() {
            this.communityMoreMenu()
          }
            .margin({ top: this.safeAreaTop() + 64, right: 12 })
            .zIndex(1)
        }
          .width('100%')
          .height('100%')
          .zIndex(120)
      }
      if (this.showDirectEditor) {
        Column({ space: 12 }) {
          Row() {
            Text('直接编辑文章').fontSize(21).fontWeight(FontWeight.Bold).layoutWeight(1)
            Button('取消').backgroundColor(Color.Transparent).fontColor('#666666').onClick(() => this.showDirectEditor = false)
          }.width('100%')
          TextInput({ text: this.directTitle, placeholder: '文章标题' }).onChange((value: string) => this.directTitle = value).backgroundColor('#F1F1EF')
          TextArea({ text: this.directBody, placeholder: '文章正文（图片使用 [[photo:key]]）' })
            .onChange((value: string) => this.directBody = value).layoutWeight(1).width('100%').backgroundColor('#F1F1EF')
          Button('保存文章').width('100%').height(48).backgroundColor(Theme.ACCENT).onClick(() => this.saveDirectEdit())
        }.padding({ left: 20, right: 20, top: 20, bottom: 24 }).width('100%').height('92%')
          .backgroundColor(Color.White).borderRadius({ topLeft: 22, topRight: 22 }).align(Alignment.Bottom)
      }
      if (this.showHistoryBrowser) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.showHistoryBrowser = false)
          Column({ space: 10 }) {
            Row() { Text('文章版本').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1); Button('关闭').onClick(() => this.showHistoryBrowser = false) }
            Scroll() {
              Column({ space: 8 }) {
                ForEach(this.history.versions.slice().reverse(), (version: ArticleVersion) => {
                  Row() {
                    Column({ space: 3 }) {
                      Text(`版本 ${version.v}${version.v === this.history.head ? ' · 当前' : ''}`).fontSize(16).fontWeight(FontWeight.Medium)
                      Text(version.savedAt ?? version.createdAt ?? version.source ?? '').fontSize(12).fontColor('#888888')
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 21, color: Theme.FAINT })
                  }.padding(13).backgroundColor(version.v === this.history.head ? '#EAF7F1' : '#F4F4F1').borderRadius(10).width('100%')
                    .onClick(() => this.selectHistoryVersion(version))
                }, (version: ArticleVersion) => `${version.v}`)
              }.width('100%')
            }.constraintSize({ maxHeight: 430 })
          }.padding({ left: 18, right: 18, top: 18, bottom: 28 }).backgroundColor(Color.White)
            .borderRadius({ topLeft: 22, topRight: 22 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#55000000')
      }
      if (this.showStyleRewrite) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.showStyleRewrite = false)
          Column({ space: 10 }) {
            Row() { Text('选择写作文风').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1); Button('关闭').onClick(() => this.showStyleRewrite = false) }
            Text('已生成过的文风可直接切换；其他版本会实时重写当前文章。').fontSize(13).fontColor('#777777').width('100%')
            Scroll() {
              Column({ space: 8 }) {
                ForEach(this.styleRewriteHistory.versions.slice().reverse(), (version: StyleVersion) => {
                  Row() {
                    Column({ space: 4 }) {
                      Text(`v${version.v}${this.styleRewriteHistory.head === version.v ? ' · 当前文风' : ''}`).fontSize(16).fontWeight(FontWeight.Bold)
                      Text(version.style).fontSize(13).fontColor('#666666').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    Text(this.generatedStyleVersion(version.v) ? '切换' : '重写').fontSize(13).fontColor('#16825D')
                  }.padding(13).backgroundColor('#F4F4F1').borderRadius(11).width('100%').onClick(() => this.requestStyleRewrite(version.v))
                }, (version: StyleVersion) => `${version.v}`)
              }.width('100%')
            }.constraintSize({ maxHeight: 430 })
          }.padding({ left: 18, right: 18, top: 18, bottom: 28 }).backgroundColor(Color.White)
            .borderRadius({ topLeft: 22, topRight: 22 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#55000000')
      }
      if (this.restylePreviewActive) {
        Column() {
          Scroll() {
            Column({ space: 12 }) {
              Text('正在用新文风重写…').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#666666').width('100%')
              Text(this.restylePreviewText).fontSize(16).lineHeight(27).width('100%')
            }.padding(20).alignItems(HorizontalAlign.Start).backgroundColor('#FFFFFB').borderRadius(16).width('90%')
          }.width('100%').constraintSize({ maxHeight: '80%' }).align(Alignment.Center)
        }.justifyContent(FlexAlign.Center).width('100%').height('100%').backgroundColor('#88000000')
      }
      if (this.showIncomingShare) {
        Column() {
          Blank().layoutWeight(1)
          Column({ space: 14 }) {
            Row() {
              Text(this.incomingShareTitle).fontSize(21).fontWeight(FontWeight.Bold).layoutWeight(1)
              Button('关闭').fontSize(15).fontColor('#666666').backgroundColor(Color.Transparent)
                .enabled(!this.importingShare).onClick(() => this.cancelIncomingShare())
            }.width('100%')
            Text(this.incomingShareDescription).fontSize(14).lineHeight(22).fontColor('#666666').width('100%')
            if (this.incomingShareExcerpt.length > 0) {
              Scroll() {
                Text(this.incomingShareExcerpt).fontSize(14).lineHeight(22).fontColor('#333333').width('100%')
              }.padding(14).backgroundColor('#F4F1EB').borderRadius(12).width('100%').constraintSize({ maxHeight: 180 })
            }
            Row({ space: 10 }) {
              Button('取消').layoutWeight(1).height(50).fontColor('#333333').backgroundColor('#E8E8E5')
                .enabled(!this.importingShare).onClick(() => this.cancelIncomingShare())
              Button(this.importingShare ? '处理中…' : (this.incomingShareTitle === '加入风格数据集' ? '收集并提取文风' : '开始生成文章'))
                .layoutWeight(1).height(50).fontColor(Color.White).backgroundColor('#D92D20')
                .enabled(!this.importingShare).onClick(() => this.confirmIncomingShare())
            }.width('100%')
          }.padding({ left: 20, right: 20, top: 18, bottom: 28 }).backgroundColor('#FAF6EF')
            .borderRadius({ topLeft: 22, topRight: 22 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#66000000')
      }
      if (this.showPrivacy) {
        Column({ space: 18 }) {
          Text('欢迎使用 VoiceDrop').fontSize(24).fontWeight(FontWeight.Bold)
          if (this.consentPolicyExpanded) {
            Scroll() {
              Text(PRIVACY_TEXT).fontSize(14).lineHeight(23).fontColor('#333333').width('100%')
            }.height('55%').width('100%').padding(12).backgroundColor('#F5F3EE').borderRadius(12)
            Button('收起隐私政策').fontSize(14).fontColor('#555555').backgroundColor(Color.Transparent)
              .onClick(() => this.consentPolicyExpanded = false)
          } else {
            Text('开始前，请阅读并同意隐私保护说明。录音仅在你主动点击后开始，并用于转写和生成文章；相册与相机仅在插图时使用。').fontSize(16).lineHeight(25)
            Button('查看完整隐私政策').fontSize(14).fontColor('#16825D').backgroundColor(Color.Transparent)
              .onClick(() => this.consentPolicyExpanded = true)
          }
          Row({ space: 10 }) {
            Button('退出使用').layoutWeight(1).backgroundColor('#E8E8E5').fontColor('#333333').onClick(() => this.context?.terminateSelf())
            Button('同意并继续').layoutWeight(1).backgroundColor(Theme.ACCENT).onClick(() => this.acceptPrivacy())
          }.width('100%')
        }.padding(24).width('88%').backgroundColor(Color.White).borderRadius(22).shadow({ radius: 28, color: '#33000000' })
      }
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }
}
