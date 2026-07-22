import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

class X25519PublicSpec implements cryptoFramework.X25519PubKeySpec {
  algName: string = 'X25519';
  specType: cryptoFramework.AsyKeySpecType = cryptoFramework.AsyKeySpecType.PUBLIC_KEY_SPEC;
  pk: bigint;
  constructor(pk: bigint) { this.pk = pk; }
}

export class DeviceLinkKeypair {
  nativeKeypair: cryptoFramework.KeyPair;
  publicKeyB64: string;
  constructor(pair: cryptoFramework.KeyPair, publicKeyB64: string) { this.nativeKeypair = pair; this.publicKeyB64 = publicKeyB64; }
  clear(): void { this.nativeKeypair.priKey.clearMem(); }
}

export class DeviceLinkBlob {
  epk: string;
  sealed: string;
  constructor(epk: string, sealed: string) { this.epk = epk; this.sealed = sealed; }
}

export class DeviceLinkCrypto {
  private static readonly EMPTY: cryptoFramework.DataBlob = { data: new Uint8Array(0) };

  static async newKeypair(): Promise<DeviceLinkKeypair> {
    const pair: cryptoFramework.KeyPair = await cryptoFramework.createAsyKeyGenerator('X25519').generateKeyPair();
    const pkValue = pair.pubKey.getAsyKeySpec(cryptoFramework.AsyKeySpecItem.X25519_PK_BN);
    if (typeof pkValue !== 'bigint') throw new Error('X25519 公钥格式错误');
    return new DeviceLinkKeypair(pair, DeviceLinkCrypto.b64(DeviceLinkCrypto.bigintToLittleEndian(pkValue, 32)));
  }

  static async accountCode(token: string): Promise<string> {
    const digest: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    await digest.update({ data: new util.TextEncoder().encodeInto(token) });
    const bytes: Uint8Array = (await digest.digest()).data; let value: string = '';
    for (let index: number = 0; index < 3; index++) value += bytes[index].toString(16).padStart(2, '0');
    return value.toUpperCase();
  }

  static async accountId(token: string): Promise<string> {
    const digest: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    await digest.update({ data: new util.TextEncoder().encodeInto(token) });
    const bytes: Uint8Array = (await digest.digest()).data; let value: string = 'anon-';
    for (let index: number = 0; index < 16; index++) value += bytes[index].toString(16).padStart(2, '0');
    return value;
  }

  static accountIdSync(token: string): string {
    const digest: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    digest.updateSync({ data: new util.TextEncoder().encodeInto(token) });
    const bytes: Uint8Array = digest.digestSync().data;
    let value: string = 'anon-';
    for (let index: number = 0; index < 16; index++) value += bytes[index].toString(16).padStart(2, '0');
    return value;
  }

  static async encrypt(token: string, toPublicKeyB64: string): Promise<DeviceLinkBlob> {
    const ephemeral: DeviceLinkKeypair = await DeviceLinkCrypto.newKeypair();
    try {
      const shared: Uint8Array = await DeviceLinkCrypto.shared(ephemeral.nativeKeypair.priKey, toPublicKeyB64);
      const key: Uint8Array = await DeviceLinkCrypto.hkdf(shared);
      const nonce: Uint8Array = cryptoFramework.createRandom().generateRandomSync(12).data;
      const encrypted: Uint8Array = await DeviceLinkCrypto.aesEncrypt(key, nonce, new util.TextEncoder().encodeInto(token));
      return new DeviceLinkBlob(ephemeral.publicKeyB64, DeviceLinkCrypto.b64(DeviceLinkCrypto.concat(nonce, encrypted)));
    } finally { ephemeral.clear(); }
  }

  static async decrypt(epkB64: string, sealedB64: string, keypair: DeviceLinkKeypair): Promise<string> {
    const shared: Uint8Array = await DeviceLinkCrypto.shared(keypair.nativeKeypair.priKey, epkB64);
    const key: Uint8Array = await DeviceLinkCrypto.hkdf(shared); const combined: Uint8Array = DeviceLinkCrypto.unb64(sealedB64);
    if (combined.byteLength < 29) throw new Error('设备配对密文过短');
    const nonce: Uint8Array = combined.slice(0, 12); const ciphertext: Uint8Array = combined.slice(12, combined.length - 16);
    const tag: Uint8Array = combined.slice(combined.length - 16);
    const plain: Uint8Array = await DeviceLinkCrypto.aesDecrypt(key, nonce, ciphertext, tag);
    return new util.TextDecoder('utf-8').decodeWithStream(plain);
  }

