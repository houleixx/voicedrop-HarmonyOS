import { util } from '@kit.ArkTS';
import { zlib } from '@kit.BasicServicesKit';

interface ASRResultWire { text?: string; utterances?: ASRUtteranceWire[]; }
interface ASRUtteranceWire { text?: string; }
interface ASRBodyWire { result?: ASRResultWire; }

export class ASRMessage {
  text: string = '';
  isFinal: boolean = false;
  isError: boolean = false;
  errorCode: number = 0;
  errorMessage: string = '';
}

export class VolcASRProtocol {
  static async fullClient(userId: string): Promise<ArrayBuffer> {
    const raw: string = `{"user":{"uid":"${userId}"},"audio":{"format":"pcm","rate":16000,"bits":16,"channel":1,"codec":"raw"},"request":{"model_name":"bigmodel","enable_punc":true,"enable_itn":true,"show_utterances":true}}`;
    return VolcASRProtocol.frame(1, 1, 1, 1, 1, VolcASRProtocol.gzip(new util.TextEncoder().encodeInto(raw)));
  }

  static async audio(pcm: ArrayBuffer, sequence: number, last: boolean): Promise<ArrayBuffer> {
    return VolcASRProtocol.frame(2, last ? 3 : 1, 0, 1, last ? -Math.abs(sequence) : Math.abs(sequence), VolcASRProtocol.gzip(new Uint8Array(pcm)));
  }

  static async parse(data: ArrayBuffer): Promise<ASRMessage> {
    const message: ASRMessage = new ASRMessage(); const bytes: Uint8Array = new Uint8Array(data);
    if (bytes.length < 8) { message.isError = true; message.errorMessage = 'ASR response too short'; return message; }
    const type: number = (bytes[1] >> 4) & 15; const flags: number = bytes[1] & 15;
    const serialization: number = (bytes[2] >> 4) & 15; const compression: number = bytes[2] & 15;
    let offset: number = 4; if ((flags & 1) !== 0 || (flags & 2) !== 0) offset += 4;
    if (type === 15) {
      message.isError = true; message.isFinal = true; message.errorCode = VolcASRProtocol.u32(bytes, offset);
      const size: number = VolcASRProtocol.u32(bytes, offset + 4);
      const body: ArrayBuffer = await VolcASRProtocol.body(bytes, offset + 8, size, compression === 1);
      message.errorMessage = VolcASRProtocol.decode(body); return message;
    }
    if (type !== 9 || bytes.length < offset + 4) return message;
    const size: number = VolcASRProtocol.u32(bytes, offset);
    const body: ArrayBuffer = await VolcASRProtocol.body(bytes, offset + 4, size, compression === 1);
    message.isFinal = (flags & 2) !== 0; if (serialization !== 1) return message;
    const parsed: ASRBodyWire = JSON.parse(VolcASRProtocol.decode(body)) as ASRBodyWire;
    message.text = parsed.result?.text ?? '';
    if (message.text.length === 0 && parsed.result?.utterances) {
      message.text = parsed.result.utterances.map((item: ASRUtteranceWire) => item.text ?? '').join('');
    }
    return message;
  }

  // A valid gzip stream using uncompressed DEFLATE blocks. Voice chunks are small,
  // so avoiding a second native compression pass keeps dictation latency predictable.
  private static gzip(source: Uint8Array): Uint8Array {
    const blocks: number = Math.max(1, Math.ceil(source.length / 65535));
    const out: Uint8Array = new Uint8Array(10 + blocks * 5 + source.length + 8);
    out.set([31, 139, 8, 0, 0, 0, 0, 0, 0, 255], 0); let input: number = 0; let cursor: number = 10;
    for (let block: number = 0; block < blocks; block++) {
      const length: number = Math.min(65535, source.length - input); out[cursor++] = block === blocks - 1 ? 1 : 0;
      out[cursor++] = length & 255; out[cursor++] = (length >>> 8) & 255;
      const inverse: number = (~length) & 65535; out[cursor++] = inverse & 255; out[cursor++] = (inverse >>> 8) & 255;
      out.set(source.subarray(input, input + length), cursor); cursor += length; input += length;
    }
    const crc: number = VolcASRProtocol.crc32(source); VolcASRProtocol.le32(out, cursor, crc); VolcASRProtocol.le32(out, cursor + 4, source.length);
    return out;
  }

  private static frame(type: number, flags: number, serialization: number, compression: number,
    sequence: number, payload: Uint8Array): ArrayBuffer {
    const out: Uint8Array = new Uint8Array(12 + payload.length); out[0] = 0x11;
    out[1] = (type << 4) | flags; out[2] = (serialization << 4) | compression;
    const view: DataView = new DataView(out.buffer); view.setInt32(4, sequence, false); view.setUint32(8, payload.length, false);
    out.set(payload, 12); return out.buffer;
  }

  private static async body(bytes: Uint8Array, offset: number, size: number, compressed: boolean): Promise<ArrayBuffer> {
    const end: number = Math.min(bytes.length, offset + Math.max(0, size));
    const portion: Uint8Array = bytes.slice(offset, end); const sliced: ArrayBuffer = new ArrayBuffer(portion.byteLength);
    new Uint8Array(sliced).set(portion);
    if (!compressed) return sliced;
    const zip: zlib.Zip = zlib.createZipSync(); const stream: zlib.ZStream = await zip.getZStream();
    const output: ArrayBuffer = new ArrayBuffer(262144); stream.nextIn = sliced; stream.availableIn = sliced.byteLength;
    stream.nextOut = output; stream.availableOut = output.byteLength; await zip.inflateInit2(stream, 31);
    try { await zip.inflate(stream, zlib.CompressFlushMode.FINISH); }
    finally { await zip.inflateEnd(stream); }
    return output.slice(0, stream.totalOut ?? 0);
  }

  private static decode(data: ArrayBuffer): string { return new util.TextDecoder('utf-8').decodeWithStream(new Uint8Array(data)); }
  private static u32(bytes: Uint8Array, offset: number): number {
    return ((bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3]) >>> 0;
  }
  private static le32(bytes: Uint8Array, offset: number, value: number): void {
    bytes[offset] = value & 255; bytes[offset + 1] = (value >>> 8) & 255; bytes[offset + 2] = (value >>> 16) & 255; bytes[offset + 3] = (value >>> 24) & 255;
  }
  private static crc32(bytes: Uint8Array): number {
    let crc: number = 0xffffffff;
    for (const value of bytes) { crc ^= value; for (let bit: number = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0); }
    return (crc ^ 0xffffffff) >>> 0;
  }
}
