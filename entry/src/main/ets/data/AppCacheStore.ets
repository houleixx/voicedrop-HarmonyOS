import { common } from '@kit.AbilityKit';
import { taskpool } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { CacheMaintenance } from '../core/CacheMaintenance';
import { communityStore } from './CommunityStore';
import { libraryStore } from './LibraryStore';
import { photoService } from './PhotoService';

@Concurrent
function measureCacheRoots(roots: string[]): number {
  let total: number = 0;
  for (const root of roots) {
    try {
      for (const name of fs.listFileSync(root)) {
        try {
          const stat: fs.Stat = fs.statSync(`${root}/${name}`);
          if (stat.isFile()) total += Math.max(0, stat.size);
        } catch (_) {}
      }
    } catch (_) {}
  }
  return total;
}

export class AppCacheStore {
  private roots: string[] = [];

  initialize(context: common.Context): void {
    this.roots = CacheMaintenance.roots(context.cacheDir);
  }

  async sizeBytes(): Promise<number> {
    if (this.roots.length === 0) return 0;
    return Number(await taskpool.execute(measureCacheRoots, this.roots));
  }

  async clear(): Promise<void> {
    // Invalidate generations before deleting files so late network responses
    // cannot repopulate a cache that the user just cleared.
    libraryStore.clearArticleSnapshots();
    communityStore.clearPostSnapshots();
    // LibraryStore also clears photos; keep this explicit so the app-owned
    // in-flight image task map is cleared even if article storage was not ready.
    photoService.clearArticlePhotoCache();
  }
}

export const appCacheStore: AppCacheStore = new AppCacheStore();
