import { describe, expect, it } from '@ohos/hypium';
import { PrivacyStartup, PrivacyStartupSurface } from '../../../main/ets/core/PrivacyStartup';

export default function privacyStartupTest() {
  describe('PrivacyStartup', () => {
    it('showsNoBusinessUiWhileConsentStateIsLoading', 0, () => {
      expect(PrivacyStartup.surface(false, false)).assertEqual(PrivacyStartupSurface.Pending);
      expect(PrivacyStartup.surface(false, true)).assertEqual(PrivacyStartupSurface.Pending);
    });

    it('showsOnlyConsentUntilTheCurrentPolicyIsAccepted', 0, () => {
      expect(PrivacyStartup.surface(true, false)).assertEqual(PrivacyStartupSurface.Consent);
      expect(PrivacyStartup.accepted('', '2026-07-31')).assertFalse();
      expect(PrivacyStartup.accepted('2026-07-30', '2026-07-31')).assertFalse();
    });

    it('allowsBusinessUiAfterTheCurrentPolicyIsAccepted', 0, () => {
      expect(PrivacyStartup.accepted('2026-07-31', '2026-07-31')).assertTrue();
      expect(PrivacyStartup.surface(true, true)).assertEqual(PrivacyStartupSurface.Business);
    });
  });
}
