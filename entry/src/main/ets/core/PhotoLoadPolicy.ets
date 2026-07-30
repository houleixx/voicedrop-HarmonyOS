export type PhotoLoadIntent = 'original' | 'generated' | 'pending' | 'generatedPending';
export type PhotoFailureState = 'loadFailed' | 'making';
export type GeneratedPhotoState = 'loading' | 'making' | 'failed';

export class PhotoLoadPolicy {
  static readonly MAKING_GRACE_MS: number = 900;
  static readonly POLL_INTERVAL_MS: number = 3000;
  static readonly POLL_TIMEOUT_MS: number = 300000;

  static failureState(intent: PhotoLoadIntent): PhotoFailureState {
    return intent === 'original' ? 'loadFailed' : 'making';
  }

  static shouldPoll(intent: PhotoLoadIntent): boolean {
    return PhotoLoadPolicy.failureState(intent) === 'making';
  }

  static shouldLoad(intent: PhotoLoadIntent): boolean {
    return intent !== 'pending';
  }

  static startsMaking(intent: PhotoLoadIntent): boolean {
    return intent === 'pending' || intent === 'generatedPending';
  }

  static generatedState(elapsedMs: number): GeneratedPhotoState {
    if (elapsedMs >= PhotoLoadPolicy.POLL_TIMEOUT_MS) return 'failed';
    return elapsedMs >= PhotoLoadPolicy.MAKING_GRACE_MS ? 'making' : 'loading';
  }

  static generatedRetryDelay(elapsedMs: number): number {
    return Math.max(0, Math.min(
      PhotoLoadPolicy.POLL_INTERVAL_MS,
      PhotoLoadPolicy.POLL_TIMEOUT_MS - elapsedMs
    ));
  }

  static introducedKeys(previous: string[], updated: string[]): string[] {
    const known: Set<string> = new Set<string>(previous);
    return updated.filter((key: string) => key.length > 0 && !known.has(key));
  }
}
