import { describe, it, expect } from '@ohos/hypium';
import { decode, decodeStrict, encode, normalize } from '../main/ets/internal/Base32';
import { OtpError, OtpErrorCode } from '../main/ets/OtpError';
import { RFC4648_BASE32, Rfc4648Base32Vector } from './vectors/RfcVectors';

/** 期望 decode/decodeStrict/encode 抛出指定错误码（try/catch 捕获后断言，比消息匹配更精确）。 */
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
      // SHA1 seed（ASCII '1'…'0'）的 base32 规范形：20 字节，'1'=49 … '0'=48。
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

    it('decodeLengthNotMultipleOf8_19Chars', 0, () => {
      // 19 字符 → floor(19*5/8)=11 字节：末组仅 3 字符（=1 字节），残留 7 bit 必须被丢弃。
      const bytes: Uint8Array = decode('GEZDGNBVGY3TQOJQGEZ');
      expect(bytes.length).assertEqual(11);
      expect(bytesEqual(bytes, decode(encode(bytes)))).assertTrue();
    });

    it('decodeLeadingAndInternalWhitespace', 0, () => {
      // 前导空白也是 \s，必须一并剔除（宽松解析的边界：仅去内部空白会漏）。
      const reference: Uint8Array = decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      const messy: Uint8Array = decode('  \tGEZD GNBV\nGY3T\rQOJQ GEZDGNBV GY3TQOJQ  ');
      expect(bytesEqual(messy, reference)).assertTrue();
    });

    it('decodeUpperLowerMixed', 0, () => {
      const reference: Uint8Array = decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      const mixed: Uint8Array = decode('GezdGnbvGY3tqojQgezdgnBvgy3tQOjq');
      expect(bytesEqual(mixed, reference)).assertTrue();
    });

    it('decodeMultiplePaddingAmounts', 0, () => {
      // '=+$' 是贪婪截断：1/4/6/8 个 '=' 必须都得到同一结果。
      const reference: Uint8Array = decode('GEZDGNBVGY3TQOJQ');
      expect(bytesEqual(decode('GEZDGNBVGY3TQOJQ='), reference)).assertTrue();
      expect(bytesEqual(decode('GEZDGNBVGY3TQOJQ===='), reference)).assertTrue();
      expect(bytesEqual(decode('GEZDGNBVGY3TQOJQ======'), reference)).assertTrue();
      expect(bytesEqual(decode('GEZDGNBVGY3TQOJQ========'), reference)).assertTrue();
    });

    it('decodeBoundaryLengths_2to104', 0, () => {
      // 位对齐边界压测（与实现无关）：覆盖 2..104 全部 base32 字符长度的 5 bit 对齐余数。
      // 输入取字节序列长度 1..64，其编码长度恰好覆盖该区间。
      for (let n = 1; n <= 64; n++) {
        const arr: Uint8Array = new Uint8Array(n);
        for (let i = 0; i < n; i++) {
          arr[i] = (i * 91 + 17) & 0xff;
        }
        const encoded: string = encode(arr);
        const decoded: Uint8Array = decode(encoded);
        expect(decoded.length).assertEqual(n);
        expect(bytesEqual(decoded, arr)).assertTrue();
      }
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

    it('decodeStrict_rfc4648VectorsRoundTrip', 0, () => {
      // RFC 4648 §10 的 7 条向量恰好覆盖全部合法尾长 {0,2,4,5,7}：
      // 归一化后的规范串必须既能 strict 解码为明文，又能编码回自身（无损等价）。
      for (let i = 0; i < RFC4648_BASE32.length; i++) {
        const v: Rfc4648Base32Vector = RFC4648_BASE32[i];
        const canonical: string = normalize(v.base32Padded);
        if (canonical === '') {
          continue; // 空串另有 EMPTY_SECRET 用例
        }
        const bytes: Uint8Array = decodeStrict(canonical);
        expect(bytesEqual(bytes, asciiBytes(v.plain))).assertTrue();
        expect(encode(bytes)).assertEqual(canonical);
      }
    });

    it('decodeStrict_acceptsLenientNormalization', 0, () => {
      // strict 拒绝的是「规范 base32 不可能产生」的尾长/尾位，不拒绝大小写/空白/尾部 '=' 风格。
      const reference: Uint8Array = decodeStrict('MY');
      expect(bytesEqual(decodeStrict('MY======'), reference)).assertTrue();
      expect(bytesEqual(decodeStrict('  my \n'), reference)).assertTrue();
      expect(bytesEqual(decodeStrict('My'), reference)).assertTrue();
      expect(reference[0]).assertEqual(0x66);
    });

    it('decodeStrict_rejectsNonZeroTailBits', 0, () => {
      // 反例构造：取 RFC 向量末字符，仅把其低位填充位由 0 翻为非 0（尾长不变）。
      // MY→MB(2) / MZXQ→MZXR(4) / MZXW6→MZXW7(5) / MZXW6YQ→MZXW6YT(7) / MZXW6YTBOI→MZXW6YTBOJ(2)
      expectThrowsCode(() => {
        decodeStrict('MB');
      }, OtpErrorCode.INVALID_BASE32_PADDING);
      expectThrowsCode(() => {
        decodeStrict('MZXR');
      }, OtpErrorCode.INVALID_BASE32_PADDING);
      expectThrowsCode(() => {
        decodeStrict('MZXW7');
      }, OtpErrorCode.INVALID_BASE32_PADDING);
      expectThrowsCode(() => {
        decodeStrict('MZXW6YT');
      }, OtpErrorCode.INVALID_BASE32_PADDING);
      expectThrowsCode(() => {
        decodeStrict('MZXW6YTBOJ');
      }, OtpErrorCode.INVALID_BASE32_PADDING);
    });

    it('decodeStrict_rejectsImpossibleTailLength', 0, () => {
      // RFC 4648 §6 只可能产生 len%8 ∈ {0,2,4,5,7}；{1,3,6} 属结构性非法。
      expectThrowsCode(() => {
        decodeStrict('A');
      }, OtpErrorCode.INVALID_BASE32_PADDING);
      expectThrowsCode(() => {
        decodeStrict('AAA');
      }, OtpErrorCode.INVALID_BASE32_PADDING);
      expectThrowsCode(() => {
        decodeStrict('MZXW6Y');
      }, OtpErrorCode.INVALID_BASE32_PADDING);
    });

    it('decodeStrict_charErrorBeforeTailLength', 0, () => {
      // 'AB1' 同时含非法字符与非法尾长：字符错误优先（对调用方更有排障价值）。
      expectThrowsCode(() => {
        decodeStrict('AB1');
      }, OtpErrorCode.INVALID_BASE32_CHAR);
    });

    it('decodeStrict_emptyThrowsEmptySecret', 0, () => {
      expectThrowsCode(() => {
        decodeStrict('');
      }, OtpErrorCode.EMPTY_SECRET);
      expectThrowsCode(() => {
        decodeStrict('   ');
      }, OtpErrorCode.EMPTY_SECRET);
      expectThrowsCode(() => {
        decodeStrict('====');
      }, OtpErrorCode.EMPTY_SECRET);
    });

    it('decodeStrict_differsFromLenientOnSingleChar', 0, () => {
      // 锁死唯一的「同输入不同码」：'A' 宽松→SECRET_TOO_SHORT，strict→INVALID_BASE32_PADDING。
      expectThrowsCode(() => {
        decode('A');
      }, OtpErrorCode.SECRET_TOO_SHORT);
      expectThrowsCode(() => {
        decodeStrict('A');
      }, OtpErrorCode.INVALID_BASE32_PADDING);
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
      // SHA1 seed：decode 后再 encode 必须还原规范形。
      const encoded: string = encode(decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'));
      expect(encoded).assertEqual('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    });

    it('sha256SeedRoundTrip', 0, () => {
      // SHA256 seed：32 字节 ASCII ↔ base32 规范形。
      const seed: Uint8Array = asciiBytes('12345678901234567890123456789012');
      const b32: string = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA';
      expect(encode(seed)).assertEqual(b32);
      expect(bytesEqual(decode(b32), seed)).assertTrue();
    });

    it('sha512SeedRoundTrip', 0, () => {
      // SHA512 seed：64 字节 ASCII ↔ base32 规范形。
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
