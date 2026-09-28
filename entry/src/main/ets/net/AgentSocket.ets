import { webSocket } from '@kit.NetworkKit';
import { Api } from '../core/Api';
import { authStore } from '../data/AuthStore';
import { ClientReliability } from '../core/ClientReliability';

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
  images?: EditImage[];
  anchor?: EditAnchor;
  itemId?: string;
  constructor(id: string, text: string, articleIndex: number, anchor?: EditAnchor, itemId?: string,
    images: EditImage[] = []) {
    this.id = id; this.text = text; this.articleIndex = articleIndex;
    this.anchor = anchor; this.itemId = itemId;
    if (images.length > 0) this.images = images;
  }
}

export class EditImage {
  key: string;
  constructor(key: string) { this.key = key; }
}

export class AgentSocket {
  private socket?: webSocket.WebSocket;
  private connected: boolean = false;
  private connecting: boolean = false;
  private generation: number = 0;
  private path: string;
  private onMessage: SocketMessageHandler;
  private onState: SocketStateHandler;
  private autoReconnect: boolean;
  private reconnectAllowed: boolean = false;
  private baseReconnectTimer: number = -1;
  private heartbeatTimer: number = -1;

  constructor(path: string, onMessage: SocketMessageHandler, onState: SocketStateHandler = () => {}, autoReconnect: boolean = false) {
    this.path = path;
    this.onMessage = onMessage;
    this.onState = onState;
    this.autoReconnect = autoReconnect;
  }

  async connect(): Promise<void> {
    this.reconnectAllowed = this.autoReconnect;
    if (!ClientReliability.shouldStartConnection(this.connected, this.connecting)) return;
    if (this.baseReconnectTimer >= 0) clearTimeout(this.baseReconnectTimer);
    this.baseReconnectTimer = -1;
    this.connecting = true;
    const connectionGeneration: number = ++this.generation;
    const socket: webSocket.WebSocket = webSocket.createWebSocket();
    this.socket = socket;
    socket.on('open', () => {
      if (!this.isCurrent(socket, connectionGeneration)) return;
      this.connecting = false; this.connected = true; this.onState(true);
      if (ClientReliability.isLongLivedSocketPath(this.path)) this.startHeartbeat(socket);
    });
    socket.on('message', (_, value: string | ArrayBuffer) => {
      if (this.isCurrent(socket, connectionGeneration)) this.onMessage(value);
    });
    socket.on('close', (_, result: webSocket.CloseResult) =>
      this.handleDisconnect(socket, connectionGeneration, result.code, result.reason));
    socket.on('error', () => this.handleDisconnect(socket, connectionGeneration));
    try {
      await socket.connect(`${Api.AGENT_WS}${this.path}`, {
        header: { 'Authorization': `Bearer ${authStore.bearer()}`, 'X-VD-Platform': 'harmonyos' }
      });
    } catch (error) {
      this.handleDisconnect(socket, connectionGeneration);
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
    this.stopHeartbeat();
    this.baseReconnectTimer = -1;
    this.generation++;
    this.connecting = false;
    const socket: webSocket.WebSocket | undefined = this.socket;
    this.socket = undefined;
    this.connected = false;
    if (socket) socket.close({ code: 1000, reason: 'client closed' });
  }

  isConnected(): boolean { return this.connected; }

  private isCurrent(socket: webSocket.WebSocket, callbackGeneration: number): boolean {
    return this.socket === socket &&
      ClientReliability.isCurrentGeneration(this.generation, callbackGeneration);
  }

  private handleDisconnect(socket: webSocket.WebSocket, callbackGeneration: number,
    code?: number, reason?: string): void {
    if (!this.isCurrent(socket, callbackGeneration)) return;
    this.stopHeartbeat();
    this.socket = undefined; this.connecting = false; this.connected = false; this.onState(false, code, reason);
    if (!this.reconnectAllowed || this.baseReconnectTimer >= 0) return;
    this.baseReconnectTimer = setTimeout(() => {
      this.baseReconnectTimer = -1;
      if (this.reconnectAllowed &&
        ClientReliability.shouldStartConnection(this.connected, this.connecting)) this.connect().catch(() => {});
    }, 1500);
  }

  private startHeartbeat(socket: webSocket.WebSocket): void {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      if (this.socket !== socket || !this.connected) return;
      socket.send(JSON.stringify({ type: 'ping' })).then((ok: boolean) => {
        if (!ok && this.socket === socket) this.handleDisconnect(socket, this.generation);
      }).catch(() => {
        if (this.socket === socket) this.handleDisconnect(socket, this.generation);
      });
    }, ClientReliability.HEARTBEAT_MS);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer >= 0) clearInterval(this.heartbeatTimer);
    this.heartbeatTimer = -1;
  }
}

export class StatusSession extends AgentSocket {
  constructor(handler: SocketMessageHandler, state?: SocketStateHandler) { super('/status', handler, state, true); }
}

export class ArticleEditSession extends AgentSocket {
  private pending: EditRequest[] = [];

  constructor(stem: string, handler: SocketMessageHandler, state?: SocketStateHandler) {
    let session: ArticleEditSession | undefined = undefined;
    super(`/edit?stem=${Api.path(stem)}`, handler, (connected: boolean, code?: number, reason?: string) => {
      if (connected) session?.flushPending();
      if (state) state(connected, code, reason);
    }, true);
    session = this;
  }

  async sendEdit(id: string, text: string, articleIndex: number, anchor?: EditAnchor, itemId?: string,
    images: EditImage[] = []): Promise<boolean> {
    const request: EditRequest = new EditRequest(id, text, articleIndex, anchor, itemId, images);
    if (!this.isConnected()) {
      this.pending.push(request);
      this.connect().catch(() => {});
      return true;
    }
    const sent: boolean = await this.sendJson(request);
    if (!sent) this.pending.push(request);
    return sent || this.pending.includes(request);
  }

  private async flushPending(): Promise<void> {
    const requests: EditRequest[] = this.pending.slice();
    this.pending = [];
    for (const request of requests) {
      if (!await this.sendJson(request)) this.pending.push(request);
    }
  }
}

export class DictationSession extends AgentSocket {
  constructor(handler: SocketMessageHandler, state?: SocketStateHandler) { super('/asr', handler, state); }
}

export class RealtimeInterviewSession extends AgentSocket {
  constructor(handler: SocketMessageHandler, state?: SocketStateHandler) { super('/realtime/relay?fmt=pcmu', handler, state); }
}
