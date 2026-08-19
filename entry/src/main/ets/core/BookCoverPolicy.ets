export class BookCoverPolicy {
  private static readonly RETRY_DELAYS: number[] = [0, 2000, 4000, 8000];

  static cacheKey(slug: string, coverAt: number): string {
    const identity: string = `${slug}\n${Math.max(0, coverAt)}`;
    let hash: number = 2166136261;
    for (let index: number = 0; index < identity.length; index++) {
      hash ^= identity.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return `bookCover.v1.${(hash >>> 0).toString(16).padStart(8, '0')}.jpg`;
  }

  static retryDelays(): number[] {
    return BookCoverPolicy.RETRY_DELAYS.slice();
  }

  static shouldBypassNetworkCache(attempt: number): boolean {
    return attempt >= 2;
  }

  static shouldApplyResult(active: boolean, requestGeneration: number, currentGeneration: number): boolean {
    return active && requestGeneration === currentGeneration;
  }

  static hasJpegSignature(data: ArrayBuffer): boolean {
    if (data.byteLength < 4) return false;
    const bytes: Uint8Array = new Uint8Array(data);
    return bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF;
  }

  static shouldRecoverDisplayFailure(recoveryUsed: boolean): boolean {
    return !recoveryUsed;
  }
}
