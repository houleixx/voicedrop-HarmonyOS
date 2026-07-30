import { audio } from '@kit.AudioKit';
import { webSocket } from '@kit.NetworkKit';
import { Api } from '../core/Api';
import { authStore } from '../data/AuthStore';
import { VolcASRProtocol, ASRMessage } from '../net/VolcASRProtocol';
import {
  HOLD_TO_TALK_TAIL_CAPTURE_MS,
  PendingAudioFrame,
  PendingAudioFrames
} from '../core/PendingAudioFrames';
import { AsrResponseGate, AsrResponseReceipt } from '../core/AsrResponseGate';

export type DictationTextHandler = (text: string, finalResult: boolean) => void;
export type DictationStateHandler = (state: string) => void;

export class AsrDictation {
  private socket?: webSocket.WebSocket;
  private capturer?: audio.AudioCapturer;
  private running: boolean = false;
  private finishing: boolean = false;
  private captureActive: boolean = false;
  private socketReady: boolean = false;
  private drainingFrames: boolean = false;
  private lastFrameSent: boolean = false;
  private sequence: number = 2;
  private onText: DictationTextHandler;
  private onState: DictationStateHandler;
  private finishTimer: number = -1;
  private tailTimer: number = -1;
  private sessionGeneration: number = 0;
  private captureTask?: Promise<void>;
  private pendingFrames: PendingAudioFrames = new PendingAudioFrames();
  private responseGate: AsrResponseGate = new AsrResponseGate();

  constructor(onText: DictationTextHandler, onState: DictationStateHandler) { this.onText = onText; this.onState = onState; }

  async start(): Promise<void> {
    if (this.running) return;
    this.running = true;
    this.finishing = false;
    this.captureActive = true;
    this.socketReady = false;
    this.drainingFrames = false;
    this.lastFrameSent = false;
    this.sequence = 2;
    this.pendingFrames.clear();
    this.responseGate.reset();
    const generation: number = ++this.sessionGeneration;
    const socket: webSocket.WebSocket = webSocket.createWebSocket(); this.socket = socket;
    socket.on('open', async () => {
      if (!this.isCurrent(socket, generation)) return;
      try {
        await socket.send(await VolcASRProtocol.fullClient('voicedrop-harmony-edit'));
        this.socketReady = true;
        await this.drainPendingFrames(socket, generation);
      } catch (error) {
        if (this.running && !this.finishing) this.onState(`听写启动失败：${String(error)}`);
        await this.stop();
      }
    });
    socket.on('message', async (_, value: string | ArrayBuffer) => {
      if (!this.isCurrent(socket, generation)) return;
      if (typeof value === 'string') return;
      const receipt: AsrResponseReceipt = this.responseGate.begin(this.lastFrameSent);
      try {
        const message: ASRMessage = await VolcASRProtocol.parse(value);
        if (!this.isCurrent(socket, generation) || !this.responseGate.accept(receipt)) return;
        if (message.isError) { this.onState(message.errorMessage || '听写失败'); await this.stop(); return; }
        if (message.text.length > 0) this.onText(message.text, message.isFinal);
        if (this.finishing && this.responseGate.shouldFinish(receipt, message.isFinal)) await this.stop();
      } catch (error) { this.onState(`听写响应解析失败：${String(error)}`); await this.stop(); }
    });
    socket.on('error', () => {
      if (!this.isCurrent(socket, generation)) return;
      this.onState('听写连接失败');
      this.stop();
    });
    socket.on('close', async () => {
      if (!this.isCurrent(socket, generation)) return;
      if (this.running) this.onState('听写连接已关闭');
      await this.stop();
    });
    // Start microphone capture on touch-down. Audio produced while the socket
    // connects is queued and drained after the client configuration frame.
    this.captureTask = this.captureAudio(generation);
    this.onState('正在连接听写…');
    try {
      await socket.connect(`${Api.AGENT_WS}/asr`, { header: {
        'Authorization': `Bearer ${authStore.bearer()}`, 'X-VD-Platform': 'harmonyos'
      } });
    } catch (error) {
      if (this.isCurrent(socket, generation)) {
        this.onState(`听写连接失败：${String(error)}`);
        await this.stop();
      }
    }
  }

  async finish(): Promise<void> {
    if (!this.running || this.finishing) return;
    this.finishing = true;
    this.onState('正在识别最后一句…');
    const generation: number = this.sessionGeneration;
    this.tailTimer = setTimeout(() => {
      this.tailTimer = -1;
      this.finishCaptureAndSignal(generation);
    }, HOLD_TO_TALK_TAIL_CAPTURE_MS);
  }

  async stop(): Promise<void> {
    const socket: webSocket.WebSocket | undefined = this.socket;
    this.running = false;
    this.captureActive = false;
    if (this.tailTimer >= 0) clearTimeout(this.tailTimer);
    this.tailTimer = -1;
    if (this.finishTimer >= 0) clearTimeout(this.finishTimer);
    this.finishTimer = -1;
    await this.stopCapture();
    socket?.close({ code: 1000, reason: 'dictation done' });
    this.cleanup();
    this.onState('');
  }

