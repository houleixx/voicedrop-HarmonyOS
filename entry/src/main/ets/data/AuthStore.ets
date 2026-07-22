import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';

export class AuthStore {
  private store?: preferences.Preferences;

  async initialize(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, { name: 'voicedrop.auth' });
    if (this.anonymousBearer().length === 0) {
      this.store.putSync('anon', this.newAnonymousToken());
      await this.store.flush();
    }
  }

  bearer(): string {
    const session: string = this.session();
    return session.length > 0 ? session : this.anonymousBearer();
  }

  anonymousBearer(): string { return String(this.store?.getSync('anon', '') ?? ''); }
  session(): string {
    const existing: string = String(this.store?.getSync('session', '') ?? '');
    if (existing.length === 0) return '';
    if (!this.isSessionToken(existing) || this.isJwtExpired(existing)) {
      const previous: string = String(this.store?.getSync('preWechatAnon', '') ?? '');
      this.store?.deleteSync('session'); this.store?.deleteSync('preWechatAnon');
      if (previous.startsWith('anon_') && previous.length >= 20) this.store?.putSync('anon', previous);
      this.store?.flush(); return '';
    }
    return existing;
  }
  isWechatAuthenticated(): boolean { return this.session().length > 0; }

  async adoptAnonymousToken(token: string): Promise<boolean> {
    if (!token.startsWith('anon_') || token.length < 20 || !this.store) return false;
    this.store.putSync('anon', token);
    this.store.deleteSync('session');
    await this.store.flush();
    return true;
  }

  async storeSession(token: string): Promise<boolean> {
    if (!this.isSessionToken(token) || this.isJwtExpired(token) || !this.store) return false;
    this.store.putSync('session', token);
    this.store.deleteSync('preWechatAnon');
    await this.store.flush();
    return true;
  }

  async switchToWechatAccount(token: string): Promise<boolean> {
    if (!this.isSessionToken(token) || this.isJwtExpired(token) || !this.store) return false;
    this.store.putSync('preWechatAnon', this.anonymousBearer());
    this.store.putSync('session', token);
    await this.store.flush();
    return true;
  }

  async signOutWechat(): Promise<void> {
    const previous: string = String(this.store?.getSync('preWechatAnon', '') ?? '');
    this.store?.deleteSync('session'); this.store?.deleteSync('preWechatAnon');
    if (previous.startsWith('anon_') && previous.length >= 20) this.store?.putSync('anon', previous);
    await this.store?.flush();
  }

  async resetAnonymous(): Promise<void> {
    if (!this.store) return;
    this.store.clearSync();
    this.store.putSync('anon', this.newAnonymousToken());
    await this.store.flush();
  }

  private newAnonymousToken(): string {
    return `anon_${util.generateRandomUUID(true).replace(/-/g, '')}${util.generateRandomUUID(true).replace(/-/g, '')}`;
  }

  private isSessionToken(token: string): boolean {
    const parts: string[] = token.split('.');
    return parts.length === 3 && parts.every((part: string) => part.length >= 8 && /^[A-Za-z0-9_-]+$/.test(part));
  }

  private isJwtExpired(token: string): boolean {
    try {
      const payload: string = token.split('.')[1];
      let padded: string = payload.replace(/-/g, '+').replace(/_/g, '/');
      while (padded.length % 4 !== 0) padded += '=';
      const bytes: Uint8Array = new util.Base64Helper().decodeSync(padded, util.Type.BASIC);
      const body: Record<string, number> = JSON.parse(new util.TextDecoder('utf-8').decodeWithStream(bytes)) as Record<string, number>;
      return !body.exp || Math.floor(Date.now() / 1000) >= body.exp;
    } catch (_) { return true; }
  }
}

export const authStore: AuthStore = new AuthStore();
