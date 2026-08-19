import { describe, expect, it } from '@ohos/hypium';
import { Api } from '../../../main/ets/core/Api';
import { ApiRoutePolicy } from '../../../main/ets/core/ApiRoutePolicy';

export default function apiRoutePolicyTest() {
  describe('ApiRoutePolicy', () => {
    it('keepsTheIncumbentWhenBothProbesFail', 0, () => {
      expect(ApiRoutePolicy.pick(ApiRoutePolicy.CN_HOST)).assertEqual(ApiRoutePolicy.CN_HOST);
      expect(ApiRoutePolicy.pick(ApiRoutePolicy.CF_HOST)).assertEqual(ApiRoutePolicy.CF_HOST);
    });

    it('usesTheOnlyReachableRoute', 0, () => {
      expect(ApiRoutePolicy.pick(ApiRoutePolicy.CF_HOST, 800, undefined))
        .assertEqual(ApiRoutePolicy.CN_HOST);
      expect(ApiRoutePolicy.pick(ApiRoutePolicy.CN_HOST, undefined, 800))
        .assertEqual(ApiRoutePolicy.CF_HOST);
    });

    it('requiresTheChallengerToWinByMoreThan150Milliseconds', 0, () => {
      expect(ApiRoutePolicy.pick(ApiRoutePolicy.CN_HOST, 500, 400))
        .assertEqual(ApiRoutePolicy.CN_HOST);
      expect(ApiRoutePolicy.pick(ApiRoutePolicy.CN_HOST, 550, 400))
        .assertEqual(ApiRoutePolicy.CN_HOST);
      expect(ApiRoutePolicy.pick(ApiRoutePolicy.CN_HOST, 551, 400))
        .assertEqual(ApiRoutePolicy.CF_HOST);
      expect(ApiRoutePolicy.pick(ApiRoutePolicy.CF_HOST, 300, 900))
        .assertEqual(ApiRoutePolicy.CN_HOST);
    });

    it('mapsApiAndPublicWebRoutesWithoutChangingFixedContracts', 0, () => {
      expect(ApiRoutePolicy.publicWebBase(ApiRoutePolicy.CN_HOST))
        .assertEqual('https://voicedrop.cn');
      expect(ApiRoutePolicy.publicWebBase(ApiRoutePolicy.CF_HOST))
        .assertEqual('https://jianshuo.dev/voicedrop');
      expect(Api.AGENT_WS).assertEqual('wss://jianshuo.dev/agent');
      expect(Api.sharePage('share_1')).assertEqual('https://voicedrop.cn/share_1');
    });

    it('throttlesForegroundProbesAndRejectsStaleGenerations', 0, () => {
      const now: number = 10_000_000;
      expect(ApiRoutePolicy.shouldProbe(0, now)).assertTrue();
      expect(ApiRoutePolicy.shouldProbe(now - ApiRoutePolicy.PROBE_MAX_AGE_MS, now)).assertFalse();
      expect(ApiRoutePolicy.shouldProbe(now - ApiRoutePolicy.PROBE_MAX_AGE_MS - 1, now)).assertTrue();
      expect(ApiRoutePolicy.isCurrentGeneration(8, 8)).assertTrue();
      expect(ApiRoutePolicy.isCurrentGeneration(9, 8)).assertFalse();
    });
  });
}
