import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { RecordingName } from '../core/RecordingName';
import { isRecordingTooShort } from '../core/RecordingPolicy';
import { RecordingStopPolicy } from '../core/RecordingStopPolicy';

export class VoiceRecorder {
  private recorder?: media.AVRecorder;
  private output?: fs.File;
  private context?: common.Context;
  private startedAt?: Date;
  private tempPath: string = '';
  private currentAmplitude: number = 0;
  private lastDurationSeconds: number = 0;

  initialize(context: common.Context): void { this.context = context; }
  isRecording(): boolean { return this.recorder !== undefined; }
  sessionTimestamp(): string { return this.startedAt ? RecordingName.timestamp(this.startedAt) : ''; }
  elapsedSeconds(): number {
    return this.startedAt ? Math.max(0, Math.floor((Date.now() - this.startedAt.getTime()) / 1000)) : 0;
  }
  durationSeconds(): number { return this.lastDurationSeconds; }
  pendingRecordingName(place: string = ''): string {
    return this.startedAt ? RecordingName.create(this.startedAt, this.elapsedSeconds(), place) : '';
  }

  async start(): Promise<void> {
    if (!this.context || this.recorder) throw new Error('录音器尚未初始化或已经在录音');
    this.startedAt = new Date();
    this.currentAmplitude = 0; this.lastDurationSeconds = 0;
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
    if (!this.recorder) return 0;
    try {
      const current: number = await this.recorder.getAudioCapturerMaxAmplitude();
      // Keep the recorder's raw PCM peak. RecordingUi is responsible for
      // normalizing it before the value reaches the waveform.
      this.currentAmplitude = Math.max(0, current);
      return this.currentAmplitude;
    } catch (_) {
      this.currentAmplitude = 0;
      return 0;
    }
  }

  async stop(place: string = ''): Promise<string> {
    if (!this.recorder || !this.startedAt || !this.context) throw new Error('当前没有录音');
    const seconds: number = Math.max(0, (Date.now() - this.startedAt.getTime()) / 1000);
    this.lastDurationSeconds = seconds;
    const recorder: media.AVRecorder = this.recorder;
    const startedAt: Date = this.startedAt;
    const temporaryPath: string = this.tempPath;
    try {
      await this.sampleAmplitude();
      let stopSucceeded: boolean = false;
      let stopError: string = '';
      try {
        await recorder.stop();
        stopSucceeded = true;
      } catch (firstError) {
        stopError = String(firstError);
        await this.delay(120);
        try {
          await recorder.stop();
          stopSucceeded = true;
          stopError = '';
        } catch (secondError) {
          stopError = String(secondError);
        }
      }
      try { await recorder.release(); } catch (releaseError) {
        if (stopError.length === 0) stopError = String(releaseError);
      }
      if (this.output) fs.closeSync(this.output);
      this.output = undefined;
      const complete: boolean = this.hasCompleteM4a(temporaryPath);
      if (!RecordingStopPolicy.canFinalize(stopSucceeded, complete)) {
        throw new Error(stopError.length > 0 ? stopError : '录音文件没有完整写入');
      }
      if (isRecordingTooShort(seconds)) {
        // Keep it under the pending name until the page deletes it. Even if deletion
        // fails, the upload queue will not mistake it for a VoiceDrop recording.
        return temporaryPath;
      }
      const name: string = RecordingName.create(startedAt, seconds, place);
      const finalPath: string = `${this.context.filesDir}/${name}`;
      fs.renameSync(temporaryPath, finalPath);
      return finalPath;
    } finally {
      this.recorder = undefined;
      this.output = undefined;
      this.startedAt = undefined;
      this.tempPath = '';
      this.currentAmplitude = 0;
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
      this.currentAmplitude = 0; this.lastDurationSeconds = 0;
    }
  }

  private hasCompleteM4a(path: string): boolean {
    let file: fs.File | undefined;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(file.fd).size;
      const buffer: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, buffer);
      return RecordingStopPolicy.hasCompleteM4a(new Uint8Array(buffer));
    } catch (_) {
      return false;
    } finally {
      if (file) try { fs.closeSync(file); } catch (_) {}
    }
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => setTimeout(resolve, milliseconds));
  }
}

export const voiceRecorder: VoiceRecorder = new VoiceRecorder();
