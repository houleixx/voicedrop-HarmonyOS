import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { Api } from '../core/Api';
import { RecordingName } from '../core/RecordingName';
import { RecordingUploadPolicy } from '../core/RecordingUploadPolicy';
import { Recording } from '../model/Models';
import { authStore } from '../data/AuthStore';
import { appPreferences } from '../data/AppPreferences';
import { httpClient, HttpResponse } from '../net/HttpClient';

export class Uploader {
  private context?: common.Context;
  private discardedNames: Set<string> = new Set<string>();
  private activeUploads: Map<string, Promise<boolean>> = new Map<string, Promise<boolean>>();
  private generation: number = 0;

  initialize(context: common.Context): void { this.context = context; }

  prepare(path: string, tags: string[] = []): void {
    if (tags.length > 0) this.writeTags(path, tags);
  }

  async upload(path: string, tags: string[] = []): Promise<boolean> {
    const active: Promise<boolean> | undefined = this.activeUploads.get(path);
    if (active) return active;
    const task: Promise<boolean> = this.performUpload(path, tags);
    this.activeUploads.set(path, task);
    try {
      return await task;
    } finally {
      if (this.activeUploads.get(path) === task) this.activeUploads.delete(path);
    }
  }

  private async performUpload(path: string, tags: string[]): Promise<boolean> {
    if (!this.isUploadable(path)) return false;
    const generation: number = this.generation;
    const bearer: string = authStore.bearer();
    const name: string = path.substring(path.lastIndexOf('/') + 1);
    if (this.discardedNames.has(name)) { await this.finishDiscarded(path, name); return false; }
    this.prepare(path, tags);
    const storedTags: string[] = this.readTags(path);
    try { await this.uploadTags(path, storedTags, bearer); } catch (_) {}
    if (generation !== this.generation) return false;
    if (this.discardedNames.has(name)) { await this.finishDiscarded(path, name); return false; }
    for (let attempt: number = 1; attempt <= 3; attempt++) {
      if (generation !== this.generation) return false;
      if (this.discardedNames.has(name)) { await this.finishDiscarded(path, name); return false; }
      try {
        const bytes: ArrayBuffer = this.readFile(path);
        const response: HttpResponse = await httpClient.putBytes(
          `${Api.FILES}/upload/${Api.path(name)}`, bearer, bytes, 'audio/mp4');
        if (generation !== this.generation) return false;
        if (response.ok()) {
          if (this.discardedNames.has(name)) { await this.finishDiscarded(path, name); return false; }
          let mineTriggered: boolean = false;
          try {
            const mineResponse: HttpResponse = await httpClient.postJson(`${Api.FILES}/mine`, bearer);
            mineTriggered = mineResponse.ok();
          } catch (_) {}
          if (generation !== this.generation) return false;
          if (RecordingUploadPolicy.uploadCompleted(true, mineTriggered)) {
            this.finishLocal(path);
            return true;
          }
        }
        if (response.code >= 400 && response.code < 500) return false;
      } catch (error) {
        // The pending file remains available for the next retry or app launch.
      }
      if (attempt < 3) await this.delay(attempt * 1500);
    }
    return false;
  }

  clearLocalAccountFiles(): void {
    this.generation++;
    this.activeUploads.clear();
    this.discardedNames.clear();
    if (!this.context) return;
    this.removeChildren(this.context.filesDir);
  }

  async drainPending(): Promise<number> {
    if (!this.context) return 0;
    let uploaded: number = 0;
    const names: string[] = fs.listFileSync(this.context.filesDir);
    names.sort();
    for (const name of names) {
      if (!RecordingName.parse(name)) continue;
      if (await this.upload(`${this.context.filesDir}/${name}`)) uploaded++;
    }
    return uploaded;
  }

  pendingRecordings(): Recording[] {
    if (!this.context) return [];
    const result: Recording[] = [];
    try {
      for (const name of fs.listFileSync(this.context.filesDir).sort()) {
        if (!RecordingName.parse(name) || this.discardedNames.has(name)) continue;
        const recording: Recording = new Recording({ name: name });
        recording.uploading = true; recording.tags = this.readTags(`${this.context.filesDir}/${name}`); result.push(recording);
      }
    } catch (_) {}
    return result;
  }

