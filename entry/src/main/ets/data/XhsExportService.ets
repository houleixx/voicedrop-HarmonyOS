import { common } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { XhsCard, XhsCardLayout, XhsMeasureText } from '../core/XhsCardLayout';
import { RecordingName } from '../core/RecordingName';
import { ArticleDoc, Recording } from '../model/Models';
import { libraryStore, XhsPack } from './LibraryStore';
import { PhotoJpeg } from '../core/PhotoJpeg';

export class XhsPreparedImages {
  fileUris: string[];
  savedUris: string[];
  constructor(fileUris: string[] = [], savedUris: string[] = []) {
    this.fileUris = fileUris; this.savedUris = savedUris;
  }
}

export class XhsExportService {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) { this.context = context; }

  async prepare(pack: XhsPack, recording: Recording, article?: ArticleDoc): Promise<XhsPreparedImages> {
    const root: string = `${this.context.cacheDir}/xhs-${Date.now()}`;
    fs.mkdirSync(root);
    const paths: string[] = await this.downloadOriginalPhotos(pack.photoKeys, article, root);
    const cardSlots: number = XhsCardLayout.generatedCardSlots(paths.length);
    if (cardSlots > 0) {
      const measureCanvas: OffscreenCanvas = new OffscreenCanvas(XhsCardLayout.WIDTH, XhsCardLayout.HEIGHT);
      const measureContext: OffscreenCanvasRenderingContext2D = measureCanvas.getContext('2d');
      this.bodyFont(measureContext);
      const measureText: XhsMeasureText = (value: string): number => measureContext.measureText(value).width;
      const parsed = RecordingName.parse(recording.name);
      const date: string = parsed?.sessionTs.substring(0, 10) ?? '';
      const cards: XhsCard[] = XhsCardLayout.cards(pack.title, pack.body, date, cardSlots, measureText);
      for (let index: number = 0; index < cards.length; index++) {
        const jpeg: ArrayBuffer = await this.renderCard(cards[index], index + 1, cards.length);
        const path: string = `${root}/${this.fileName(paths.length + index)}`;
        this.write(path, jpeg); paths.push(path);
      }
    }
    const fileUris: string[] = paths.slice(0, XhsCardLayout.MAX_IMAGES)
      .map((path: string): string => fileUri.getUriFromPath(path));
    const savedUris: string[] = await this.saveToAlbum(fileUris);
    return new XhsPreparedImages(fileUris, savedUris);
  }

  private async downloadOriginalPhotos(keys: string[], article: ArticleDoc | undefined,
    root: string): Promise<string[]> {
    const paths: string[] = [];
    const owner: string = (article?.owner ?? await libraryStore.ownerScope()).trim();
    const scope: string = owner.length > 0 && !owner.endsWith('/') ? `${owner}/` : owner;
    for (const rawKey of keys) {
      if (paths.length >= XhsCardLayout.MAX_IMAGES) break;
      const key: string = rawKey.trim();
      if (key.length === 0) continue;
      const fullKey: string = key.startsWith('users/') || key.startsWith('anonymous/') ? key : `${scope}${key}`;
      if (fullKey.length === 0 || fullKey.includes('..')) continue;
      try {
        const source: ArrayBuffer | undefined = await libraryStore.download(fullKey);
        if (!source || source.byteLength === 0) continue;
        const jpeg: ArrayBuffer = await PhotoJpeg.transcode(source);
        const path: string = `${root}/${this.fileName(paths.length)}`;
        this.write(path, jpeg); paths.push(path);
      } catch (_) {}
    }
    return paths;
  }

  private async renderCard(card: XhsCard, page: number, total: number): Promise<ArrayBuffer> {
    const canvas: OffscreenCanvas = new OffscreenCanvas(XhsCardLayout.WIDTH, XhsCardLayout.HEIGHT);
    const context: OffscreenCanvasRenderingContext2D = canvas.getContext('2d');
    context.textBaseline = 'top'; context.textAlign = 'left';
    context.fillStyle = '#f5f1e8';
    context.fillRect(0, 0, XhsCardLayout.WIDTH, XhsCardLayout.HEIGHT);
    if (card.kind === 'title') this.drawTitle(context, card);
    else this.drawBody(context, card);
    this.drawFooter(context, page, total);

    const pixelMap: image.PixelMap = context.getPixelMap(0, 0, XhsCardLayout.WIDTH, XhsCardLayout.HEIGHT);
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      return await packer.packToData(pixelMap, {
        format: 'image/jpeg', quality: 92, bufferSize: 10 * 1024 * 1024
      });
    } finally {
      try { await pixelMap.release(); } catch (_) {}
      try { await packer.release(); } catch (_) {}
    }
  }

  private drawTitle(context: OffscreenCanvasRenderingContext2D, card: XhsCard): void {
    context.fillStyle = '#8d8372';
    context.font = 'normal 400 30px sans-serif'; context.letterSpacing = '4px';
    if (card.date.length > 0) context.fillText(card.date, 112, 200);
    context.fillStyle = '#b9502e'; context.beginPath();
    context.roundRect(112, 286, 76, 8, 4); context.fill();
    context.fillStyle = '#3a352e';
    context.font = 'normal 600 78px sans-serif'; context.letterSpacing = '1px';
    const measureTitle: XhsMeasureText = (value: string): number => context.measureText(value).width;
    const lines: string[] = XhsCardLayout.titleLines(card.title, measureTitle).slice(0, 8);
    for (let index: number = 0; index < lines.length; index++) {
      context.fillText(lines[index], 110, 380 + index * 104);
    }
  }

  private drawBody(context: OffscreenCanvasRenderingContext2D, card: XhsCard): void {
    context.fillStyle = '#3a352e'; this.bodyFont(context);
    for (const line of card.lines) context.fillText(line.text, XhsCardLayout.BODY_LEFT, line.y);
  }

  private drawFooter(context: OffscreenCanvasRenderingContext2D, page: number, total: number): void {
    context.fillStyle = '#8d8372';
    context.font = 'normal 500 26px sans-serif'; context.letterSpacing = '3px';
    const value: string = `${page} / ${total}`;
    const width: number = context.measureText(value).width;
    context.fillText(value, (XhsCardLayout.WIDTH - width) / 2, XhsCardLayout.HEIGHT - 84);
  }

  private bodyFont(context: OffscreenCanvasRenderingContext2D): void {
    context.font = 'normal 400 42px sans-serif'; context.letterSpacing = '0.5px';
  }

  private async saveToAlbum(fileUris: string[]): Promise<string[]> {
    if (fileUris.length === 0) return [];
    const configs: photoAccessHelper.PhotoCreationConfig[] = fileUris.map(
      (_uri: string, index: number): photoAccessHelper.PhotoCreationConfig => ({
        title: `VoiceDrop-小红书-${index + 1}`,
        fileNameExtension: 'jpg',
        photoType: photoAccessHelper.PhotoType.IMAGE
      }));
    try {
      return await photoAccessHelper.getPhotoAccessHelper(this.context)
        .showAssetsCreationDialog(fileUris, configs);
    } catch (_) { return []; }
  }

  private fileName(index: number): string {
    return `VoiceDrop-XHS-${(index + 1).toString().padStart(2, '0')}.jpg`;
  }

  private write(path: string, data: ArrayBuffer): void {
    const output: fs.File = fs.openSync(path,
      fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try { fs.writeSync(output.fd, data); } finally { fs.closeSync(output); }
  }
}
