export class ClientReliability {
  static readonly HEARTBEAT_MS: number = 25000;

  static isEditTerminal(type: string, snapshotResolved: boolean): boolean {
    return type === 'updated' || type === 'error' || (type === 'snapshot' && snapshotResolved);
  }

  static commandMessageRequiresRefresh(type: string): boolean {
    return type === 'updated' || type === 'snapshot';
  }

  static isLongLivedSocketPath(path: string): boolean {
    return path === '/status' || path === '/command' || path.startsWith('/edit?');
  }

  static shouldStartConnection(connected: boolean, connecting: boolean): boolean {
    return !connected && !connecting;
  }

  static isCurrentGeneration(activeGeneration: number, callbackGeneration: number): boolean {
    return activeGeneration === callbackGeneration;
  }

  static accountIdentityChanged(previousBearer: string, currentBearer: string): boolean {
    return previousBearer !== currentBearer;
  }

  static errorMessage(error: Object): string {
    const typedError: Error = error as Error;
    const message: string = String(typedError.message ?? '').trim();
    if (message.length > 0 && message !== '[object Object]') return message;
    const fallback: string = String(error).trim();
    if (fallback.length > 0 && fallback !== '[object Object]' && fallback !== 'Error') return fallback;
    return '网络请求失败，请稍后重试';
  }

  static libraryErrorText(error: Object, hasCachedRows: boolean, showFailure: boolean): string {
    if (hasCachedRows && !showFailure) return '';
    return `暂时无法加载录音：${ClientReliability.errorMessage(error)}`;
  }

  static shouldRetryDirectApi(method: string, url: string, responseCode: number,
    transportFailed: boolean): boolean {
    if (!url.startsWith('https://voicedrop.cn/')) return false;
    if (method !== 'GET' && method !== 'PUT') return false;
    return transportFailed || responseCode === 502 || responseCode === 503 || responseCode === 504 ||
      (responseCode >= 521 && responseCode <= 524);
  }

  static promptCacheKey(identity: string): string {
    return `promptsCache.v1.${ClientReliability.cacheHash(identity)}`;
  }

  static homeSnapshotCacheKey(kind: string, identity: string): string {
    return `${kind}.v1.${ClientReliability.cacheHash(identity)}`;
  }

  static cacheHash(identity: string): string {
    let hash: number = 2166136261;
    for (let index: number = 0; index < identity.length; index++) {
      hash ^= identity.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(16).padStart(8, '0');
  }

  static articleDocCacheKey(identity: string, stem: string): string {
    return `articleDocCache.v1.${ClientReliability.cacheHash(identity)}.${ClientReliability.cacheHash(stem)}`;
  }

  static photoCacheKey(fullKey: string): string {
    return `photoCache.v1.${ClientReliability.cacheHash(fullKey)}.jpg`;
  }

  static photoCacheInvalidations(previous: string[], next: string[], refresh: string[] = []): string[] {
    const nextKeys: Set<string> = new Set<string>(next);
    const invalid: Set<string> = new Set<string>(refresh);
    for (const key of previous) if (!nextKeys.has(key)) invalid.add(key);
    const values: string[] = [];
    invalid.forEach((key: string) => values.push(key));
    return values;
  }

}
