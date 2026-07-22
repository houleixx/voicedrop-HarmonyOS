import { bundleManager } from '@kit.AbilityKit';
import { httpClient, HttpResponse } from '../net/HttpClient';

interface ReleaseAssetWire {
  name?: string;
  browser_download_url?: string;
  size?: number;
}

interface ReleaseWire {
  tag_name?: string;
  html_url?: string;
  body?: string;
  draft?: boolean;
  prerelease?: boolean;
  assets?: ReleaseAssetWire[];
}

export class HarmonyRelease {
  tag: string;
  pageUrl: string;
  downloadUrl: string;
  notes: string;
  size: number;
  constructor(tag: string, pageUrl: string, downloadUrl: string, notes: string, size: number) {
    this.tag = tag; this.pageUrl = pageUrl; this.downloadUrl = downloadUrl; this.notes = notes; this.size = size;
  }
}

export class UpdateCheckResult {
  status: string;
  currentVersion: string;
  release?: HarmonyRelease;
  constructor(status: string, currentVersion: string, release?: HarmonyRelease) {
    this.status = status; this.currentVersion = currentVersion; this.release = release;
  }
}

export class AppUpdateService {
  static readonly RELEASE_API: string = 'https://api.github.com/repos/houleixx/voicedrop-HarmonyOS/releases/latest';

  async currentVersion(): Promise<string> {
    try {
      const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return info.versionName || '0.1.0';
    } catch (_) { return '0.1.0'; }
  }

  async check(): Promise<UpdateCheckResult> {
    const current: string = await this.currentVersion();
    let response: HttpResponse;
    try { response = await httpClient.get(AppUpdateService.RELEASE_API); }
    catch (_) { return new UpdateCheckResult('failed', current); }
    if (response.code === 404) return new UpdateCheckResult('unavailable', current);
    if (response.code === 403 || response.code === 429) return new UpdateCheckResult('rate_limited', current);
    if (!response.ok()) return new UpdateCheckResult('failed', current);
    try {
      const wire: ReleaseWire = JSON.parse(response.text) as ReleaseWire;
      if (wire.draft || wire.prerelease) return new UpdateCheckResult('no_update', current);
      const asset: ReleaseAssetWire | undefined = (wire.assets ?? []).find((item: ReleaseAssetWire) => {
        const name: string = (item.name ?? '').toLowerCase();
        return name.endsWith('.hap') && !name.includes('unsigned');
      });
      if (!asset?.browser_download_url || !wire.tag_name) return new UpdateCheckResult('unavailable', current);
      if (!this.isNewer(wire.tag_name, current)) return new UpdateCheckResult('no_update', current);
      return new UpdateCheckResult('available', current, new HarmonyRelease(wire.tag_name,
        wire.html_url ?? asset.browser_download_url, asset.browser_download_url, wire.body ?? '', asset.size ?? 0));
    } catch (_) { return new UpdateCheckResult('failed', current); }
  }

  isNewer(candidate: string, current: string): boolean { return this.compare(candidate, current) > 0; }

  compare(left: string, right: string): number {
    const a: string = left.trim().replace(/^[vV]/, '');
    const b: string = right.trim().replace(/^[vV]/, '');
    const aCore: string = (a.match(/^\d+(?:\.\d+)*/) ?? [''])[0];
    const bCore: string = (b.match(/^\d+(?:\.\d+)*/) ?? [''])[0];
    const aa: number[] = aCore.split('.').map((part: string) => Number(part) || 0);
    const bb: number[] = bCore.split('.').map((part: string) => Number(part) || 0);
    const count: number = Math.max(aa.length, bb.length);
    for (let index: number = 0; index < count; index++) {
      const av: number = aa[index] ?? 0; const bv: number = bb[index] ?? 0;
      if (av !== bv) return av < bv ? -1 : 1;
    }
    const aPreview: boolean = /(alpha|beta|rc|ci|test)/i.test(a.substring(aCore.length));
    const bPreview: boolean = /(alpha|beta|rc|ci|test)/i.test(b.substring(bCore.length));
    if (aPreview !== bPreview) return aPreview ? -1 : 1;
    return 0;
  }
}

export const appUpdateService: AppUpdateService = new AppUpdateService();
