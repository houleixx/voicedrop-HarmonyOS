import { webSocket } from '@kit.NetworkKit';
import { Api } from '../core/Api';
import { httpClient, HttpResponse } from '../net/HttpClient';
import { authStore } from './AuthStore';
import { DeviceLinkBlob, DeviceLinkCrypto, DeviceLinkKeypair } from './DeviceLinkCrypto';

class LinkStartBody { prefix: string; pubkey: string; constructor(prefix: string, pubkey: string) { this.prefix = prefix; this.pubkey = pubkey; } }
class LinkVerifyBody { pairingId: string; code: string; constructor(pairingId: string, code: string) { this.pairingId = pairingId; this.code = code; } }
class LinkIdBody { pairingId: string; constructor(pairingId: string) { this.pairingId = pairingId; } }
class LinkCompleteBody { pairingId: string; blob: DeviceLinkBlob; constructor(pairingId: string, blob: DeviceLinkBlob) { this.pairingId = pairingId; this.blob = blob; } }
interface LinkResponse { ok?: boolean; reason?: string; pairingId?: string; remaining?: number; dead?: boolean; expired?: boolean; }
interface LinkSocketMessage { type?: string; blob?: DeviceLinkBlob; epk?: string; sealed?: string; }
export type LinkStateHandler = (phase: string, message: string) => void;

export class DeviceLinkPending {
  pairingId: string;
  code: string;
  pubkey: string;
  released: boolean;
  constructor(pairingId: string, code: string, pubkey: string, released: boolean = false) {
    this.pairingId = pairingId; this.code = code; this.pubkey = pubkey; this.released = released;
  }
}

interface PendingResponse { pairingId?: string; code?: string; pubkey?: string; released?: boolean; }

export class DeviceLinkStore {
  private keypair?: DeviceLinkKeypair;
  private pairingId: string = '';
  private socket?: webSocket.WebSocket;
  private onState: LinkStateHandler;
  constructor(onState: LinkStateHandler) { this.onState = onState; }

  async start(prefix: string): Promise<void> {
    const normalized: string = prefix.trim().toLowerCase();
    if (!/^[0-9a-f]{6}$/.test(normalized)) { this.onState('prefix', '请输入老设备显示的 6 位代码'); return; }
    await this.cancel(false); this.onState('working', '正在查找账号…'); this.keypair = await DeviceLinkCrypto.newKeypair();
    const response: HttpResponse = await httpClient.postJson(`${Api.AGENT}/link/start`, authStore.bearer(),
      new LinkStartBody(normalized, this.keypair.publicKeyB64));
    if (!response.ok()) throw new Error(`发起登录失败 HTTP ${response.code}`);
    const result: LinkResponse = JSON.parse(response.text) as LinkResponse;
    if (result.ok === false) {
      await this.cancel(false);
      this.onState('error', result.reason === 'no_match' ? '没有找到这个账号' : (result.reason ?? '发起失败'));
      return;
    }
    this.pairingId = result.pairingId ?? '';
    if (!this.pairingId) throw new Error('服务端没有返回 pairingId');
    await this.openSocket(); this.onState('code', '请查看老设备上显示的 4 位验证码');
  }

  async verify(code: string): Promise<void> {
    if (!/^\d{4}$/.test(code.trim())) { this.onState('code', '请输入 4 位验证码'); return; }
    if (!this.pairingId) throw new Error('请先输入账号代码'); this.onState('working', '正在验证…');
    const response: HttpResponse = await httpClient.postJson(`${Api.AGENT}/link/verify`, authStore.bearer(),
      new LinkVerifyBody(this.pairingId, code.trim()));
    if (!response.ok()) throw new Error(`验证码提交失败 HTTP ${response.code}`);
    const result: LinkResponse = JSON.parse(response.text) as LinkResponse;
    if (result.ok) this.onState('working', '正在安全接收账号…');
    else if (result.dead || result.expired) this.onState('error', '验证已失效，请重新发起');
    else this.onState('code', `验证码不正确，还可尝试 ${result.remaining ?? 0} 次`);
  }

  async cancel(notify: boolean = true): Promise<void> {
    const pairingId: string = this.pairingId;
    this.pairingId = '';
    if (notify && pairingId) await httpClient.postJson(`${Api.AGENT}/link/cancel`, authStore.bearer(), new LinkIdBody(pairingId));
    this.socket?.close({ code: 1000, reason: 'cancel' }); this.socket = undefined;
    this.keypair?.clear(); this.keypair = undefined;
  }

  static async complete(pairingId: string, publicKey: string): Promise<boolean> {
    const blob: DeviceLinkBlob = await DeviceLinkCrypto.encrypt(authStore.anonymousBearer(), publicKey);
    return (await httpClient.postJson(`${Api.AGENT}/link/complete`, authStore.bearer(), new LinkCompleteBody(pairingId, blob))).ok();
  }
  static async reject(pairingId: string): Promise<void> {
    await httpClient.postJson(`${Api.AGENT}/link/cancel`, authStore.bearer(), new LinkIdBody(pairingId));
  }

  static async pending(): Promise<DeviceLinkPending | undefined> {
    const response: HttpResponse = await httpClient.get(`${Api.AGENT}/link/pending`, authStore.bearer());
    if (!response.ok() || response.text.trim().length === 0) return undefined;
    const value: PendingResponse = JSON.parse(response.text) as PendingResponse;
    if (!value.pairingId || !value.code || !value.pubkey) return undefined;
    return new DeviceLinkPending(value.pairingId, value.code, value.pubkey, value.released ?? false);
  }

  private async openSocket(): Promise<void> {
    const socket: webSocket.WebSocket = webSocket.createWebSocket(); this.socket = socket;
    socket.on('message', async (_, value: string | ArrayBuffer) => { if (typeof value === 'string') await this.handle(value); });
    socket.on('error', () => this.onState('error', '设备配对连接中断'));
    socket.on('close', () => { if (this.pairingId) this.onState('error', '设备配对连接已关闭'); });
    await socket.connect(`${Api.AGENT_WS}/link/socket?pairingId=${Api.path(this.pairingId)}`,
      { header: { 'Authorization': `Bearer ${authStore.bearer()}`, 'X-VD-Platform': 'harmonyos' } });
  }

  private async handle(raw: string): Promise<void> {
    const message: LinkSocketMessage = JSON.parse(raw) as LinkSocketMessage;
    if (message.type === 'link_ready') {
      const blob: DeviceLinkBlob | undefined = message.blob ?? (message.epk && message.sealed ? new DeviceLinkBlob(message.epk, message.sealed) : undefined);
      if (!blob || !this.keypair) throw new Error('设备配对密文缺失');
      const token: string = await DeviceLinkCrypto.decrypt(blob.epk, blob.sealed, this.keypair);
      if (!(await authStore.adoptAnonymousToken(token))) { this.onState('error', '收到的账号令牌无效'); return; }
      this.onState('done', '账号迁移成功'); await this.cancel(false);
    } else if (message.type === 'link_cancelled') { this.onState('error', '对方已拒绝'); await this.cancel(false); }
    else if (message.type === 'link_expired') { this.onState('error', '配对已超时'); await this.cancel(false); }
  }
}
