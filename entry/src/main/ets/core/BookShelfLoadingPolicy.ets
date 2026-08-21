export class BookShelfLoadingPolicy {
  static shouldShowExclusiveLoading(loading: boolean, cachedBookCount: number): boolean {
    return loading && cachedBookCount <= 0;
  }
}
