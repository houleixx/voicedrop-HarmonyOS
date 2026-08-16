import { describe, expect, it } from '@ohos/hypium';
import { CacheMaintenance } from '../../../main/ets/core/CacheMaintenance';
import { RemixIconGlyph } from '../../../main/ets/ui/RemixIcon';

export default function cacheMaintenanceTest() {
  describe('CacheMaintenance', () => {
    it('limitsCleanupToReloadableArticlePhotoAndCommunityDetailDirectories', 0, () => {
      expect(JSON.stringify(CacheMaintenance.DIRECTORY_NAMES)).assertEqual(
        JSON.stringify(['article-doc-cache-v1', 'photo-cache', 'community-post-cache-v1']));
      expect(JSON.stringify(CacheMaintenance.roots('/data/cache/'))).assertEqual(JSON.stringify([
        '/data/cache/article-doc-cache-v1',
        '/data/cache/photo-cache',
        '/data/cache/community-post-cache-v1'
      ]));
    });

    it('formatsCacheSizesForSettings', 0, () => {
      expect(CacheMaintenance.formatBytes(0)).assertEqual('0 B');
      expect(CacheMaintenance.formatBytes(512)).assertEqual('512 B');
      expect(CacheMaintenance.formatBytes(1536)).assertEqual('1.5 KB');
      expect(CacheMaintenance.formatBytes(12 * 1024 * 1024)).assertEqual('12.0 MB');
      expect(CacheMaintenance.formatBytes(-1)).assertEqual('0 B');
    });

    it('rejectsStaleOrDestroyedPageResults', 0, () => {
      expect(CacheMaintenance.shouldApplyResult(3, 3, true)).assertTrue();
      expect(CacheMaintenance.shouldApplyResult(2, 3, true)).assertFalse();
      expect(CacheMaintenance.shouldApplyResult(3, 3, false)).assertFalse();
    });

    it('usesRemix250DeleteBinLineGlyph', 0, () => {
      expect(RemixIconGlyph.DELETE_BIN_LINE).assertEqual('\uEC2A');
      expect(RemixIconGlyph.DELETE).assertEqual('\uEC26');
    });
  });
}
