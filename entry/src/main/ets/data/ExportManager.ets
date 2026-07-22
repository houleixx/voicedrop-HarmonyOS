import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { ArticleBody } from '../core/ArticleBody';
import { ArticleDoc, Recording } from '../model/Models';
import { libraryStore } from './LibraryStore';

export class ExportManager {
  private context: common.UIAbilityContext;
  constructor(context: common.UIAbilityContext) { this.context = context; }

  async create(recordings: Recording[]): Promise<string> {
    if (recordings.length === 0) throw new Error('没有录音可以导出');
    const stamp: string = this.stamp();
    const root: string = `${this.context.cacheDir}/VoiceDrop-${stamp}`;
    fs.mkdirSync(root); fs.mkdirSync(`${root}/audio`); fs.mkdirSync(`${root}/recordings`);
    let cards: string = ''; let articleCount: number = 0;
    for (const recording of recordings) {
      if (recording.uploading) continue;
      const audio: ArrayBuffer | undefined = await libraryStore.download(recording.name);
      if (audio) this.write(`${root}/audio/${recording.stem()}.m4a`, audio);
      let doc: ArticleDoc | undefined;
      if (recording.hasArticles) doc = await libraryStore.fetchArticle(recording);
      if (doc) {
        articleCount++;
        await this.downloadPhotos(root, doc);
        this.writeText(`${root}/recordings/${recording.stem()}.html`, this.articleHtml(recording, doc));
        const srt: ArrayBuffer | undefined = await libraryStore.download(recording.srtKey());
        if (srt) this.write(`${root}/recordings/${recording.stem()}.srt`, srt);
      }
      cards += this.card(recording, doc);
    }
    this.writeText(`${root}/index.html`, this.indexHtml(recordings.length, articleCount, cards));
    const zipPath: string = `${this.context.cacheDir}/VoiceDrop-${stamp}.zip`;
    await zlib.compressFile(root, zipPath, { level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION });
    return zipPath;
  }

  private async downloadPhotos(root: string, doc: ArticleDoc): Promise<void> {
    const seen: Set<string> = new Set<string>();
    for (const article of doc.articles) {
      for (const block of ArticleBody.blocks(article.body)) {
        if (block.kind !== 'photo') continue;
        const key: string = ArticleBody.resolvePhotoKey(block.value, doc.photos) ?? '';
        if (key.length === 0 || key.includes('..') || seen.has(key)) continue;
        seen.add(key); const data: ArrayBuffer | undefined = await libraryStore.download(key);
        if (!data) continue;
        const path: string = `${root}/${key}`; this.ensureParent(path); this.write(path, data);
      }
    }
  }

  private indexHtml(total: number, articles: number, cards: string): string {
    return `<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>VoiceDrop 导出</title><style>${this.css()}</style><body><main><h1>Voice<span>Drop</span> 口述</h1><p>${total} 条录音 · ${articles} 篇文章</p>${cards}</main></body></html>`;
  }
  private card(rec: Recording, doc?: ArticleDoc): string {
    const title: string = doc?.articles?.[0]?.title ?? rec.rowTitle();
    const preview: string = doc ? ArticleBody.stripMarkers(doc.articles[0]?.body ?? '').replace(/\n/g, ' ').substring(0, 120) : '';
    return `<section><h2>${this.h(title)}</h2><small>${this.h(rec.rowTitle())}</small><p>${this.h(preview)}</p>${doc ? `<a href="recordings/${this.h(rec.stem())}.html">读文章</a>` : ''} <a href="audio/${this.h(rec.stem())}.m4a">听录音</a></section>`;
  }
  private articleHtml(rec: Recording, doc: ArticleDoc): string {
    let content: string = '';
    for (const article of doc.articles) {
      content += `<h1>${this.h(article.title)}</h1>`;
      for (const block of ArticleBody.blocks(article.body)) {
        if (block.kind === 'photo') {
          const key: string = ArticleBody.resolvePhotoKey(block.value, doc.photos) ?? '';
          if (key.length > 0) content += `<img src="../${this.h(key)}">`;
        } else for (const paragraph of block.value.split(/\n\n/)) if (paragraph.trim()) content += `<p>${this.h(paragraph.trim())}</p>`;
      }
    }
    const transcript: string = doc.transcript ? `<details><summary>原始转录</summary><pre>${this.h(doc.transcript)}</pre></details>` : '';
    return `<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><style>${this.css()}</style><body><main><a href="../index.html">‹ 所有录音</a><audio controls src="../audio/${this.h(rec.stem())}.m4a"></audio>${content}${transcript}</main></body></html>`;
  }
  private css(): string { return 'body{background:#faf6ef;color:#2a2521;font-family:-apple-system,PingFang SC,sans-serif}main{max-width:680px;margin:auto;padding:24px}span,a{color:#d8593b}section{background:#fff;border:1px solid #ece3d5;border-radius:10px;padding:18px;margin:12px 0}h1{line-height:1.4}h2{margin-bottom:4px}p{line-height:1.8}small{color:#888}audio,img{display:block;width:100%;margin:20px 0;border-radius:10px}pre{white-space:pre-wrap;line-height:1.7}'; }
  private h(value: string): string { return value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  private stamp(): string { const d: Date = new Date(); return `${d.getFullYear()}${this.two(d.getMonth()+1)}${this.two(d.getDate())}-${this.two(d.getHours())}${this.two(d.getMinutes())}${this.two(d.getSeconds())}`; }
  private two(value: number): string { return value.toString().padStart(2, '0'); }
  private ensureParent(path: string): void { const parts: string[] = path.substring(0, path.lastIndexOf('/')).split('/'); let current: string = ''; for (const part of parts) { if (!part) continue; current += `/${part}`; try { fs.mkdirSync(current); } catch (_) {} } }
  private writeText(path: string, value: string): void { const bytes: Uint8Array = new util.TextEncoder().encodeInto(value); const out: ArrayBuffer = new ArrayBuffer(bytes.byteLength); new Uint8Array(out).set(bytes); this.write(path, out); }
  private write(path: string, data: ArrayBuffer): void { const file: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY); try { fs.writeSync(file.fd, data); } finally { fs.closeSync(file); } }
}
