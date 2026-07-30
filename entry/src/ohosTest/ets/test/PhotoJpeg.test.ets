import { image } from '@kit.ImageKit';
import { describe, expect, it } from '@ohos/hypium';
import { PhotoJpeg } from '../../../main/ets/core/PhotoJpeg';

export default function photoJpegTest() {
  describe('PhotoJpeg', () => {
    it('compositesStraightAndPremultipliedAlphaOnWhite', 0, () => {
      const straightBuffer: ArrayBuffer = new ArrayBuffer(8);
      const straight: Uint8Array = new Uint8Array(straightBuffer);
      straight[0] = 0; straight[1] = 0; straight[2] = 0; straight[3] = 0;
      straight[4] = 255; straight[5] = 0; straight[6] = 0; straight[7] = 128;
      const straightResult: Uint8Array = new Uint8Array(
        PhotoJpeg.flattenOnWhite(straightBuffer, 2, 1, 8, false));
      expect(straightResult[0]).assertEqual(255);
      expect(straightResult[1]).assertEqual(255);
      expect(straightResult[2]).assertEqual(255);
      expect(straightResult[4]).assertEqual(255);
      expect(straightResult[5]).assertEqual(127);
      expect(straightResult[6]).assertEqual(127);
      expect(straightResult[7]).assertEqual(255);

      const premultipliedBuffer: ArrayBuffer = new ArrayBuffer(4);
      const premultiplied: Uint8Array = new Uint8Array(premultipliedBuffer);
      premultiplied[0] = 128; premultiplied[1] = 0;
      premultiplied[2] = 0; premultiplied[3] = 128;
      const premultipliedResult: Uint8Array = new Uint8Array(
        PhotoJpeg.flattenOnWhite(premultipliedBuffer, 1, 1, 4, true));
      expect(premultipliedResult[0]).assertEqual(255);
      expect(premultipliedResult[1]).assertEqual(127);
      expect(premultipliedResult[2]).assertEqual(127);
      expect(premultipliedResult[3]).assertEqual(255);
    });

    it('usesWhiteForTransparentPngPixels', 0, async () => {
      const width: number = 8;
      const height: number = 8;
      const inputBuffer: ArrayBuffer = new ArrayBuffer(width * height * 4);
      const input: Uint8Array = new Uint8Array(inputBuffer);
      for (let y: number = 0; y < height; y++) {
        for (let x: number = 0; x < width; x++) {
          const index: number = (y * width + x) * 4;
          if (x < width / 2) {
            input[index] = 0; input[index + 1] = 0; input[index + 2] = 0; input[index + 3] = 0;
          } else {
            input[index] = 255; input[index + 1] = 0; input[index + 2] = 0; input[index + 3] = 255;
          }
        }
      }

      const pixelMap: image.PixelMap = await image.createPixelMap(inputBuffer, {
        size: { width: width, height: height },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        alphaType: image.AlphaType.UNPREMUL,
        editable: false
      });
      const pngPacker: image.ImagePacker = image.createImagePacker();
      let png: ArrayBuffer;
      try {
        png = await pngPacker.packToData(pixelMap, {
          format: 'image/png', quality: 100, bufferSize: 1024 * 1024
        });
      } finally {
        try { await pixelMap.release(); } catch (_) {}
        try { await pngPacker.release(); } catch (_) {}
      }

      const jpeg: ArrayBuffer = await PhotoJpeg.transcode(png);
      const jpegSource: image.ImageSource = image.createImageSource(jpeg);
      const decoded: image.PixelMap = await jpegSource.createPixelMap({
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const output: ArrayBuffer = new ArrayBuffer(decoded.getPixelBytesNumber());
      try {
        await decoded.readPixelsToBuffer(output);
      } finally {
        try { await decoded.release(); } catch (_) {}
        try { await jpegSource.release(); } catch (_) {}
      }
      const pixel: Uint8Array = new Uint8Array(output);
      expect(pixel[0] > 220).assertTrue();
      expect(pixel[1] > 220).assertTrue();
      expect(pixel[2] > 220).assertTrue();
    });
  });
}
