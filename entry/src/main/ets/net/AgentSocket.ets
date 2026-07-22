import { webSocket } from '@kit.NetworkKit';
import { Api } from '../core/Api';
import { authStore } from '../data/AuthStore';
import { appPreferences } from '../data/AppPreferences';

export type SocketMessageHandler = (message: string | ArrayBuffer) => void;
export type SocketStateHandler = (connected: boolean, code?: number, reason?: string) => void;

export class EditAnchor {
  type: string;
  line?: number;
  text?: string;
  key?: string;
  private constructor(type: string) { this.type = type; }
  static forLine(line: number, text: string): EditAnchor {
    const anchor: EditAnchor = new EditAnchor('line'); anchor.line = line; anchor.text = text; return anchor;
  }
  static forImage(key: string): EditAnchor {
    const anchor: EditAnchor = new EditAnchor('image'); anchor.key = key; return anchor;
  }
}

class EditRequest {
  type: string = 'instruct';
  id: string;
  text: string;
  articleIndex: number;
  anchor?: EditAnchor;
  itemId?: string;
  constructor(id: string, text: string, articleIndex: number, anchor?: EditAnchor, itemId?: string) {
    this.id = id; this.text = text; this.articleIndex = articleIndex;
    this.anchor = anchor; this.itemId = itemId;
  }
}

export class AgentSocket {
  private socket?: webSocket.WebSocket;
  private connected: boolean = false;
  private path: string;
  private onMessage: SocketMessageHandler;
  private onState: SocketStateHandler;
  private autoReconnect: boolean;
  private reconnectAllowed: boolean = false;
  private baseReconnectTimer: number = -1;

  constructor(path: string, onMessage: SocketMessageHandler, onState: SocketStateHandler = () => {}, autoReconnect: boolean = false) {
    this.path = path;
    this.onMessage = onMessage;
    this.onState = onState;
    this.autoReconnect = autoReconnect;
  }

  async connect(): Promise<void> {
    this.reconnectAllowed = this.autoReconnect;
    const previous: webSocket.WebSocket | undefined = this.socket;
    this.socket = undefined;
    if (previous) previous.close({ code: 1000, reason: 'replaced' });
    const socket: webSocket.WebSocket = webSocket.createWebSocket();
    this.socket = socket;
    socket.on('open', () => {
      if (this.socket !== socket) return;
      this.connected = true; this.onState(true);
    });
    socket.on('message', (_, value: string | ArrayBuffer) => {
      if (this.socket === socket) this.onMessage(value);
    });
    socket.on('close', (_, result: webSocket.CloseResult) =>
      this.handleDisconnect(socket, result.code, result.reason));
    socket.on('error', () => this.handleDisconnect(socket));
    try {
      await socket.connect(`${Api.AGENT_WS}${this.path}`, {
        header: { 'Authorization': `Bearer ${authStore.bearer()}`, 'X-VD-Platform': 'harmonyos' }
      });
    } catch (error) {
      this.handleDisconnect(socket);
      throw new Error(String(error));
    }
  }

  async sendJson(message: Object): Promise<boolean> {
    return this.socket?.send(JSON.stringify(message)) ?? false;
  }

  async sendAudio(bytes: ArrayBuffer): Promise<boolean> {
    return this.socket?.send(bytes) ?? false;
  }

  close(): void {
    this.reconnectAllowed = false;
    if (this.baseReconnectTimer >= 0) clearTimeout(this.baseReconnectTimer);
    this.baseReconnectTimer = -1;
    const socket: webSocket.WebSocket | undefined = this.socket;
    this.socket = undefined;
    this.connected = false;
    if (socket) socket.close({ code: 1000, reason: 'client closed' });
  }

  isConnected(): boolean { return this.connected; }

