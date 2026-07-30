import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { libraryStore } from '../data/LibraryStore';

export type PlaybackProgressHandler = (playing: boolean, progress: number, duration: number) => void;

export class AudioPlayback {
  private context?: common.Context;
  private player?: media.AVPlayer;
  private file?: fs.File;
  private timer: number = -1;
  private handler: PlaybackProgressHandler = () => {};

  initialize(context: common.Context): void { this.context = context; }
  setProgressHandler(handler: PlaybackProgressHandler): void { this.handler = handler; }

  async toggle(audioName: string): Promise<void> {
    if (this.player) { await this.stop(); return; }
    if (!this.context) throw new Error('播放器尚未初始化');
    const path: string = `${this.context.cacheDir}/${audioName.substring(audioName.lastIndexOf('/') + 1)}`;
    let cached: boolean = false;
    try {
      const existing: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      cached = fs.statSync(existing.fd).size > 0;
      fs.closeSync(existing);
    } catch (_) {}
    if (!cached) {
      const data: ArrayBuffer | undefined = await libraryStore.download(audioName);
      if (!data) throw new Error('无法下载录音');
      const output: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(output.fd, data);
      fs.closeSync(output);
    }
    this.file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const player: media.AVPlayer = await media.createAVPlayer();
      this.player = player;
      let initializationSettled: boolean = false;
      let initializationTimer: number = -1;
      let resolveInitialization: () => void = () => {};
      let rejectInitialization: (reason?: Error) => void = () => {};
      const initialized: Promise<void> = new Promise<void>(
        (resolve: () => void, reject: (reason?: Error) => void) => {
          resolveInitialization = resolve;
          rejectInitialization = reject;
        });
      player.on('stateChange', (state: media.AVPlayerState) => {
        if (this.player !== player) return;
        if (!initializationSettled && state === 'initialized') {
          initializationSettled = true;
          if (initializationTimer >= 0) clearTimeout(initializationTimer);
          resolveInitialization();
        } else if (!initializationSettled && (state === 'error' || state === 'released')) {
          initializationSettled = true;
          if (initializationTimer >= 0) clearTimeout(initializationTimer);
          rejectInitialization(new Error(`播放器初始化失败：${state}`));
        } else if (initializationSettled && (state === 'completed' || state === 'error')) {
          this.stop().catch(() => {});
        }
      });
      const size: number = fs.statSync(this.file.fd).size;
      initializationTimer = setTimeout(() => {
        if (initializationSettled) return;
        initializationSettled = true;
        rejectInitialization(new Error('播放器初始化超时'));
      }, 5000);
      player.fdSrc = { fd: this.file.fd, offset: 0, length: size };
      await initialized;
      await player.prepare();
      await player.play();
      this.handler(true, 0, player.duration);
      this.timer = setInterval(() => {
        if (this.player) this.handler(true, this.player.currentTime, this.player.duration);
      }, 250);
    } catch (error) {
      await this.stop();
      throw new Error(String(error));
    }
  }

  async stop(): Promise<void> {
    if (this.timer >= 0) clearInterval(this.timer);
    this.timer = -1;
    const player: media.AVPlayer | undefined = this.player;
    this.player = undefined;
    if (player) {
      player.off('stateChange');
      if (player.state === 'prepared' || player.state === 'playing' ||
          player.state === 'paused' || player.state === 'completed') {
        try { await player.stop(); } catch (_) {}
      }
      await player.release();
    }
    if (this.file) fs.closeSync(this.file);
    this.file = undefined;
    this.handler(false, 0, 0);
  }

  async seek(positionMs: number): Promise<void> {
    if (this.player) this.player.seek(positionMs, media.SeekMode.SEEK_CLOSEST);
  }

  isPlaying(): boolean { return this.player !== undefined; }
}

export const audioPlayback: AudioPlayback = new AudioPlayback();
