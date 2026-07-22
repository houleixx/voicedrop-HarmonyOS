import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

interface PendingCommunityTimestamp { createdAt?: number; }

export class AppPreferences {
  private store?: preferences.Preferences;
  static readonly PRIVACY_VERSION: string = '2026-07-17';

  async initialize(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, { name: 'voicedrop.prefs' });
  }

  privacyAccepted(): boolean {
    return String(this.store?.getSync('privacyAcceptedVersion', '') ?? '') === AppPreferences.PRIVACY_VERSION;
  }

  async acceptPrivacy(): Promise<void> {
    this.store?.putSync('privacyAcceptedVersion', AppPreferences.PRIVACY_VERSION);
    this.store?.putSync('privacyAcceptedAt', Date.now());
    await this.store?.flush();
  }

  deleteLocalAfterUpload(): boolean { return Boolean(this.store?.getSync('deleteLocalAfterUpload', true) ?? true); }
  classicRecorder(): boolean { return Boolean(this.store?.getSync('classicRecorder', false) ?? false); }
  autoShareCommunity(): boolean { return Boolean(this.store?.getSync('autoShareCommunity', false) ?? false); }
  communityTermsAccepted(): boolean { return Boolean(this.store?.getSync('communityTermsAccepted', false) ?? false); }

  async setBoolean(key: string, value: boolean): Promise<void> {
    this.store?.putSync(key, value);
    await this.store?.flush();
  }

  shouldCheckUpdate(currentVersion: string): boolean {
    const last: number = Number(this.store?.getSync('updateLastCheckMs', 0) ?? 0);
    const version: string = String(this.store?.getSync('updateLastCheckVersion', '') ?? '');
    return last <= 0 || version !== currentVersion || Date.now() - last >= 24 * 60 * 60 * 1000;
  }

  async markUpdateChecked(currentVersion: string): Promise<void> {
    this.store?.putSync('updateLastCheckMs', Date.now());
    this.store?.putSync('updateLastCheckVersion', currentVersion);
    await this.store?.flush();
  }

  ignoredUpdateTag(): string { return String(this.store?.getSync('ignoredUpdateTag', '') ?? ''); }

  async ignoreUpdate(tag: string): Promise<void> {
    this.store?.putSync('ignoredUpdateTag', tag);
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

  pendingCommands(): string { return String(this.store?.getSync('pendingLibraryCommands', '[]') ?? '[]'); }

  async savePendingCommands(value: string): Promise<void> {
    this.store?.putSync('pendingLibraryCommands', value);
    await this.store?.flush();
  }

  pendingCommandControls(): string { return String(this.store?.getSync('pendingLibraryCommandControls', '[]') ?? '[]'); }
  pendingCommandConfirmations(): string { return String(this.store?.getSync('pendingLibraryCommandConfirmations', '[]') ?? '[]'); }

  async savePendingCommandControls(value: string): Promise<void> {
    this.store?.putSync('pendingLibraryCommandControls', value); await this.store?.flush();
  }

  async savePendingCommandConfirmations(value: string): Promise<void> {
    this.store?.putSync('pendingLibraryCommandConfirmations', value); await this.store?.flush();
  }

  async clearAccountQueues(recordingNames: string[]): Promise<void> {
    this.store?.deleteSync('pendingCommunityShare');
    this.store?.deleteSync('pendingLibraryCommands');
    this.store?.deleteSync('pendingLibraryCommandControls');
    this.store?.deleteSync('pendingLibraryCommandConfirmations');
    for (const name of recordingNames) this.store?.deleteSync(`pendingReply.${name}`);
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
