import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Api } from '../core/Api';
import { RecordingName } from '../core/RecordingName';
import { authStore } from '../data/AuthStore';
import { photoService } from '../data/PhotoService';
import { httpClient, HttpResponse } from '../net/HttpClient';

class StyleCollectBody {
  type: string;
  title: string;
  text: string;
  source: string;
  constructor(type: string, title: string, text: string, source: string) {
    this.type = type; this.title = title; this.text = text; this.source = source;
  }
}

export class ShareCollectResult {
  ok: boolean;
  message: string;
  constructor(ok: boolean, message: string) { this.ok = ok; this.message = message; }
}

export class ShareCollectService {
  private static readonly SILENT_M4A: string =
    'AAAAHGZ0eXBNNEEgAAACAE00QSBpc29taXNvMgAAAAhmcmVlAAAAXW1kYXTeAgBMYXZjNjIuMjguMTAxAAIwQA4BGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHAAADP21vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAAPoAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAJpdHJhawAAAFx0a2hkAAAAAwAAAAAAAAAAAAAAAQAAAAAAAAPoAAAAAAAAAAAAAAABAQAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAJGVkdHMAAAAcZWxzdAAAAAAAAAABAAAD6AAABAAAAQAAAAAB4W1kaWEAAAAgbWRoZAAAAAAAAAAAAAAAAAAAPoAAAEKAVcQAAAAAAC1oZGxyAAAAAAAAAABzb3VuAAAAAAAAAAAAAAAAU291bmRIYW5kbGVyAAAAAYxtaW5mAAAAEHNtaGQAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAAVBzdGJsAAAAanN0c2QAAAAAAAAAAQAAAFptcDRhAAAAAAAAAAEAAAAAAAAAAAABABAAAAAAPoAAAAAAADZlc2RzAAAAAAOAgIAlAAEABICAgBdAFQAAAAAAfQAAAAJ/BYCAgAUUCFblAAaAgIABAgAAACBzdHRzAAAAAAAAAAIAAAAQAAAEAAAAAAEAAAKAAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAARAAAAAQAAAFhzdHN6AAAAAAAAAAAAAAARAAAAFQAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAUc3RjbwAAAAAAAAABAAAALAAAABpzZ3BkAQAAAHJvbGwAAAACAAAAAf//AAAAHHNiZ3AAAAAAcm9sbAAAAAEAAAARAAAAAQAAAGJ1ZHRhAAAAWm1ldGEAAAAAAAAAIWhkbHIAAAAAAAAAAG1kaXJhcHBsAAAAAAAAAAAAAAAALWlsc3QAAAAlqXRvbwAAAB1kYXRhAAAAAQAAAABMYXZmNjIuMTIuMTAx';

  async collectText(text: string, title: string = '', source: string = 'harmonyos-share'): Promise<boolean> {
    if (text.trim().length === 0) return false;
    const kind: string = this.isWebUrl(text.trim()) ? 'web' : 'text';
    const response: HttpResponse = await this.collectStyle(kind, title.length > 0 ? title : this.firstLineTitle(text), text.trim(), source);
    return response.ok();
  }

  async collectIncoming(mime: string, uris: string[], text: string, title: string = ''): Promise<ShareCollectResult> {
    const lower: string = mime.toLowerCase();
    if (lower.startsWith('audio/') && uris.length > 0) return this.generateFromAudio(uris[0]);
    if (lower.startsWith('image/') && uris.length > 0) return this.generateFromImages(uris);
    if (uris.length > 0 && this.looksLikeAudio(uris[0])) return this.generateFromAudio(uris[0]);
    if (uris.length > 0 && this.looksLikeImage(uris[0])) return this.generateFromImages(uris);
    return this.collectDataset(uris, text, title);
  }

