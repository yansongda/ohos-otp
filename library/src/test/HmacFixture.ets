/**
 * 可注入 HMAC fixture（黄金 digest 查表，kit-free）。
 * 表键 = `<algorithm>:<message hex>`，值 = digest hex。
 * 未命中必须抛错（绝不允许返回零值数组，那会让用例假绿）。
 */
import { HmacProvider } from '../main/ets/internal/HmacProvider';
import { OtpAlgorithm } from '../main/ets/OtpOptions';
import { toBytes as counterToBytes } from '../main/ets/internal/Counter';
import {
  RFC4226_SHA1_6DIGIT,
  RFC6238_SHA1,
  RFC6238_SHA256,
  RFC6238_SHA512,
  BOUNDARY_COUNTERS,
  SHA256_C0_DIGEST
} from './vectors/RfcVectors';

function bytesToHex(bytes: Uint8Array): string {
  let out: string = '';
  for (let i = 0; i < bytes.length; i++) {
    const b: number = bytes[i];
    out += (b < 16 ? '0' : '') + b.toString(16);
  }
  return out;
}

function hexToBytes(hex: string): Uint8Array {
  const out: Uint8Array = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

/** counter → 8 字节大端 message hex（与引擎侧 toBytes 同源，保证键一致）。 */
function counterMessageHex(counter: number): string {
  return bytesToHex(counterToBytes(counter));
}

export class HmacFixture implements HmacProvider {
  private readonly table: Map<string, string>;

  constructor(table: Map<string, string>) {
    this.table = table;
  }

  sign(algorithm: OtpAlgorithm, key: Uint8Array, message: Uint8Array): Uint8Array {
    const messageHex: string = bytesToHex(message);
    const digestHex: string | undefined = this.table.get(algorithm + ':' + messageHex);
    if (digestHex === undefined) {
      throw new Error('HmacFixture 未命中: ' + algorithm + ':' + messageHex);
    }
    return hexToBytes(digestHex);
  }
}

/**
 * 把 RfcVectors 的全部 digest 装入查表。
 * SHA1 counter=1 在 A.2 与 A.3（T=59）各出现一次且 digest 相同，Map.set 重复写入幂等无害。
 */
export function buildRfcFixture(): HmacFixture {
  const table: Map<string, string> = new Map<string, string>();
  const put = (algorithm: OtpAlgorithm, counter: number, digestHex: string): void => {
    table.set(algorithm + ':' + counterMessageHex(counter), digestHex);
  };

  for (let i = 0; i < RFC4226_SHA1_6DIGIT.length; i++) {
    const v = RFC4226_SHA1_6DIGIT[i];
    put(OtpAlgorithm.SHA1, v.counter, v.digestHex);
  }
  for (let i = 0; i < RFC6238_SHA1.length; i++) {
    const v = RFC6238_SHA1[i];
    put(OtpAlgorithm.SHA1, v.counter, v.digestHex);
  }
  for (let i = 0; i < RFC6238_SHA256.length; i++) {
    const v = RFC6238_SHA256[i];
    put(OtpAlgorithm.SHA256, v.counter, v.digestHex);
  }
  for (let i = 0; i < RFC6238_SHA512.length; i++) {
    const v = RFC6238_SHA512[i];
    put(OtpAlgorithm.SHA512, v.counter, v.digestHex);
  }
  for (let i = 0; i < BOUNDARY_COUNTERS.length; i++) {
    const v = BOUNDARY_COUNTERS[i];
    put(OtpAlgorithm.SHA1, v.counter, v.sha1.digest);
    put(OtpAlgorithm.SHA256, v.counter, v.sha256.digest);
    put(OtpAlgorithm.SHA512, v.counter, v.sha512.digest);
  }
  // A.6 第 1 行：SHA256 / counter=0（T10 fromURI 用例走 period=60 → counter=0 需要此条）
  put(OtpAlgorithm.SHA256, 0, SHA256_C0_DIGEST);

  return new HmacFixture(table);
}
