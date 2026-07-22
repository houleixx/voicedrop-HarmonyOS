import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { RecordingName } from '../core/RecordingName';

export class VoiceRecorder {
  private recorder?: media.AVRecorder;
  private output?: fs.File;
  private context?: common.Context;
  private startedAt?: Date;
  private tempPath: string = '';
  private peakAmplitude: number = 0;
  private lastDurationSeconds: number = 0;

  initialize(context: common.Context): void { this.context = context; }
  isRecording(): boolean { return this.recorder !== undefined; }
  sessionTimestamp(): string { return this.startedAt ? RecordingName.timestamp(this.startedAt) : ''; }

  async start(): Promise<void> {
    if (!this.context || this.recorder) throw new Error('录音器尚未初始化或已经在录音');
    this.startedAt = new Date();
    this.peakAmplitude = 0; this.lastDurationSeconds = 0;
    this.tempPath = `${this.context.filesDir}/VoiceDrop-pending-${Date.now()}.m4a`;
    this.output = fs.openSync(this.tempPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    this.recorder = await media.createAVRecorder();
    const profile: media.AVRecorderProfile = {
      audioBitrate: 128000,
      audioChannels: 1,
      audioCodec: media.CodecMimeType.AUDIO_AAC,
      audioSampleRate: 48000,
      fileFormat: media.ContainerFormatType.CFT_MPEG_4A
    };
    const config: media.AVRecorderConfig = {
      audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
      profile: profile,
      url: `fd://${this.output.fd}`
    };
    await this.recorder.prepare(config);
    await this.recorder.start();
  }

  async sampleAmplitude(): Promise<number> {
    if (!this.recorder) return this.peakAmplitude;
    try {
      const current: number = await this.recorder.getAudioCapturerMaxAmplitude();
      this.peakAmplitude = Math.max(this.peakAmplitude, current); return this.peakAmplitude;
    } catch (_) { return this.peakAmplitude; }
  }

  looksSilent(): boolean {
    return this.lastDurationSeconds >= 1 && this.peakAmplitude < 0.01;
  }

  async stop(place: string = ''): Promise<string> {
    if (!this.recorder || !this.startedAt || !this.context) throw new Error('当前没有录音');
    const seconds: number = Math.max(1, Math.round((Date.now() - this.startedAt.getTime()) / 1000));
    this.lastDurationSeconds = seconds;
    try {
      await this.sampleAmplitude();
      await this.recorder.stop();
      await this.recorder.release();
      if (this.output) fs.closeSync(this.output);
      const name: string = RecordingName.create(this.startedAt, seconds, place);
      const finalPath: string = `${this.context.filesDir}/${name}`;
      fs.renameSync(this.tempPath, finalPath);
      return finalPath;
    } finally {
      this.recorder = undefined;
      this.output = undefined;
      this.startedAt = undefined;
      this.tempPath = '';
    }
  }

  async cancel(): Promise<void> {
    try {
      if (this.recorder) {
        await this.recorder.stop();
        await this.recorder.release();
      }
      if (this.output) fs.closeSync(this.output);
      if (this.tempPath.length > 0) fs.unlinkSync(this.tempPath);
    } finally {
      this.recorder = undefined;
      this.output = undefined;
      this.startedAt = undefined;
      this.tempPath = '';
      this.peakAmplitude = 0; this.lastDurationSeconds = 0;
    }
  }
}

export const voiceRecorder: VoiceRecorder = new VoiceRecorder();
