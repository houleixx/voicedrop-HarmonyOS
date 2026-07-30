/**
 * Keep audio captured before the ASR socket is ready in capture order.
 *
 * The final, zero-length frame goes through the same queue so an early release
 * cannot overtake either the touch-down pre-roll or the release tail.
 */

// HarmonyOS devices can retain more input latency than Android's AudioRecord
// path. Keep enough post-release audio/silence for the final phoneme to leave
// the system capture buffer and for streaming ASR to close the last word.
export const HOLD_TO_TALK_TAIL_CAPTURE_MS: number = 600;

export class PendingAudioFrame {
  data: ArrayBuffer;
  isLast: boolean;

  constructor(data: ArrayBuffer, isLast: boolean) {
    this.data = data;
    this.isLast = isLast;
  }
}

export class PendingAudioFrames {
  private frames: PendingAudioFrame[] = [];

  offer(data: ArrayBuffer, isLast: boolean): void {
    const source: Uint8Array = new Uint8Array(data);
    const copyBuffer: ArrayBuffer = new ArrayBuffer(source.byteLength);
    const copy: Uint8Array = new Uint8Array(copyBuffer);
    copy.set(source);
    this.frames.push(new PendingAudioFrame(copyBuffer, isLast));
  }

  take(): PendingAudioFrame | undefined {
    return this.frames.shift();
  }

  clear(): void {
    this.frames = [];
  }

  length(): number {
    return this.frames.length;
  }
}
