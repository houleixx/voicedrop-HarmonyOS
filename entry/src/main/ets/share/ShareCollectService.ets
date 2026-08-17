import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { zlib } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { pdfService } from '@kit.PDFKit';
import { Api } from '../core/Api';
import { RecordingName } from '../core/RecordingName';
import { ShareDatasetSnapshot, ShareImport, ShareImportKind } from '../core/ShareImport';
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
  kind: ShareImportKind;
  collectedChars: number;
  constructor(ok: boolean, message: string, kind: ShareImportKind = ShareImportKind.DATASET,
    collectedChars: number = 0) {
    this.ok = ok; this.message = message; this.kind = kind; this.collectedChars = collectedChars;
  }
}

class ExtractedWebPage {
  title: string;
  text: string;
  source: string;
  constructor(title: string = '', text: string = '', source: string = '') {
    this.title = title; this.text = text; this.source = source;
  }
}

export class ShareCollectService {
  private static readonly SILENT_M4A: string =
    'AAAAHGZ0eXBNNEEgAAACAE00QSBpc29taXNvMgAAAAhmcmVlAAAAXW1kYXTeAgBMYXZjNjIuMjguMTAxAAIwQA4BGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHARggBwEYIAcBGCAHAAADP21vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAAPoAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAJpdHJhawAAAFx0a2hkAAAAAwAAAAAAAAAAAAAAAQAAAAAAAAPoAAAAAAAAAAAAAAABAQAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAJGVkdHMAAAAcZWxzdAAAAAAAAAABAAAD6AAABAAAAQAAAAAB4W1kaWEAAAAgbWRoZAAAAAAAAAAAAAAAAAAAPoAAAEKAVcQAAAAAAC1oZGxyAAAAAAAAAABzb3VuAAAAAAAAAAAAAAAAU291bmRIYW5kbGVyAAAAAYxtaW5mAAAAEHNtaGQAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAAVBzdGJsAAAAanN0c2QAAAAAAAAAAQAAAFptcDRhAAAAAAAAAAEAAAAAAAAAAAABABAAAAAAPoAAAAAAADZlc2RzAAAAAAOAgIAlAAEABICAgBdAFQAAAAAAfQAAAAJ/BYCAgAUUCFblAAaAgIABAgAAACBzdHRzAAAAAAAAAAIAAAAQAAAEAAAAAAEAAAKAAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAARAAAAAQAAAFhzdHN6AAAAAAAAAAAAAAARAAAAFQAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAEAAAABAAAAAQAAAAUc3RjbwAAAAAAAAABAAAALAAAABpzZ3BkAQAAAHJvbGwAAAACAAAAAf//AAAAHHNiZ3AAAAAAcm9sbAAAAAEAAAARAAAAAQAAAGJ1ZHRhAAAAWm1ldGEAAAAAAAAAIWhkbHIAAAAAAAAAAG1kaXJhcHBsAAAAAAAAAAAAAAAALWlsc3QAAAAlqXRvbwAAAB1kYXRhAAAAAQAAAABMYXZmNjIuMTIuMTAx';

  async collectText(text: string, title: string = '', source: string = 'harmonyos-share'): Promise<boolean> {
    if (text.trim().length === 0) return false;
    const kind: string = ShareImport.isWebUrl(text.trim()) ? 'web' : 'text';
    const response: HttpResponse = await this.collectStyle(kind,
      title.length > 0 ? title : ShareImport.firstLineTitle(text), text.trim(), source);
    return response.ok();
  }

  async collectIncoming(context: common.UIAbilityContext, mime: string, uris: string[], text: string,
    title: string = ''): Promise<ShareCollectResult> {
    const kind: ShareImportKind = ShareImport.classify(mime, uris);
    if (kind === ShareImportKind.AUDIO && uris.length > 0) return this.generateFromAudio(uris[0]);
    if (kind === ShareImportKind.IMAGE && uris.length > 0) return this.generateFromImages(uris);
    return this.collectDataset(context, uris, text, title);
  }

