import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { Api } from '../core/Api';
import { RecordingName } from '../core/RecordingName';
import { authStore } from './AuthStore';
import { httpClient } from '../net/HttpClient';
import { appPreferences } from './AppPreferences';
import { common } from '@kit.AbilityKit';

export interface UploadedPhoto {
  key: string;
  sourceUri: string;
}

export class CapturedPhoto {
  key: string;
  localPath: string;
  sourceUri: string;
  constructor(key: string, localPath: string, sourceUri: string) {
    this.key = key; this.localPath = localPath; this.sourceUri = sourceUri;
  }
}

interface PendingPhotoValue { key: string; localPath: string; sourceUri?: string; }

export class PhotoService {
  private context?: common.Context;

  initialize(context: common.Context): void { this.context = context; }

  async pickForRecording(sessionTimestamp: string, elapsedSeconds: number, maximum: number = 9): Promise<CapturedPhoto[]> {
    if (!this.context || !sessionTimestamp) throw new Error('录音照片服务尚未初始化');
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = maximum; options.isPhotoTakingSupported = true; options.isOriginalSupported = true;
    const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
    const added: CapturedPhoto[] = [];
    for (const uri of result.photoUris) {
      const input: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      try {
        const bytes: ArrayBuffer = new ArrayBuffer(fs.statSync(input.fd).size); fs.readSync(input.fd, bytes);
        const jpeg: ArrayBuffer = await this.asJpeg(bytes);
        const random: string = util.generateRandomUUID(true).replace(/-/g, '').substring(0, 3).toLowerCase();
        const key: string = `photos/${sessionTimestamp}/${elapsedSeconds}-${random}.jpg`;
        const localPath: string = `${this.context.filesDir}/pending-photo-${random}.jpg`;
        const output: fs.File = fs.openSync(localPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        try { fs.writeSync(output.fd, jpeg); } finally { fs.closeSync(output); }
        const photo: CapturedPhoto = new CapturedPhoto(key, localPath, uri); added.push(photo);
      } finally { fs.closeSync(input); }
    }
    const queue: CapturedPhoto[] = this.pending(); queue.push(...added); await this.persist(queue);
    return added;
  }

  async removeCaptured(photo: CapturedPhoto): Promise<void> {
    try { fs.unlinkSync(photo.localPath); } catch (_) {}
    await this.persist(this.pending().filter((value: CapturedPhoto) => value.key !== photo.key));
  }

  async discardCaptured(photos: CapturedPhoto[]): Promise<void> {
    const keys: Set<string> = new Set<string>();
    photos.forEach((photo: CapturedPhoto) => {
      keys.add(photo.key); try { fs.unlinkSync(photo.localPath); } catch (_) {}
    });
    await this.persist(this.pending().filter((value: CapturedPhoto) => !keys.has(value.key)));
  }

  async uploadCaptured(photos: CapturedPhoto[]): Promise<number> {
    let uploaded: number = 0;
    for (const photo of photos) {
      try {
        const file: fs.File = fs.openSync(photo.localPath, fs.OpenMode.READ_ONLY);
        try {
          const bytes: ArrayBuffer = new ArrayBuffer(fs.statSync(file.fd).size); fs.readSync(file.fd, bytes);
          const response = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(photo.key)}`,
            authStore.bearer(), bytes, 'image/jpeg');
          if (!response.ok()) continue;
        } finally { fs.closeSync(file); }
        uploaded++; await this.removeCaptured(photo);
      } catch (_) {}
    }
    return uploaded;
  }

  async retryPending(): Promise<number> { return this.uploadCaptured(this.pending()); }

  private pending(): CapturedPhoto[] {
    try {
      return (JSON.parse(appPreferences.pendingPhotos()) as PendingPhotoValue[])
        .map((value: PendingPhotoValue) => new CapturedPhoto(value.key, value.localPath, value.sourceUri ?? ''));
    } catch (_) { return []; }
  }

  private async persist(values: CapturedPhoto[]): Promise<void> {
    await appPreferences.savePendingPhotos(JSON.stringify(values));
  }

  async pickAndUpload(recordingName: string, maximum: number = 9): Promise<UploadedPhoto[]> {
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = maximum;
    options.isPhotoTakingSupported = true;
    options.isOriginalSupported = true;
    const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
    const uploaded: UploadedPhoto[] = [];
    let offset: number = 0;
    for (const uri of result.photoUris) {
      const key: string = await this.uploadUri(uri, recordingName, offset++);
      if (key.length > 0) uploaded.push({ key: key, sourceUri: uri });
    }
    return uploaded;
  }

  async uploadUri(uri: string, recordingName: string, offset: number): Promise<string> {
    const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const size: number = fs.statSync(file.fd).size;
      const bytes: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, bytes);
      const parsed = RecordingName.parse(recordingName);
      const session: string = parsed?.sessionTs ?? `${Date.now()}`;
      const random: string = util.generateRandomUUID(true).replace(/-/g, '').substring(0, 3).toLowerCase();
      const key: string = `photos/${session}/${offset}-${random}.jpg`;
      const jpeg: ArrayBuffer = await this.asJpeg(bytes);
      const response = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(key)}`,
        authStore.bearer(), jpeg, 'image/jpeg');
      return response.ok() ? key : '';
    } finally {
      fs.closeSync(file);
    }
  }


  async uploadBytes(bytes: ArrayBuffer, recordingName: string, offset: number): Promise<string> {
    const parsed = RecordingName.parse(recordingName);
    const session: string = parsed?.sessionTs ?? `${Date.now()}`;
    const random: string = util.generateRandomUUID(true).replace(/-/g, '').substring(0, 3).toLowerCase();
    const key: string = `photos/${session}/${offset}-${random}.jpg`;
    const jpeg: ArrayBuffer = await this.asJpeg(bytes);
    const response = await httpClient.putBytes(`${Api.FILES}/upload/${Api.path(key)}`,
      authStore.bearer(), jpeg, 'image/jpeg');
    return response.ok() ? key : '';
  }

  private async asJpeg(bytes: ArrayBuffer): Promise<ArrayBuffer> {
    const source: image.ImageSource = image.createImageSource(bytes);
    const packer: image.ImagePacker = image.createImagePacker();
    try { return await packer.packToData(source, { format: 'image/jpeg', quality: 86, bufferSize: 10 * 1024 * 1024 }); }
    finally {
      try { await source.release(); } catch (_) {}
      try { await packer.release(); } catch (_) {}
    }
  }
}

export const photoService: PhotoService = new PhotoService();
