import { describe, expect, it } from '@ohos/hypium';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { DeviceLinkBlob, DeviceLinkCrypto, DeviceLinkKeypair } from '../../../main/ets/data/DeviceLinkCrypto';

function decodeBase64Url(value: string): Uint8Array {
  let padded: string = value.replace(/-/g, '+').replace(/_/g, '/');
  while (padded.length % 4 !== 0) padded += '=';
  return new util.Base64Helper().decodeSync(padded, util.Type.BASIC);
}

export default function deviceLinkCryptoInteropTest() {
  describe('DeviceLinkCryptoInterop', () => {
    it('encryptsForAWebCryptoRawX25519PublicKey', 0, async () => {
      // Exported as `raw` by WebCrypto, exactly like the VoiceDrop MCP login tool.
      const webCryptoPublicKey: string = 'rN-gPlYHTvHqUWW7ycxaO4w5UG5sr1zDodKfclW8lko';
      const blob: DeviceLinkBlob = await DeviceLinkCrypto.encrypt('anon_cross_platform_test', webCryptoPublicKey);

      expect(blob.epk.length).assertEqual(43);
      expect(blob.sealed.length > 40).assertTrue();
    });

    it('decryptsAWebCryptoX25519HkdfAesGcmVector', 0, async () => {
      // Generated independently by Node WebCrypto with nonce 01..0c.
      const recipientPublicX509: string =
        'MCowBQYDK2VuAyEAa0Vkdt5L6CGl0fGfGNH7DsAGOC-4gQJN_w8M2e1-Mho';
      const recipientPrivatePkcs8: string =
        'MC4CAQAwBQYDK2VuBCIEIAitlMfqdHXMle6L8UzWHbAqIUye2JoEvUqW8kTHeMlk';
      const senderPublicRaw: string = 'yBatDoI4DapPXNg2MjEKJb1BO5_4ctccjh21b_x-7hI';
      const sealed: string =
        'AQIDBAUGBwgJCgsMZ5TF0JeIH-9nI0AEar4CZzPYBe7WtfWTrKmoZwBfe7k1m94RN6HBwG1rjsd4AK-5';
      const nativeKeypair: cryptoFramework.KeyPair = await cryptoFramework.createAsyKeyGenerator('X25519')
        .convertKey({ data: decodeBase64Url(recipientPublicX509) },
          { data: decodeBase64Url(recipientPrivatePkcs8) });
      const keypair: DeviceLinkKeypair = new DeviceLinkKeypair(nativeKeypair, '');
      try {
        const token: string = await DeviceLinkCrypto.decrypt(senderPublicRaw, sealed, keypair);
        expect(token).assertEqual('anon_cross_platform_decrypt_test');
      } finally {
        keypair.clear();
      }
    });
  });
}