  private handleDisconnect(socket: webSocket.WebSocket, code?: number, reason?: string): void {
    if (this.socket !== socket) return;
    this.socket = undefined; this.connected = false; this.onState(false, code, reason);
    if (!this.reconnectAllowed || this.baseReconnectTimer >= 0) return;
    this.baseReconnectTimer = setTimeout(() => {
      this.baseReconnectTimer = -1;
      if (this.reconnectAllowed && !this.connected) this.connect().catch(() => {});
    }, 1500);
  }
}

export class StatusSession extends AgentSocket {
  constructor(handler: SocketMessageHandler, state?: SocketStateHandler) { super('/status', handler, state, true); }
}

export class ArticleEditSession extends AgentSocket {
  constructor(stem: string, handler: SocketMessageHandler, state?: SocketStateHandler) {
    super(`/edit?stem=${Api.path(stem)}`, handler, state, true);
  }

  sendEdit(id: string, text: string, articleIndex: number, anchor?: EditAnchor, itemId?: string): Promise<boolean> {
    return this.sendJson(new EditRequest(id, text, articleIndex, anchor, itemId));
  }
}

export class DictationSession extends AgentSocket {
  constructor(handler: SocketMessageHandler, state?: SocketStateHandler) { super('/asr', handler, state); }
}

export class RealtimeInterviewSession extends AgentSocket {
  constructor(handler: SocketMessageHandler, state?: SocketStateHandler) { super('/realtime/relay?fmt=pcmu', handler, state); }
}

export class CommandRef {
  n: number; stem: string; title: string;
  constructor(n: number, stem: string, title: string) { this.n = n; this.stem = stem; this.title = title; }
}
export class CommandInstruction {
  type: string = 'instruct'; id: string; text: string; refs: CommandRef[];
  constructor(id: string, text: string, refs: CommandRef[]) { this.id = id; this.text = text; this.refs = refs; }
}
class CommandControl {
  type: string; id: string;
  constructor(type: string, id: string) { this.type = type; this.id = id; }
}
interface CommandConfirmation { id: string; text: string; }
interface CommandQueueState { id?: string; status?: string; }
interface CommandStateMessage {
  type?: string; id?: string; queue?: CommandQueueState[]; summary?: string; text?: string; message?: string;
}
export class LibraryCommandSession extends AgentSocket {
  private queue: CommandInstruction[] = [];
  private refs: CommandRef[] = [];
  private controls: CommandControl[] = [];
  private confirmations: CommandConfirmation[] = [];
  private allowReconnect: boolean = false;
  private reconnectTimer: number = -1;

  constructor(handler: SocketMessageHandler, state?: SocketStateHandler) {
    let session: LibraryCommandSession | undefined = undefined;
    super('/command', (message: string | ArrayBuffer) => {
      if (typeof message === 'string') session?.handleCommandState(message);
      handler(message);
    }, (connected: boolean) => {
      if (connected) {
        session?.flushQueue(); session?.flushControls(); session?.notifyConfirmations(handler);
      } else session?.scheduleReconnect();
      if (state) state(connected);
    });
    session = this;
    try {
      const stored: CommandInstruction[] = JSON.parse(appPreferences.pendingCommands()) as CommandInstruction[];
      this.queue = stored.filter((value: CommandInstruction) => value.id.length > 0 && value.text.trim().length > 0);
    } catch (_) { this.queue = []; }
    try {
      const stored: CommandControl[] = JSON.parse(appPreferences.pendingCommandControls()) as CommandControl[];
      this.controls = stored.filter((value: CommandControl) => ['confirm', 'cancel'].includes(value.type) && value.id.length > 0);
    } catch (_) { this.controls = []; }
    try {
      const stored: CommandConfirmation[] = JSON.parse(appPreferences.pendingCommandConfirmations()) as CommandConfirmation[];
      this.confirmations = stored.filter((value: CommandConfirmation) => value.id.length > 0 && value.text.length > 0);
    } catch (_) { this.confirmations = []; }
  }

  async connect(): Promise<void> {
    this.allowReconnect = false;
    await super.connect();
    this.allowReconnect = true;
  }

