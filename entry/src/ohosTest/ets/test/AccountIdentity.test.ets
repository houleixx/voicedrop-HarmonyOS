import { describe, expect, it } from '@ohos/hypium';
import { AccountIdentity } from '../../../main/ets/core/AccountIdentity';
import { DeviceLinkCrypto } from '../../../main/ets/data/DeviceLinkCrypto';

export default function accountIdentityTest() {
  describe('AccountIdentity', () => {
    it('extractsTheCurrentAccountIdFromStorageScope', 0, () => {
      expect(AccountIdentity.accountIdFromScope('users/anon-example/')).assertEqual('anon-example');
      expect(AccountIdentity.accountIdFromScope('users/wechat-current/')).assertEqual('wechat-current');
    });

    it('masksDisplayTokenButKeepsShortValuesReadable', 0, () => {
      expect(AccountIdentity.maskedToken('anon_1234567890abcdefghijkl')).assertEqual('anon_12345••••••ijkl');
      expect(AccountIdentity.maskedToken('anon_short')).assertEqual('anon_short');
    });

    it('keepsBothEndsOfLongAccountValuesVisibleLikeAndroid', 0, () => {
      expect(AccountIdentity.valueEllipsisMode).assertEqual(EllipsisMode.CENTER);
    });

    it('derivesTheAndroidCompatibleAnonymousIdSynchronously', 0, () => {
      expect(DeviceLinkCrypto.accountIdSync('anon_test')).assertEqual('anon-7d6eeb1a3887c808b1861da010fb0513');
    });
  });
}
