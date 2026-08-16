export class CacheMaintenance {
  static readonly DIRECTORY_NAMES: string[] = [
    'article-doc-cache-v1',
    'photo-cache',
    'community-post-cache-v1'
  ];

  static roots(cacheDir: string): string[] {
    const base: string = cacheDir.replace(/\/+$/, '');
    return CacheMaintenance.DIRECTORY_NAMES.map((name: string) => `${base}/${name}`);
  }

  static formatBytes(bytes: number): string {
    const safe: number = Math.max(0, Number.isFinite(bytes) ? bytes : 0);
    if (safe < 1024) return `${Math.round(safe)} B`;
    const units: string[] = ['KB', 'MB', 'GB'];
    let value: number = safe / 1024;
    let unitIndex: number = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    const digits: number = value >= 100 ? 0 : 1;
    return `${value.toFixed(digits)} ${units[unitIndex]}`;
  }

  static shouldApplyResult(requestId: number, latestRequestId: number, active: boolean): boolean {
    return active && requestId === latestRequestId;
  }
}
