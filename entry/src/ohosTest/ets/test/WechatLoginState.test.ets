import { describe, expect, it } from '@ohos/hypium';
import { WechatLoginState } from '../../../main/ets/core/WechatLoginState';

export default function wechatLoginStateTest() {
  describe('WechatLoginState', () => {
    it('acceptsOnlyTheCurrentUnexpiredOneTimeState', 0, () => {
      const now: number = 1000000;
      const state: string = `${WechatLoginState.PREFIX}request123`;
      expect(WechatLoginState.isValid(state, state, now - 1000, now)).assertTrue();
      expect(WechatLoginState.isValid(state, `${state}other`, now - 1000, now)).assertFalse();
      expect(WechatLoginState.isValid('', '', now - 1000, now)).assertFalse();
      expect(WechatLoginState.isValid(state, state,
        now - WechatLoginState.MAX_AGE_MS - 1, now)).assertFalse();
      expect(WechatLoginState.isValid(state, state, now + 1, now)).assertFalse();
    });
  });
}
