import { describe, expect, it } from '@ohos/hypium';
import {
  HOLD_TO_TALK_TAIL_CAPTURE_MS,
  PendingAudioFrame,
  PendingAudioFrames
} from '../../../main/ets/core/PendingAudioFrames';

export default function pendingAudioFramesTest() {
  describe('PendingAudioFrames', () => {
    it('keepsPrerollTailAndFinalFrameInCaptureOrder', 0, () => {
      const frames: PendingAudioFrames = new PendingAudioFrames();
      const prerollBuffer: ArrayBuffer = new ArrayBuffer(2);
      new Uint8Array(prerollBuffer).set([1, 2]);
      const tailBuffer: ArrayBuffer = new ArrayBuffer(2);
      new Uint8Array(tailBuffer).set([3, 4]);
      frames.offer(prerollBuffer, false);
      frames.offer(tailBuffer, false);
      frames.offer(new ArrayBuffer(0), true);

      const preroll: PendingAudioFrame | undefined = frames.take();
      const tail: PendingAudioFrame | undefined = frames.take();
      const finalFrame: PendingAudioFrame | undefined = frames.take();
      expect(new Uint8Array(preroll?.data ?? new ArrayBuffer(0))[0]).assertEqual(1);
      expect(preroll?.isLast ?? true).assertFalse();
      expect(new Uint8Array(tail?.data ?? new ArrayBuffer(0))[0]).assertEqual(3);
      expect(tail?.isLast ?? true).assertFalse();
      expect(finalFrame?.data.byteLength ?? -1).assertEqual(0);
      expect(finalFrame?.isLast ?? false).assertTrue();
      expect(frames.take() === undefined).assertTrue();
    });

    it('retainsEnoughTailAudioForHarmonyCaptureLatency', 0, () => {
      expect(HOLD_TO_TALK_TAIL_CAPTURE_MS >= 600).assertTrue();
    });

    it('acceptsTailWhileAnEarlierFrameIsBeingSent', 0, () => {
      const frames: PendingAudioFrames = new PendingAudioFrames();
      const firstBuffer: ArrayBuffer = new ArrayBuffer(1);
      new Uint8Array(firstBuffer)[0] = 1;
      const tailBuffer: ArrayBuffer = new ArrayBuffer(1);
      new Uint8Array(tailBuffer)[0] = 2;

      frames.offer(firstBuffer, false);
      const sending: PendingAudioFrame | undefined = frames.take();
      frames.offer(tailBuffer, false);
      frames.offer(new ArrayBuffer(0), true);

      expect(new Uint8Array(sending?.data ?? new ArrayBuffer(0))[0]).assertEqual(1);
      expect(new Uint8Array(frames.take()?.data ?? new ArrayBuffer(0))[0]).assertEqual(2);
      expect(frames.take()?.isLast ?? false).assertTrue();
    });
  });
}