  private async generateFromAudio(uri: string): Promise<ShareCollectResult> {
    const bytes: ArrayBuffer = this.readUri(uri);
    if (bytes.byteLength === 0) return new ShareCollectResult(false, '分享音频为空');
    const name: string = RecordingName.create(new Date(), 0);
    const upload: HttpResponse = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(name)}`,
      authStore.bearer(), bytes, 'audio/mp4');
    if (!upload.ok()) return new ShareCollectResult(false, `音频上传失败（${upload.code}）`);
    await this.triggerMine();
    return new ShareCollectResult(true, '音频已送入 VoiceDrop，正在转写成文');
  }

  private async generateFromImages(uris: string[]): Promise<ShareCollectResult> {
    const taskName: string = RecordingName.create(new Date(), 0);
    let uploaded: number = 0;
    for (let index: number = 0; index < uris.length; index++) {
      const bytes: ArrayBuffer = this.readUri(uris[index]);
      if (bytes.byteLength > 0 && (await photoService.uploadBytes(bytes, taskName, index)).length > 0) uploaded++;
    }
    if (uploaded === 0) return new ShareCollectResult(false, '图片读取或上传失败');
    const silent: Uint8Array = new util.Base64Helper().decodeSync(ShareCollectService.SILENT_M4A);
    const task: HttpResponse = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(taskName)}`,
      authStore.bearer(), this.toBuffer(silent), 'audio/mp4');
    if (!task.ok()) return new ShareCollectResult(false, `生成任务创建失败（${task.code}）`);
    await this.triggerMine();
    return new ShareCollectResult(true, `${uploaded} 张图片已送入 VoiceDrop，正在看图成文`);
  }

  private async collectDataset(uris: string[], sharedText: string, sharedTitle: string): Promise<ShareCollectResult> {
    let chars: number = 0;
    const text: string = sharedText.trim();
    if (text.length > 0) {
      const web: boolean = this.isWebUrl(text);
      const response: HttpResponse = await this.collectStyle(web ? 'web' : 'text',
        sharedTitle.length > 0 ? sharedTitle : this.firstLineTitle(text), text, web ? text : '分享文本');
      if (!response.ok()) return new ShareCollectResult(false, `文字收集失败（${response.code}）`);
      chars += text.length;
    }
    for (const uri of uris) {
      const docText: string = this.decodeDocument(this.readUri(uri), uri);
      if (docText.trim().length === 0) continue;
      const response: HttpResponse = await this.collectStyle('doc', this.firstLineTitle(docText, this.fileName(uri)),
        docText.trim(), this.fileName(uri));
      if (response.ok()) chars += docText.trim().length;
    }
    if (chars === 0) return new ShareCollectResult(false, '未能从分享内容中读取文字');
    if (chars < 300) return new ShareCollectResult(false, `已收集 ${chars} 字；至少 300 字才会开始提取文风`);
    const base: string = RecordingName.create(new Date(), 0);
    const taskName: string = `${base.substring(0, base.length - 4)}-TaskStyleExtract.m4a`;
    const silent: Uint8Array = new util.Base64Helper().decodeSync(ShareCollectService.SILENT_M4A);
    const task: HttpResponse = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(taskName)}`,
      authStore.bearer(), this.toBuffer(silent), 'audio/mp4');
    if (!task.ok()) return new ShareCollectResult(false, `文风提取任务创建失败（${task.code}）`);
    await this.triggerMine();
    return new ShareCollectResult(true, `已收集 ${chars} 字，正在提取文章风格`);
  }

  private async collectStyle(type: string, title: string, text: string, source: string): Promise<HttpResponse> {
    return httpClient.postJson(`${Api.FILES}/style/collect`, authStore.bearer(),
      new StyleCollectBody(type, title, text, source));
  }

  private async triggerMine(): Promise<void> {
    await httpClient.postJson(`${Api.AGENT}/mine/trigger`, authStore.bearer());
  }

  private readUri(uri: string): ArrayBuffer {
    const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const size: number = fs.statSync(file.fd).size;
      const bytes: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, bytes);
      return bytes;
    } finally { fs.closeSync(file); }
  }

  private decodeDocument(bytes: ArrayBuffer, uri: string): string {
    if (bytes.byteLength === 0) return '';
    const data: Uint8Array = new Uint8Array(bytes);
    if ((data[0] === 0x25 && data[1] === 0x50 && data[2] === 0x44 && data[3] === 0x46) ||
      (data[0] === 0x50 && data[1] === 0x4b)) return '';
    let value: string = new util.TextDecoder('utf-8').decodeWithStream(data);
    if (uri.toLowerCase().endsWith('.rtf') || value.trim().startsWith('{\\rtf')) {
      value = value.replace(/\\'[0-9a-fA-F]{2}/g, '').replace(/\\[a-zA-Z]+-?\d* ?/g, '')
        .replace(/[{}]/g, '').replace(/\r?\n/g, '\n');
    }
    return value.indexOf('\u0000') >= 0 ? '' : value;
  }

  private firstLineTitle(text: string, fallback: string = '分享内容'): string {
    for (const line of text.split(/\r?\n/)) if (line.trim().length > 0) return line.trim().substring(0, 40);
    return fallback.substring(0, 40);
  }

  private fileName(uri: string): string {
    const clean: string = uri.split('?')[0];
    return decodeURIComponent(clean.substring(clean.lastIndexOf('/') + 1)) || '分享文档';
  }

  private isWebUrl(value: string): boolean { return /^https?:\/\/\S+$/i.test(value); }
  private looksLikeAudio(uri: string): boolean { return /\.(m4a|mp3|aac|wav|flac|ogg)(\?|$)/i.test(uri); }
  private looksLikeImage(uri: string): boolean { return /\.(jpe?g|png|webp|heic|gif)(\?|$)/i.test(uri); }
  private toBuffer(bytes: Uint8Array): ArrayBuffer {
    const output: ArrayBuffer = new ArrayBuffer(bytes.byteLength); new Uint8Array(output).set(bytes); return output;
  }
}

export const shareCollectService: ShareCollectService = new ShareCollectService();
