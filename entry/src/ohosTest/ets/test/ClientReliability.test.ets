import { describe, expect, it } from '@ohos/hypium';
import { Api } from '../../../main/ets/core/Api';
import { ArticleBody } from '../../../main/ets/core/ArticleBody';
import { ClientReliability } from '../../../main/ets/core/ClientReliability';
import { PromptMarketFilter, PromptMarketFilters } from '../../../main/ets/core/PromptMarketFilter';

export default function clientReliabilityTest() {
  describe('ClientReliability', () => {
    it('usesTheDomesticDomainForHttpApisAndPhotosButKeepsVerifiedWebSocketHost', 0, () => {
      expect(Api.FILES).assertEqual('https://voicedrop.cn/files/api');
      expect(Api.AGENT).assertEqual('https://voicedrop.cn/agent');
      expect(Api.RECO).assertEqual('https://voicedrop.cn/reco');
      expect(Api.AGENT_WS).assertEqual('wss://jianshuo.dev/agent');
      expect(Api.directApiUrl(`${Api.FILES}/list`))
        .assertEqual('https://jianshuo.dev/files/api/list');
      expect(ArticleBody.photoUrl('users/a/photos/a b.jpg'))
        .assertEqual('https://voicedrop.cn/files/api/photo/users/a/photos/a%20b.jpg');
      expect(ArticleBody.photoThumbnailUrl('users/a/photos/a b.jpg'))
        .assertEqual('https://jianshuo.dev/cdn-cgi/image/width=512,quality=60/files/api/photo/users/a/photos/a%20b.jpg');
    });

    it('doesNotOverwriteAnAuthoritativeSocketArticleWithASecondRefresh', 0, () => {
      expect(ClientReliability.shouldRefreshResolvedArticle('updated', false, true)).assertFalse();
      expect(ClientReliability.shouldRefreshResolvedArticle('snapshot', true, true)).assertFalse();
      expect(ClientReliability.shouldRefreshResolvedArticle('updated', false, false)).assertTrue();
      expect(ClientReliability.shouldRefreshResolvedArticle('error', false, false)).assertTrue();
      expect(ClientReliability.shouldRefreshResolvedArticle('snapshot', true, false)).assertTrue();
      expect(ClientReliability.shouldRefreshResolvedArticle('snapshot', false, false)).assertFalse();
      expect(ClientReliability.shouldRefreshResolvedArticle('reply', false, false)).assertFalse();
    });

    it('refreshesTheLibraryForUpdatedAndSnapshotCommandMessages', 0, () => {
      expect(ClientReliability.commandMessageRequiresRefresh('updated')).assertTrue();
      expect(ClientReliability.commandMessageRequiresRefresh('snapshot')).assertTrue();
      expect(ClientReliability.commandMessageRequiresRefresh('reply')).assertFalse();
    });

    it('keepsSocketsAliveEvery25SecondsAndScopesPromptCachesByAccount', 0, () => {
      expect(ClientReliability.HEARTBEAT_MS).assertEqual(25000);
      expect(ClientReliability.isLongLivedSocketPath('/status')).assertTrue();
      expect(ClientReliability.isLongLivedSocketPath('/command')).assertTrue();
      expect(ClientReliability.isLongLivedSocketPath('/edit?stem=VoiceDrop-a')).assertTrue();
      expect(ClientReliability.isLongLivedSocketPath('/asr')).assertFalse();
      expect(ClientReliability.shouldStartConnection(false, false)).assertTrue();
      expect(ClientReliability.shouldStartConnection(false, true)).assertFalse();
      expect(ClientReliability.shouldStartConnection(true, false)).assertFalse();
      expect(ClientReliability.isCurrentGeneration(5, 5)).assertTrue();
      expect(ClientReliability.isCurrentGeneration(6, 5)).assertFalse();
      expect(ClientReliability.accountIdentityChanged('anon_old', 'anon_new')).assertTrue();
      expect(ClientReliability.accountIdentityChanged('anon_same', 'anon_same')).assertFalse();
      expect(ClientReliability.promptCacheKey('anon-first') !==
        ClientReliability.promptCacheKey('anon-second')).assertTrue();
      expect(ClientReliability.homeSnapshotCacheKey('libraryList', 'anon-first') !==
        ClientReliability.homeSnapshotCacheKey('libraryList', 'anon-second')).assertTrue();
      expect(ClientReliability.homeSnapshotCacheKey('libraryList', 'anon-first') !==
        ClientReliability.homeSnapshotCacheKey('communityFeed', 'anon-first')).assertTrue();
      expect(ClientReliability.articleDocCacheKey('anon-first', 'VoiceDrop-a') !==
        ClientReliability.articleDocCacheKey('anon-second', 'VoiceDrop-a')).assertTrue();
      expect(ClientReliability.articleDocCacheKey('anon-first', 'VoiceDrop-a') !==
        ClientReliability.articleDocCacheKey('anon-first', 'VoiceDrop-b')).assertTrue();
      expect(ClientReliability.communityPostCacheKey('anon-first', 'share-a') !==
        ClientReliability.communityPostCacheKey('anon-second', 'share-a')).assertTrue();
      expect(ClientReliability.communityPostCacheKey('anon-first', 'share-a') !==
        ClientReliability.communityPostCacheKey('anon-first', 'share-b')).assertTrue();
      expect(ClientReliability.photoCacheKey('users/a/photos/one.jpg') !==
        ClientReliability.photoCacheKey('users/a/photos/two.jpg')).assertTrue();
      expect(ClientReliability.photoCacheInvalidations(
        ['keep.jpg', 'deleted.jpg'], ['keep.jpg', 'added.jpg'], ['processed.jpg']).sort().join(','))
        .assertEqual('deleted.jpg,processed.jpg');
    });

    it('blocksDetailLoadingOnlyWhenNoCachedContentCanRender', 0, () => {
      expect(ClientReliability.shouldBlockDetailLoading(false)).assertTrue();
      expect(ClientReliability.shouldBlockDetailLoading(true)).assertFalse();
    });

    it('rejectsCacheResponsesFromOldAccountsClearsAndRequests', 0, () => {
      expect(ClientReliability.shouldApplyCacheResponse('account-a', 'account-a', 3, 3, 7, 7)).assertTrue();
      expect(ClientReliability.shouldApplyCacheResponse('account-a', 'account-b', 3, 3, 7, 7)).assertFalse();
      expect(ClientReliability.shouldApplyCacheResponse('account-a', 'account-a', 2, 3, 7, 7)).assertFalse();
      expect(ClientReliability.shouldApplyCacheResponse('account-a', 'account-a', 3, 3, 6, 7)).assertFalse();
    });

    it('formatsHarmonyBusinessErrorsAndHidesBackgroundRefreshFailuresWithCachedRows', 0, () => {
      const businessError: Error = new Error('Network unavailable');
      expect(ClientReliability.errorMessage(businessError)).assertEqual('Network unavailable');
      expect(ClientReliability.errorMessage(new Error(''))).assertEqual('网络请求失败，请稍后重试');
      expect(ClientReliability.libraryErrorText(businessError, true, false)).assertEqual('');
      expect(ClientReliability.libraryErrorText(businessError, false, false))
        .assertEqual('暂时无法加载录音：Network unavailable');
      expect(ClientReliability.libraryErrorText(businessError, true, true))
        .assertEqual('暂时无法加载录音：Network unavailable');
    });

    it('retriesOnlyIdempotentDomesticApiRequestsAgainstTheDirectBackend', 0, () => {
      expect(ClientReliability.shouldRetryDirectApi('GET', `${Api.FILES}/list`, 522, false)).assertTrue();
      expect(ClientReliability.shouldRetryDirectApi('PUT', `${Api.FILES}/upload/a.m4a`, 0, true)).assertTrue();
      expect(ClientReliability.shouldRetryDirectApi('POST', `${Api.FILES}/mine`, 522, false)).assertFalse();
      expect(ClientReliability.shouldRetryDirectApi('GET', 'https://jianshuo.dev/files/api/list', 522, false))
        .assertFalse();
      expect(ClientReliability.shouldRetryDirectApi('GET', `${Api.FILES}/list`, 401, false)).assertFalse();
    });

    it('mapsEveryCommunityPromptFilterToTheIosApiContract', 0, () => {
      const filters: PromptMarketFilter[] = PromptMarketFilters.all();
      expect(filters.map((filter: PromptMarketFilter) => filter.label).join(','))
        .assertEqual('热门,最新,文字,配图');
      expect(PromptMarketFilters.resolve('hot').sort).assertEqual('hot');
      expect(PromptMarketFilters.resolve('hot').scope).assertEqual('');
      expect(PromptMarketFilters.resolve('new').sort).assertEqual('new');
      expect(PromptMarketFilters.resolve('text').scope).assertEqual('text');
      expect(PromptMarketFilters.resolve('image').scope).assertEqual('image');
      expect(PromptMarketFilters.resolve('unknown').key).assertEqual('hot');
    });
  });
}
