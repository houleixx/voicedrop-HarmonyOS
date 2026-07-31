import { describe, expect, it } from '@ohos/hypium';
import { WechatAuthResponse } from '../../../main/ets/core/WechatAuthResponse';

export default function wechatAuthResponseTest() {
  describe('WechatAuthResponse', () => {
    it('acceptsTheBackendSessionAndScopeContract', 0, () => {
      const parsed = WechatAuthResponse.parse(200,
        '{"session":"abcdefgh.ijklmnop.qrstuvwx","scope":"users/anon-example/"}');
      expect(parsed.ok).assertTrue();
      expect(parsed.session).assertEqual('abcdefgh.ijklmnop.qrstuvwx');
      expect(parsed.scope).assertEqual('users/anon-example/');
    });

    it('rejectsMalformedSessionsScopesAndJson', 0, () => {
      expect(WechatAuthResponse.parse(200,
        '{"session":"not-a-jwt","scope":"users/anon-example/"}').ok).assertFalse();
      expect(WechatAuthResponse.parse(200,
        '{"session":"abcdefgh.ijklmnop.qrstuvwx","scope":"../other"}').ok).assertFalse();
      expect(WechatAuthResponse.parse(200, 'not json').error).assertEqual('bad_session');
    });

    it('onlyRequiresConfirmationWhenWechatBelongsToAnotherSpace', 0, () => {
      expect(WechatAuthResponse.requiresAccountSwitch(
        'users/anon-current/', 'anon-current')).assertFalse();
      expect(WechatAuthResponse.requiresAccountSwitch(
        'users/wechat-existing/', 'anon-current')).assertTrue();
      expect(WechatAuthResponse.requiresAccountSwitch(
        'invalid-scope', 'anon-current')).assertFalse();
      expect(WechatAuthResponse.requiresAccountSwitch(
        'users/wechat-existing/', '')).assertFalse();
    });

    it('preservesBackendErrorsAndPresentsActionableMessages', 0, () => {
      const parsed = WechatAuthResponse.parse(401,
        '{"error":"invalid wechat code","detail":"code been used"}');
      expect(parsed.ok).assertFalse();
      expect(parsed.error).assertEqual('invalid wechat code');
      expect(parsed.detail).assertEqual('code been used');
      expect(WechatAuthResponse.message(parsed.error, '')).assertEqual('微信授权已失效，请重新登录');
      expect(WechatAuthResponse.message('server misconfigured: no wechat app credentials', ''))
        .assertEqual('微信登录服务尚未配置');
    });
  });
}