  async fetchDataset(): Promise<ShareDatasetSnapshot> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/style/dataset`, authStore.bearer());
    return response.ok() ? ShareImport.parseDatasetResponse(response.text) : new ShareDatasetSnapshot();
  }

  async extractStyle(clearAfter: boolean): Promise<ShareCollectResult> {
    const snapshot: ShareDatasetSnapshot = await this.fetchDataset();
    if (!ShareImport.canExtract(snapshot)) {
      return new ShareCollectResult(false,
        `素材还太少（共 ${snapshot.totalChars} 字），至少需要 ${ShareImport.MIN_STYLE_CHARS} 字`);
    }
    const base: string = RecordingName.create(new Date(), 0);
    const taskName: string = `${base.substring(0, base.length - 4)}-${ShareImport.styleTaskTag(clearAfter)}.m4a`;
    const silent: Uint8Array = new util.Base64Helper().decodeSync(ShareCollectService.SILENT_M4A);
    const task: HttpResponse = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(taskName)}`,
      authStore.bearer(), this.toBuffer(silent), 'audio/mp4');
    if (!task.ok()) return new ShareCollectResult(false, `文风提取任务创建失败（${task.code}）`);
    await this.triggerMine();
    return new ShareCollectResult(true, '正在提取文章风格，可在“我的录音”查看进度');
  }

  async clearDataset(): Promise<boolean> {
    return (await httpClient.delete(`${Api.FILES}/style/dataset`, authStore.bearer())).ok();
  }

  private async generateFromAudio(uri: string): Promise<ShareCollectResult> {
    const bytes: ArrayBuffer = this.readUri(uri);
    if (bytes.byteLength === 0) return new ShareCollectResult(false, '分享音频为空', ShareImportKind.AUDIO);
    const name: string = RecordingName.create(new Date(), 0);
    const upload: HttpResponse = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(name)}`,
      authStore.bearer(), bytes, 'audio/mp4');
    if (!upload.ok()) return new ShareCollectResult(false, `音频上传失败（${upload.code}）`, ShareImportKind.AUDIO);
    await this.triggerMine();
    return new ShareCollectResult(true, '音频已送入 VoiceDrop，正在转写成文', ShareImportKind.AUDIO);
  }

  private async generateFromImages(uris: string[]): Promise<ShareCollectResult> {
    const taskName: string = RecordingName.create(new Date(), 0);
    let uploaded: number = 0;
    for (let index: number = 0; index < uris.length; index++) {
      const bytes: ArrayBuffer = this.readUri(uris[index]);
      if (bytes.byteLength > 0 && (await photoService.uploadBytes(bytes, taskName, index)).length > 0) uploaded++;
    }
    if (uploaded === 0) return new ShareCollectResult(false, '图片读取或上传失败', ShareImportKind.IMAGE);
    const silent: Uint8Array = new util.Base64Helper().decodeSync(ShareCollectService.SILENT_M4A);
    const task: HttpResponse = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(taskName)}`,
      authStore.bearer(), this.toBuffer(silent), 'audio/mp4');
    if (!task.ok()) return new ShareCollectResult(false, `生成任务创建失败（${task.code}）`, ShareImportKind.IMAGE);
    await this.triggerMine();
    return new ShareCollectResult(true, `${uploaded} 张图片已送入 VoiceDrop，正在看图成文`, ShareImportKind.IMAGE);
  }

  private async collectDataset(context: common.UIAbilityContext, uris: string[], sharedText: string,
    sharedTitle: string): Promise<ShareCollectResult> {
    let chars: number = 0;
    const text: string = sharedText.trim();
    if (text.length > 0) {
      if (ShareImport.isWebUrl(text)) {
        const page: ExtractedWebPage = await this.fetchWebPage(text);
        if (page.text.length > 0) {
          const response: HttpResponse = await this.collectStyle('web', page.title, page.text, page.source);
          if (!response.ok()) return new ShareCollectResult(false, `网页收集失败（${response.code}）`);
          chars += page.text.length;
        }
      } else {
        const response: HttpResponse = await this.collectStyle('text',
          sharedTitle.length > 0 ? sharedTitle : ShareImport.firstLineTitle(text), text, '分享文本');
        if (!response.ok()) return new ShareCollectResult(false, `文字收集失败（${response.code}）`);
        chars += text.length;
      }
    }
    for (const uri of uris) {
      const docText: string = await this.decodeDocument(context, this.readUri(uri), uri);
      if (docText.trim().length === 0) continue;
      const response: HttpResponse = await this.collectStyle('doc',
        ShareImport.firstLineTitle(docText, this.fileName(uri)),
        docText.trim(), this.fileName(uri));
      if (response.ok()) chars += docText.trim().length;
    }
    if (chars === 0) return new ShareCollectResult(false, '未能读取正文；PDF 扫描件暂不支持 OCR');
    return new ShareCollectResult(true, `本次已加入 ${chars} 字，可继续收集或提取文章风格`,
      ShareImportKind.DATASET, chars);
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

  private async decodeDocument(context: common.UIAbilityContext, bytes: ArrayBuffer, uri: string): Promise<string> {
    if (bytes.byteLength === 0) return '';
    const data: Uint8Array = new Uint8Array(bytes);
    if (data[0] === 0x25 && data[1] === 0x50 && data[2] === 0x44 && data[3] === 0x46) {
      return this.extractPdf(context, bytes);
    }
    if (data[0] === 0x50 && data[1] === 0x4b) return this.extractDocx(context, bytes);
    let value: string = new util.TextDecoder('utf-8').decodeWithStream(data);
    if (uri.toLowerCase().endsWith('.rtf') || value.trim().startsWith('{\\rtf')) {
      value = ShareImport.extractRtf(value);
    }
    return value.indexOf('\u0000') >= 0 ? '' : value;
  }

  private extractPdf(context: common.UIAbilityContext, bytes: ArrayBuffer): string {
    const path: string = this.writeTemporary(context, bytes, '.pdf');
    const document: pdfService.PdfDocument = new pdfService.PdfDocument();
    const pages: string[] = [];
    try {
      if (document.loadDocument(path) !== pdfService.ParseResult.PARSE_SUCCESS) return '';
      for (let index: number = 0; index < document.getPageCount(); index++) {
        const page: pdfService.PdfPage = document.getPage(index);
        try {
          const values: string[] = [];
          for (const object of page.getGraphicsObjects()) {
            if (object.type === pdfService.GraphicsObjectType.OBJECT_TEXT) {
              const text: string = (object as pdfService.TextObject).text.trim();
              if (text.length > 0) values.push(text);
            }
          }
          if (values.length > 0) pages.push(values.join(' '));
        } finally { page.release(); }
      }
    } finally {
      try { document.releaseDocument(); } catch (_) {}
      try { fs.unlinkSync(path); } catch (_) {}
    }
    return pages.join('\n\n').trim();
  }

  private async extractDocx(context: common.UIAbilityContext, bytes: ArrayBuffer): Promise<string> {
    const zipPath: string = this.writeTemporary(context, bytes, '.docx');
    const root: string = `${context.cacheDir}/share-docx-${Date.now()}-${Math.floor(Math.random() * 100000)}`;
    try {
      fs.mkdirSync(root);
      await zlib.decompressFile(zipPath, root);
      const xmlPath: string = `${root}/word/document.xml`;
      const xml: string = new util.TextDecoder('utf-8').decodeWithStream(new Uint8Array(this.readUri(xmlPath)));
      return ShareImport.extractDocxXml(xml);
    } catch (_) {
      return '';
    } finally {
      try { fs.unlinkSync(zipPath); } catch (_) {}
      this.removeTree(root);
    }
  }

  private async fetchWebPage(url: string): Promise<ExtractedWebPage> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'text/html,application/xhtml+xml',
          'User-Agent': 'Mozilla/5.0 (Linux; HarmonyOS) AppleWebKit/537.36 Mobile Safari/537.36 VoiceDrop/1.0'
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) return new ExtractedWebPage();
      const html: string = String(response.result ?? '');
      let host: string = url;
      const hostMatch: RegExpMatchArray | null = url.match(/^https?:\/\/([^/?#]+)/i);
      if (hostMatch && hostMatch[1]) host = hostMatch[1];
      const text: string = ShareImport.extractHtml(html);
      return text.length >= 40 ? new ExtractedWebPage(ShareImport.htmlTitle(html, host), text, host) :
        new ExtractedWebPage();
    } catch (_) {
      return new ExtractedWebPage();
    } finally { request.destroy(); }
  }

  private writeTemporary(context: common.UIAbilityContext, bytes: ArrayBuffer, suffix: string): string {
    const path: string = `${context.cacheDir}/share-${Date.now()}-${Math.floor(Math.random() * 100000)}${suffix}`;
    const file: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try { fs.writeSync(file.fd, bytes); } finally { fs.closeSync(file); }
    return path;
  }

  private removeTree(root: string): void {
    try {
      const files: string[] = fs.listFileSync(root, { recursion: true });
      files.sort((left: string, right: string) => right.length - left.length);
      for (const relative of files) {
        const path: string = relative.startsWith('/') ? `${root}${relative}` : `${root}/${relative}`;
        try { if (fs.statSync(path).isDirectory()) fs.rmdirSync(path); else fs.unlinkSync(path); } catch (_) {}
      }
      fs.rmdirSync(root);
    } catch (_) {}
  }

  private fileName(uri: string): string {
    const clean: string = uri.split('?')[0];
    return decodeURIComponent(clean.substring(clean.lastIndexOf('/') + 1)) || '分享文档';
  }

  private toBuffer(bytes: Uint8Array): ArrayBuffer {
    const output: ArrayBuffer = new ArrayBuffer(bytes.byteLength); new Uint8Array(output).set(bytes); return output;
  }
}

export const shareCollectService: ShareCollectService = new ShareCollectService();
