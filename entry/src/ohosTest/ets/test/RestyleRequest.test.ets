import { describe, expect, it } from '@ohos/hypium';
import { RestyleRequest } from '../../../main/ets/core/RestyleRequest';
import { Api } from '../../../main/ets/core/Api';

export default function restyleRequestTest() {
  describe('RestyleRequest', () => {
    it('encodesTheSameExplicitJsonContractAsAndroid', 0, () => {
      expect(RestyleRequest.body('VoiceDrop-2026-07-30-120000', 3))
        .assertEqual('{"stem":"VoiceDrop-2026-07-30-120000","styleV":3}');
      expect(RestyleRequest.body('VoiceDrop-2026-07-30-120000'))
        .assertEqual('{"stem":"VoiceDrop-2026-07-30-120000"}');
    });

    it('bypassesTheShortLivedProxyForLongRunningRewrites', 0, () => {
      expect(Api.restyleUrl()).assertEqual('https://jianshuo.dev/agent/restyle');
    });

    it('requiresBothHttpAndBusinessSuccess', 0, () => {
      expect(RestyleRequest.result(200, '{"ok":true,"head":4}').ok).assertTrue();
      expect(RestyleRequest.result(422, '{"ok":false,"reason":"no-style"}').ok).assertFalse();
      expect(RestyleRequest.result(200, '{"ok":false,"reason":"no-article"}').ok).assertFalse();
    });

    it('turnsServerReasonsIntoUsefulMessages', 0, () => {
      expect(RestyleRequest.result(422, '{"ok":false,"reason":"no-style"}').message())
        .assertEqual('所选文风不可用，请重新选择');
      expect(RestyleRequest.result(422, '{"ok":false,"reason":"no-transcript"}').message())
        .assertEqual('当前文章没有可重写的内容');
      expect(RestyleRequest.result(504, '<html>Gateway Timeout</html>').message())
        .assertEqual('重写服务暂时不可用（HTTP 504），请稍后重试');
    });
  });
}
