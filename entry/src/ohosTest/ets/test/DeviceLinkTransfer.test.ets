import { describe, expect, it } from '@ohos/hypium';
import { DeviceLinkTransfer } from '../../../main/ets/data/DeviceLinkStore';
import { DeviceLinkBlob } from '../../../main/ets/data/DeviceLinkCrypto';

export default function deviceLinkTransferTest() {
  describe('DeviceLinkTransfer', () => {
    it('serializesTheCompletePayloadLikeAndroid', 0, () => {
      const payload: string = DeviceLinkTransfer.completePayload(
        'a'.repeat(32), new DeviceLinkBlob('ephemeral-key', 'sealed-token'));
      const value = JSON.parse(payload) as Record<string, Object | string>;
      const blob = value['blob'] as Record<string, string>;
      expect(value['pairingId']).assertEqual('a'.repeat(32));
      expect(blob['epk']).assertEqual('ephemeral-key');
      expect(blob['sealed']).assertEqual('sealed-token');
    });
  });
}
