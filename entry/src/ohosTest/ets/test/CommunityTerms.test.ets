import { describe, expect, it } from '@ohos/hypium';
import {
  COMMUNITY_TERM_AGREEMENT,
  COMMUNITY_TERM_CONTROL,
  COMMUNITY_TERM_ENFORCEMENT,
  COMMUNITY_TERM_PROHIBITED,
  COMMUNITY_TERM_RESPONSIBILITY,
  COMMUNITY_TERMS,
  SUPPORT_EMAIL
} from '../../../main/ets/core/CommunityTerms';

export default function communityTermsTest() {
  describe('CommunityTerms', () => {
    it('keepsEveryDisplayedRuleInConsentText', 0, () => {
      expect(COMMUNITY_TERMS.includes(COMMUNITY_TERM_RESPONSIBILITY)).assertTrue();
      expect(COMMUNITY_TERMS.includes(COMMUNITY_TERM_PROHIBITED)).assertTrue();
      expect(COMMUNITY_TERMS.includes(COMMUNITY_TERM_ENFORCEMENT)).assertTrue();
      expect(COMMUNITY_TERMS.includes(COMMUNITY_TERM_CONTROL)).assertTrue();
    });

    it('keepsAgreementAndSupportContactInConsentText', 0, () => {
      expect(COMMUNITY_TERMS.includes(COMMUNITY_TERM_AGREEMENT)).assertTrue();
      expect(COMMUNITY_TERMS.includes('EULA')).assertTrue();
      expect(COMMUNITY_TERMS.includes(SUPPORT_EMAIL)).assertTrue();
    });
  });
}
