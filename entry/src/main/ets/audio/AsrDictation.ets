import { audio } from '@kit.AudioKit';
import { webSocket } from '@kit.NetworkKit';
import { Api } from '../core/Api';
import { authStore } from '../data/AuthStore';
import { VolcASRProtocol, ASRMessage } from '../net/VolcASRProtocol';

export type DictationTextHandler = (text: string, finalResult: boolean) => void;
export type DictationStateHandler = (state: string) => void;

export class AsrDictation {
  private socket?: webSocket.WebSocket;
  private capturer?: audio.AudioCapturer;
  private running: boolean = false;
  private finishing: boolean = false;
  private sequence: number = 2;
  private onText: DictationTextHandler;
  private onState: DictationStateHandler;
  private finishTimer: number = -1;

  constructor(onText: DictationTextHandler, onState: DictationStateHandler) { this.onText = onText; this.onState = onState; }

  async start(): Promise<void> {
    if (this.running) return; this.running = true; this.finishing = false; this.sequence = 2;
    const socket: webSocket.WebSocket = webSocket.createWebSocket(); this.socket = socket;
    socket.on('open', async () => {
      if (this.socket !== socket || !this.running) return;
      try {
        await socket.send(await VolcASRProtocol.fullClient('voicedrop-harmony-edit'));
        await this.startCapture();
      } catch (error) {
        if (this.running && !this.finishing) this.onState(`听写启动失败：${String(error)}`);
        await this.stop();
      }
    });
    socket.on('message', async (_, value: string | ArrayBuffer) => {
      if (typeof value === 'string') return;
      try {
        const message: ASRMessage = await VolcASRProtocol.parse(value);
        if (message.isError) { this.onState(message.errorMessage || '听写失败'); await this.stop(); return; }
        if (message.text.length > 0) this.onText(message.text, message.isFinal);
        if (this.finishing && message.isFinal) await this.stop();
      } catch (error) { this.onState(`听写响应解析失败：${String(error)}`); await this.stop(); }
    });
    socket.on('error', () => { this.onState('听写连接失败'); this.stop(); });
    socket.on('close', () => { if (this.running) this.onState('听写连接已关闭'); this.cleanup(); });
    await socket.connect(`${Api.AGENT_WS}/asr`, { header: {
      'Authorization': `Bearer ${authStore.bearer()}`, 'X-VD-Platform': 'harmonyos'
    } });
    this.onState('正在连接听写…');
  }

  async finish(): Promise<void> {
    if (!this.running || this.finishing) return; this.finishing = true; this.onState('正在识别最后一句…');
    await this.stopCapture();
    if (this.socket) await this.socket.send(await VolcASRProtocol.audio(new ArrayBuffer(0), this.sequence++, true));
    this.finishTimer = setTimeout(() => this.stop(), 3000);
  }

  async stop(): Promise<void> {
    this.running = false; await this.stopCapture(); this.socket?.close({ code: 1000, reason: 'dictation done' }); this.cleanup();
    this.onState('');
  }

  isRunning(): boolean { return this.running; }

  private async startCapture(): Promise<void> {
    const options: audio.AudioCapturerOptions = {
      streamInfo: { samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000, channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE, encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW },
      capturerInfo: { source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION, capturerFlags: 0 }
    };
    const capturer: audio.AudioCapturer = await audio.createAudioCapturer(options); this.capturer = capturer;
    await capturer.start(); this.onState('正在听写…'); const bufferSize: number = await capturer.getBufferSize();
    while (this.running && !this.finishing && this.capturer === capturer) {
      try {
        const pcm: ArrayBuffer = await capturer.read(bufferSize, true);
        if (pcm.byteLength > 0 && this.socket) await this.socket.send(await VolcASRProtocol.audio(pcm, this.sequence++, false));
      } catch (error) {
        if (this.running && !this.finishing && this.capturer === capturer) throw new Error(String(error));
        break;
      }
    }
  }

  private async stopCapture(): Promise<void> {
    const capturer: audio.AudioCapturer | undefined = this.capturer; this.capturer = undefined;
    if (!capturer) return;
    try { await capturer.stop(); } catch (_) {}
    try { await capturer.release(); } catch (_) {}
  }

  private cleanup(): void {
    this.running = false; this.finishing = false; this.socket = undefined;
    if (this.finishTimer >= 0) clearTimeout(this.finishTimer); this.finishTimer = -1;
  }
}