  private static async shared(privateKey: cryptoFramework.PriKey, publicKeyB64: string): Promise<Uint8Array> {
    const raw: Uint8Array = DeviceLinkCrypto.unb64(publicKeyB64);
    if (raw.byteLength !== 32) throw new Error('X25519 公钥长度错误');
    const peer: cryptoFramework.PubKey = await cryptoFramework.createAsyKeyGeneratorBySpec(
      new X25519PublicSpec(DeviceLinkCrypto.littleEndianToBigint(raw))).generatePubKey();
    return (await cryptoFramework.createKeyAgreement('X25519').generateSecret(privateKey, peer)).data;
  }

  private static async hkdf(shared: Uint8Array): Promise<Uint8Array> {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const spec: cryptoFramework.HKDFSpec = { algName: 'HKDF|SHA256', key: shared,
      salt: encoder.encodeInto('voicedrop-device-link/v1'), info: encoder.encodeInto('anon-token'), keySize: 32 };
    return (await cryptoFramework.createKdf('HKDF|SHA256').generateSecret(spec)).data;
  }

  private static async aesEncrypt(keyBytes: Uint8Array, nonce: Uint8Array, plain: Uint8Array): Promise<Uint8Array> {
    const key: cryptoFramework.SymKey = cryptoFramework.createSymKeyGenerator('AES256').convertKeySync({ data: keyBytes });
    const params: cryptoFramework.GcmParamsSpec = { algName: 'GcmParamsSpec', iv: { data: nonce }, aad: DeviceLinkCrypto.EMPTY,
      authTag: { data: new Uint8Array(0) } };
    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    try {
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, params);
      const result: Uint8Array = (await cipher.doFinal({ data: plain })).data;
      if (params.authTag.data.byteLength === 16) return DeviceLinkCrypto.concat(result, params.authTag.data);
      if (result.byteLength === plain.byteLength + 16) return result;
      throw new Error('AES-GCM 未返回认证标签');
    } finally { key.clearMem(); }
  }

  private static async aesDecrypt(keyBytes: Uint8Array, nonce: Uint8Array, encrypted: Uint8Array,
    tag: Uint8Array): Promise<Uint8Array> {
    const key: cryptoFramework.SymKey = cryptoFramework.createSymKeyGenerator('AES256').convertKeySync({ data: keyBytes });
    const params: cryptoFramework.GcmParamsSpec = { algName: 'GcmParamsSpec', iv: { data: nonce }, aad: DeviceLinkCrypto.EMPTY,
      authTag: { data: tag } };
    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    try { await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, key, params); return (await cipher.doFinal({ data: encrypted })).data; }
    finally { key.clearMem(); }
  }

  private static b64(value: Uint8Array): string {
    return new util.Base64Helper().encodeToStringSync(value, util.Type.BASIC_URL_SAFE).replace(/=/g, '');
  }
  private static unb64(value: string): Uint8Array {
    let padded: string = value.replace(/-/g, '+').replace(/_/g, '/'); while (padded.length % 4 !== 0) padded += '=';
    return new util.Base64Helper().decodeSync(padded, util.Type.BASIC);
  }
  private static concat(left: Uint8Array, right: Uint8Array): Uint8Array {
    const out: Uint8Array = new Uint8Array(left.length + right.length); out.set(left, 0); out.set(right, left.length); return out;
  }
  private static littleEndianToBigint(bytes: Uint8Array): bigint {
    let value: bigint = BigInt(0); for (let index: number = bytes.length - 1; index >= 0; index--) value = (value << BigInt(8)) | BigInt(bytes[index]); return value;
  }
  private static bigintToLittleEndian(input: bigint, length: number): Uint8Array {
    let value: bigint = input; const bytes: Uint8Array = new Uint8Array(length);
    for (let index: number = 0; index < length; index++) { bytes[index] = Number(value & BigInt(255)); value >>= BigInt(8); }
    return bytes;
  }
}
