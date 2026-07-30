import { image } from '@kit.ImageKit';

export class PhotoJpeg {
  static async transcode(bytes: ArrayBuffer): Promise<ArrayBuffer> {
    const source: image.ImageSource = image.createImageSource(bytes);
    const packer: image.ImagePacker = image.createImagePacker();
    let decoded: image.PixelMap | undefined;
    let flattened: image.PixelMap | undefined;
    try {
      const sourceInfo: image.ImageInfo = await source.getImageInfo();
      if (sourceInfo.alphaType !== image.AlphaType.OPAQUE) {
        decoded = await source.createPixelMap({
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888
        });
        const decodedInfo: image.ImageInfo = await decoded.getImageInfo();
        const rgba: ArrayBuffer = new ArrayBuffer(decoded.getPixelBytesNumber());
        await decoded.readPixelsToBuffer(rgba);
        const opaqueRgba: ArrayBuffer = PhotoJpeg.flattenOnWhite(
          rgba,
          decodedInfo.size.width,
          decodedInfo.size.height,
          decoded.getBytesNumberPerRow(),
          decodedInfo.alphaType === image.AlphaType.PREMUL
        );
        flattened = await image.createPixelMap(opaqueRgba, {
          size: decodedInfo.size,
          srcPixelFormat: image.PixelMapFormat.RGBA_8888,
          pixelFormat: image.PixelMapFormat.RGBA_8888,
          alphaType: image.AlphaType.OPAQUE,
          editable: false
        });
        return await packer.packToData(flattened, {
          format: 'image/jpeg',
          quality: 86,
          bufferSize: 10 * 1024 * 1024
        });
      }
      return await packer.packToData(source, {
        format: 'image/jpeg',
        quality: 86,
        bufferSize: 10 * 1024 * 1024
      });
    } finally {
      if (flattened) try { await flattened.release(); } catch (_) {}
      if (decoded) try { await decoded.release(); } catch (_) {}
      try { await source.release(); } catch (_) {}
      try { await packer.release(); } catch (_) {}
    }
  }

  static flattenOnWhite(
    rgba: ArrayBuffer,
    width: number,
    height: number,
    bytesPerRow: number,
    premultiplied: boolean
  ): ArrayBuffer {
    const source: Uint8Array = new Uint8Array(rgba);
    const output: Uint8Array = new Uint8Array(width * height * 4);
    for (let y: number = 0; y < height; y++) {
      for (let x: number = 0; x < width; x++) {
        const sourceIndex: number = y * bytesPerRow + x * 4;
        const outputIndex: number = (y * width + x) * 4;
        const alpha: number = source[sourceIndex + 3];
        output[outputIndex] = PhotoJpeg.compositeOnWhite(source[sourceIndex], alpha, premultiplied);
        output[outputIndex + 1] = PhotoJpeg.compositeOnWhite(source[sourceIndex + 1], alpha, premultiplied);
        output[outputIndex + 2] = PhotoJpeg.compositeOnWhite(source[sourceIndex + 2], alpha, premultiplied);
        output[outputIndex + 3] = 255;
      }
    }
    return output.buffer;
  }

  private static compositeOnWhite(channel: number, alpha: number, premultiplied: boolean): number {
    if (alpha >= 255) return channel;
    if (alpha <= 0) return 255;
    if (premultiplied) return Math.min(255, channel + 255 - alpha);
    return Math.round((channel * alpha + 255 * (255 - alpha)) / 255);
  }
}
