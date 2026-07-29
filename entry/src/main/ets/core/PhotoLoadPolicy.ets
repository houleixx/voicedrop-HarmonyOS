export type PhotoLoadIntent = 'original' | 'generated';
export type PhotoFailureState = 'loadFailed' | 'making';

export class PhotoLoadPolicy {
  static failureState(intent: PhotoLoadIntent): PhotoFailureState {
    return intent === 'generated' ? 'making' : 'loadFailed';
  }

  static shouldPoll(intent: PhotoLoadIntent): boolean {
    return PhotoLoadPolicy.failureState(intent) === 'making';
  }

  static introducedKeys(previous: string[], updated: string[]): string[] {
    const known: Set<string> = new Set<string>(previous);
    return updated.filter((key: string) => key.length > 0 && !known.has(key));
  }

  static processingKeys(active: string[], refresh: string[]): string[] {
    return Array.from(new Set<string>(active.concat(refresh).filter((key: string) => key.length > 0)));
  }
}