  close(): void {
    this.allowReconnect = false;
    if (this.reconnectTimer >= 0) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = -1; super.close();
  }

  setRefs(refs: CommandRef[]): void { this.refs = refs.slice(); }

  async instruct(id: string, text: string, refs: CommandRef[]): Promise<boolean> {
    this.setRefs(refs);
    const request: CommandInstruction = new CommandInstruction(id, text.trim(), refs);
    this.queue.push(request); await this.persist();
    if (this.isConnected()) await this.sendJson(request);
    return true;
  }
  confirm(id: string): Promise<boolean> { return this.queueControl('confirm', id); }
  cancel(id: string): Promise<boolean> { return this.queueControl('cancel', id); }

  private async flushQueue(): Promise<void> {
    for (const request of this.queue) {
      request.refs = this.refs.length > 0 ? this.refs : request.refs;
      await this.sendJson(request);
    }
  }

  private async flushControls(): Promise<void> {
    if (!this.isConnected()) return;
    for (const control of this.controls) await this.sendJson(control);
  }

  private notifyConfirmations(handler: SocketMessageHandler): void {
    for (const confirmation of this.confirmations) handler(JSON.stringify({
      type: 'confirm', id: confirmation.id, summary: confirmation.text
    }));
  }

  private async queueControl(type: string, id: string): Promise<boolean> {
    if (!id) return false;
    this.confirmations = this.confirmations.filter((value: CommandConfirmation) => value.id !== id);
    this.controls = this.controls.filter((value: CommandControl) => value.id !== id);
    this.controls.push(new CommandControl(type, id));
    await this.persistState();
    if (this.isConnected()) await this.sendJson(this.controls[this.controls.length - 1]);
    return true;
  }

  private rememberConfirmation(id: string, text: string): void {
    if (!id || this.controls.some((value: CommandControl) => value.id === id)) return;
    this.confirmations = this.confirmations.filter((value: CommandConfirmation) => value.id !== id);
    this.confirmations.push({ id: id, text: text }); this.persistState();
  }

  private clearCommandState(id: string): void {
    this.controls = this.controls.filter((value: CommandControl) => value.id !== id);
    this.confirmations = this.confirmations.filter((value: CommandConfirmation) => value.id !== id);
    this.persistState();
  }

  private handleCommandState(raw: string): void {
    try {
      const message = JSON.parse(raw) as CommandStateMessage;
      if (message.type === 'confirm' && message.id) {
        this.rememberConfirmation(message.id, message.summary ?? message.text ?? message.message ?? '确认执行这条图库指令？');
      }
      if ((message.type === 'reply' || message.type === 'updated' || message.type === 'error') && message.id) {
        this.queue = this.queue.filter((request: CommandInstruction) => request.id !== message.id);
        this.clearCommandState(message.id); this.persist();
      } else if (message.type === 'snapshot' && message.queue) {
        const known: Set<string> = new Set<string>();
        for (const item of message.queue) {
          if (item.id && item.status !== 'done' && item.status !== 'error') known.add(item.id);
          if (item.id && (item.status === 'done' || item.status === 'error')) {
            this.queue = this.queue.filter((request: CommandInstruction) => request.id !== item.id);
            this.clearCommandState(item.id);
          }
        }
        for (const request of this.queue) if (!known.has(request.id)) this.sendJson(request);
        this.persist();
      }
    } catch (_) {}
  }

  private scheduleReconnect(): void {
    if (!this.allowReconnect || this.reconnectTimer >= 0) return;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = -1;
      if (this.allowReconnect && !this.isConnected()) this.connect().catch(() => this.scheduleReconnect());
    }, 1500);
  }

  private async persist(): Promise<void> { await appPreferences.savePendingCommands(JSON.stringify(this.queue)); }
  private async persistState(): Promise<void> {
    await appPreferences.savePendingCommandControls(JSON.stringify(this.controls));
    await appPreferences.savePendingCommandConfirmations(JSON.stringify(this.confirmations));
  }
}
