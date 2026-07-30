import { audio } from '@kit.AudioKit';
import { util } from '@kit.ArkTS';
import { RealtimeInterviewSession } from '../net/AgentSocket';

export type InterviewStateHandler = (active: boolean, status: string) => void;

interface RealtimeMessage {
  type?: string;
  delta?: string;
  error?: RealtimeError;
}

interface RealtimeError {
  code?: string;
  type?: string;
  message?: string;
}

class InputAudioAppend {
  type: string = 'input_audio_buffer.append';
  audio: string;
  constructor(audio: string) { this.audio = audio; }
}

class InputAudioClear { type: string = 'input_audio_buffer.clear'; }

export class RealtimeInterviewer {
  private session?: RealtimeInterviewSession;
  private capturer?: audio.AudioCapturer;
  private renderer?: audio.AudioRenderer;
  private active: boolean = false;
  private muted: boolean = false;
  private connected: boolean = false;
  private fatal: boolean = false;
  private reconnectAttempt: number = 0;
  private reconnectTimer: number = -1;
  private reopenTimer: number = -1;
  private handler: InterviewStateHandler;
  private base64: util.Base64Helper = new util.Base64Helper();
  private playback: Promise<void> = Promise.resolve();
  private captureTask?: Promise<void>;
  private lifecycle: Promise<void> = Promise.resolve();

  constructor(handler: InterviewStateHandler = () => {}) { this.handler = handler; }

  isActive(): boolean { return this.active; }

  statusText(): string {
    if (!this.active) return '';
    if (this.fatal) return 'AI 采访暂不可用 · 录音继续';
    if (!this.connected) return this.reconnectAttempt > 0 ? 'AI 已断开，正在重连 · 录音继续' : 'AI 连接中…';
    return this.muted ? 'AI 正在说话' : 'AI 采访中 · 再点一下结束';
  }

  start(): Promise<void> {
    const operation: Promise<void> = this.lifecycle.then(() => this.startNow());
    this.lifecycle = operation.catch(() => {});
    return operation;
  }

  stop(): Promise<void> {
    const operation: Promise<void> = this.lifecycle.then(
      () => this.stopNow(), () => this.stopNow());
    this.lifecycle = operation.catch(() => {});
    return operation;
  }

  private async startNow(): Promise<void> {
    if (this.active) return;
    this.active = true; this.muted = false; this.fatal = false; this.reconnectAttempt = 0;
    this.notify();
    try {
      await this.startCapture();
      await this.connect();
    } catch (error) {
      await this.stopNow();
      throw new Error(String(error));
    }
  }

  private async stopNow(): Promise<void> {
    this.active = false; this.muted = false; this.connected = false;
    if (this.reconnectTimer >= 0) clearTimeout(this.reconnectTimer);
    if (this.reopenTimer >= 0) clearTimeout(this.reopenTimer);
    this.reconnectTimer = -1; this.reopenTimer = -1;
    this.session?.close(); this.session = undefined;
    const capturer: audio.AudioCapturer | undefined = this.capturer; this.capturer = undefined;
    const captureTask: Promise<void> | undefined = this.captureTask; this.captureTask = undefined;
    if (capturer) {
      try { await capturer.stop(); } catch (_) {}
      if (captureTask) await captureTask.catch(() => {});
      try { await capturer.release(); } catch (_) {}
    }
    const playback: Promise<void> = this.playback; this.playback = Promise.resolve();
    await playback.catch(() => {});
    const renderer: audio.AudioRenderer | undefined = this.renderer; this.renderer = undefined;
    if (renderer) { try { await renderer.stop(); } catch (_) {} try { await renderer.release(); } catch (_) {} }
    this.notify();
  }

  private async connect(): Promise<void> {
    if (!this.active || this.fatal) return;
    const session: RealtimeInterviewSession = new RealtimeInterviewSession(
      (message: string | ArrayBuffer) => { if (typeof message === 'string') this.handleMessage(message); },
      (connected: boolean, code?: number, reason?: string) => this.handleConnection(connected, code, reason));
    this.session = session;
    await session.connect();
  }

  private handleConnection(connected: boolean, code?: number, reason?: string): void {
    if (!this.active) return;
    this.connected = connected;
    if (connected) this.reconnectAttempt = 0;
    else if (code === 1013 || this.isFatalReason(reason ?? '')) {
      this.markUnavailable();
      return;
    } else if (!this.fatal) this.scheduleReconnect();
    this.notify();
  }

  private handleMessage(raw: string): void {
    try {
      const message: RealtimeMessage = JSON.parse(raw) as RealtimeMessage;
      if (message.type === 'response.created') this.beginAiTurn();
      else if (message.type === 'response.output_audio.delta' && message.delta) {
        this.beginAiTurn();
        const bytes: Uint8Array = this.base64.decodeSync(message.delta);
        this.playback = this.playback.then(() => this.play(bytes)).catch(() => {});
      } else if (message.type === 'response.done') {
        if (this.reopenTimer >= 0) clearTimeout(this.reopenTimer);
        this.reopenTimer = setTimeout(() => this.openMic(), 500);
      } else if (message.type === 'error') {
        const reason: string = `${message.error?.code ?? ''} ${message.error?.type ?? ''} ${message.error?.message ?? ''}`.toLowerCase();
        if (this.isFatalReason(reason)) this.markUnavailable();
      }
    } catch (_) {}
  }

