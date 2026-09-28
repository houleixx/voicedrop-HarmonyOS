import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CommunityLikeState } from '../core/CommunityLikeState';
import { PrivacyStartup } from '../core/PrivacyStartup';
import { BookShelfCachePolicy } from '../core/BookShelfCachePolicy';

interface PendingCommunityTimestamp { createdAt?: number; }

export class AppPreferences {
  private store?: preferences.Preferences;
  static readonly PRIVACY_VERSION: string = '2026-07-31';

  async initialize(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, { name: 'voicedrop.prefs' });
  }

  privacyAccepted(): boolean {
    return PrivacyStartup.accepted(
      String(this.store?.getSync('privacyAcceptedVersion', '') ?? ''), AppPreferences.PRIVACY_VERSION);
  }

  async acceptPrivacy(): Promise<void> {
    this.store?.putSync('privacyAcceptedVersion', AppPreferences.PRIVACY_VERSION);
    this.store?.putSync('privacyAcceptedAt', Date.now());
    await this.store?.flush();
  }

  photoWaitStart(fullKey: string): number {
    return Number(this.store?.getSync(`photoWait:${fullKey}`, 0) ?? 0);
  }

  photoWasGenerated(fullKey: string): boolean {
    return Boolean(this.store?.getSync(`photoGenerated:${fullKey}`, false) ?? false);
  }

  photoWasLoaded(fullKey: string): boolean {
    return Boolean(this.store?.getSync(`photoLoaded:${fullKey}`, false) ?? false);
  }

  setPhotoWait(fullKey: string, startedAt: number, generated: boolean = false): void {
    if (!fullKey.startsWith('users/')) return;
    this.store?.putSync(`photoWait:${fullKey}`, startedAt);
    if (generated) this.store?.putSync(`photoGenerated:${fullKey}`, true);
    this.store?.flush().catch(() => {});
  }

  setPhotoLoaded(fullKey: string): void {
    if (!fullKey.startsWith('users/')) return;
    this.store?.putSync(`photoLoaded:${fullKey}`, true);
    this.store?.deleteSync(`photoWait:${fullKey}`);
    this.store?.deleteSync(`photoGenerated:${fullKey}`);
    this.store?.flush().catch(() => {});
  }

  deleteLocalAfterUpload(): boolean { return Boolean(this.store?.getSync('deleteLocalAfterUpload', true) ?? true); }
  classicRecorder(): boolean { return Boolean(this.store?.getSync('classicRecorder', false) ?? false); }
  autoShareCommunity(): boolean { return Boolean(this.store?.getSync('autoShareCommunity', false) ?? false); }
  communityTermsAccepted(): boolean { return Boolean(this.store?.getSync('communityTermsAccepted', false) ?? false); }

  likedCommunityPost(shareId: string): boolean {
    const raw: string = String(this.store?.getSync('likedCommunityPosts', '[]') ?? '[]');
    return CommunityLikeState.contains(raw, shareId);
  }

  async setLikedCommunityPost(shareId: string, liked: boolean): Promise<void> {
    const raw: string = String(this.store?.getSync('likedCommunityPosts', '[]') ?? '[]');
    this.store?.putSync('likedCommunityPosts', CommunityLikeState.update(raw, shareId, liked));
    await this.store?.flush();
  }

  async setBoolean(key: string, value: boolean): Promise<void> {
    this.store?.putSync(key, value);
    await this.store?.flush();
  }

  bookShelfCache(identity: string): string {
    const storedIdentity: string = String(this.store?.getSync('booksShelfCacheIdentity', '') ?? '');
    if (BookShelfCachePolicy.canRestore(storedIdentity, identity)) {
      return String(this.store?.getSync('booksShelfCache', '') ?? '');
    }
    this.store?.deleteSync('booksShelfCache');
    this.store?.deleteSync('booksShelfCacheIdentity');
    this.store?.flush();
    return '';
  }

  async saveBookShelfCache(identity: string, value: string): Promise<void> {
    this.store?.putSync('booksShelfCacheIdentity', identity);
    this.store?.putSync('booksShelfCache', value);
    await this.store?.flush();
  }

  pricesCache(): string { return String(this.store?.getSync('pricesCache.v1', '') ?? ''); }

  async savePricesCache(value: string): Promise<void> {
    this.store?.putSync('pricesCache.v1', value);
    await this.store?.flush();
  }

  referralDone(): boolean { return Boolean(this.store?.getSync('referralDone', false) ?? false); }

  referralWithinWindow(): boolean {
    let first: number = Number(this.store?.getSync('referralFirstLaunchAt', 0) ?? 0);
    if (first <= 0) { first = Date.now(); this.store?.putSync('referralFirstLaunchAt', first); this.store?.flush(); }
    return Date.now() - first < 24 * 60 * 60 * 1000;
  }

  async markReferralDone(): Promise<void> {
    this.store?.putSync('referralDone', true);
    await this.store?.flush();
  }

  pendingCommunityShare(): string {
    const raw: string = String(this.store?.getSync('pendingCommunityShare', '') ?? '');
    if (raw.length === 0) return '';
    try {
      const value: PendingCommunityTimestamp = JSON.parse(raw) as PendingCommunityTimestamp;
      if (Date.now() - (value.createdAt ?? 0) < 15 * 60 * 1000) return raw;
    } catch (_) {}
    this.store?.deleteSync('pendingCommunityShare'); this.store?.flush(); return '';
  }

  async savePendingCommunityShare(articleKey: string, replyTo: string = ''): Promise<void> {
    this.store?.putSync('pendingCommunityShare', JSON.stringify({ articleKey: articleKey, replyTo: replyTo, createdAt: Date.now() }));
    await this.store?.flush();
  }

  async clearPendingCommunityShare(): Promise<void> {
    this.store?.deleteSync('pendingCommunityShare');
    await this.store?.flush();
  }

  pendingReply(audioName: string): string {
    return String(this.store?.getSync(`pendingReply.${audioName}`, '') ?? '');
  }

  async savePendingReply(audioName: string, shareId: string): Promise<void> {
    this.store?.putSync(`pendingReply.${audioName}`, shareId);
    await this.store?.flush();
  }

  async clearPendingReply(audioName: string): Promise<void> {
    this.store?.deleteSync(`pendingReply.${audioName}`);
    await this.store?.flush();
  }

  pendingPhotos(): string { return String(this.store?.getSync('pendingRecordingPhotos', '[]') ?? '[]'); }

  async savePendingPhotos(value: string): Promise<void> {
    this.store?.putSync('pendingRecordingPhotos', value);
    await this.store?.flush();
  }

  async clearAccountQueues(recordingNames: string[]): Promise<void> {
    this.store?.deleteSync('pendingCommunityShare');
    this.store?.deleteSync('pendingLibraryCommands');
    this.store?.deleteSync('pendingLibraryCommandControls');
    this.store?.deleteSync('pendingLibraryCommandConfirmations');
    for (const name of recordingNames) this.store?.deleteSync(`pendingReply.${name}`);
    await this.store?.flush();
  }

  async clearDeletedAccountState(): Promise<void> {
    this.store?.clearSync();
    await this.store?.flush();
  }

  blockedAuthors(): string[] {
    try { return JSON.parse(String(this.store?.getSync('blockedCommunityAuthors', '[]') ?? '[]')) as string[]; }
    catch (_) { return []; }
  }

  async setAuthorBlocked(author: string, blocked: boolean): Promise<void> {
    let authors: string[] = this.blockedAuthors().filter((value: string) => value !== author);
    if (blocked && author.trim().length > 0) authors.push(author);
    this.store?.putSync('blockedCommunityAuthors', JSON.stringify(authors));
    await this.store?.flush();
  }
}

export const appPreferences: AppPreferences = new AppPreferences();