  isRunning(): boolean { return this.running; }

  private isCurrent(socket: webSocket.WebSocket, generation: number): boolean {
    return this.running && this.socket === socket && this.sessionGeneration === generation;
  }

  private async captureAudio(generation: number): Promise<void> {
    const options: audio.AudioCapturerOptions = {
      streamInfo: { samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000, channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE, encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW },
      capturerInfo: { source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION, capturerFlags: 0 }
    };
    let capturer: audio.AudioCapturer | undefined;
    try {
      capturer = await audio.createAudioCapturer(options);
      if (!this.running || !this.captureActive || this.sessionGeneration !== generation) {
        await capturer.release();
        return;
      }
      this.capturer = capturer;
      await capturer.start();
      if (!this.running || !this.captureActive || this.sessionGeneration !== generation) return;
      this.onState('正在听写…');
      const bufferSize: number = await capturer.getBufferSize();
      while (this.running && this.captureActive && this.capturer === capturer &&
        this.sessionGeneration === generation) {
        const pcm: ArrayBuffer = await capturer.read(bufferSize, true);
        if (pcm.byteLength > 0) this.queueFrame(pcm, false, generation);
      }
    } catch (error) {
      if (this.running && this.captureActive && this.sessionGeneration === generation) {
        this.onState(`听写启动失败：${String(error)}`);
        await this.stop();
      }
    }
    if (capturer) {
      await this.releaseCapture(capturer);
    }
  }

  private async stopCapture(): Promise<void> {
    const capturer: audio.AudioCapturer | undefined = this.capturer; this.capturer = undefined;
    if (!capturer) return;
    try { await capturer.stop(); } catch (_) {}
    try { await capturer.release(); } catch (_) {}
  }

  private async releaseCapture(capturer: audio.AudioCapturer): Promise<void> {
    if (this.capturer !== capturer) return;
    this.capturer = undefined;
    try { await capturer.stop(); } catch (_) {}
    try { await capturer.release(); } catch (_) {}
  }

  private async finishCaptureAndSignal(generation: number): Promise<void> {
    if (!this.running || !this.finishing || this.sessionGeneration !== generation) return;
    this.captureActive = false;
    // Let the in-flight blocking read complete so PCM already buffered by the
    // system is queued before the final frame. A hard cancel still stops the
    // capturer immediately through stop().
    const captureTask: Promise<void> | undefined = this.captureTask;
    if (captureTask) await captureTask;
    if (!this.running || this.sessionGeneration !== generation) return;
    this.queueFrame(new ArrayBuffer(0), true, generation);
  }

  private queueFrame(data: ArrayBuffer, isLast: boolean, generation: number): void {
    if (!this.running || this.sessionGeneration !== generation) return;
    this.pendingFrames.offer(data, isLast);
    const socket: webSocket.WebSocket | undefined = this.socket;
    if (socket && this.socketReady && !this.drainingFrames) {
      this.drainPendingFrames(socket, generation).catch((error: Object) => {
        if (!this.isCurrent(socket, generation)) return;
        this.onState(`听写发送失败：${String(error)}`);
        this.stop();
      });
    }
  }

  private async drainPendingFrames(socket: webSocket.WebSocket, generation: number): Promise<void> {
    if (!this.isCurrent(socket, generation) || !this.socketReady || this.drainingFrames) return;
    this.drainingFrames = true;
    try {
      let frame: PendingAudioFrame | undefined = this.pendingFrames.take();
      while (frame && this.isCurrent(socket, generation)) {
        await this.sendFrame(socket, frame.data, frame.isLast, generation);
        frame = this.pendingFrames.take();
      }
    } finally {
      this.drainingFrames = false;
    }
  }

  private async sendFrame(socket: webSocket.WebSocket, data: ArrayBuffer, isLast: boolean,
    generation: number): Promise<void> {
    if (!this.isCurrent(socket, generation)) return;
    await socket.send(await VolcASRProtocol.audio(data, this.sequence++, isLast));
    if (isLast && this.isCurrent(socket, generation)) {
      this.lastFrameSent = true;
      if (this.finishTimer >= 0) clearTimeout(this.finishTimer);
      this.finishTimer = setTimeout(() => this.stop(), 3000);
    }
  }

  private cleanup(): void {
    this.running = false;
    this.finishing = false;
    this.captureActive = false;
    this.socketReady = false;
    this.drainingFrames = false;
    this.lastFrameSent = false;
    this.socket = undefined;
    this.capturer = undefined;
    this.captureTask = undefined;
    this.pendingFrames.clear();
    this.responseGate.reset();
    if (this.tailTimer >= 0) clearTimeout(this.tailTimer);
    this.tailTimer = -1;
    if (this.finishTimer >= 0) clearTimeout(this.finishTimer); this.finishTimer = -1;
  }
}
