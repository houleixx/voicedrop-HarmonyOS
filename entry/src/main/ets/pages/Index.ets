import { bundleManager, common, Permissions } from '@kit.AbilityKit';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { ColorMetrics, FrameNode, LengthMetrics, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { ArticleBody, ArticleBlock } from '../core/ArticleBody';
import {
  ArticleEditEvent,
  ArticleEditFeedback,
  ArticleEditQueueItem,
  ArticleEditQueueState,
  ArticleEditUi
} from '../core/ArticleEditUi';
import { ArticlePhotoInsert } from '../core/ArticlePhotoInsert';
import { ArticleVersionNavigation } from '../core/ArticleVersionNavigation';
import { Api } from '../core/Api';
import { PhotoLoadIntent, PhotoLoadPolicy } from '../core/PhotoLoadPolicy';
import { LibraryCommandEvent, LibraryCommandFeedback, LibraryCommandGestureAction, LibraryCommandTarget, LibraryCommandTone, LibraryCommandUi } from '../core/LibraryCommandUi';
import { PromptNode, PromptTree } from '../core/PromptTree';
import { RecordingListUi } from '../core/RecordingListUi';
import { RecordingName } from '../core/RecordingName';
import { isRecordingTooShort } from '../core/RecordingPolicy';
import { normalizeAmplitude } from '../core/RecordingUi';
import { StyleRewriteUi } from '../core/StyleRewriteUi';
import { RestyleResult } from '../core/RestyleRequest';
import { Recording, ArticleDoc, ArticleHistory, ArticleVersion, FollowupQuestion, MinedArticle, CommunityPost } from '../model/Models';
import { authStore } from '../data/AuthStore';
import { appPreferences } from '../data/AppPreferences';
import { umengAnalytics } from '../data/UmengAnalytics';
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
import { ArticleEditSession, EditAnchor, EditImage, StatusSession, LibraryCommandSession, CommandRef } from '../net/AgentSocket';
import { AboutPage } from './AboutPage';
import { AccountPage } from './AccountPage';
import { AppPage } from './AppPage';
import { COMMUNITY_TERMS, SUPPORT_EMAIL } from '../core/CommunityTerms';
import { CommunityLikeState } from '../core/CommunityLikeState';
import { CommunityLikePresentation } from '../core/CommunityLikePresentation';
import { CommunityReplyUi } from '../core/CommunityReplyUi';
import { CommunityShareUi } from '../core/CommunityShareUi';
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
import { WechatAuthResponse } from '../core/WechatAuthResponse';
import { CommandGestureGate, CommandGestureState } from '../core/CommandGestureGate';
import { HoldToTalkTranscript } from '../core/HoldToTalkTranscript';
import { ArticlePhotoView } from '../components/ArticlePhotoView';
import { CommunityReplyRecordingDock } from '../components/CommunityReplyRecordingDock';
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
  id?: string;
  text?: string;
  message?: string;
  article?: ArticleDoc;
  doc?: ArticleDoc;
  items?: PreviewDeltaValue[];
  ok?: boolean;
  queue?: ArticleEditQueueState[];
}
interface PendingCommunityShareValue { articleKey: string; replyTo?: string; createdAt?: number; }
const RECORDING_METER_INTERVAL_MS: number = 100;
const PARAGRAPH_EDIT_INPUT_ID: string = 'paragraph-inline-edit-input';

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
  @StorageLink('windowHeightPx') private windowHeightPx: number = 0;
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
  @State private libraryRefreshStatus: RefreshStatus = RefreshStatus.Inactive;
  @State private communityRefreshStatus: RefreshStatus = RefreshStatus.Inactive;
  @State private libraryRefreshOffset: number = 0;
  @State private communityRefreshOffset: number = 0;
  @State private errorText: string = '';
  @State private recording: boolean = false;
  @State private recordingTransitioning: boolean = false;
  @State private recordingSeconds: number = 0;
  @State private recordingLevel: number = 0;
  @State private communityReplyRecording: boolean = false;
  @State private interviewActive: boolean = false;
  @State private interviewStatus: string = '';
  @State private capturedPhotos: CapturedPhoto[] = [];
  @State private showPrivacy: boolean = false;
  @State private consentPolicyExpanded: boolean = false;
  @State private editText: string = '';
  @State private articleEditQueue: ArticleEditQueueItem[] = [];
  @State private articleEditReply: string = '';
  @State private articleEditReplyOk: boolean = true;
  @State private selectedArticle: number = 0;
  @State private playing: boolean = false;
  @State private playbackLoading: boolean = false;
  @State private insertingPhotos: boolean = false;
  @State private xhsPreparing: boolean = false;
  @State private playbackProgress: number = 0;
  @State private playbackDuration: number = 0;
  @State private history: ArticleHistory = new ArticleHistory();
  @State private communityShareId: string = '';
  private communityShareGeneration: number = 0;
  @State private selectedPost?: CommunityPost = undefined;
  @State private selectedReplyParent?: CommunityPost = undefined;
  @State private communityReplies: CommunityPost[] = [];
  @State private communityDetailLoading: boolean = false;
  @State private communityDetailError: string = '';
  @State private postFed: boolean = false;
  @State private postLiked: boolean = false;
  @State private postFeedCount: number = 0;
  @State private postFeeding: boolean = false;
  private communityLikeRequest?: Promise<boolean>;
  private communityLikeShareId: string = '';
  private communityLikeTargetCount: number = -1;
  private communityLikeTargetLiked: boolean = false;
  private communityLikeSucceeded: boolean = false;
  private communityDetailDirty: boolean = false;
  @State private showCommunityMenu: boolean = false;
  @State private promptImporting: boolean = false;
  @State private wechatLoggedIn: boolean = false;
  @State private wechatLoggingIn: boolean = false;
  @State private pendingReplyTarget: string = '';
  @State private showPromptMenu: boolean = false;
  @State private promptMenuNodes: PromptNode[] = [];
  @State private promptMenuNested: boolean = false;
  @State private promptMenuAnchorX: number = 16;
  @State private promptMenuAnchorY: number = 160;
  @State private promptTargetKind: string = '';
  @State private promptTargetValue: string = '';
  @State private promptTargetIndex: number = -1;
  @State private promptTargetLine: number = 0;
  @State private libraryCommand: string = '';
  @State private commandState: string = '';
  @State private commandStateTone: LibraryCommandTone = LibraryCommandTone.Hidden;
  @State private commandTalking: boolean = false;
  @State private commandCanceled: boolean = false;
  @State private commandTranscriptText: string = '';
  @State private commandTranscriptConfirming: boolean = false;
  @State private paragraphEditing: boolean = false;
  @State private paragraphEditText: string = '';
  @State private paragraphEditSaving: boolean = false;
  @State private showHistoryBrowser: boolean = false;
  @State private dictating: boolean = false;
  @State private dictationState: string = '';
  @State private holdEditPressed: boolean = false;
  @State private holdEditCanceled: boolean = false;
  @State private holdEditFinishing: boolean = false;
  @State private holdEditPromptText: string = '';
  @State private holdEditTranscriptText: string = '';
  @State private exporting: boolean = false;
  @State private showStyleRewrite: boolean = false;
  @State private styleRewriteLoading: boolean = false;
  @State private styleRewriteError: string = '';
  @State private styleRewriteHistory: StyleHistory = new StyleHistory();
  @State private selectedStyleRewriteVersion: number = -1;
  @State private restylePreviewActive: boolean = false;
  @State private historySwitching: boolean = false;
  @State private showArticleLines: boolean = false;
  @State private promptImportCode: string = '';
  @State private showIncomingShare: boolean = false;
  @State private incomingShareTitle: string = '';
  @State private incomingShareDescription: string = '';
  @State private incomingShareExcerpt: string = '';
  @State private importingShare: boolean = false;
  @State private appVersion: string = '0.1.0';
  @State private blockedAuthorCount: number = 0;
  @State private checkingUpdate: boolean = false;
  @State private autoShareCommunity: boolean = false;
  @State private savingAutoShare: boolean = false;
  @State private preparingInvite: boolean = false;
  @State private sharedArticle?: ArticleDoc = undefined;
  @State private sharedArticleIndex: number = 0;
  @State private generatedPhotoKeys: string[] = [];
  @State private pendingPhotoKeys: string[] = [];
  @State private makingGeneratedPhotoKeys: string[] = [];
  @State private thumbnailFallbackKeys: string[] = [];
  @State private recordingThumbnailFallbackKeys: string[] = [];
  @State private recordingPhotoFailureKeys: string[] = [];
  private context?: common.UIAbilityContext;
  private timer: number = -1;
  private recordingMeterSampling: boolean = false;
  private statusSession?: StatusSession;
  private editSession?: ArticleEditSession;
  private commandSession?: LibraryCommandSession;
  private dictation?: AsrDictation;
  private commandHoldPressed: boolean = false;
  private commandLongPressed: boolean = false;
  private commandHoldStartY: number = 0;
  private commandHoldTimer: number = -1;
  private commandTranscriptConfirmTimer: number = -1;
  private commandRecognizing: boolean = false;
  private commandFinalized: boolean = false;
  private commandGestureGate: CommandGestureGate = new CommandGestureGate();
  private commandTranscript: HoldToTalkTranscript = new HoldToTalkTranscript();
  private commandPrimePromise?: Promise<boolean>;
  private commandDictationGeneration: number = 0;
  private commandLibraryRefreshRunning: boolean = false;
  private commandLibraryRefreshQueued: boolean = false;
  private commandLibraryRefreshStems: string[] = [];
  private interviewer?: RealtimeInterviewer;
  private dictationTarget: string = '';
  private dictationPrefix: string = '';
  private holdEditStartY: number = 0;
  private holdEditOriginalText: string = '';
  private holdEditShouldSend: boolean = false;
  private holdEditCompleted: boolean = false;
  private paragraphEditLine: number = 0;
  private paragraphEditArticleIndex: number = -1;
  private paragraphEditOriginal: string = '';
  private paragraphEditRenderedBody: string = '';
  private deferredParagraphArticle?: ArticleDoc;
  private paragraphEditController: TextAreaController = new TextAreaController();
  private restyleFinishing: boolean = false;
  private restyleTargetStyleVersion: number = -1;
  private processingReplies: Set<string> = new Set<string>();
  private pendingLinkId: string = '';
  private pendingLinkPubkey: string = '';
  private linkDialogShowing: boolean = false;
  private settledLinkIds: Set<string> = new Set<string>();
  private incomingShare?: IncomingShareDraft;
  private defaultRecordTag: string = '';
  private recordingDetailOpenBlockedUntil: number = 0;
  private detailLoadSequence: number = 0;
  private communityDetailLoadSequence: number = 0;
  private pendingPhotoRequests: Map<string, string> = new Map<string, string>();
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
    if (routeName === 'blocked') {
      // Wait for NavPathStack to finish popping the blocked page before
      // replacing the cached About page with one bound to the latest count.
      setTimeout(() => this.reopenAboutAfterBlockedAuthors(), 0);
    }
    if (routeName === 'detail') {
      this.showDetailMenu = false;
      this.showPromptMenu = false;
      this.closeParagraphEdit(false);
      this.showHistoryBrowser = false;
      this.showStyleRewrite = false;
      this.clearPendingPhotoEdits();
      this.editSession?.close();
      audioPlayback.stop().catch(() => {});
    }
    if (routeName === 'communityDetail') {
      this.showCommunityMenu = false;
      if (this.communityReplyRecording) this.cancelCommunityReplyRecording().catch(() => {});
      if (this.communityDetailDirty) {
        this.communityDetailDirty = false;
        this.refreshCommunityAfterDetail().catch(() => {});
      }
    }
  }

  private reopenAboutAfterBlockedAuthors(): void {
    this.blockedAuthorCount = appPreferences.blockedAuthors().length;
    const paths: string[] = this.pathStack.getAllPathName();
    if (paths.length === 0 || paths[paths.length - 1] !== 'about') return;
    this.pathStack.removeByName('about');
    this.pathStack.pushPath({ name: 'about' });
  }

  /**
   * Match the mini program's onShow -> loadCommunity behavior when a community
   * detail route is popped. Wait for a pending like write so the fresh feed does
   * not race the engagement request and restore the old count.
   */
  private async refreshCommunityAfterDetail(): Promise<void> {
    const likeRequest: Promise<boolean> | undefined = this.communityLikeRequest;
    let likeSucceeded: boolean = this.communityLikeSucceeded;
    if (likeRequest) likeSucceeded = await likeRequest.catch(() => false);
    await this.refreshCommunity(false);
    if (likeSucceeded) this.reapplyCommunityLikeTarget();
    this.communityLikeRequest = undefined;
    this.communityLikeShareId = '';
    this.communityLikeTargetCount = -1;
    this.communityLikeSucceeded = false;
  }

  private reapplyCommunityLikeTarget(): void {
    if (this.communityLikeShareId.length === 0 || this.communityLikeTargetCount < 0) return;
    this.communityRecommended = CommunityLikePresentation.applyTarget(
      this.communityRecommended, this.communityLikeShareId,
      this.communityLikeTargetCount, this.communityLikeTargetLiked);
    this.communityLatest = CommunityLikePresentation.applyTarget(
      this.communityLatest, this.communityLikeShareId,
      this.communityLikeTargetCount, this.communityLikeTargetLiked);
    this.updateCommunityFilter();
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
    this.clearCommandTranscriptConfirmation();
    ++this.commandDictationGeneration;
    this.commandGestureGate.cancel();
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
    this.blockedAuthorCount = appPreferences.blockedAuthors().length;
    this.showPrivacy = !appPreferences.privacyAccepted();
    if (!this.showPrivacy) await this.activateBusiness();
  }

  private async activateBusiness(): Promise<void> {
    if (this.initialized || !this.context) return;
    await umengAnalytics.initializeAfterPrivacyConsent();
    await authStore.initialize(this.context);
    libraryStore.initialize(this.context);
    communityStore.initialize(this.context);
    this.wechatLoggedIn = authStore.isWechatAuthenticated();
    await promptStore.initialize(this.context);
    await this.handleWechatCallback();
    voiceRecorder.initialize(this.context);
    uploader.initialize(this.context);
    photoService.initialize(this.context);
    this.restoreCachedHomeSnapshots();
    Promise.all([photoService.retryPending(), uploader.drainPending(), uploader.drainPendingTags()]).then((result: number[]) => {
      if (result[1] > 0) { promptAction.showToast({ message: `已续传 ${result[1]} 条录音` }); this.refreshLibrary(); }
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
    this.detailLoadSequence++;
    this.communityDetailLoadSequence++;
    this.selected = undefined;
    this.article = undefined;
    this.selectedPost = undefined;
    this.selectedReplyParent = undefined;
    this.communityReplies = [];
    this.recordings = [];
    this.posts = []; this.communityRecommended = []; this.communityLatest = [];
    libraryStore.clearArticleSnapshots();
    communityStore.clearPostSnapshots();
    this.reconnectAgentSessions();
    this.navigateHome();
    await this.refreshLibrary(true, true, undefined, true);
  }

  private onForegroundSequence(): void {
    this.wechatLoggingIn = false;
    if (!this.initialized || this.pathStack.size() > 0) return;
    this.refreshLibrary(this.recordings.length === 0).catch(() => {});
    if (this.tab === 1) this.refreshCommunity().catch(() => {});
  }

  private onWechatSequence(): void {
    if (!this.initialized) return;
    this.handleWechatCallback().catch((error: Error) => {
      this.wechatLoggingIn = false;
      promptAction.showToast({ message: `微信登录失败：${error.message}` });
    });
  }

  private async startWechatLogin(): Promise<void> {
    if (!this.context || this.wechatLoggingIn) return;
    this.wechatLoggingIn = true;
    try {
      if (!await WechatLogin.start(this.context)) {
        this.wechatLoggingIn = false;
        promptAction.showToast({ message: '无法打开微信，请确认已安装微信' });
      }
    } catch (error) {
      this.wechatLoggingIn = false;
      promptAction.showToast({ message: `无法打开微信：${String(error)}` });
    }
  }

  private async handleWechatCallback(): Promise<void> {
    const code: string = String(AppStorage.get<string>('wechatCode') ?? '');
    const callbackMessage: string = String(AppStorage.get<string>('wechatMessage') ?? '');
    if (code.length > 0 || callbackMessage.length > 0) this.wechatLoggingIn = false;
    if (code.length === 0) {
      if (callbackMessage.length > 0) {
        AppStorage.setOrCreate<string>('wechatMessage', ''); promptAction.showToast({ message: callbackMessage });
      }
      return;
    }
    AppStorage.setOrCreate<string>('wechatCode', ''); AppStorage.setOrCreate<string>('wechatMessage', '');
    const result: WechatAuthResult = await WechatAuthStore.exchange(code);
    if (!result.ok) {
      promptAction.showToast({ message: `微信登录失败：${result.message()}` }); return;
    }
    const previousScope: string = authStore.storageScope();
    const anonId: string = await DeviceLinkCrypto.accountId(authStore.anonymousBearer());
    const switchingAccount: boolean = WechatAuthResponse.requiresAccountSwitch(result.scope, anonId);
    let switched: boolean = false;
    if (switchingAccount) {
      const confirmation = await promptAction.showDialog({ title: '该微信已关联另一个云端空间',
        message: '是否切换到微信已绑定的云端空间？当前空间会保存在本机，退出微信登录后会恢复当前空间。',
        buttons: [{ text: '保留当前空间', color: '#666666' }, { text: '切换到微信空间', color: '#D92D20' }] });
      if (confirmation.index !== 1) return;
      switched = await authStore.switchToWechatAccount(result.session);
    } else switched = await authStore.storeSession(result.session);
    if (!switched) { promptAction.showToast({ message: '微信登录失败：无效会话' }); return; }
    const accountChanged: boolean =
      ClientReliability.accountIdentityChanged(previousScope, authStore.storageScope());
    this.wechatLoggedIn = true;
    if (accountChanged) {
      await this.applyAccountIdentityChange(true);
    } else {
      this.reconnectAgentSessions();
      this.navigateHome();
      await this.refreshLibrary(false, false);
    }
    promptAction.showToast({ message: result.scope === `users/${anonId}/` ? '已登录微信' : '已切换到微信空间' });
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

  private async refreshLibrary(showLoading: boolean = true, showFailure: boolean = showLoading,
    invalidatedStems?: string[], enrichBeforeDisplay: boolean = false): Promise<void> {
    const displayLoading: boolean =
      ClientReliability.libraryRefreshShowsLoading(showLoading, this.recordings.length > 0);
    if (displayLoading) this.loading = true;
    this.errorText = '';
    try {
      const remote: Recording[] = await libraryStore.load();
      if (enrichBeforeDisplay) await libraryStore.enrichMissingMetadata(remote, invalidatedStems);
      const staleDeleted: Recording[] = remote.filter((recording: Recording) =>
        this.deletedRecordingNames.includes(recording.name));
      this.recordings = RecordingListUi.afterRefresh(
        uploader.pendingRecordings(), remote, this.deletedRecordingNames,
        this.recordings.filter((recording: Recording) => recording.saving), this.recordings,
        invalidatedStems ?? []);
      libraryStore.storeRecordingsSnapshot(this.recordings);
      this.commandSession?.setRefs(this.currentCommandRefs());
      staleDeleted.forEach((recording: Recording) => libraryStore.delete(recording).catch(() => false));
      if (!enrichBeforeDisplay) {
        libraryStore.enrichMissingMetadata(remote, invalidatedStems).then((changed: boolean) => {
          if (changed) {
            this.recordings = this.recordings.slice();
            libraryStore.storeRecordingsSnapshot(this.recordings);
          }
        }).catch(() => {});
      }
      this.publishReadyReplies();
      this.drainPendingCommunityShare().catch(() => {});
    } catch (error) {
      this.errorText = ClientReliability.libraryErrorText(error as Object, this.recordings.length > 0, showFailure);
    } finally {
      if (displayLoading) this.loading = false;
    }
  }

  private queueCommandLibraryRefresh(stems: string[]): void {
    const merged: Set<string> = new Set<string>(this.commandLibraryRefreshStems);
    stems.forEach((stem: string) => { if (stem.length > 0) merged.add(stem); });
    this.commandLibraryRefreshStems = Array.from(merged);
    this.commandLibraryRefreshQueued = true;
    if (!this.commandLibraryRefreshRunning) this.drainCommandLibraryRefresh().catch(() => {});
  }

  private async drainCommandLibraryRefresh(): Promise<void> {
    if (this.commandLibraryRefreshRunning) return;
    this.commandLibraryRefreshRunning = true;
    try {
      while (this.commandLibraryRefreshQueued) {
        this.commandLibraryRefreshQueued = false;
        const stems: string[] = this.commandLibraryRefreshStems;
        this.commandLibraryRefreshStems = [];
        libraryStore.invalidateArticleStems(stems);
        await this.refreshLibrary(false, false, stems);
      }
    } finally {
      this.commandLibraryRefreshRunning = false;
      if (this.commandLibraryRefreshQueued) this.drainCommandLibraryRefresh().catch(() => {});
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
      await Promise.all([photoService.retryPending(), uploader.drainPending(), uploader.drainPendingTags()]);
      await this.refreshLibrary(false, true);
    }
    finally {
      this.libraryRefreshing = false;
      this.libraryRefreshStatus = RefreshStatus.Done;
      this.libraryRefreshOffset = 0;
    }
  }

  private async pullRefreshCommunity(): Promise<void> {
    if (this.communityRefreshing) return;
    this.communityRefreshing = true;
    try { await this.refreshCommunity(false); }
    finally {
      this.communityRefreshing = false;
      this.communityRefreshStatus = RefreshStatus.Done;
      this.communityRefreshOffset = 0;
    }
  }

  private updateCommunityFilter(): void {
    if (this.communityFilter === 'latest') this.posts = this.communityLatest.slice();
    else if (this.communityFilter === 'replies') this.posts = this.communityRecommended.filter((post: CommunityPost) => (post.replyTo ?? '').length > 0);
    else this.posts = this.communityRecommended.slice();
  }

  // Community detail is a nested route. Remove moderated content from every
  // in-memory feed before returning; refreshCommunity below reconciles it with
  // the server snapshot afterwards.
  private removeCommunityContent(shareId: string, author: string = ''): void {
    const keep = (post: CommunityPost): boolean => {
      if (shareId.length > 0 && post.shareId === shareId) return false;
      if (author.length > 0 && post.author === author) return false;
      return true;
    };
    this.communityRecommended = this.communityRecommended.filter(keep);
    this.communityLatest = this.communityLatest.filter(keep);
    this.updateCommunityFilter();
  }

  /**
   * Keep stable card instances while replacing a disk snapshot with its fresh network copy.
   * Image aspect ratios are runtime presentation state, so carry them across an unchanged cover.
   */
  private applyCommunityFeed(feed: CommunityFeed, blocked: string[]): void {
    this.reconcileCommunityLikes(feed.recommended);
    this.reconcileCommunityLikes(feed.latest);
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

  private reconcileCommunityLikes(posts: CommunityPost[]): void {
    posts.forEach((post: CommunityPost) => {
      const serverLiked: boolean = post.liked ?? false;
      const locallyLiked: boolean = appPreferences.likedCommunityPost(post.shareId);
      post.likes = CommunityLikeState.reconciledCount(post.likes, serverLiked, locallyLiked);
      post.liked = CommunityLikeState.reconciledLiked(serverLiked, locallyLiked);
    });
  }

  private applyCommunityLikeToPosts(posts: CommunityPost[], shareId: string, liked: boolean): CommunityPost[] {
    return CommunityLikePresentation.apply(posts, shareId, liked);
  }

  private updateCommunityLikePresentation(shareId: string, liked: boolean): void {
    this.communityRecommended =
      this.applyCommunityLikeToPosts(this.communityRecommended, shareId, liked);
    this.communityLatest =
      this.applyCommunityLikeToPosts(this.communityLatest, shareId, liked);
    this.posts = this.applyCommunityLikeToPosts(this.posts, shareId, liked);
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
    if (recording.isEmpty) return '#8F877D';
    return recording.hasArticles ? '#3E8765' : Theme.AMBER;
  }

  private async openRecording(recording: Recording): Promise<void> {
    if (this.recording || this.recordingTransitioning || Date.now() < this.recordingDetailOpenBlockedUntil) return;
    if (recording.saving) {
      promptAction.showToast({ message: '录音正在保存，请稍候' });
      return;
    }
    this.selected = recording;
    this.generatedPhotoKeys = [];
    this.clearPendingPhotoEdits();
    this.articleEditQueue = [];
    this.articleEditReply = '';
    this.articleEditReplyOk = true;
    const communityShareGeneration: number = ++this.communityShareGeneration;
    this.closeParagraphEdit(false);
    const detailLoadSequence: number = ++this.detailLoadSequence;
    this.detailLoadError = '';
    this.showDetailMenu = false;
    this.article = recording.hasArticles ? libraryStore.cachedArticle(recording) : undefined;
    this.detailLoading = ClientReliability.shouldBlockDetailLoading(this.article !== undefined);
    this.history = new ArticleHistory();
    this.communityShareId = '';
    this.warmArticlePhotos(this.article);
    this.navigateTo('detail');
    this.selectedArticle = 0;
    try {
      if (recording.hasArticles) {
        libraryStore.versionHistory(recording).then((history: ArticleHistory) => {
          if (detailLoadSequence === this.detailLoadSequence &&
            this.selected?.stem() === recording.stem()) this.history = history;
        }).catch(() => {});
        communityStore.sharedShareId(recording.articleKey()).then((shareId: string) => {
          if (CommunityShareUi.shouldApplyLookup(communityShareGeneration, this.communityShareGeneration) &&
            detailLoadSequence === this.detailLoadSequence &&
            this.selected?.stem() === recording.stem()) this.communityShareId = shareId;
        }).catch(() => {});
        const fresh: ArticleDoc | undefined = await libraryStore.fetchArticle(recording);
        if (fresh && detailLoadSequence === this.detailLoadSequence &&
          this.selected?.stem() === recording.stem()) {
          this.article = fresh;
          this.warmArticlePhotos(fresh);
        }
        if (!fresh && detailLoadSequence === this.detailLoadSequence) {
          const cacheStillValid: boolean = libraryStore.cachedArticle(recording) !== undefined;
          if (this.article && !cacheStillValid) {
            this.article = undefined;
            this.detailLoadError = '文章已不存在或已删除';
          } else if (!this.article) {
            this.detailLoadError = '文章加载失败，请检查网络后重试';
          }
        }
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
      const editEvent: ArticleEditEvent = new ArticleEditEvent(message.type ?? '', message.id);
      editEvent.text = message.text;
      editEvent.message = message.message;
      editEvent.ok = message.ok;
      editEvent.queue = message.queue;
      this.articleEditQueue = ArticleEditUi.reconcile(this.articleEditQueue, editEvent);
      const feedback: ArticleEditFeedback | undefined = ArticleEditUi.feedback(editEvent);
      if (feedback) {
        this.articleEditReply = feedback.text;
        this.articleEditReplyOk = feedback.ok;
        if (!feedback.ok) promptAction.showToast({ message: `修改失败：${feedback.text}` });
      }
      const updated: ArticleDoc | undefined = message.article ?? message.doc;
      if ((message.type === 'updated' || message.type === 'snapshot') && updated) {
        updated.owner = updated.owner ?? this.article?.owner;
        const introduced: string[] = PhotoLoadPolicy.introducedKeys(
          photoService.articlePhotoKeys(this.article), photoService.articlePhotoKeys(updated));
        this.generatedPhotoKeys = Array.from(new Set<string>(this.generatedPhotoKeys.concat(introduced)));
        if (message.id) this.continuePendingPhotoEdit(message.id, introduced);
        for (const item of message.queue ?? []) {
          if (item.id && item.status === 'done') this.continuePendingPhotoEdit(item.id, introduced);
        }
        libraryStore.cacheArticle(recording, updated).catch(() => {});
        if (this.paragraphEditing) {
          this.deferredParagraphArticle = updated;
        } else {
          this.article = updated;
          this.warmArticlePhotos(updated);
        }
      }
      if ((message.type === 'updated' || message.type === 'error') && message.id) {
        this.finishPendingPhotoEdit(message.id);
      }
      for (const item of message.queue ?? []) {
        if (item.id && (item.status === 'done' || item.status === 'error')) {
          this.finishPendingPhotoEdit(item.id);
        }
      }
      const snapshotResolved: boolean = (message.queue ?? []).some((item: ArticleEditQueueState): boolean =>
        item.status === 'done' || item.status === 'error');
      if (ClientReliability.shouldRefreshResolvedArticle(message.type ?? '', snapshotResolved, updated !== undefined)) {
        this.refreshResolvedArticle(recording).catch(() => {});
      }
      if (message.type === 'preview-reset' || message.type === 'preview-delta') return;
      if (message.type === 'preview-done' && message.ok !== false) this.finishRestyle(recording, true);
    } catch (_) {}
  }

  private async refreshResolvedArticle(recording: Recording): Promise<void> {
    const fresh: ArticleDoc | undefined = await libraryStore.fetchArticle(recording);
    if (!fresh || this.selected?.stem() !== recording.stem()) return;
    fresh.owner = fresh.owner ?? this.article?.owner;
    if (this.paragraphEditing) {
      this.deferredParagraphArticle = fresh;
      return;
    }
    this.article = fresh;
    this.warmArticlePhotos(fresh);
    this.selectedArticle = Math.min(this.selectedArticle, Math.max(0, fresh.articles.length - 1));
    this.history = await libraryStore.versionHistory(recording);
  }

  private openStyleRewrite(): void {
    if (this.showStyleRewrite) return;
    this.selectedStyleRewriteVersion = this.currentArticleStyleVersion() ?? -1;
    this.showStyleRewrite = true;
    this.loadStyleRewriteHistory();
  }

  private async loadStyleRewriteHistory(): Promise<void> {
    this.styleRewriteLoading = true;
    this.styleRewriteError = '';
    try {
      const history: StyleHistory = await settingsStore.loadStyleHistory();
      if (this.showStyleRewrite) this.styleRewriteHistory = history;
    } catch (_) {
      if (this.showStyleRewrite) this.styleRewriteError = '写作风格加载失败，请稍后重试。';
    } finally {
      this.styleRewriteLoading = false;
    }
  }

  private generatedStyleVersion(styleVersion: number): ArticleVersion | undefined {
    return this.history.versions.find((version: ArticleVersion) =>
      (version.articles ?? []).some((article: MinedArticle) =>
        StyleRewriteUi.articleStyleVersion(article.style, article.body) === styleVersion));
  }

  private async requestStyleRewrite(styleVersion: number): Promise<void> {
    if (!this.selected || styleVersion < 0) return;
    const recording: Recording = this.selected;
    const generated: ArticleVersion | undefined = this.generatedStyleVersion(styleVersion);
    this.showStyleRewrite = false;
    if (generated) { await this.selectHistoryVersion(generated); promptAction.showToast({ message: `已切换到 v${styleVersion} 文风` }); return; }
    this.restyleTargetStyleVersion = styleVersion;
    this.restyleFinishing = false; this.restylePreviewActive = true;
    try {
      const result: RestyleResult = await libraryStore.restyle(recording, styleVersion);
      if (this.restylePreviewActive) await this.finishRestyle(recording, result.ok, result.message());
    } catch (_) {
      if (this.restylePreviewActive) await this.finishRestyle(recording, false, '网络请求失败，请稍后重试');
    }
  }

  private async finishRestyle(recording: Recording, ok: boolean, failureMessage: string = '换文风请求失败'):
    Promise<void> {
    if (!this.restylePreviewActive || this.restyleFinishing) return;
    this.restyleFinishing = true;
    if (!ok) {
      this.restylePreviewActive = false;
      this.restyleFinishing = false;
      this.restyleTargetStyleVersion = -1;
      promptAction.showToast({ message: failureMessage });
      return;
    }
    try {
      const updated: ArticleDoc | undefined = await libraryStore.fetchArticle(recording);
      if (this.selected?.stem() !== recording.stem()) return;
      if (updated) {
        if (this.restyleTargetStyleVersion >= 0) {
          for (const article of updated.articles) {
            article.style = StyleRewriteUi.articleStyleVersion(article.style, article.body) ??
              this.restyleTargetStyleVersion;
          }
        }
        this.article = updated; this.warmArticlePhotos(updated);
        this.selectedArticle = 0; this.history = await libraryStore.versionHistory(recording);
        this.selectedStyleRewriteVersion = this.currentArticleStyleVersion() ?? -1;
        promptAction.showToast({ message: this.restyleTargetStyleVersion >= 0 ?
          `已切换到 v${this.restyleTargetStyleVersion} 文风` : '换文风成功' });
      } else {
        promptAction.showToast({ message: '新文风文章暂不可读' });
      }
    } catch (_) {
      promptAction.showToast({ message: '新文风文章加载失败' });
    } finally {
      this.restylePreviewActive = false;
      this.restyleFinishing = false;
      this.restyleTargetStyleVersion = -1;
    }
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
      this.communityReplyRecording = false;
      this.interviewer = undefined;
      this.interviewActive = false;
      this.interviewStatus = '';
      this.capturedPhotos = [];
      this.recordingSeconds = 0;
      this.recordingLevel = 0;
      this.recording = true;
      this.updateRecordingMeter();
      this.timer = setInterval(() => this.updateRecordingMeter(), RECORDING_METER_INTERVAL_MS);
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
    const communityReply: boolean = this.communityReplyRecording && replyTarget.length > 0;
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
    this.finishRecordingStop(interviewer, savingName, photos, replyTarget, tag, communityReply).catch(() => {});
  }

  private async finishRecordingStop(
    interviewer: RealtimeInterviewer | undefined,
    savingName: string,
    photos: CapturedPhoto[],
    replyTarget: string,
    tag: string,
    communityReply: boolean
  ): Promise<void> {
    let remainOnCommunityDetail: boolean = false;
    try {
      await interviewer?.stop();
      const path: string = await voiceRecorder.stop();
      if (isRecordingTooShort(voiceRecorder.durationSeconds())) {
        try { fs.unlinkSync(path); } catch (_) {}
        await photoService.discardCaptured(photos);
        this.recordings = RecordingListUi.cancelSaving(this.recordings, savingName);
        if (replyTarget.length > 0) {
          remainOnCommunityDetail = CommunityReplyUi.shouldRemainOnDetail(communityReply, false);
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
      if (communityReply) {
        const uploaded: boolean = await this.continueRecordingUpload(path, audioName, photos, false);
        promptAction.showToast({ message: CommunityReplyUi.savedMessage(uploaded) });
      } else {
        this.continueRecordingUpload(path, audioName, photos);
      }
    } catch (error) {
      this.recordings = RecordingListUi.cancelSaving(this.recordings, savingName);
      await photoService.discardCaptured(photos);
      remainOnCommunityDetail = CommunityReplyUi.shouldRemainOnDetail(communityReply, false);
      promptAction.showToast({ message: `录音保存失败：${String(error)}` });
    } finally {
      if (!remainOnCommunityDetail) this.navigateHome(false);
      this.recordingDetailOpenBlockedUntil = Date.now() + 600;
      if (communityReply) {
        this.communityReplyRecording = false;
        this.recording = false;
        this.recordingTransitioning = false;
      } else {
        setTimeout(() => {
          this.recording = false;
          this.recordingTransitioning = false;
        }, 180);
      }
    }
  }

  private async continueRecordingUpload(path: string, audioName: string, photos: CapturedPhoto[],
    showFailureToast: boolean = true): Promise<boolean> {
    try {
      // Photo uploads are durable and no longer gate audio. The server backfills
      // a late photo marker after its PUT succeeds.
      photoService.uploadCaptured(photos).catch(() => {});
      const uploaded: boolean = await uploader.upload(path);
      if (!uploaded && showFailureToast) promptAction.showToast({ message: '上传失败，录音已保留' });
      if (uploaded) {
        this.recordings = RecordingListUi.applyStatus(this.recordings,
          audioName.endsWith('.m4a') ? audioName.substring(0, audioName.length - 4) : audioName, 'asr');
        this.commandSession?.setRefs(this.currentCommandRefs());
        libraryStore.storeRecordingsSnapshot(this.recordings);
      }
      return uploaded;
    } catch (error) {
      if (showFailureToast) promptAction.showToast({ message: `上传失败，录音已保留：${String(error)}` });
      return false;
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
      ++this.communityShareGeneration;
      const result: CommunityShareResult = await communityStore.shareResult(pending.articleKey, pending.replyTo ?? '');
      if (result.ok) {
        if (!pending.replyTo && this.selected?.articleKey() === pending.articleKey) {
          this.communityShareId = result.shareId;
        }
        await appPreferences.clearPendingCommunityShare();
        promptAction.showToast({ message: CommunityShareUi.successMessage((pending.replyTo ?? '').length > 0) });
      }
    } catch (error) {
      promptAction.showToast({ message: `社区分享失败：${ClientReliability.errorMessage(error as Object)}` });
    }
  }

  private async startCommunityShareWechatLogin(articleKey: string): Promise<void> {
    await appPreferences.savePendingCommunityShare(articleKey);
    await this.startWechatLogin();
    if (this.wechatLoggingIn) {
      promptAction.showToast({ message: '请在微信中完成登录，登录后将自动分享到社区' });
    }
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
      }.height(52).width('100%').padding({ left: 18, right: 12, top: 8 })
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

  private recordingCoverFullKey(recording: Recording): string {
    const key: string = recording.coverPhotoKey.trim().replace(/^\/+/, '');
    if (key.length === 0 || key.startsWith('users/')) return key;
    return `${authStore.storageScope()}${key}`;
  }

  private recordingCoverSource(fullKey: string): string {
    return this.recordingThumbnailFallbackKeys.includes(fullKey)
      ? ArticleBody.photoUrl(fullKey)
      : ArticleBody.photoThumbnailUrl(fullKey);
  }

  private fallbackRecordingCover(fullKey: string): void {
    if (fullKey.length === 0) return;
    if (!this.recordingThumbnailFallbackKeys.includes(fullKey)) {
      this.recordingThumbnailFallbackKeys = this.recordingThumbnailFallbackKeys.concat(fullKey);
    } else if (!this.recordingPhotoFailureKeys.includes(fullKey)) {
      this.recordingPhotoFailureKeys = this.recordingPhotoFailureKeys.concat(fullKey);
    }
    this.recordings = this.recordings.slice();
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
      if (this.recordingCoverFullKey(recording).length > 0 &&
        !this.recordingPhotoFailureKeys.includes(this.recordingCoverFullKey(recording))) {
        Image(this.recordingCoverSource(this.recordingCoverFullKey(recording)))
          .width(44).height(44)
          .objectFit(ImageFit.Cover)
          .borderRadius(14)
          .clip(true)
          .onError(() => this.fallbackRecordingCover(this.recordingCoverFullKey(recording)))
      }
      if (this.commandTalking && this.commandRefNumber(recording) > 0) {
        Text(`${this.commandRefNumber(recording)}`)
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Theme.WHITE)
          .width(24).height(24).textAlign(TextAlign.Center)
          .backgroundColor(Theme.ACCENT_STRONG).borderRadius(12)
      }
    }.width(44).height(44).margin({ right: 14 })
  }

  @Builder
  private pageLoadingState() {
    Column({ space: 14 }) {
      LoadingProgress().width(40).height(40).color(Theme.ACCENT_STRONG)
      Text('正在加载...').fontSize(16).fontColor(Theme.SECONDARY)
    }
      .height(180)
      .margin({ top: 50 })
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private refreshPlaceholder() {
    Row() {
    }
      .width(1)
      .height(1)
      .opacity(0)
  }

  @Builder
  private libraryPage() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
      this.topBar('VoiceDrop 口述')
      Scroll() {
        Row() {
          Text('我的录音')
            .fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.selectedTag.length === 0 ? Theme.INK : Theme.SECONDARY)
            .padding({ left: 0, right: 14, top: 2, bottom: 6 })
            .onClick(() => this.selectedTag = '')
          Text('VD社区').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.SECONDARY)
            .padding({ left: 14, right: 14, top: 2, bottom: 6 }).onClick(() => {
              this.selectedTag = '';
              this.tab = 1;
              this.refreshCommunity(false).catch(() => {});
            })
          ForEach(this.homeTags(), (tag: string) => {
            Text(tag)
              .fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor(this.selectedTag === tag ? Theme.INK : Theme.SECONDARY)
              .maxLines(1)
              .padding({ left: 14, right: 14, top: 2, bottom: 6 })
              .onClick(() => this.selectedTag = tag)
          }, (tag: string) => tag)
        }
          .constraintSize({ minWidth: '100%' })
          .justifyContent(FlexAlign.Start)
          .padding({ left: 18, right: 18 })
      }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      Row() { Blank().width(78).height(3).backgroundColor(Theme.ACCENT_STRONG).borderRadius(2) }
        .width('100%').padding({ left: 18 }).margin({ bottom: 10 })
        .opacity(this.selectedTag.length === 0 ? 1 : 0)
      if (this.loading) {
        this.pageLoadingState()
        Blank()
      } else if (this.visibleRecordings().length === 0) {
        Stack({ alignContent: Alignment.Top }) {
          Refresh({ refreshing: this.libraryRefreshing, builder: () => { this.refreshPlaceholder() } }) {
            List() {
              ListItem() {
                Column() {
                  Text(this.selectedTag ? `「${this.selectedTag}」标签下还没有文章` : '轻点下方按钮开始第一条录音')
                    .fontSize(16).fontColor(Theme.SECONDARY).textAlign(TextAlign.Center)
                }.width('100%').height(180)
                  .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              }
            }.width('100%').height('100%')
              .padding({ left: 18, right: 18, top: 6, bottom: 16 })
          }.width('100%').height('100%')
            .onStateChange((status: RefreshStatus) => this.libraryRefreshStatus = status)
            .onOffsetChange((offset: number) => this.libraryRefreshOffset = offset)
            .onRefreshing(() => this.pullRefreshLibrary())
          if (this.libraryRefreshing ||
            ((this.libraryRefreshStatus === RefreshStatus.Drag ||
              this.libraryRefreshStatus === RefreshStatus.OverDrag) && this.libraryRefreshOffset > 0)) {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(Theme.ACCENT_STRONG)
              .translate({ y: Math.max(0, this.libraryRefreshOffset / 2 - 20) })
          }
        }.layoutWeight(1).width('100%')
      } else {
        Stack({ alignContent: Alignment.Top }) {
          Refresh({ refreshing: this.libraryRefreshing, builder: () => { this.refreshPlaceholder() } }) {
            List({ space: 10 }) {
              ForEach(this.visibleRecordings(), (item: Recording) => {
                ListItem() {
                  Row() {
                    this.recordingRowIcon(item)
                    Column({ space: 5 }) {
                      Text(item.rowTitle()).fontSize(17).fontWeight(FontWeight.Medium)
                        .fontColor(item.isEmpty ? '#6F6A63' : Theme.INK)
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Row({ space: 10 }) {
                        Text(item.dateTimeLabel()).fontSize(14)
                          .fontColor(item.isEmpty ? '#8F877D' : Theme.SECONDARY)
                        Text(item.durationLabel()).fontSize(14)
                          .fontColor(item.isEmpty ? '#8F877D' : Theme.SECONDARY)
                        Row({ space: 4 }) {
                          Text('•').fontSize(14).fontColor(this.recordingStatusColor(item))
                          Text(item.statusLabel()).fontSize(14).fontColor(this.recordingStatusColor(item))
                        }.alignItems(VerticalAlign.Center)
                      }.alignItems(VerticalAlign.Center)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 22, color: '#9F968B' })
                  }.padding({ left: 16, right: 16, top: 12, bottom: 12 }).width('100%')
                    .backgroundColor(Theme.CARD).borderRadius(16).border({ width: 1, color: Theme.BORDER })
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
            }.width('100%').height('100%')
              .padding({ left: 18, right: 18, bottom: 8 })
              .onScrollStart(() => this.closeOpenRecordingSwipe())
          }.width('100%').height('100%')
            .onStateChange((status: RefreshStatus) => this.libraryRefreshStatus = status)
            .onOffsetChange((offset: number) => {
              this.libraryRefreshOffset = offset;
              if (offset > 0) this.closeOpenRecordingSwipe();
            })
            .onRefreshing(() => this.pullRefreshLibrary())
          if (this.libraryRefreshing ||
            ((this.libraryRefreshStatus === RefreshStatus.Drag ||
              this.libraryRefreshStatus === RefreshStatus.OverDrag) && this.libraryRefreshOffset > 0)) {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(Theme.ACCENT_STRONG)
              .translate({ y: Math.max(0, this.libraryRefreshOffset / 2 - 20) })
          }
        }.layoutWeight(1).width('100%')
      }
      if (this.errorText.length > 0) Text(this.errorText).fontSize(13).fontColor('#B42318').padding(12)
      if (this.pendingReplyTarget.length > 0) {
        Row() {
          Text('正在准备语音回复，点击下面开始录音').fontSize(13).fontColor('#8A4B08').layoutWeight(1)
          Button('取消').fontSize(12).backgroundColor(Color.Transparent).fontColor('#8A4B08')
            .onClick(() => this.pendingReplyTarget = '')
        }.padding({ left: 18, right: 18, top: 8 }).width('100%')
      }
      }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(Theme.BG)
      if (!this.recording) {
        Column() {
          if (this.displayedCommandFeedback().visible()) {
            this.libraryCommandStatus()
          }
          this.recordingFab()
        }.width('100%').margin({ bottom: this.safeAreaBottom() + 20 }).hitTestBehavior(HitTestMode.Transparent)
      }
    }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
  }

  @Builder
  private libraryCommandStatus() {
    Row() {
      Text(this.displayedCommandFeedback().text).fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor(this.displayedCommandFeedback().tone === LibraryCommandTone.Error ? '#B42318' :
          (this.displayedCommandFeedback().tone === LibraryCommandTone.Active ? Theme.INK : Theme.SECONDARY))
        .textAlign(TextAlign.Center).padding({ left: 18, right: 18, top: 9, bottom: 9 })
        .backgroundColor(this.displayedCommandFeedback().tone === LibraryCommandTone.Error ? '#FFEBE8' : Theme.ACCENT_SOFT)
        .borderRadius(14).layoutWeight(1)
    }.width('100%').padding({ left: 16, right: 16, bottom: 10 }).hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private recordingFab() {
    Column({ space: 2 }) {
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
          .monopolizeEvents(true)
          .onTouch((event: TouchEvent) => this.handleRecordFabTouch(event))
      }.justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center).width('100%').hitTestBehavior(HitTestMode.Transparent)
      Text(LibraryCommandUi.recordButtonLabel(this.commandTalking, this.commandCanceled))
        .fontSize(13).fontColor(this.commandTalking ? Theme.ACCENT_STRONG : Theme.SECONDARY)
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

  private displayedCommandFeedback(): LibraryCommandFeedback {
    return LibraryCommandUi.displayedFeedback(
      new LibraryCommandFeedback(this.commandState, this.commandStateTone),
      this.commandTranscriptText,
      this.commandTalking || this.commandRecognizing || this.commandTranscriptConfirming
    );
  }

  private clearCommandTranscriptConfirmation(): void {
    if (this.commandTranscriptConfirmTimer >= 0) clearTimeout(this.commandTranscriptConfirmTimer);
    this.commandTranscriptConfirmTimer = -1;
    this.commandTranscriptConfirming = false;
    this.commandTranscriptText = '';
  }

  private confirmCommandTranscript(text: string, generation: number): void {
    this.clearCommandTranscriptConfirmation();
    const transcript: string = text.trim();
    if (transcript.length === 0) return;
    this.commandTranscriptText = transcript;
    this.commandTranscriptConfirming = true;
    this.commandTranscriptConfirmTimer = setTimeout(() => {
      this.commandTranscriptConfirmTimer = -1;
      if (generation !== this.commandDictationGeneration) return;
      this.commandTranscriptConfirming = false;
      this.commandTranscriptText = '';
    }, LibraryCommandUi.transcriptConfirmationMs());
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
    event.stopPropagation();
    if (event.type === TouchType.Down) {
      if (this.recordingTransitioning || this.commandTalking || this.commandRecognizing) return;
      if (!this.commandGestureGate.beginPress()) return;
      this.commandHoldPressed = true;
      this.commandLongPressed = false;
      this.commandCanceled = false;
      this.commandFinalized = false;
      this.clearCommandTranscriptConfirmation();
      this.commandTranscript.clear();
      this.commandHoldStartY = this.commandTouchY(event);
      const generation: number = ++this.commandDictationGeneration;
      this.commandPrimePromise = this.primeLibraryCommandTalk(generation);
      if (this.commandHoldTimer >= 0) clearTimeout(this.commandHoldTimer);
      this.commandHoldTimer = setTimeout(() => {
        this.commandHoldTimer = -1;
        if (!this.commandHoldPressed || !this.commandGestureGate.confirmLongPress()) return;
        this.commandLongPressed = true;
        this.commandTalking = true;
        this.applyCommandFeedback(LibraryCommandUi.dictationFeedback('', false));
        this.startLibraryCommandTalk(generation);
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
      if (action === LibraryCommandGestureAction.Send && !this.commandGestureGate.beginFinish()) return;
      if (action === LibraryCommandGestureAction.Cancel) this.commandGestureGate.cancel();
      this.finishLibraryCommandTalk(action === LibraryCommandGestureAction.Cancel);
    } else if (action === LibraryCommandGestureAction.Record) {
      if (this.commandGestureGate.beginHandoff()) this.cancelPrimedLibraryCommandTalk(true);
    } else {
      this.commandGestureGate.cancel();
      this.cancelPrimedLibraryCommandTalk(false);
    }
  }

  private microphonePermissionGranted(): boolean {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const manager = abilityAccessCtrl.createAtManager();
      return manager.checkAccessTokenSync(info.appInfo.accessTokenId,
        'ohos.permission.MICROPHONE' as Permissions) === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (_) {
      return false;
    }
  }

  private async primeLibraryCommandTalk(generation: number): Promise<boolean> {
    if (!this.context || this.recording || !this.microphonePermissionGranted()) return false;
    if (generation !== this.commandDictationGeneration) return false;
    if (this.dictating) {
      return this.dictationTarget === 'command' && this.dictation?.isRunning() === true;
    }
    const session = new AsrDictation((text: string, finalResult: boolean) => {
      if (generation !== this.commandDictationGeneration || this.dictationTarget !== 'command') return;
      this.commandTranscript.accept(text, finalResult);
      this.commandTranscriptText = this.commandTranscript.bestText();
      if (this.commandTalking || this.commandRecognizing) {
        this.applyCommandFeedback(
          LibraryCommandUi.dictationFeedback(this.commandTranscriptText, this.commandCanceled));
      }
    }, (state: string) => {
      if (generation !== this.commandDictationGeneration || this.dictationTarget !== 'command') return;
      if (state.includes('失败') || state.includes('关闭')) {
        this.dictating = false;
        if (this.commandTalking || this.commandRecognizing) {
          this.commandTalking = false;
          this.commandRecognizing = false;
          this.commandGestureGate.cancel();
          this.applyCommandFeedback(
            new LibraryCommandFeedback(state.length > 0 ? state : '听写失败', LibraryCommandTone.Error));
        }
      } else if (state.length === 0 && this.commandRecognizing) {
        this.finalizeLibraryCommandTalk(generation);
      } else if (this.commandTalking && this.commandTranscriptText.length === 0) {
        this.applyCommandFeedback(LibraryCommandUi.dictationFeedback('', this.commandCanceled));
      }
    });
    this.dictationTarget = 'command';
    this.dictation = session;
    this.dictating = true;
    try {
      await session.start();
    } catch (error) {
      if (generation === this.commandDictationGeneration) {
        this.dictating = false;
        this.commandTalking = false;
        this.commandGestureGate.cancel();
        this.applyCommandFeedback(
          new LibraryCommandFeedback(`听写启动失败：${String(error)}`, LibraryCommandTone.Error));
      }
      return false;
    }
    if (generation !== this.commandDictationGeneration) {
      await session.stop();
      return false;
    }
    return session.isRunning();
  }

  private async startLibraryCommandTalk(generation: number): Promise<void> {
    if (!this.context || !this.commandTalking ||
      this.commandGestureGate.currentState() !== CommandGestureState.TALKING) return;
    if (this.recording) {
      this.commandTalking = false;
      this.commandGestureGate.cancel();
      this.applyCommandFeedback(
        new LibraryCommandFeedback('请先结束当前录音', LibraryCommandTone.Error));
      return;
    }
    if (!this.microphonePermissionGranted()) {
      const manager = abilityAccessCtrl.createAtManager();
      const permission = await manager.requestPermissionsFromUser(
        this.context, ['ohos.permission.MICROPHONE'] as Permissions[]);
      if (permission.authResults[0] !== 0) {
        this.commandTalking = false;
        this.commandHoldPressed = false;
        this.commandGestureGate.cancel();
        this.applyCommandFeedback(
          new LibraryCommandFeedback('需要麦克风权限才能使用语音指令', LibraryCommandTone.Error));
        return;
      }
      if (generation !== this.commandDictationGeneration || !this.commandTalking ||
        this.commandGestureGate.currentState() !== CommandGestureState.TALKING) return;
      this.commandPrimePromise = this.primeLibraryCommandTalk(generation);
    }
    const primePromise: Promise<boolean> | undefined = this.commandPrimePromise;
    const ready: boolean = primePromise ? await primePromise :
      await this.primeLibraryCommandTalk(generation);
    if (generation !== this.commandDictationGeneration || !this.commandTalking ||
      this.commandGestureGate.currentState() !== CommandGestureState.TALKING) return;
    if (!ready) {
      this.commandTalking = false;
      this.commandGestureGate.cancel();
      this.applyCommandFeedback(new LibraryCommandFeedback('听写启动失败，请重试', LibraryCommandTone.Error));
    }
  }

  private async cancelPrimedLibraryCommandTalk(startRecording: boolean): Promise<void> {
    const generation: number = ++this.commandDictationGeneration;
    const session: AsrDictation | undefined =
      this.dictationTarget === 'command' ? this.dictation : undefined;
    if (session) {
      this.dictation = undefined;
      this.dictationTarget = '';
      this.dictating = false;
      await session.stop();
    }
    this.commandTranscript.clear();
    this.commandTranscriptText = '';
    this.commandPrimePromise = undefined;
    if (generation !== this.commandDictationGeneration) return;
    this.commandGestureGate.complete();
    if (startRecording) await this.toggleRecording();
  }

  private async finishLibraryCommandTalk(cancel: boolean): Promise<void> {
    this.commandTalking = false;
    this.commandCanceled = false;
    if (cancel) {
      this.commandRecognizing = false;
      this.commandFinalized = true;
      this.clearCommandTranscriptConfirmation();
      this.dictating = false;
      this.dictationTarget = '';
      const session: AsrDictation | undefined = this.dictation;
      this.dictation = undefined;
      ++this.commandDictationGeneration;
      await session?.stop();
      this.commandTranscript.clear();
      this.commandPrimePromise = undefined;
      this.applyCommandFeedback(new LibraryCommandFeedback());
      return;
    }
    this.commandRecognizing = true;
    this.applyCommandFeedback(new LibraryCommandFeedback('正在识别…', LibraryCommandTone.Active));
    if (this.dictation?.isRunning()) await this.dictation.finish();
    else await this.finalizeLibraryCommandTalk(this.commandDictationGeneration);
  }

  private async finalizeLibraryCommandTalk(generation: number): Promise<void> {
    if (generation !== this.commandDictationGeneration) return;
    if (this.commandFinalized) return;
    this.commandFinalized = true;
    const text: string = this.commandTranscript.bestText();
    this.commandRecognizing = false;
    this.dictating = false;
    this.dictationTarget = '';
    this.dictation = undefined;
    this.commandPrimePromise = undefined;
    this.commandTranscript.clear();
    this.commandGestureGate.complete();
    this.confirmCommandTranscript(text, generation);
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
    if (permission.authResults[0] !== 0) {
      if (target === 'edit') {
        this.editText = this.holdEditOriginalText;
        this.resetEditHold();
        promptAction.showToast({ message: '请授权麦克风后再按住修改文章' });
      } else {
        promptAction.showToast({ message: '需要麦克风权限才能听写' });
      }
      return;
    }
    this.dictationTarget = target;
    if (target === 'edit') {
      this.editText = '';
      this.dictationPrefix = '';
    } else {
      this.dictationPrefix = this.libraryCommand;
    }
    if (this.dictationPrefix.length > 0 && !this.dictationPrefix.endsWith(' ')) this.dictationPrefix += ' ';
    this.dictation = new AsrDictation((text: string, finalResult: boolean) => {
      if (target === 'edit') {
        this.holdEditTranscriptText = text.trim();
        this.editText = this.dictationPrefix + text;
      } else {
        this.libraryCommand = this.dictationPrefix + text;
      }
      if (finalResult) {
        this.dictating = false; this.dictationState = '听写完成';
        if (target === 'edit' && this.holdEditShouldSend) this.completeEditHold();
      }
    }, (state: string) => {
      this.dictationState = state;
      if (target === 'edit') {
        if (state === '正在听写…' && !this.holdEditFinishing) {
          this.holdEditPromptText = '';
        } else if (state.length === 0 && this.holdEditShouldSend) {
          this.completeEditHold();
        } else if ((state.includes('失败') || state.includes('关闭')) && !this.holdEditFinishing) {
          this.editText = this.holdEditOriginalText;
          this.resetEditHold();
          promptAction.showToast({ message: `听写失败：${state.replace(/^听写/, '')}` });
        }
      }
      if (state.length === 0 || state.includes('失败') || state.includes('关闭')) this.dictating = false;
    });
    this.dictating = true;
    try {
      await this.dictation.start();
    } catch (error) {
      this.dictating = false;
      this.dictationState = `听写启动失败：${String(error)}`;
      if (target === 'edit') {
        this.editText = this.holdEditOriginalText;
        this.resetEditHold();
        promptAction.showToast({ message: `听写失败：${String(error)}` });
      }
    }
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
      this.holdEditFinishing = false; this.holdEditCompleted = false;
      this.holdEditPromptText = '正在连接…'; this.holdEditTranscriptText = '';
      this.showArticleLines = true;
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
      await this.dictation?.stop(); this.dictating = false; this.dictationState = '';
      this.resetEditHold();
      promptAction.showToast({ message: '已取消语音修改' });
    } else if (this.dictating) {
      this.holdEditShouldSend = true; this.holdEditFinishing = true;
      this.holdEditPromptText = '正在识别…';
      await this.dictation?.finish();
    } else {
      this.completeEditHold();
    }
  }

  private async completeEditHold(): Promise<void> {
    if (this.holdEditCompleted) return;
    this.holdEditCompleted = true;
    this.holdEditShouldSend = false;
    const text: string = this.holdEditTranscriptText.trim();
    this.resetEditHold();
    if (text.length === 0) {
      this.editText = '';
      promptAction.showToast({ message: '没有识别到语音' });
      return;
    }
    this.editText = text;
    await this.sendEdit();
  }

  private resetEditHold(): void {
    this.holdEditPressed = false;
    this.holdEditCanceled = false;
    this.holdEditFinishing = false;
    this.holdEditPromptText = '';
    this.holdEditTranscriptText = '';
    this.showArticleLines = false;
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
      if (ClientReliability.commandMessageRequiresRefresh(message.type ?? '')) {
        this.queueCommandLibraryRefresh(message.stems ?? []);
      }
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
      Scroll() {
        Row() {
          Text('我的录音').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.SECONDARY)
            .padding({ left: 0, right: 14, top: 2, bottom: 6 }).onClick(() => {
              this.selectedTag = '';
              this.tab = 0;
            })
          Text('VD社区').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
            .padding({ left: 14, right: 14, top: 2, bottom: 6 })
          ForEach(this.homeTags(), (tag: string) => {
            Text(tag)
              .fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor(Theme.SECONDARY)
              .maxLines(1)
              .padding({ left: 14, right: 14, top: 2, bottom: 6 })
              .onClick(() => {
                this.selectedTag = tag;
                this.tab = 0;
              })
          }, (tag: string) => tag)
        }
          .constraintSize({ minWidth: '100%' })
          .justifyContent(FlexAlign.Start)
          .padding({ left: 18, right: 18 })
      }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
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
        this.pageLoadingState()
        Blank()
      } else {
        Stack({ alignContent: Alignment.Top }) {
          Refresh({ refreshing: this.communityRefreshing, builder: () => { this.refreshPlaceholder() } }) {
            Scroll() {
              Row({ space: 8 }) {
                Column({ space: 8 }) {
                  ForEach(this.communityColumnPosts(0), (post: CommunityPost) => this.communityCard(post),
                    (post: CommunityPost) => CommunityLikePresentation.cardKey(post))
                }.layoutWeight(1)
                Column({ space: 8 }) {
                  ForEach(this.communityColumnPosts(1), (post: CommunityPost) => this.communityCard(post),
                    (post: CommunityPost) => CommunityLikePresentation.cardKey(post))
                }.layoutWeight(1)
              }.alignItems(VerticalAlign.Top).padding({ left: 16, right: 16, bottom: 24 }).width('100%')
            }.width('100%').height('100%').scrollBar(BarState.Off)
          }.width('100%').height('100%')
            .onStateChange((status: RefreshStatus) => this.communityRefreshStatus = status)
            .onOffsetChange((offset: number) => this.communityRefreshOffset = offset)
            .onRefreshing(() => this.pullRefreshCommunity())
          if (this.communityRefreshing ||
            ((this.communityRefreshStatus === RefreshStatus.Drag ||
              this.communityRefreshStatus === RefreshStatus.OverDrag) && this.communityRefreshOffset > 0)) {
            LoadingProgress()
              .width(40)
              .height(40)
              .color(Theme.ACCENT_STRONG)
              .translate({ y: Math.max(0, this.communityRefreshOffset / 2 - 20) })
          }
        }.layoutWeight(1).width('100%')
      }
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.COMMUNITY_BG)
  }

  private async openCommunityPost(post: CommunityPost): Promise<void> {
    const shareId: string = post.shareId;
    const loadSequence: number = ++this.communityDetailLoadSequence;
    this.showCommunityMenu = false;
    const cached: CommunityPost | undefined = communityStore.cachedPost(shareId);
    if (cached) {
      cached.likes = post.likes;
      cached.liked = post.liked;
      cached.replies = post.replies;
      cached.mine = post.mine ?? cached.mine;
    }
    this.selectedPost = cached ?? post;
    this.selectedReplyParent = undefined;
    this.communityReplies = [];
    this.communityDetailLoading = ClientReliability.shouldBlockDetailLoading(cached !== undefined);
    this.communityDetailError = '';
    this.postLiked = Boolean(this.selectedPost?.liked) || appPreferences.likedCommunityPost(shareId);
    this.postFed = false; this.postFeedCount = 0; this.postFeeding = false;
    this.navigateTo('communityDetail');
    communityStore.engage(shareId, 'view').catch(() => {});
    communityStore.feedState(shareId).then((state: CommunityFeedState) => {
      if (this.selectedPost?.shareId === shareId) { this.postFed = state.fed; this.postFeedCount = state.count; }
    }).catch(() => {});
    try {
      const full: CommunityPost | undefined = await communityStore.get(shareId);
      if (loadSequence !== this.communityDetailLoadSequence || this.selectedPost?.shareId !== shareId) return;
      if (!full) {
        if (!cached) {
          this.communityDetailError = '文章加载失败，请稍后重试';
        } else if (!communityStore.cachedPost(shareId)) {
          this.communityDetailError = '文章已不存在或已下架';
        } else {
          this.loadCommunityDetailRelations(cached, loadSequence).catch(() => {});
        }
        return;
      }
      this.selectedPost = full;
      this.communityDetailLoading = false;
      this.loadCommunityDetailRelations(full, loadSequence).catch(() => {});
    } catch (_) {
      if (!cached && loadSequence === this.communityDetailLoadSequence &&
        this.selectedPost?.shareId === shareId) {
        this.communityDetailError = '文章加载失败，请检查网络后重试';
      } else if (cached && loadSequence === this.communityDetailLoadSequence &&
        this.selectedPost?.shareId === shareId) {
        this.loadCommunityDetailRelations(cached, loadSequence).catch(() => {});
      }
    } finally {
      if (loadSequence === this.communityDetailLoadSequence &&
        this.selectedPost?.shareId === shareId) this.communityDetailLoading = false;
    }
  }

  private async loadCommunityDetailRelations(post: CommunityPost, loadSequence: number): Promise<void> {
    const shareId: string = post.shareId;
    const parentId: string = post.replyTo ?? '';
    if (parentId.length > 0) {
      const cachedParent: CommunityPost | undefined = communityStore.cachedPost(parentId);
      if (cachedParent && loadSequence === this.communityDetailLoadSequence &&
        this.selectedPost?.shareId === shareId) this.selectedReplyParent = cachedParent;
    }
    const repliesPromise: Promise<CommunityPost[]> =
      post.kind === 'prompt' ? Promise.resolve([]) : communityStore.replies(shareId);
    const parentPromise: Promise<CommunityPost | undefined> =
      parentId.length > 0 ? communityStore.get(parentId) : Promise.resolve(undefined);
    const replies: CommunityPost[] = await repliesPromise;
    const parent: CommunityPost | undefined = await parentPromise;
    if (loadSequence !== this.communityDetailLoadSequence || this.selectedPost?.shareId !== shareId) return;
    this.communityReplies = replies;
    this.selectedReplyParent = parent ?? this.selectedReplyParent;
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

  private selectedCommunityPromptOwned(): boolean {
    const post: CommunityPost | undefined = this.selectedPost;
    if (!post) return false;
    return post.mine === true ||
      ((post.owner ?? '').length > 0 && post.owner === authStore.storageScope());
  }

  private selectedCommunityPromptImported(): boolean {
    const code: string = this.selectedPost?.promptCode ?? '';
    return code.length > 0 && PromptTree.containsImport(promptStore.items(), code);
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

  private detailTitleVisualUnits(title: string): number {
    let units: number = 0;
    for (let index: number = 0; index < title.length; index++) {
      units += title.charCodeAt(index) <= 0x7F ? 0.56 : 1;
    }
    return Math.max(1, units);
  }

  private detailTitleFontSize(title: string, preferred: number): number {
    const windowWidth: number = this.windowWidthPx > 0 ? this.getUIContext().px2vp(this.windowWidthPx) : 360;
    const contentWidth: number = Math.max(1, windowWidth - 44);
    const fitted: number = Math.floor(contentWidth / this.detailTitleVisualUnits(title) * 2) / 2;
    return fitted >= 23 && fitted < preferred ? fitted : preferred;
  }

  private detailTitleLineHeight(title: string, preferred: number): number {
    return this.detailTitleFontSize(title, preferred) + 10;
  }

  @Builder
  private communityDetailSummary() {
    Column() {
      Text(this.selectedPost?.title ?? '(无题)')
        .fontSize(this.detailTitleFontSize(this.selectedPost?.title ?? '(无题)', 26))
        .fontWeight(FontWeight.Bold).fontColor(Theme.INK)
        .lineHeight(this.detailTitleLineHeight(this.selectedPost?.title ?? '(无题)', 26)).width('100%')
      Row({ space: 8 }) {
        Text(this.communityAuthor(this.selectedPost))
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG)
        if (this.communityDate(this.selectedPost).length > 0) {
          Text(this.communityDate(this.selectedPost)).fontSize(14).fontColor(Theme.SECONDARY)
        }
      }.width('100%').margin({ top: 9, bottom: 4 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  private articleHeadingFontSize(value: string): number {
    const level: number = ArticleBody.markdownHeadingLevel(value);
    if (level === 1) return 22;
    if (level === 2) return 20;
    return 18;
  }

  private articleHeadingLineHeight(value: string): number {
    const level: number = ArticleBody.markdownHeadingLevel(value);
    if (level === 1) return 32;
    if (level === 2) return 30;
    return 27;
  }

  @Builder
  private articleHeadingBlock(block: ArticleBlock, editable: boolean, blockIndex: number, lineNumber: number) {
    if (editable) {
      Stack({ alignContent: Alignment.TopStart }) {
        Text(ArticleBody.markdownDisplayText(block.value))
          .fontSize(this.articleHeadingFontSize(block.value))
          .lineHeight(this.articleHeadingLineHeight(block.value))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.INK)
          .width('100%')
          .padding({ top: 6, bottom: 12 })
          .copyOption(CopyOptions.LocalDevice)
        if (this.showArticleLines) {
          Text(`${lineNumber}`)
            .fontSize(11).lineHeight(this.articleHeadingLineHeight(block.value))
            .fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG)
            .width(20).textAlign(TextAlign.End).position({ x: -24, y: 6 })
        }
      }
        .width('100%').clip(false)
        .gesture(LongPressGesture().onAction((event: GestureEvent) => {
          if (!this.paragraphEditing) this.openPromptMenu(block, blockIndex, lineNumber, event);
        }))
    } else {
      Text(ArticleBody.markdownDisplayText(block.value))
        .fontSize(this.articleHeadingFontSize(block.value))
        .lineHeight(this.articleHeadingLineHeight(block.value))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.INK)
        .width('100%')
        .padding({ top: 6, bottom: 12 })
        .copyOption(CopyOptions.LocalDevice)
    }
  }

  @Builder
  private articleBlock(block: ArticleBlock, editable: boolean = false, blockIndex: number = -1,
    lineNumber: number = 0, imageNumber: number = 0) {
    if (block.kind === 'photo') {
      if (editable) {
        Stack({ alignContent: Alignment.TopStart }) {
          ArticlePhotoView({
            photoKey: this.blockPhotoKey(block.value),
            intent: this.photoIntent(block.value),
            loadPhoto: (ignoringLocalCache: boolean) =>
              this.loadArticlePhotoToken(block.value, ignoringLocalCache),
            onLoaded: () => this.cacheArticlePhotoToken(block.value),
            onLongPress: (event: GestureEvent) => {
              if (!this.paragraphEditing) this.openPromptMenu(block, blockIndex, lineNumber, event);
            }
          })
          if (this.showArticleLines) {
            Text(`${lineNumber}`)
              .fontSize(11).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG)
              .width(20).textAlign(TextAlign.End).position({ x: -24, y: 21 })
            Text(`图${imageNumber}`)
              .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Theme.WHITE)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('#66000000').borderRadius(6).position({ x: 8, y: 44 })
          }
        }
          .width('100%').clip(false)
      } else {
        ArticlePhotoView({
          photoKey: this.blockPhotoKey(block.value), intent: 'original',
          loadPhoto: (ignoringLocalCache: boolean) =>
            this.loadArticlePhotoToken(block.value, ignoringLocalCache),
          onLoaded: () => this.cacheArticlePhotoToken(block.value)
        })
      }
    } else {
      if (editable) {
        if (this.paragraphEditing && this.paragraphEditArticleIndex === this.selectedArticle &&
          this.paragraphEditLine === lineNumber) {
          Row() {
            TextArea({
              text: this.paragraphEditText,
              placeholder: '编辑这一段文字',
              controller: this.paragraphEditController
            })
              .id(PARAGRAPH_EDIT_INPUT_ID)
              .fontSize(16)
              .lineHeight(28)
              .fontColor(Theme.INK)
              .caretColor(Theme.ACCENT_STRONG)
              .maxLines(8)
              .enterKeyType(EnterKeyType.Done)
              .enableKeyboardOnFocus(true)
              .enabled(!this.paragraphEditSaving)
              .padding({ left: 4, right: 4, top: 0, bottom: 0 })
              .layoutWeight(1)
              .backgroundColor('#FFFDF9')
              .border({ width: 1, color: 'rgba(216, 89, 59, 0.52)', radius: 7 })
              .borderRadius(7)
              .focusBox({
                margin: LengthMetrics.vp(0),
                strokeColor: ColorMetrics.rgba(216, 89, 59, 0.52),
                strokeWidth: LengthMetrics.vp(1)
              })
              .onChange((value: string) => this.paragraphEditText = value)
              .onSubmit(() => this.saveParagraphEdit())
              .onEditChange((isEditing: boolean) => {
                if (isEditing) this.placeParagraphCaretAtEnd(30);
              })
              .onAppear(() => this.focusParagraphEditor())
          }
            .width('100%')
            .padding({ left: 4, right: 4 })
        } else if (ArticleBody.markdownHeadingLevel(block.value) > 0) {
          this.articleHeadingBlock(block, true, blockIndex, lineNumber)
        } else {
          Stack({ alignContent: Alignment.TopStart }) {
            Text(block.value).fontSize(16).lineHeight(28).fontColor(Theme.INK)
              .width('100%').padding({ bottom: 8 }).copyOption(CopyOptions.LocalDevice)
            if (this.showArticleLines) {
              Text(`${lineNumber}`)
                .fontSize(11).lineHeight(28).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG)
                .width(20).textAlign(TextAlign.End).position({ x: -24, y: 0 })
            }
          }
            .width('100%').clip(false)
            .gesture(LongPressGesture().onAction((event: GestureEvent) => {
              if (!this.paragraphEditing) this.openPromptMenu(block, blockIndex, lineNumber, event);
            }))
        }
      } else if (ArticleBody.markdownHeadingLevel(block.value) > 0) {
        this.articleHeadingBlock(block, false, blockIndex, lineNumber)
      } else {
        Text(block.value)
          .fontSize(16)
          .lineHeight(28)
          .fontColor(Theme.INK)
          .width('100%')
          .padding({ bottom: 8 })
          .copyOption(CopyOptions.LocalDevice)
      }
    }
  }

  private blockPhotoKey(token: string): string {
    const communityDetail: boolean = this.isCommunityDetailActive();
    const doc: ArticleDoc | undefined = communityDetail ? this.selectedPost?.doc : this.article;
    if (!doc) return '';
    const key: string | undefined = ArticleBody.resolvePhotoKey(token, doc.photos);
    if (!key) return '';
    const owner: string = (doc.owner ?? '').replace(/\/+$/, '');
    const fullKey: string = owner.length > 0 && !key.startsWith('users/') ? `${owner}/${key}` : key;
    return fullKey;
  }

  private async loadArticlePhotoToken(token: string, ignoringLocalCache: boolean): Promise<string> {
    const fullKey: string = this.blockPhotoKey(token);
    if (fullKey.length === 0) return '';
    return photoService.fetchArticlePhoto(fullKey, ignoringLocalCache);
  }

  private isGeneratedPhoto(token: string): boolean {
    if (!this.article) return false;
    const key: string | undefined = ArticleBody.resolvePhotoKey(token, this.article.photos);
    if (!key) return false;
    const owner: string = (this.article.owner ?? '').replace(/\/+$/, '');
    const fullKey: string = owner.length > 0 && !key.startsWith('users/') ? `${owner}/${key}` : key;
    return this.generatedPhotoKeys.includes(fullKey);
  }

  private photoIntent(token: string): PhotoLoadIntent {
    const fullKey: string = this.blockPhotoKey(token);
    if (this.pendingPhotoKeys.includes(fullKey)) return 'pending';
    if (this.makingGeneratedPhotoKeys.includes(fullKey)) return 'generatedPending';
    return this.isGeneratedPhoto(token) ? 'generated' : 'original';
  }

  private startPendingPhotoEdit(id: string, fullKey: string): void {
    if (fullKey.length === 0) return;
    this.pendingPhotoRequests.set(id, fullKey);
    if (!this.pendingPhotoKeys.includes(fullKey)) {
      this.pendingPhotoKeys = this.pendingPhotoKeys.concat(fullKey);
    }
  }

  private finishPendingPhotoEdit(id: string): void {
    const fullKey: string | undefined = this.pendingPhotoRequests.get(id);
    if (!fullKey) return;
    this.pendingPhotoRequests.delete(id);
    let stillPending: boolean = false;
    this.pendingPhotoRequests.forEach((key: string) => {
      if (key === fullKey) stillPending = true;
    });
    if (!stillPending) {
      this.pendingPhotoKeys = this.pendingPhotoKeys.filter((key: string) => key !== fullKey);
    }
  }

  private continuePendingPhotoEdit(id: string, introducedKeys: string[]): void {
    if (!this.pendingPhotoRequests.has(id) || introducedKeys.length === 0) return;
    this.makingGeneratedPhotoKeys = Array.from(new Set<string>(
      this.makingGeneratedPhotoKeys.concat(introducedKeys)));
  }

  private clearPendingPhotoEdits(): void {
    this.pendingPhotoRequests.clear();
    this.pendingPhotoKeys = [];
    this.makingGeneratedPhotoKeys = [];
  }

  private warmArticlePhotos(doc?: ArticleDoc): void {
    if (!doc) return;
    photoService.cacheArticlePhotos(doc).catch(() => {});
  }

  private cacheArticlePhotoToken(token: string): void {
    const doc: ArticleDoc | undefined = this.isCommunityDetailActive() ? this.selectedPost?.doc : this.article;
    if (!doc) return;
    const key: string | undefined = ArticleBody.resolvePhotoKey(token, doc.photos);
    if (!key) return;
    const owner: string = (doc.owner ?? '').replace(/\/+$/, '');
    const fullKey: string = owner.length > 0 && !key.startsWith('users/') ? `${owner}/${key}` : key;
    photoService.cacheArticlePhoto(fullKey).catch(() => {});
  }

  private articleLine(blockIndex: number): number {
    if (!this.article) return 1;
    return ArticleBody.visibleLine(ArticleBody.blocks(this.article.articles[this.selectedArticle].body), blockIndex);
  }

  private openPromptMenu(block: ArticleBlock, blockIndex: number, lineNumber: number = 0,
    event?: GestureEvent): void {
    if (!this.editSession || !this.article) return;
    const anchor: string = block.kind === 'photo' ? 'image' : 'text';
    const nodes: PromptNode[] = PromptTree.menu(promptStore.items(), anchor);
    if (nodes.length === 0) { promptAction.showToast({ message: '请先在设置中添加快捷提示词' }); return; }
    this.promptMenuNodes = nodes; this.promptMenuNested = false;
    const finger: FingerInfo | undefined = event?.fingerList.length ? event.fingerList[0] : undefined;
    // Use the actual finger position. Subtracting localY/localX yields the
    // pressed view's top-left, which can be above the viewport for a long image
    // and makes the popup clamp to the screen top.
    this.promptMenuAnchorX = finger && finger.globalX > 0 ? finger.globalX : 16;
    this.promptMenuAnchorY = finger && finger.globalY > 0 ? finger.globalY : 160;
    this.promptTargetKind = block.kind; this.promptTargetValue = block.value;
    this.promptTargetIndex = blockIndex; this.promptTargetLine = lineNumber; this.showPromptMenu = true;
  }

  private openPromptGroup(group: PromptNode): void {
    this.promptMenuNodes = group.children.map((node: PromptNode) => node.copy());
    this.promptMenuNested = true;
  }

  private showPromptRoot(): void {
    const anchor: string = this.promptTargetKind === 'photo' ? 'image' : 'text';
    this.promptMenuNodes = PromptTree.menu(promptStore.items(), anchor);
    this.promptMenuNested = false;
  }

  private systemPromptMenuNodes(): PromptNode[] {
    return this.promptMenuNodes.filter((node: PromptNode) => node.origin === 'system');
  }

  private customPromptMenuNodes(): PromptNode[] {
    return this.promptMenuNodes.filter((node: PromptNode) => node.origin !== 'system');
  }

  private promptMenuWindowWidth(): number {
    return this.windowWidthPx > 0 ? this.getUIContext().px2vp(this.windowWidthPx) : 360;
  }

  private promptMenuWindowHeight(): number {
    return this.windowHeightPx > 0 ? this.getUIContext().px2vp(this.windowHeightPx) : 800;
  }

  private promptMenuSurfaceWidth(): number {
    return Math.min(340, Math.max(240, this.promptMenuWindowWidth() - 48));
  }

  private promptMenuSurfaceMaxHeight(): number {
    return Math.min(504, Math.max(240, this.promptMenuWindowHeight() * 0.68 - 16));
  }

  private promptMenuListHeight(nodes: PromptNode[]): number {
    return nodes.length === 0 ? 0 : nodes.length * 48 + nodes.length - 1;
  }

  private promptMenuHasBottomRows(): boolean {
    return !this.promptMenuNested && this.promptTargetKind !== 'photo';
  }

  private promptMenuSectionDividerCount(): number {
    if (this.promptMenuNested) return this.promptMenuNodes.length > 0 ? 1 : 0;
    const hasTop: boolean = this.systemPromptMenuNodes().length > 0;
    const hasScrollable: boolean = this.customPromptMenuNodes().length > 0;
    const hasBottom: boolean = this.promptMenuHasBottomRows();
    return (hasTop && hasScrollable ? 1 : 0) + (hasBottom && (hasTop || hasScrollable) ? 1 : 0);
  }

  private promptMenuFixedHeight(): number {
    const topHeight: number = this.promptMenuNested ? 48 :
      this.promptMenuListHeight(this.systemPromptMenuNodes());
    const bottomHeight: number = this.promptMenuHasBottomRows() ? 97 : 0;
    return 8 + topHeight + bottomHeight + this.promptMenuSectionDividerCount();
  }

  private promptMenuScrollableNodes(): PromptNode[] {
    return this.promptMenuNested ? this.promptMenuNodes : this.customPromptMenuNodes();
  }

  private promptMenuScrollMaxHeight(): number {
    return Math.max(0, this.promptMenuSurfaceMaxHeight() - this.promptMenuFixedHeight());
  }

  private promptMenuEstimatedSurfaceHeight(): number {
    const contentHeight: number =
      this.promptMenuFixedHeight() + this.promptMenuListHeight(this.promptMenuScrollableNodes());
    return Math.min(this.promptMenuSurfaceMaxHeight(), contentHeight);
  }

  private promptMenuSurfaceX(): number {
    const windowWidth: number = this.promptMenuWindowWidth();
    const outerWidth: number = this.promptMenuSurfaceWidth() + 16;
    const outerX: number = Math.max(16, Math.min(this.promptMenuAnchorX, windowWidth - outerWidth - 16));
    return outerX + 8;
  }

  private promptMenuSurfaceY(): number {
    const windowHeight: number = this.promptMenuWindowHeight();
    const outerHeight: number = this.promptMenuEstimatedSurfaceHeight() + 16;
    const outerY: number = Math.max(16,
      Math.min(this.promptMenuAnchorY, windowHeight - outerHeight - 16));
    return outerY + 8;
  }

  private copyPromptTarget(): void {
    pasteboard.getSystemPasteboard().setData(pasteboard.createPlainTextData(this.promptTargetValue));
    this.showPromptMenu = false; promptAction.showToast({ message: '已拷贝' });
  }

  private editPromptTarget(): void {
    this.showPromptMenu = false;
    this.beginParagraphEdit();
  }

  private async applyPrompt(action: PromptNode): Promise<void> {
    if (!this.editSession || !this.article || !this.selected) return;
    this.showPromptMenu = false;
    let instruction: string = action.prompt;
    let anchor: EditAnchor;
    let pendingPhotoKey: string = '';
    if (this.promptTargetKind === 'photo') {
      const articlePhotos: string[] = this.article.photos ?? [];
      const resolvedKey: string | undefined = ArticleBody.resolvePhotoKey(this.promptTargetValue, articlePhotos);
      if (!resolvedKey || resolvedKey.trim().length === 0) {
        promptAction.showToast({ message: '这篇旧文章的图片信息不完整，无法编辑' });
        return;
      }
      const key: string = resolvedKey.trim();
      const currentArticle: MinedArticle = this.article.articles[this.selectedArticle];
      const materializedBody: string =
        ArticleBody.materializePhotoMarker(currentArticle.body, this.promptTargetValue, articlePhotos);
      if (materializedBody !== currentArticle.body) {
        const migratedArticles: MinedArticle[] = this.article.articles.slice();
        migratedArticles[this.selectedArticle] = {
          title: currentArticle.title,
          body: materializedBody,
          style: currentArticle.style,
          wechatMediaId: currentArticle.wechatMediaId
        };
        const migratedDoc: ArticleDoc = {
          id: this.article.id,
          transcript: this.article.transcript,
          articles: migratedArticles,
          tags: this.article.tags,
          questions: this.article.questions,
          photos: this.article.photos,
          owner: this.article.owner
        };
        let saved: boolean = false;
        try {
          saved = await libraryStore.saveArticle(this.selected, migratedDoc);
        } catch (_) {}
        if (!saved) {
          promptAction.showToast({ message: '旧文章图片标记升级失败，请重试' });
          return;
        }
        this.article = migratedDoc;
      }
      instruction = instruction.replace(/\{\{KEY\}\}/g, key);
      anchor = EditAnchor.forImage(key);
      pendingPhotoKey = this.blockPhotoKey(this.promptTargetValue);
    } else {
      const blocks: ArticleBlock[] = ArticleBody.blocks(this.article.articles[this.selectedArticle].body);
      const line: number = this.promptTargetLine > 0 ?
        this.promptTargetLine : ArticleBody.visibleLine(blocks, this.promptTargetIndex);
      const quote: string = this.promptTargetValue.trim().replace(/\s+/g, ' ').substring(0, 24);
      instruction = instruction.replace(/\{\{LINE\}\}/g, `${line}`).replace(/\{\{QUOTE\}\}/g, quote);
      anchor = EditAnchor.forLine(line, this.promptTargetValue);
    }
    const requestId: string = `${Date.now()}`;
    if (pendingPhotoKey.length > 0) this.startPendingPhotoEdit(requestId, pendingPhotoKey);
    let sent: boolean = false;
    try {
      sent = await this.editSession.sendEdit(requestId, instruction, this.selectedArticle, anchor, action.id);
    } catch (_) {}
    if (!sent) {
      this.finishPendingPhotoEdit(requestId);
      promptAction.showToast({ message: '指令发送失败，请重试' });
      return;
    }
    this.articleEditQueue = ArticleEditUi.enqueue(this.articleEditQueue, requestId, instruction);
    promptAction.showToast({ message: '已加入修改队列' });
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
        if (index > 0) this.configuredPromptDivider()
        this.configuredPromptRow(node)
      }, (node: PromptNode) => node.id)
    }.width('100%')
  }

  @Builder
  private configuredPromptDivider() {
    Divider().height(1).color('#E4E1DB').margin({ left: 18, right: 18 })
  }

  @Builder
  private promptMenuBottomRows() {
    Column() {
      Row() {
        Text('拷贝').fontSize(16).fontColor('#252525')
      }
        .height(48).padding({ left: 18, right: 18 }).width('100%')
        .onClick(() => this.copyPromptTarget())
      this.configuredPromptDivider()
      Row() {
        Text('编辑').fontSize(16).fontColor('#252525')
      }
        .height(48).padding({ left: 18, right: 18 }).width('100%')
        .onClick(() => this.editPromptTarget())
    }.width('100%')
  }

  @Builder
  private promptMenuSurface() {
    Column() {
      if (this.promptMenuNested) {
        Row() {
          Text('返回').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.SECONDARY)
        }
          .height(48).padding({ left: 18, right: 18 }).width('100%')
          .onClick(() => this.showPromptRoot())
        if (this.promptMenuNodes.length > 0) this.configuredPromptDivider()
        if (this.promptMenuNodes.length > 0) {
          Scroll() {
            this.configuredPromptList(this.promptMenuNodes)
          }
            .constraintSize({ maxHeight: this.promptMenuScrollMaxHeight() })
            .width('100%')
            .scrollBar(BarState.On)
            .edgeEffect(EdgeEffect.Spring)
        }
      } else {
        if (this.systemPromptMenuNodes().length > 0) {
          this.configuredPromptList(this.systemPromptMenuNodes())
        }
        if (this.systemPromptMenuNodes().length > 0 && this.customPromptMenuNodes().length > 0) {
          this.configuredPromptDivider()
        }
        if (this.customPromptMenuNodes().length > 0) {
          Scroll() {
            this.configuredPromptList(this.customPromptMenuNodes())
          }
            .constraintSize({ maxHeight: this.promptMenuScrollMaxHeight() })
            .width('100%')
            .scrollBar(BarState.On)
            .edgeEffect(EdgeEffect.Spring)
        }
        if (this.promptMenuHasBottomRows()) {
          if (this.systemPromptMenuNodes().length > 0 || this.customPromptMenuNodes().length > 0) {
            this.configuredPromptDivider()
          }
          this.promptMenuBottomRows()
        }
      }
    }
      .padding({ top: 4, bottom: 4 })
      .constraintSize({ maxHeight: this.promptMenuSurfaceMaxHeight() })
      .width(this.promptMenuSurfaceWidth())
      .backgroundColor('#FAFFFFFF')
      .borderRadius(14)
      .clip(true)
      .shadow({ radius: 14, color: '#2B2A2529', offsetX: 0, offsetY: 6 })
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
      .stateEffect(false)
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
    }.height(56).padding({ left: 16, right: 12, top: 8, bottom: 0 }).width('100%')
  }

  @Builder
  private detailToolbar() {
    Row() {
      if (this.paragraphEditing) {
        Button('取消')
          .height(40).padding({ left: 4, right: 4 })
          .fontSize(15).fontColor(Theme.SECONDARY)
          .backgroundColor(Color.Transparent)
          .enabled(!this.paragraphEditSaving)
          .onClick(() => this.closeParagraphEdit())
        Blank()
        Button(this.paragraphEditSaving ? '保存中…' : '完成')
          .height(40).padding({ left: 4, right: 4 })
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG)
          .backgroundColor(Color.Transparent)
          .enabled(!this.paragraphEditSaving)
          .opacity(this.paragraphEditSaving ? 0.55 : 1)
          .onClick(() => this.saveParagraphEdit())
      } else {
        this.detailBackButton()
        Blank()
        if (!this.detailLoading && this.article && this.article.articles.length > 0) {
          this.detailPlaybackButton()
          Button({ type: ButtonType.Normal }) {
            if (this.insertingPhotos) {
              LoadingProgress().width(21).height(21).color(Theme.ACCENT_STRONG)
            } else {
              RemixIcon({ glyph: RI.IMAGE, iconSize: 25, color: Theme.INK })
            }
          }
            .width(40).height(40).padding(0).margin({ left: 8 })
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.BORDER, radius: 11 })
            .borderRadius(11).clip(true)
            .shadow({ radius: 5, color: '#34291F22', offsetX: 0, offsetY: 2 })
            .enabled(!this.insertingPhotos)
            .onClick(() => this.insertPhotos())
          Row() {
            Button({ type: ButtonType.Normal }) {
              RemixIcon({
                glyph: RI.ARROW_GO_BACK,
                iconSize: 25,
                color: this.canUndo() ? Theme.INK : Theme.FAINT
              })
            }
              .width(40).height(40).padding(0).backgroundColor(Color.Transparent)
              .enabled(this.canUndo()).onClick(() => this.shiftHistory(-1))
            Divider().vertical(true).height(24).color(Theme.BORDER)
            Button({ type: ButtonType.Normal }) {
              RemixIcon({
                glyph: RI.ARROW_GO_FORWARD,
                iconSize: 25,
                color: this.canRedo() ? Theme.INK : Theme.FAINT
              })
            }
              .width(40).height(40).padding(0).backgroundColor(Color.Transparent)
              .enabled(this.canRedo()).onClick(() => this.shiftHistory(1))
          }
            .height(40).margin({ left: 8 })
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.BORDER, radius: 11 })
            .borderRadius(11).clip(true)
            .shadow({ radius: 5, color: '#34291F22', offsetX: 0, offsetY: 2 })
          Button({ type: ButtonType.Normal }) {
            RemixIcon({ glyph: RI.MORE, iconSize: 24, color: Theme.SECONDARY })
          }
            .width(40).height(40).padding(0).margin({ left: 8 })
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.BORDER, radius: 11 })
            .borderRadius(11).clip(true)
            .shadow({ radius: 5, color: '#34291F22', offsetX: 0, offsetY: 2 })
            .onClick(() => this.showDetailMenu = !this.showDetailMenu)
        }
      }
    }.height(56).padding({ left: 16, right: 12, top: 8, bottom: 0 }).width('100%')
  }

  @Builder
  private detailPlaybackButton() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.playbackLoading || this.playing || this.playbackDuration > 0) {
        Progress({ value: 100, total: 100, type: ProgressType.Ring })
          .width(40).height(40)
          .color('#33DF5B49')
          .style({ strokeWidth: 3, enableSmoothEffect: true })
        Progress({
          value: Math.min(this.playbackProgress, Math.max(1, this.playbackDuration)),
          total: Math.max(1, this.playbackDuration),
          type: ProgressType.Ring
        })
          .width(40).height(40)
          .color(Theme.ACCENT_STRONG)
          .style({ strokeWidth: 3, enableSmoothEffect: true })
      }
      Button({ type: ButtonType.Normal }) {
        if (this.playbackLoading) {
          LoadingProgress().width(20).height(20).color(Theme.WHITE)
        } else if (this.playing) {
          Text('■').fontSize(15).fontColor(Theme.WHITE)
        } else {
          RemixIcon({ glyph: RI.PLAY, iconSize: 23, color: Theme.WHITE })
        }
      }
        .width(32).height(32).padding(0).borderRadius(16)
        .backgroundColor(Theme.ACCENT_STRONG)
        .shadow({ radius: 5, color: '#34291F2B', offsetX: 0, offsetY: 2 })
        .stateEffect(false)
        .onClick(() => this.togglePlayback())
    }.width(40).height(40)
  }

  private detailSubtitle(): string {
    if (!this.selected) return '';
    const parsed = RecordingName.parse(this.selected.name);
    if (!parsed) return '';
    return `${parsed.month}月${parsed.day}日${parsed.hhmm.length > 0 ? ` ${parsed.hhmm}` : ''}`;
  }

  private detailSummaryTitle(): string {
    const current: MinedArticle | undefined = this.article?.articles[this.selectedArticle];
    return current?.title || this.selected?.rowTitle() || '(无题)';
  }

  @Builder
  private recordingDetailSummary(showStyle: boolean) {
    Column() {
      Text(this.detailSummaryTitle())
        .fontSize(this.detailTitleFontSize(this.detailSummaryTitle(), 23))
        .fontWeight(FontWeight.Bold).fontColor(Theme.INK)
        .lineHeight(this.detailTitleLineHeight(this.detailSummaryTitle(), 23)).width('100%')
      Row({ space: 4 }) {
        Text(this.detailSubtitle()).fontSize(13).fontColor(Theme.SECONDARY)
        if (showStyle) {
          Button(`✎  ${this.currentArticleStyleVersion() === undefined ?
            '选风格' : `v${this.currentArticleStyleVersion()} 风格`}  ›`)
            .fontSize(13).fontColor(Theme.FAINT).height(28).padding({ left: 8, right: 8 })
            .backgroundColor(Color.Transparent)
            .enabled(!this.paragraphEditing)
            .onClick(() => this.openStyleRewrite())
        }
      }.width('100%').margin({ top: 8, bottom: 4 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  private currentArticleStyleVersion(): number | undefined {
    const article: MinedArticle | undefined = this.article?.articles[this.selectedArticle];
    return article ? StyleRewriteUi.articleStyleVersion(article.style, article.body) : undefined;
  }

  private detailVoiceLabel(): string {
    if (this.holdEditPressed) {
      return this.holdEditCanceled ? '上滑取消 · 松开放弃' : '松开 发送 · 上滑取消';
    }
    if (this.holdEditFinishing) return '正在整理…';
    if (this.dictating) return '正在识别…';
    if (this.articleEditQueue.length > 0) return '正在改…按住继续说';
    return this.pendingQuestion() ? '按住 说话 回答' : '按住 说话 修改';
  }

  private articleEditQueueHeight(): number {
    return Math.min(174, this.articleEditQueue.length * 58);
  }

  private articleEditFeedbackHeight(): number {
    return (this.articleEditReply.length > 0 ? 58 : 0) +
      (this.articleEditQueue.length > 0 ? this.articleEditQueueHeight() + 8 : 0);
  }

  private detailContentBottomPadding(): number {
    if (this.paragraphEditing) return 40 + this.safeAreaBottom();
    return (this.pendingQuestion() ? 230 : 110) + this.articleEditFeedbackHeight() + this.safeAreaBottom();
  }

  private articleEditInFlight(item: ArticleEditQueueItem): boolean {
    return this.articleEditQueue.length > 0 && this.articleEditQueue[0].id === item.id;
  }

  @Builder
  private articleEditFeedbackPanel() {
    if (this.articleEditReply.length > 0) {
      Text(`${this.articleEditReplyOk ? '✨' : '⚠'} ${this.articleEditReply}`)
        .fontSize(14).lineHeight(20)
        .fontColor(this.articleEditReplyOk ? Theme.INK : '#C4413A')
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .constraintSize({ minHeight: 48 })
        .width('100%')
        .backgroundColor(Theme.CARD)
        .borderRadius(12)
    }
    if (this.articleEditQueue.length > 0) {
      Scroll() {
        Column({ space: 6 }) {
          ForEach(this.articleEditQueue.slice().reverse(), (item: ArticleEditQueueItem) => {
            Text(`${this.articleEditInFlight(item) ? '✎' : '⏱'} ${item.text}`)
              .fontSize(14).lineHeight(20)
              .fontColor(this.articleEditInFlight(item) ? Theme.INK : Theme.SECONDARY)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .constraintSize({ minHeight: 48 })
              .width('100%')
              .backgroundColor(this.articleEditInFlight(item) ? '#FFF0D8' : Theme.CARD)
              .borderRadius(12)
          }, (item: ArticleEditQueueItem): string => item.id)
        }.width('100%')
      }
        .height(this.articleEditQueueHeight())
        .width('100%')
        .scrollBar(BarState.Off)
    }
  }

  private detailVoiceBubbleText(): string {
    if (this.holdEditTranscriptText.trim().length > 0) return this.holdEditTranscriptText.trim();
    if (this.holdEditPromptText.length > 0) return this.holdEditPromptText;
    return '在听…';
  }

  @Builder
  private detailVoiceBubble() {
    Column({ space: 0 }) {
      Text(this.detailVoiceBubbleText())
        .fontSize(16).lineHeight(23).fontColor('#FBF6EE')
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .constraintSize({ minHeight: 48 }).width('100%')
        .backgroundColor('#2E2823').borderRadius(16)
      Row() {
        Column().width(12).height(12).backgroundColor('#2E2823').rotate({ angle: 45 })
      }.height(9).width('100%').padding({ left: 28 }).margin({ top: -6 })
    }.width('100%').alignItems(HorizontalAlign.Start)
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
      .backgroundColor(this.holdEditCanceled ? '#FFE5E5' :
        (this.holdEditFinishing ? '#FFF0D8' : '#FFFBF7'))
      .border({ width: 1, color: '#E8DED0', radius: 16 })
      .borderRadius(16).clip(true)
      .shadow({ radius: 9, color: '#34291F22', offsetX: 0, offsetY: 3 })
      .stateEffect(false)
      .onTouch((event: TouchEvent) => this.handleEditHold(event))
  }

  @Builder
  private detailPage() {
    Column() {
      this.detailToolbar()
      if (this.detailLoading) {
        Column() {
          this.recordingDetailSummary(false)
          this.pageLoadingState()
          Blank()
        }
          .layoutWeight(1).width('100%')
          .padding({ left: 22, right: 22, top: 8, bottom: 40 })
          .alignItems(HorizontalAlign.Start)
      } else if (this.detailLoadError.length > 0 && !this.article) {
        Column() {
          this.recordingDetailSummary(false)
          Column({ space: 14 }) {
            Text(this.detailLoadError).fontSize(16).fontColor(Theme.SECONDARY)
            Button('重新加载').fontSize(14).height(38).backgroundColor(Theme.ACCENT_STRONG)
              .onClick(() => {
                if (this.selected) this.openRecording(this.selected);
              })
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        }
          .layoutWeight(1).width('100%')
          .padding({ left: 22, right: 22, top: 8, bottom: 40 })
          .alignItems(HorizontalAlign.Start)
      } else if (!this.article || this.article.articles.length === 0) {
        Column() {
          this.recordingDetailSummary(false)
          Column({ space: 14 }) {
            LoadingProgress().width(36).height(36).color(Theme.ACCENT_STRONG)
            Text(this.selected?.statusLabel() ?? '正在处理').fontSize(18).fontColor(Theme.INK)
            Text('转写和文章生成完成后会自动刷新').fontSize(14).fontColor(Theme.SECONDARY)
          }
            .layoutWeight(1)
            .width('100%')
            .padding({ top: 48 })
            .justifyContent(FlexAlign.Start)
            .alignItems(HorizontalAlign.Center)
        }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 22, right: 22, top: 8, bottom: 40 })
          .alignItems(HorizontalAlign.Start)
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          Scroll() {
            Column() {
              this.recordingDetailSummary(true)
              if (this.article.articles.length > 1) {
                Scroll() {
                  Row({ space: 8 }) {
                    ForEach(this.article.articles, (article: MinedArticle, index: number) => {
                      Button(article.title)
                        .height(32).fontSize(13).fontWeight(FontWeight.Bold)
                        .fontColor(this.selectedArticle === index ? Theme.WHITE : Theme.SECONDARY)
                        .backgroundColor(this.selectedArticle === index ? Theme.ACCENT_STRONG : Color.Transparent)
                        .borderRadius(16).padding({ left: 14, right: 14 })
                        .enabled(!this.paragraphEditing)
                        .onClick(() => this.selectedArticle = index)
                    })
                  }
                }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
                  .margin({ bottom: 12 })
              }
              ForEach(ArticleBody.locatedBlocks(this.article.articles[this.selectedArticle].body),
                (block: ArticleBlock, index: number) =>
                  this.articleBlock(block, true, index, block.lineNumber ?? 0, block.imageNumber ?? 0),
                (block: ArticleBlock, index: number) => `${index}:${block.kind}:${block.value}`)
            }
              .padding({
                left: 22,
                right: 22,
                top: 8,
                bottom: this.detailContentBottomPadding()
              })
              .constraintSize({ minHeight: '100%' })
              .justifyContent(FlexAlign.Start)
              .alignItems(HorizontalAlign.Start)
              .width('100%')
          }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          if (!this.paragraphEditing) {
            Column({ space: 8 }) {
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
                  .padding(12).width('100%')
                  .backgroundColor('#FFFBF7')
                  .border({ width: 1, color: '#FFD6AD', radius: 14 })
                  .borderRadius(14).alignItems(HorizontalAlign.Start)
              }
              this.articleEditFeedbackPanel()
              if (this.holdEditPressed || this.holdEditFinishing) {
                this.detailVoiceBubble()
              }
              this.detailVoiceButton()
            }
              .padding({ left: 20, right: 20, bottom: 12 + this.safeAreaBottom() })
              .width('100%')
              .layoutGravity(LocalizedAlignment.BOTTOM)
          }
        }.layoutWeight(1).width('100%')
      }
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.BG)
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

  private historyTarget(delta: number): number | undefined {
    return ArticleVersionNavigation.target(this.history.head, this.history.versions, delta);
  }

  private canUndo(): boolean { return !this.historySwitching && this.historyTarget(-1) !== undefined; }
  private canRedo(): boolean { return !this.historySwitching && this.historyTarget(1) !== undefined; }

  private async shiftHistory(delta: number): Promise<void> {
    if (!this.selected || !this.article || this.historySwitching) return;
    const recording: Recording = this.selected;
    this.historySwitching = true;
    try {
      const freshHistory: ArticleHistory = await libraryStore.versionHistory(recording);
      if (this.selected?.stem() !== recording.stem()) return;
      this.history = freshHistory;
      const targetHead: number | undefined =
        ArticleVersionNavigation.target(freshHistory.head, freshHistory.versions, delta);
      const target: ArticleVersion | undefined = targetHead === undefined ? undefined :
        freshHistory.versions.find((version: ArticleVersion) => version.v === targetHead);
      if (!target) {
        promptAction.showToast({ message: delta < 0 ? '没有更早的版本' : '没有更新的版本' });
        return;
      }
      const oldArticle: ArticleDoc = this.article;
      const oldHead: number = freshHistory.head;
      const oldSelectedArticle: number = this.selectedArticle;
      this.article = libraryStore.articleFromVersion(this.article, target);
      this.selectedArticle = Math.min(this.selectedArticle, Math.max(0, this.article.articles.length - 1));
      this.history.head = target.v;
      this.history = this.history;
      let patched: boolean = false;
      try {
        patched = await libraryStore.patchHead(recording, target.v);
      } catch (_) {}
      if (!patched) {
        this.article = oldArticle;
        this.selectedArticle = oldSelectedArticle;
        this.history.head = oldHead;
        this.history = this.history;
        promptAction.showToast({ message: '版本切换失败' });
      } else {
        await libraryStore.cacheArticle(recording, this.article);
        this.warmArticlePhotos(this.article);
      }
    } catch (_) {
      promptAction.showToast({ message: '版本切换失败' });
    } finally {
      this.historySwitching = false;
    }
  }

  private placeParagraphCaretAtEnd(delay: number = 0): void {
    setTimeout(() => {
      if (!this.paragraphEditing) return;
      const end: number = this.paragraphEditText.length;
      this.paragraphEditController.setTextSelection(end, end);
      this.paragraphEditController.caretPosition(end);
    }, delay);
  }

  private focusParagraphEditor(attempt: number = 0): void {
    setTimeout(() => {
      if (!this.paragraphEditing) return;
      const focused: boolean = focusControl.requestFocus(PARAGRAPH_EDIT_INPUT_ID);
      this.placeParagraphCaretAtEnd(30);
      if (!focused && attempt < 2) this.focusParagraphEditor(attempt + 1);
    }, attempt === 0 ? 0 : 50);
  }

  private beginParagraphEdit(): void {
    if (!this.article || this.promptTargetKind !== 'text' ||
      this.article.articles.length <= this.selectedArticle) return;
    if (this.paragraphEditing) return;
    if (this.holdEditPressed || this.holdEditFinishing || this.dictating ||
      this.articleEditQueue.length > 0) {
      promptAction.showToast({ message: '当前修改完成后再精修' });
      return;
    }
    const renderedBody: string = this.article.articles[this.selectedArticle].body;
    const blocks: ArticleBlock[] = ArticleBody.locatedBlocks(renderedBody);
    const target: ArticleBlock | undefined = blocks[this.promptTargetIndex];
    const line: number = this.promptTargetLine > 0 ?
      this.promptTargetLine : (target?.lineNumber ?? 0);
    if (line < 1 || this.promptTargetValue.trim().length === 0) return;
    this.paragraphEditLine = line;
    this.paragraphEditArticleIndex = this.selectedArticle;
    this.paragraphEditOriginal = this.promptTargetValue.trim();
    this.paragraphEditRenderedBody = renderedBody;
    this.paragraphEditText = this.paragraphEditOriginal;
    this.paragraphEditSaving = false;
    this.deferredParagraphArticle = undefined;
    this.paragraphEditing = true;
  }

  private closeParagraphEdit(applyDeferred: boolean = true): void {
    const deferred: ArticleDoc | undefined = this.deferredParagraphArticle;
    this.paragraphEditing = false;
    this.paragraphEditText = '';
    this.paragraphEditSaving = false;
    this.paragraphEditLine = 0;
    this.paragraphEditArticleIndex = -1;
    this.paragraphEditOriginal = '';
    this.paragraphEditRenderedBody = '';
    this.deferredParagraphArticle = undefined;
    if (applyDeferred && deferred) {
      this.article = deferred;
      this.selectedArticle = Math.min(this.selectedArticle, Math.max(0, deferred.articles.length - 1));
      this.warmArticlePhotos(deferred);
    }
  }

  private async saveParagraphEdit(): Promise<void> {
    if (this.paragraphEditSaving || !this.selected || !this.article || this.paragraphEditLine < 1 ||
      this.paragraphEditArticleIndex < 0 ||
      this.paragraphEditArticleIndex >= this.article.articles.length) return;
    const recording: Recording = this.selected;
    const editLine: number = this.paragraphEditLine;
    const editArticleIndex: number = this.paragraphEditArticleIndex;
    const edited: string = this.paragraphEditText.trim();
    if (edited.length === 0 || edited === this.paragraphEditOriginal) {
      this.closeParagraphEdit();
      return;
    }
    const current: MinedArticle = this.article.articles[this.paragraphEditArticleIndex];
    const nextBody: string = ArticleBody.replacingRenderedLine(
      this.paragraphEditLine, edited, this.paragraphEditRenderedBody, current.body);
    if (nextBody === current.body) {
      promptAction.showToast({ message: '段落状态已变化，请重新长按编辑' });
      return;
    }
    const articles: MinedArticle[] = this.article.articles.slice();
    articles[this.paragraphEditArticleIndex] = {
      title: current.title,
      body: nextBody,
      style: current.style,
      wechatMediaId: current.wechatMediaId
    };
    const nextDoc: ArticleDoc = {
      id: this.article.id,
      transcript: this.article.transcript,
      articles: articles,
      tags: this.article.tags,
      questions: this.article.questions,
      photos: this.article.photos,
      owner: this.article.owner
    };
    this.paragraphEditSaving = true;
    let saved: boolean = false;
    try {
      saved = await libraryStore.saveArticle(recording, nextDoc);
    } catch (_) {}
    if (!this.paragraphEditing || this.selected?.stem() !== recording.stem() ||
      this.paragraphEditLine !== editLine || this.paragraphEditArticleIndex !== editArticleIndex) return;
    if (!saved) {
      this.paragraphEditSaving = false;
      this.focusParagraphEditor();
      promptAction.showToast({ message: '段落保存失败，请重试' });
      return;
    }
    this.deferredParagraphArticle = undefined;
    this.article = nextDoc;
    this.warmArticlePhotos(nextDoc);
    this.closeParagraphEdit(false);
    this.history = await libraryStore.versionHistory(recording);
    promptAction.showToast({ message: '这一段已保存' });
  }

  private async selectHistoryVersion(version: ArticleVersion): Promise<void> {
    if (!this.selected || !this.article) return;
    if (await libraryStore.patchHead(this.selected, version.v)) {
      this.article = libraryStore.articleFromVersion(this.article, version);
      this.selectedArticle = Math.min(this.selectedArticle, Math.max(0, this.article.articles.length - 1));
      this.history.head = version.v; this.history = this.history; this.showHistoryBrowser = false;
      await libraryStore.cacheArticle(this.selected, this.article);
      this.warmArticlePhotos(this.article);
    } else promptAction.showToast({ message: '版本切换失败' });
  }

  private async toggleCommunityShare(): Promise<void> {
    try {
      if (!this.selected) return;
      if (this.communityShareId.length > 0) {
        ++this.communityShareGeneration;
        promptAction.showToast({ message: '正在从 VD 社区隐藏…' });
        if (await communityStore.unshare(this.communityShareId)) {
          this.communityShareId = '';
          promptAction.showToast({ message: '已从 VD 社区隐藏' });
        } else {
          promptAction.showToast({ message: '从 VD 社区隐藏失败，请稍后重试' });
        }
        return;
      }
      if (!appPreferences.communityTermsAccepted()) {
        const accepted: boolean = await this.confirmCommunityTerms();
        if (!accepted) return;
      }
      ++this.communityShareGeneration;
      const articleKey: string = this.selected.articleKey();
      promptAction.showToast({ message: '正在设置 VD 社区可见…' });
      if (!authStore.isWechatAuthenticated()) {
        await this.startCommunityShareWechatLogin(articleKey);
        return;
      }
      const result: CommunityShareResult = await communityStore.shareResult(articleKey);
      if (result.ok) {
        this.communityShareId = result.shareId;
        promptAction.showToast({ message: CommunityShareUi.successMessage(false) });
      } else if (result.needsWechatSignin()) {
        if (result.code === 401) await authStore.signOutWechat();
        await this.startCommunityShareWechatLogin(articleKey);
      } else {
        promptAction.showToast({ message: result.error ? `分享社区失败：${result.error}` : '分享社区失败，请稍后再试' });
      }
    } catch (error) {
      promptAction.showToast({ message: `社区分享失败：${ClientReliability.errorMessage(error as Object)}` });
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

  private async beginCommunityReply(): Promise<void> {
    if (!this.selectedPost || !this.context || this.recording || this.recordingTransitioning) return;
    const replyTarget: string = this.selectedPost.shareId;
    this.recordingTransitioning = true;
    try {
      const manager = abilityAccessCtrl.createAtManager();
      const result = await manager.requestPermissionsFromUser(
        this.context, ['ohos.permission.MICROPHONE'] as Permissions[]);
      if (result.authResults[0] !== 0) {
        promptAction.showToast({ message: '需要麦克风权限才能写回应' });
        return;
      }
      await voiceRecorder.start();
      this.pendingReplyTarget = replyTarget;
      this.communityReplyRecording = true;
      this.interviewer = undefined;
      this.interviewActive = false;
      this.interviewStatus = '';
      this.capturedPhotos = [];
      this.recordingSeconds = 0;
      this.recordingLevel = 0;
      this.recording = true;
      this.updateRecordingMeter();
      this.timer = setInterval(() => this.updateRecordingMeter(), RECORDING_METER_INTERVAL_MS);
    } catch (error) {
      this.pendingReplyTarget = '';
      this.communityReplyRecording = false;
      await voiceRecorder.cancel().catch(() => {});
      promptAction.showToast({ message: `无法开始回应录音：${String(error)}` });
    } finally {
      this.recordingTransitioning = false;
    }
  }

  private async cancelCommunityReplyRecording(): Promise<void> {
    if (!this.communityReplyRecording || this.recordingTransitioning) return;
    this.recordingTransitioning = true;
    if (this.timer >= 0) clearInterval(this.timer);
    this.timer = -1;
    this.recording = false;
    this.communityReplyRecording = false;
    this.pendingReplyTarget = '';
    this.recordingSeconds = 0;
    this.recordingLevel = 0;
    this.recordingMeterSampling = false;
    try {
      await voiceRecorder.cancel();
    } catch (error) {
      promptAction.showToast({ message: `取消回应录音失败：${String(error)}` });
    } finally {
      this.recordingTransitioning = false;
    }
  }

  private async runCommunityMenuAction(action: string): Promise<void> {
    this.showCommunityMenu = false;
    if (action === 'reply') {
      await this.beginCommunityReply();
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
      this.communityDetailDirty = true;
      this.removeCommunityContent(post.shareId);
      promptAction.showToast({ message: '已举报，内容已下架待审核' });
      this.navigateHome();
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
        .fontSize(14).fontWeight(FontWeight.Normal)
        .fontColor(danger ? Theme.ACCENT_STRONG : Theme.INK)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      RemixIcon({ glyph: glyph, iconSize: 20, color: danger ? Theme.ACCENT_STRONG : Theme.INK })
    }
      .height(44).padding({ left: 14, right: 12 }).width('100%')
      .onClick(() => this.runDetailMenuAction(action))
  }

  @Builder
  private detailMoreMenu() {
    Column() {
      this.detailMenuRow(this.hasWechatDraft() ? '更新公众号草稿' : '发布公众号草稿',
        RI.SEND_PLANE, 'publish')
      Divider().color('#E0D8CC').margin({ left: 14, right: 14 })
      this.detailMenuRow(this.communityShareId.length > 0 ? '从 VD 社区隐藏' : 'VD 社区可见',
        RI.TEAM, 'community')
      Divider().color('#E0D8CC').margin({ left: 14, right: 14 })
      this.detailMenuRow(this.xhsPreparing ? '正在生成小红书…' : '分享到小红书',
        RI.FILE_TEXT, 'xhs')
      Divider().color('#E0D8CC').margin({ left: 14, right: 14 })
      this.detailMenuRow('分享到微信', RI.SHARE_FORWARD, 'wechat')
      Divider().color('#E0D8CC').margin({ left: 14, right: 14 })
      this.detailMenuRow('分享', RI.SHARE_FORWARD, 'share')
      Divider().height(4).color('#E9E5DC').margin({ left: 14, right: 14 })
      this.detailMenuRow('删除', RI.DELETE, 'delete', true)
    }
      .padding({ top: 1, bottom: 1 }).width(228)
      .backgroundColor('#FCFFFFFF')
      .border({ width: 1, color: '#ECE7DE', radius: 14 })
      .borderRadius(14).clip(true)
      .shadow({ radius: 12, color: '#2B2A2529', offsetX: 0, offsetY: 5 })
  }

  @Builder
  private communityDetailHeader() {
    Row() {
      Button({ type: ButtonType.Normal }) {
        RemixIcon({ glyph: RI.ARROW_LEFT, iconSize: 25, color: Theme.INK })
      }
        .width(40).height(40).padding(0).backgroundColor(Theme.CARD)
        .border({ width: 1, color: Theme.BORDER, radius: 11 }).borderRadius(11).clip(true)
        .shadow({ radius: 5, color: '#34291F22', offsetX: 0, offsetY: 2 })
        .stateEffect(false)
        .onClick(() => {
          this.showCommunityMenu = false;
          if (this.communityReplyRecording) {
            this.cancelCommunityReplyRecording().catch(() => {});
          } else {
            this.navigateBack();
          }
        })
      if (this.communityReplyRecording) {
        Text(`回应：${this.selectedPost?.title || '社区文章'}`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 12, right: 16 })
      } else {
        Blank()
        Button({ type: ButtonType.Normal }) {
          RemixIcon({
            glyph: this.postFed ? RI.FLASHLIGHT_FILL : RI.FLASHLIGHT,
            iconSize: 24,
            color: this.postFed ? Theme.AMBER : Theme.INK
          })
        }
          .width(40).height(40).padding(0).backgroundColor(Color.Transparent)
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
          .width(40).height(40).padding(0).backgroundColor(Color.Transparent)
          .stateEffect(false)
          .enabled(!this.communityDetailLoading)
          .opacity(this.communityDetailLoading ? 0.45 : 1)
          .onClick(() => this.togglePostLike())
        Stack({ alignContent: Alignment.Center }) {
          Button({ type: ButtonType.Normal }) {
            RemixIcon({ glyph: RI.MORE, iconSize: 24, color: Theme.SECONDARY })
          }
            .width(40).height(40).padding(0).backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.BORDER, radius: 11 }).borderRadius(11)
            .shadow({ radius: 7, color: '#19000000', offsetX: 0, offsetY: 2 })
            .enabled(!this.communityDetailLoading)
            .opacity(this.communityDetailLoading ? 0.45 : 1)
            .onClick(() => this.showCommunityMenu = !this.showCommunityMenu)
        }
          .width(56).height(48)
      }
    }
      .height(CommunityReplyUi.headerHeight(this.communityReplyRecording))
      .width('100%')
      .padding({ left: 16, right: 5, top: 8, bottom: 0 })
  }

  @Builder
  private communityDetailPage() {
    Column() {
      if (this.communityDetailLoading && !this.communityReplyRecording) {
        this.detailLoadingHeader()
      } else {
        this.communityDetailHeader()
      }
      if (this.communityDetailLoading) {
        Column() {
          this.communityDetailSummary()
          this.pageLoadingState()
          Blank()
        }
          .layoutWeight(1).width('100%')
          .padding({ left: 22, right: 22, top: 8, bottom: 40 })
          .alignItems(HorizontalAlign.Start)
      } else if (this.communityDetailError.length > 0) {
        Column() {
          this.communityDetailSummary()
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
        }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 22, right: 22, top: 8, bottom: 40 })
          .alignItems(HorizontalAlign.Start)
      } else {
        Scroll() {
          Column() {
          this.communityDetailSummary()
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
                  .fontSize(13).fontColor(Theme.FAINT).width('100%').textAlign(TextAlign.Center)
                Text(this.selectedPost?.promptCode ?? '')
                  .fontSize(38).fontWeight(FontWeight.Bold).letterSpacing(5)
                  .fontColor(Theme.INK).width('100%').textAlign(TextAlign.Center)
                  .padding({ top: 8, bottom: 8 })
              }
              Text(this.selectedPost?.doc?.articles?.[0]?.body || '这条提示词暂不可读，请稍后刷新。')
                .fontSize(16).lineHeight(27).fontColor(Theme.INK).padding(15)
                .backgroundColor('#F0ECE5').borderRadius(12).width('100%')
                .copyOption(CopyOptions.LocalDevice)
              Text('怎么用').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
                .margin({ top: 10 }).width('100%')
              if ((this.selectedPost?.promptCode ?? '').length > 0) {
                Text(`在任意文章里长按屏幕按住说话，说「用 ${this.selectedPost?.promptCode ?? ''} 改这段」——AI 按这条提示词干活，只管这一次，不改你的设置。`)
                  .fontSize(14).lineHeight(22).fontColor(Theme.SECONDARY).width('100%')
              }
              Text(this.selectedCommunityPromptOwned() ?
                '这是你分享的提示词。把分享码发给朋友，或在 设置 → 提示词 里管理。' :
                '想长期用：点下面「收下这条提示词」，之后长按菜单里随手可用。')
                .fontSize(14).lineHeight(22).fontColor(Theme.SECONDARY).width('100%')
              if (!this.selectedCommunityPromptOwned() &&
                (this.selectedPost?.promptCode ?? '').length > 0) {
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 9 }) {
                    RemixIcon({
                      glyph: this.selectedCommunityPromptImported() ? RI.CHECK : RI.DOWNLOAD,
                      iconSize: 21,
                      color: Color.White
                    })
                    Text(this.selectedCommunityPromptImported() ? '已收下' :
                      (this.promptImporting ? '正在导入…' : '收下这条提示词'))
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
                  }.justifyContent(FlexAlign.Center)
                }
                  .enabled(!this.selectedCommunityPromptImported() && !this.promptImporting)
                  .opacity(this.promptImporting ? 0.55 : 1)
                  .stateEffect(false)
                  .width('100%').height(56).margin({ top: 12 })
                  .backgroundColor(this.selectedCommunityPromptImported() ?
                    Theme.SECONDARY : Theme.ACCENT)
                  .borderRadius(12)
                  .onClick(() => this.importSelectedCommunityPrompt())
              }
            }.width('100%')
          } else if (this.selectedPost?.doc && this.selectedPost!.doc!.articles.length > 0) {
            Column() {
              ForEach(ArticleBody.locatedBlocks(this.selectedPost!.doc!.articles[0].body),
                (block: ArticleBlock) => this.articleBlock(block))
            }.width('100%')
          } else {
            Text(this.selectedPost?.excerpt ?? '')
              .fontSize(16).lineHeight(28).fontColor(Theme.INK).width('100%')
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
                Column({ space: 8 }) {
                  Row() {
                    Text(this.communityAuthor(reply)).fontSize(13).fontWeight(FontWeight.Bold)
                      .fontColor(Theme.ACCENT_STRONG)
                    Text(`  续文${this.communityDate(reply).length > 0 ? ` · ${this.communityDate(reply)}` : ''}`)
                      .fontSize(12).fontColor('#9A9387')
                  }.width('100%')
                  Text(reply.title || reply.excerpt)
                    .fontSize(18).fontWeight(FontWeight.Bold).lineHeight(27).fontColor(Theme.INK).width('100%')
                }
                  .padding({ left: 16 })
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .border({ width: { left: 3 }, color: '#E8C7B8', radius: 2 })
              }
                .padding({ top: 24 }).width('100%').alignItems(VerticalAlign.Top)
                .onClick(() => this.openCommunityPost(reply))
            }, (reply: CommunityPost) => reply.shareId)
          }
          }
            .padding({ left: 22, right: 22, top: 8, bottom: 40 })
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Start)
            .constraintSize({ minHeight: '100%' })
            .width('100%')
        }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
      if (this.communityReplyRecording) {
        CommunityReplyRecordingDock({
          recordingSeconds: this.recordingSeconds,
          activeLevel: this.recordingLevel,
          transitioning: this.recordingTransitioning,
          safeAreaBottom: this.safeAreaBottom(),
          onStop: () => this.toggleRecording().catch(() => {})
        })
      }
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.BG)
  }

  @Builder
  private communityMenuRow(label: string, glyph: string, action: string, danger: boolean = false) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Normal)
        .fontColor(danger ? Theme.ACCENT_STRONG : Theme.INK)
        .layoutWeight(1)
      RemixIcon({
        glyph: glyph,
        iconSize: 20,
        color: danger ? Theme.ACCENT_STRONG : Theme.INK
      })
    }
      .height(44)
      .padding({ left: 14, right: 14 })
      .width('100%')
      .onClick(() => this.runCommunityMenuAction(action))
  }

  @Builder
  private communityMoreMenu() {
    Column() {
      if (this.selectedPost?.kind !== 'prompt') {
        this.communityMenuRow('写回应', RI.MIC, 'reply')
        Divider().color('#E7E0D5').margin({ left: 14, right: 14 })
      }
      this.communityMenuRow('分享到微信', RI.SHARE_BOX, 'wechat')
      Divider().color('#E7E0D5').margin({ left: 14, right: 14 })
      this.communityMenuRow('分享', RI.SHARE_BOX, 'share')
      Divider().color('#E7E0D5').margin({ left: 14, right: 14 })
      this.communityMenuRow('举报', RI.FLAG, 'report', true)
      Divider().color('#E7E0D5').margin({ left: 14, right: 14 })
      this.communityMenuRow('屏蔽此用户', RI.HAND_HEART, 'block', true)
    }
      .padding({ top: 1, bottom: 1 })
      .width(232)
      .backgroundColor('#FCFFFFFF')
      .border({ width: 1, color: '#ECE7DE', radius: 14 })
      .borderRadius(14)
      .clip(true)
      .shadow({ radius: 12, color: '#2B2A2521', offsetX: 0, offsetY: 5 })
  }

  private async sendEdit(): Promise<void> {
    if (!this.editSession || this.editText.trim().length === 0) return;
    const answer: string = this.editText.trim();
    const question: FollowupQuestion | undefined = this.pendingQuestion();
    const text: string = question ? `【回答追问】问题：「${question.text}」我的口述回答：「${answer}」把回答里的信息织进正文最相关的段落——只用回答里出现的事实，不照抄问题本身、不动无关段落。` : answer;
    this.editText = '';
    const requestId: string = `${Date.now()}`;
    const sent: boolean = await this.editSession.sendEdit(requestId, text, this.selectedArticle);
    if (!sent) {
      promptAction.showToast({ message: '指令发送失败，请重试' });
      return;
    }
    this.articleEditQueue = ArticleEditUi.enqueue(this.articleEditQueue, requestId, text);
    if (question && this.selected) {
      question.status = 'answered'; this.article = this.article;
      libraryStore.patchQuestion(this.selected, question.id, 'answered').catch(() => {});
    }
    promptAction.showToast({ message: `已发送修改：${answer}` });
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
    const shareId: string = this.selectedPost.shareId;
    this.postLiked = next;
    this.updateCommunityLikePresentation(shareId, next);
    const currentLiked: boolean = this.selectedPost.liked ?? false;
    this.selectedPost.likes =
      CommunityLikeState.countAfterToggle(this.selectedPost.likes, currentLiked, next);
    this.selectedPost.liked = next;
    this.communityDetailDirty = true;
    const visiblePost: CommunityPost | undefined = this.posts.find((post: CommunityPost) => post.shareId === shareId);
    this.communityLikeShareId = shareId;
    this.communityLikeTargetCount = visiblePost?.likes ?? this.selectedPost.likes;
    this.communityLikeTargetLiked = next;
    this.communityLikeSucceeded = false;
    const updatedPost: CommunityPost = this.selectedPost;
    appPreferences.setLikedCommunityPost(shareId, next).catch(() => {});
    const likeRequest: Promise<boolean> = communityStore.engage(shareId, 'like', next);
    this.communityLikeRequest = likeRequest;
    likeRequest.then((ok: boolean) => {
      if (ok) communityStore.cachePost(updatedPost);
      if (this.communityLikeRequest === likeRequest) this.communityLikeSucceeded = ok;
    }).catch(() => {
      if (this.communityLikeRequest === likeRequest) this.communityLikeSucceeded = false;
    });
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
    this.blockedAuthorCount = appPreferences.blockedAuthors().length;
    this.communityDetailDirty = true;
    this.removeCommunityContent('', author);
    promptAction.showToast({ message: '已屏蔽，TA 的内容将不再显示' });
    this.navigateHome();
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
    if (!this.selected || !this.article || this.insertingPhotos) return;
    const recording: Recording = this.selected;
    this.insertingPhotos = true;
    try {
      const photos: UploadedPhoto[] = await photoService.pickAndUpload(recording.name);
      if (photos.length === 0) return;
      if (this.selected?.stem() !== recording.stem()) throw new Error('文章已切换，请重新选择图片');
      const keys: string[] = photos.map((photo: UploadedPhoto) => photo.key);
      const images: EditImage[] = ArticlePhotoInsert.imagesForKeys(keys)
        .map((image) => new EditImage(image.key));
      const requestId: string = `${Date.now()}`;
      const instruction: string = ArticlePhotoInsert.instructionForKeys(keys);
      const sent: boolean = await this.editSession?.sendEdit(
        requestId,
        instruction,
        this.selectedArticle,
        undefined,
        undefined,
        images
      ) ?? false;
      if (!sent) throw new Error('文章编辑服务尚未连接');
      this.articleEditQueue = ArticleEditUi.enqueue(this.articleEditQueue, requestId, instruction);
      promptAction.showToast({ message: `${photos.length} 张图片已上传，正在插入文章` });
    } catch (error) {
      promptAction.showToast({ message: `插图失败：${String(error)}` });
    } finally {
      this.insertingPhotos = false;
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
      wechatLoggingIn: this.wechatLoggingIn,
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
    else if (page === 'blocked') BlockedAuthorsPage({
      onBack: () => this.navigateBack(),
      onUnblocked: (count: number) => {
        this.blockedAuthorCount = count;
        this.refreshCommunity(false).catch(() => {});
      }
    })
    else if (page === 'privacy') PrivacyPolicyPage({ onBack: () => this.navigateBack() })
    else if (page === 'usage') UsagePage({ onBack: () => this.navigateBack() })
    else if (page === 'about') AboutPage({
      onBack: () => this.navigateBack(),
      onPrivacy: () => this.navigateTo('privacy'),
      onBlockedAuthors: () => {
        this.blockedAuthorCount = appPreferences.blockedAuthors().length;
        this.navigateTo('blocked');
      },
      onContact: () => this.openSupportEmail(),
      appVersion: this.appVersion,
      blockedAuthorCount: $blockedAuthorCount
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
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
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
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
          .padding({ top: this.safeAreaTop() })
          .backgroundColor(this.tab === 1 ? Theme.COMMUNITY_BG : Theme.BG)
      }
        .width('100%')
        .height('100%')
        .mode(NavigationMode.Stack)
        .hideTitleBar(true)
        .recoverable(false)
        .navDestination(this.navigationDestination)
      if (this.recording && !this.communityReplyRecording) {
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
        Stack({ alignContent: Alignment.TopStart }) {
          Column()
            .width('100%')
            .height('100%')
            .onClick(() => this.showPromptMenu = false)
          Column() {
            this.promptMenuSurface()
          }
            .position({ x: this.promptMenuSurfaceX(), y: this.promptMenuSurfaceY() })
            .zIndex(1)
        }
          .width('100%')
          .height('100%')
          .zIndex(130)
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
          Column() {
            Row() {
              Blank().width(44)
              Text('换个风格重写')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.INK)
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
              Button({ type: ButtonType.Normal }) {
                RemixIcon({ glyph: RI.CLOSE, iconSize: 24, color: Theme.SECONDARY })
              }
                .width(44).height(44).padding(0)
                .backgroundColor(Color.Transparent)
                .onClick(() => this.showStyleRewrite = false)
            }.height(66).padding({ left: 8, right: 8 }).width('100%')
            Divider().color('#1A000000')
            Column() {
              Text('选一个范文版本，把本文重写一遍，原文不变，可随时换回。')
                .fontSize(14)
                .lineHeight(22)
                .fontColor(Theme.SECONDARY)
                .width('100%')
                .margin({ bottom: 12 })
              if (this.styleRewriteLoading) {
                Column({ space: 12 }) {
                  LoadingProgress().width(32).height(32).color(Theme.ACCENT_STRONG)
                  Text('正在加载写作风格...').fontSize(14).fontColor(Theme.SECONDARY)
                }
                  .height(180)
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
              } else if (this.styleRewriteError.length > 0) {
                Column({ space: 10 }) {
                  Text(this.styleRewriteError).fontSize(14).fontColor(Theme.SECONDARY)
                  Button('重新加载')
                    .fontSize(13).fontColor(Theme.ACCENT_STRONG).backgroundColor(Color.Transparent)
                    .onClick(() => this.loadStyleRewriteHistory())
                }
                  .height(180)
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
              } else if (this.styleRewriteHistory.versions.length === 0) {
                Text('暂无可用写作风格版本。')
                  .fontSize(14).fontColor(Theme.FAINT).height(160).width('100%')
                  .textAlign(TextAlign.Center)
              } else {
                Scroll() {
                  Column({ space: 8 }) {
                    ForEach(this.styleRewriteHistory.versions.slice().reverse(), (version: StyleVersion) => {
                      Row() {
                        Text(`v${version.v}`)
                          .fontSize(18)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(this.selectedStyleRewriteVersion === version.v ?
                            Theme.ACCENT_STRONG : Theme.INK)
                          .width(52)
                        Column({ space: 4 }) {
                          Row({ space: 8 }) {
                            Text(StyleRewriteUi.displayName(version.style, version.source))
                              .fontSize(15)
                              .fontWeight(FontWeight.Bold)
                              .fontColor(this.selectedStyleRewriteVersion === version.v ?
                                Theme.ACCENT_STRONG : Theme.INK)
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                              .layoutWeight(1)
                            if (this.currentArticleStyleVersion() === version.v) {
                              Text('当前')
                                .fontSize(11)
                                .fontWeight(FontWeight.Bold)
                                .fontColor(Theme.ACCENT_STRONG)
                                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                                .backgroundColor(Theme.ACCENT_SOFT)
                                .borderRadius(10)
                            }
                          }.width('100%')
                          Text(StyleRewriteUi.metadata(
                            version.style, version.savedAt ?? version.createdAt, version.source))
                            .fontSize(13)
                            .fontColor(Theme.FAINT)
                        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                        Stack({ alignContent: Alignment.Center }) {
                          if (this.selectedStyleRewriteVersion === version.v) {
                            RemixIcon({ glyph: RI.CHECK, iconSize: 20, color: Theme.WHITE })
                          }
                        }
                          .width(30)
                          .height(30)
                          .backgroundColor(this.selectedStyleRewriteVersion === version.v ?
                            Theme.ACCENT_STRONG : Color.Transparent)
                          .border({
                            width: this.selectedStyleRewriteVersion === version.v ? 0 : 2,
                            color: '#D5CEC3',
                            radius: 15
                          })
                          .borderRadius(15)
                      }
                        .height(76)
                        .padding({ left: 12, right: 12 })
                        .backgroundColor(this.selectedStyleRewriteVersion === version.v ?
                          Theme.ACCENT_SOFT : Theme.CARD)
                        .border({ width: 1, color: '#E5DDD2', radius: 12 })
                        .borderRadius(12)
                        .width('100%')
                        .onClick(() => this.selectedStyleRewriteVersion = version.v)
                    }, (version: StyleVersion) => `${version.v}`)
                  }.width('100%')
                }
                  .constraintSize({ maxHeight: 340 })
                  .width('100%')
                  .scrollBar(BarState.Off)
                Button(StyleRewriteUi.actionLabel(
                  this.selectedStyleRewriteVersion,
                  this.generatedStyleVersion(this.selectedStyleRewriteVersion) !== undefined))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Theme.WHITE)
                  .height(58)
                  .width('100%')
                  .margin({ top: 20 })
                  .backgroundColor(this.selectedStyleRewriteVersion < 0 ?
                    Theme.ACCENT_SOFT : Theme.ACCENT_STRONG)
                  .borderRadius(12)
                  .enabled(this.selectedStyleRewriteVersion >= 0)
                  .stateEffect(this.selectedStyleRewriteVersion >= 0)
                  .onClick(() => this.requestStyleRewrite(this.selectedStyleRewriteVersion))
              }
            }
              .padding({ left: 14, right: 14, top: 14, bottom: 20 + this.safeAreaBottom() })
              .layoutWeight(1)
              .width('100%')
              .alignItems(HorizontalAlign.Start)
          }
            .height('73%')
            .backgroundColor(Theme.CARD)
            .borderRadius({ topLeft: 22, topRight: 22 })
            .width('100%')
        }.width('100%').height('100%').backgroundColor('#55000000')
      }
      if (this.restylePreviewActive) {
        Stack({ alignContent: Alignment.Center }) {
          Column({ space: 12 }) {
            LoadingProgress()
              .width(30)
              .height(30)
              .color(Theme.WHITE)
            Text('正在重写')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.WHITE)
          }
            .width(160)
            .height(112)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#E6000000')
            .borderRadius(16)
        }
          .width('100%')
          .height('100%')
          .backgroundColor('#33000000')
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
