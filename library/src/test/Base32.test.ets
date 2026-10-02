import { describe, it, expect } from '@ohos/hypium';
import { decode, encode } from '../main/ets/internal/Base32';
import { OtpError, OtpErrorCode } from '../main/ets/OtpError';

/** 期望 decode/encode 抛出指定错误码（try/catch 捕获后断言，比消息匹配更精确）。 */
function expectThrowsCode(fn: () => void, code: OtpErrorCode): void {
  let thrown: boolean = false;
  let actualCode: string = '';
  try {
    fn();
  } catch (e) {
    thrown = true;
    actualCode = (e as OtpError).code;
  }
  expect(thrown).assertTrue();
  expect(actualCode).assertEqual(code);
}

/** 把 ASCII 字符串转成字节数组（seed 均为纯数字 ASCII）。 */
function asciiBytes(s: string): Uint8Array {
  const arr: Uint8Array = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) {
    arr[i] = s.charCodeAt(i) & 0xff;
  }
  return arr;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

export default function base32Test() {
  describe('base32Test', () => {
    it('decodeRfcSecret_20Bytes', 0, () => {
      // 附录 A.1 SHA1 seed 的 base32 规范形：20 字节，'1'=49 … '0'=48。
      const bytes: Uint8Array = decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      expect(bytes.length).assertEqual(20);
      expect(bytes[0]).assertEqual(49);
      expect(bytes[19]).assertEqual(48);
    });

    it('decodeTailGroupTruncate_MY', 0, () => {
      // 'MY'（2 字符末组）应解出 1 字节 0x66（102）。
      const bytes: Uint8Array = decode('MY');
      expect(bytes.length).assertEqual(1);
      expect(bytes[0]).assertEqual(0x66);
    });

    it('decodeCaseInsensitiveEquivalent', 0, () => {
      const reference: Uint8Array = decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      const lower: Uint8Array = decode('gezdgnbvgy3tqojqgezdgnbvgy3tqojq');
      expect(bytesEqual(lower, reference)).assertTrue();
    });

    it('decodePaddingEquivalent', 0, () => {
      const reference: Uint8Array = decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      const padded: Uint8Array = decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ======');
      expect(bytesEqual(padded, reference)).assertTrue();
    });

    it('decodeWhitespaceEquivalent', 0, () => {
      const reference: Uint8Array = decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      const spaced: Uint8Array = decode('GEZDGNBV GY3TQOJQ GEZDGNBV GY3TQOJQ');
      expect(bytesEqual(spaced, reference)).assertTrue();
    });

    it('decodeEmptyThrowsEmptySecret', 0, () => {
      expectThrowsCode(() => {
        decode('');
      }, OtpErrorCode.EMPTY_SECRET);
    });

    it('decodeSingleCharThrowsTooShort', 0, () => {
      // 1 字符 → floor(5/8)=0 字节。
      expectThrowsCode(() => {
        decode('A');
      }, OtpErrorCode.SECRET_TOO_SHORT);
    });

    it('decodeIllegalChar_AB1', 0, () => {
      // '1' 不在字母表（A-Z、2-7）。
      expectThrowsCode(() => {
        decode('AB1');
      }, OtpErrorCode.INVALID_BASE32_CHAR);
    });

    it('decodeIllegalChar_ab0', 0, () => {
      // '0' 不在字母表（A-Z、2-7）。
      expectThrowsCode(() => {
        decode('ab0');
      }, OtpErrorCode.INVALID_BASE32_CHAR);
    });

    it('encodeDecodeRoundTrip_RfcVector', 0, () => {
      // 附录 A.1 SHA1 seed：decode 后再 encode 必须还原规范形。
      const encoded: string = encode(decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'));
      expect(encoded).assertEqual('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    });

    it('sha256SeedRoundTrip', 0, () => {
      // 附录 A.1 SHA256 seed：32 字节 ASCII ↔ base32 规范形。
      const seed: Uint8Array = asciiBytes('12345678901234567890123456789012');
      const b32: string = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA';
      expect(encode(seed)).assertEqual(b32);
      expect(bytesEqual(decode(b32), seed)).assertTrue();
    });

    it('sha512SeedRoundTrip', 0, () => {
      // 附录 A.1 SHA512 seed：64 字节 ASCII ↔ base32 规范形。
      const seed: Uint8Array = asciiBytes(
        '1234567890123456789012345678901234567890123456789012345678901234');
      const b32: string =
        'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ' +
        'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA';
      expect(encode(seed)).assertEqual(b32);
      expect(bytesEqual(decode(b32), seed)).assertTrue();
    });

    it('roundTripByteArrays_1to8', 0, () => {
      // 任意 1..8 字节数组 decode(encode(x)) 必须逐字节还原。
      for (let n = 1; n <= 8; n++) {
        const arr: Uint8Array = new Uint8Array(n);
        for (let i = 0; i < n; i++) {
          arr[i] = (i * 37 + 11) & 0xff;
        }
        expect(bytesEqual(decode(encode(arr)), arr)).assertTrue();
      }
    });

    it('encodeEmptyReturnsEmptyString', 0, () => {
      expect(encode(new Uint8Array(0))).assertEqual('');
    });

    it('encodeUppercaseNoPadding', 0, () => {
      const encoded: string = encode(asciiBytes('12345678901234567890'));
      expect(encoded === encoded.toUpperCase()).assertTrue();
      expect(encoded.indexOf('=')).assertEqual(-1);
    });

    it('encodeOutputLengthFormula', 0, () => {
      // 派生量：输出字符数 = ceil(len*8/5)：20→32、32→52、64→103。
      expect(encode(asciiBytes('12345678901234567890')).length).assertEqual(32);
      expect(encode(asciiBytes('12345678901234567890123456789012')).length).assertEqual(52);
      expect(encode(asciiBytes(
        '1234567890123456789012345678901234567890123456789012345678901234')).length)
        .assertEqual(103);
    });
  });
}