  private beginAiTurn(): void { this.muted = true; this.notify(); }

  private isFatalReason(reason: string): boolean {
    const value: string = reason.toLowerCase();
    return value.includes('insufficient_quota') || value.includes('exceeded_current_quota') ||
      value.includes('account_deactivated') || value.includes('billing');
  }

  private markUnavailable(): void {
    this.fatal = true; this.connected = false; this.muted = true;
    if (this.reconnectTimer >= 0) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = -1; this.session?.close(); this.releaseRenderer(); this.notify();
  }

  private openMic(): void {
    this.reopenTimer = -1;
    if (!this.active || this.fatal) return;
    this.session?.sendJson(new InputAudioClear());
    this.muted = false; this.notify();
  }

  private scheduleReconnect(): void {
    if (!this.active || this.fatal || this.reconnectTimer >= 0 || this.reconnectAttempt >= 6) return;
    const delay: number = Math.pow(2, this.reconnectAttempt) * 1000; this.reconnectAttempt++;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = -1;
      if (!this.active || this.connected || this.fatal) return;
      this.session?.close(); this.connect().catch(() => this.scheduleReconnect());
    }, delay);
  }

  private async startCapture(): Promise<void> {
    const options: audio.AudioCapturerOptions = {
      streamInfo: { samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000, channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE, encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW },
      capturerInfo: { source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION, capturerFlags: 0 }
    };
    const capturer: audio.AudioCapturer = await audio.createAudioCapturer(options); this.capturer = capturer;
    const size: number = await capturer.getBufferSize(); await capturer.start();
    this.captureTask = this.captureLoop(capturer, size).catch(() => {
      if (this.active && this.capturer === capturer) {
        this.fatal = true; this.connected = false; this.session?.close(); this.notify();
      }
    });
  }

  private async captureLoop(capturer: audio.AudioCapturer, size: number): Promise<void> {
    while (this.active && this.capturer === capturer) {
      const pcm: ArrayBuffer = await capturer.read(size, true);
      if (!this.muted && this.connected && pcm.byteLength > 1) {
        const encoded: Uint8Array = RealtimeInterviewer.pcm16ToMuLaw8k(new Uint8Array(pcm), 16000);
        await this.session?.sendJson(new InputAudioAppend(this.base64.encodeToStringSync(encoded)));
      }
    }
  }

  private async play(bytes: Uint8Array): Promise<void> {
    if (!this.active || bytes.byteLength === 0) return;
    if (!this.renderer) {
      const options: audio.AudioRendererOptions = {
        streamInfo: { samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_24000, channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE, encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW },
        // Match Android's media playback route. The voice-assistant route can
        // suppress its own playback from the concurrent microphone recording.
        rendererInfo: { content: audio.ContentType.CONTENT_TYPE_SPEECH, usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
          rendererFlags: 0 }
      };
      this.renderer = await audio.createAudioRenderer(options);
      await this.renderer.start();
      try { await this.renderer.setVolume(1); } catch (_) {}
    }
    const buffer: ArrayBuffer = new ArrayBuffer(bytes.byteLength); new Uint8Array(buffer).set(bytes);
    await this.renderer.write(buffer);
  }

  private releaseRenderer(): void {
    const renderer: audio.AudioRenderer | undefined = this.renderer; this.renderer = undefined;
    if (renderer) renderer.stop().then(() => renderer.release()).catch(() => renderer.release());
  }

  private notify(): void { this.handler(this.active, this.statusText()); }

  static pcm16ToMuLaw8k(pcm: Uint8Array, sampleRate: number): Uint8Array {
    if (pcm.byteLength < 2 || sampleRate <= 0) return new Uint8Array();
    const samples: number = Math.floor(pcm.byteLength / 2); const step: number = Math.max(1, Math.floor(sampleRate / 8000));
    const output: Uint8Array = new Uint8Array(Math.ceil(samples / step)); let target: number = 0;
    for (let index: number = 0; index < samples; index += step) {
      const low: number = pcm[index * 2]; const high: number = pcm[index * 2 + 1];
      let sample: number = low | (high << 8); if ((sample & 0x8000) !== 0) sample -= 0x10000;
      output[target++] = RealtimeInterviewer.linearToMuLaw(sample);
    }
    return target === output.byteLength ? output : output.slice(0, target);
  }

  private static linearToMuLaw(value: number): number {
    let sample: number = value; const sign: number = (sample >> 8) & 0x80;
    if (sign !== 0) sample = -sample; sample = Math.min(32635, sample) + 0x84;
    let exponent: number = 7; let mask: number = 0x4000;
    while ((sample & mask) === 0 && exponent > 0) { mask >>= 1; exponent--; }
    const mantissa: number = (sample >> (exponent + 3)) & 0x0f;
    return (~(sign | (exponent << 4) | mantissa)) & 0xff;
  }
}