  discardPending(recordingName: string): boolean {
    if (!this.context) return false;
    let pending: boolean = false;
    try { pending = fs.listFileSync(this.context.filesDir).includes(recordingName); } catch (_) {}
    if (!pending) return false;
    this.discardedNames.add(recordingName);
    const path: string = `${this.context.filesDir}/${recordingName}`;
    try { fs.unlinkSync(path); } catch (_) {}
    try { fs.unlinkSync(this.tagPath(path)); } catch (_) {}
    return true;
  }

  private readFile(path: string): ArrayBuffer {
    const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const bytes: ArrayBuffer = new ArrayBuffer(fs.statSync(path).size); fs.readSync(file.fd, bytes); return bytes;
    } finally { fs.closeSync(file); }
  }

  private isUploadable(path: string): boolean {
    try {
      const bytes: Uint8Array = new Uint8Array(this.readFile(path)); if (bytes.byteLength <= 1024) return false;
      for (let index: number = 0; index <= bytes.length - 4; index++) {
        if (bytes[index] === 109 && bytes[index + 1] === 111 && bytes[index + 2] === 111 && bytes[index + 3] === 118) return true;
      }
    } catch (_) {}
    return false;
  }

  private tagPath(path: string): string { return `${path.substring(0, path.lastIndexOf('.'))}.tags.json`; }

  private writeTags(path: string, tags: string[]): void {
    const clean: string[] = tags.map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0);
    if (clean.length === 0) return;
    const file: fs.File = fs.openSync(this.tagPath(path), fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try {
      const bytes: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify(clean));
      const buffer: ArrayBuffer = new ArrayBuffer(bytes.byteLength); new Uint8Array(buffer).set(bytes); fs.writeSync(file.fd, buffer);
    } finally { fs.closeSync(file); }
  }

  private readTags(path: string): string[] {
    try {
      const bytes: Uint8Array = new Uint8Array(this.readFile(this.tagPath(path)));
      return JSON.parse(new util.TextDecoder('utf-8').decodeWithStream(bytes)) as string[];
    } catch (_) { return []; }
  }

  private async uploadTags(path: string, tags: string[], bearer: string): Promise<void> {
    if (tags.length === 0) return;
    const name: string = path.substring(path.lastIndexOf('/') + 1);
    const stem: string = name.endsWith('.m4a') ? name.substring(0, name.length - 4) : name;
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify(tags));
    const buffer: ArrayBuffer = new ArrayBuffer(bytes.byteLength); new Uint8Array(buffer).set(bytes);
    await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(`articles/${stem}.tags`)}`,
      bearer, buffer, 'application/json');
  }

  private removeChildren(directory: string): void {
    let names: string[] = [];
    try { names = fs.listFileSync(directory); } catch (_) { return; }
    for (const name of names) {
      const path: string = `${directory}/${name}`;
      try {
        if (fs.statSync(path).isDirectory()) {
          this.removeChildren(path);
          fs.rmdirSync(path);
        } else {
          fs.unlinkSync(path);
        }
      } catch (_) {}
    }
  }

  private finishLocal(path: string): void {
    try { fs.unlinkSync(this.tagPath(path)); } catch (_) {}
    if (appPreferences.deleteLocalAfterUpload()) { try { fs.unlinkSync(path); } catch (_) {} return; }
    if (!this.context) return;
    const uploadedDir: string = `${this.context.filesDir}/uploaded`;
    try { fs.mkdirSync(uploadedDir, true); } catch (_) {}
    try { fs.renameSync(path, `${uploadedDir}/${path.substring(path.lastIndexOf('/') + 1)}`); } catch (_) {}
  }

  private async finishDiscarded(path: string, name: string): Promise<void> {
    try { fs.unlinkSync(path); } catch (_) {}
    try { fs.unlinkSync(this.tagPath(path)); } catch (_) {}
    await Promise.all([
      httpClient.delete(`${Api.FILES}/file/${Api.path(name)}`, authStore.bearer()).catch(() => undefined),
      httpClient.delete(`${Api.FILES}/file/${Api.path(`articles/${RecordingName.stem(name)}.tags`)}`,
        authStore.bearer()).catch(() => undefined)
    ]);
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => setTimeout(resolve, milliseconds));
  }
}

export const uploader: Uploader = new Uploader();
