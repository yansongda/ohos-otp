/**
 * Secret 规范化 / 拷贝语义 / 随机生成 / 脱敏测试。
 * 随机生成用例注入 RandomFixture 固定序列，不用真实随机源断言。
 */
import { describe, it, expect } from '@ohos/hypium';
import { Secret } from '../main/ets/Secret';
import { OtpError, OtpErrorCode } from '../main/ets/OtpError';
import { registerRandom } from '../main/ets/internal/HmacProvider';
import { RandomFixture } from './RandomFixture';

/** 期望抛出指定错误码（try/catch 捕获后断言 code，比消息匹配精确）。 */
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

export default function secretTest() {
  describe('secretTest', () => {
    it('fromBase32_lowercase80bit_belowR6Recommendation', 0, () => {
      // 10 字节 = 80 bit，低于 RFC 4226 §4 R6 的 128 bit 建议（本库默认不强制）
      const secret: Secret = Secret.fromBase32('jbswy3dpehpk3pxp');
      expect(secret.byteLength).assertEqual(10);
      expect(secret.bitLength).assertEqual(80);
    });

    it('fromBase32_tolerantCasePaddingWhitespace', 0, () => {
      const ref: Secret = Secret.fromBase32('JBSWY3DPEHPK3PXP');
      const lower: Secret = Secret.fromBase32('jbswy3dpehpk3pxp');
      const padded: Secret = Secret.fromBase32('JBSWY3DPEHPK3PXP======');
      const spaced: Secret = Secret.fromBase32('JBSWY3DPEHPK3 PXP');
      expect(lower.toBase32()).assertEqual(ref.toBase32());
      expect(padded.toBase32()).assertEqual(ref.toBase32());
      expect(spaced.toBase32()).assertEqual(ref.toBase32());
      expect(ref.toBase32()).assertEqual('JBSWY3DPEHPK3PXP');
    });

    it('fromBytes_emptyThrows', 0, () => {
      expectThrowsCode(() => Secret.fromBytes(new Uint8Array()), OtpErrorCode.EMPTY_SECRET);
    });

    it('fromBytes_copiesInput', 0, () => {
      const input: Uint8Array = new Uint8Array([1, 2, 3, 4]);
      const secret: Secret = Secret.fromBytes(input);
      input[0] = 99; // 改写入参数组，不影响实例
      expect(secret.bytes[0]).assertEqual(1);
    });

    it('bytesGetter_returnsCopy', 0, () => {
      const secret: Secret = Secret.fromBase32('JBSWY3DPEHPK3PXP');
      const view: Uint8Array = secret.bytes;
      view[0] = 0xff; // 改动返回的拷贝，不影响内部
      expect(secret.bytes[0]).assertEqual(72); // 'H' = 72
      expect(secret.toBase32()).assertEqual('JBSWY3DPEHPK3PXP');
    });

    it('toBase32_normalizedUppercase', 0, () => {
      const secret: Secret = Secret.fromBase32('jbswy3dpehpk3pxp');
      expect(secret.toBase32()).assertEqual('JBSWY3DPEHPK3PXP');
    });

    it('generate_20BytesDeterministicViaRandomFixture', 0, () => {
      const fixture: RandomFixture = new RandomFixture();
      registerRandom(fixture);
      const secret: Secret = Secret.generate(20);
      expect(secret.byteLength).assertEqual(20);
      expect(fixture.lastRequestedBytes).assertEqual(20);
      // 固定递增序列 0x00..0x13 → 确定性 base32（与 python base64.b32encode 交叉验证一致）
      expect(secret.toBase32()).assertEqual('AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQT');
    });

    it('generate_invalidSizeThrows', 0, () => {
      const fixture: RandomFixture = new RandomFixture();
      registerRandom(fixture);
      expectThrowsCode(() => Secret.generate(0), OtpErrorCode.SECRET_TOO_WEAK);
      expectThrowsCode(() => Secret.generate(1.5), OtpErrorCode.SECRET_TOO_WEAK);
      expectThrowsCode(() => Secret.generate(4097), OtpErrorCode.SECRET_TOO_WEAK);
    });

    it('jsonStringify_redactsSecret', 0, () => {
      const secret: Secret = Secret.fromBase32('JBSWY3DPEHPK3PXP');
      const json: string = JSON.stringify({ s: secret });
      expect(json.indexOf('JBSWY3DPEHPK3PXP')).assertEqual(-1); // 不含密钥内容
      expect(json.indexOf('[REDACTED]')).assertLargerOrEqual(0); // 含脱敏标记
    });

    it('stringConversion_doesNotLeakSecret', 0, () => {
      const secret: Secret = Secret.fromBase32('JBSWY3DPEHPK3PXP');
      const s: string = String(secret);
      // 未实现 toString() 时 String(secret) === '[object Object]'，两种结果都不含明文 base32
      expect(s.indexOf('JBSWY3DPEHPK3PXP')).assertEqual(-1);
    });
  });
}
