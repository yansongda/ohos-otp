/**
 * 编排引擎 单测：全部经 HmacFixture 注入，不碰系统能力。
 * 期望值全部来自黄金向量（RfcVectors.ets），逐条比对；
 * 派生量（如 step(timeSec*1000,0,30)）在断言前写出推导。
 */
import { describe, it, expect } from '@ohos/hypium';
import { generate, verify, EngineParams } from '../main/ets/internal/OtpEngine';
import { OtpAlgorithm } from '../main/ets/OtpOptions';
import { step } from '../main/ets/internal/TimeStep';
import { buildRfcFixture } from './HmacFixture';
import {
  RFC4226_SHA1_6DIGIT,
  RFC6238_SHA1,
  RFC6238_SHA256,
  RFC6238_SHA512,
  BOUNDARY_COUNTERS,
  DIGITS7_SHA1,
  SEEDS,
  SHA256_C0_8DIGIT
} from './vectors/RfcVectors';

/** ASCII 字节串 → Uint8Array（A.1 seed 用）。 */
function asciiBytes(s: string): Uint8Array {
  const out: Uint8Array = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) {
    out[i] = s.charCodeAt(i);
  }
  return out;
}

export default function otpEngineTest() {
  const fixture = buildRfcFixture();
  const key20: Uint8Array = asciiBytes(SEEDS.SHA1);
  const key32: Uint8Array = asciiBytes(SEEDS.SHA256);
  const key64: Uint8Array = asciiBytes(SEEDS.SHA512);
  const p6: EngineParams = { algorithm: OtpAlgorithm.SHA1, digits: 6, key: key20 };
  const p7: EngineParams = { algorithm: OtpAlgorithm.SHA1, digits: 7, key: key20 };
  const p8: EngineParams = { algorithm: OtpAlgorithm.SHA1, digits: 8, key: key20 };
  const p256_6: EngineParams = { algorithm: OtpAlgorithm.SHA256, digits: 6, key: key32 };
  const p256_8: EngineParams = { algorithm: OtpAlgorithm.SHA256, digits: 8, key: key32 };
  const p512_6: EngineParams = { algorithm: OtpAlgorithm.SHA512, digits: 6, key: key64 };
  const p512_8: EngineParams = { algorithm: OtpAlgorithm.SHA512, digits: 8, key: key64 };

  describe('otpEngineTest', () => {
    // ── RFC 4226 Appendix D：SHA1 / seed 20B / digits=6，counter 0..9（A.2，10 条）──
    it('rfc4226_counter_0', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[0].counter)).assertEqual(RFC4226_SHA1_6DIGIT[0].code);
    });
    it('rfc4226_counter_1', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[1].counter)).assertEqual(RFC4226_SHA1_6DIGIT[1].code);
    });
    it('rfc4226_counter_2', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[2].counter)).assertEqual(RFC4226_SHA1_6DIGIT[2].code);
    });
    it('rfc4226_counter_3', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[3].counter)).assertEqual(RFC4226_SHA1_6DIGIT[3].code);
    });
    it('rfc4226_counter_4', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[4].counter)).assertEqual(RFC4226_SHA1_6DIGIT[4].code);
    });
    it('rfc4226_counter_5', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[5].counter)).assertEqual(RFC4226_SHA1_6DIGIT[5].code);
    });
    it('rfc4226_counter_6', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[6].counter)).assertEqual(RFC4226_SHA1_6DIGIT[6].code);
    });
    it('rfc4226_counter_7', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[7].counter)).assertEqual(RFC4226_SHA1_6DIGIT[7].code);
    });
    it('rfc4226_counter_8', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[8].counter)).assertEqual(RFC4226_SHA1_6DIGIT[8].code);
    });
    it('rfc4226_counter_9', 0, () => {
      expect(generate(fixture, p6, RFC4226_SHA1_6DIGIT[9].counter)).assertEqual(RFC4226_SHA1_6DIGIT[9].code);
    });

    // ── RFC 6238 Appendix B：X=30 / T0=0 / digits=8（A.3，三算法 × 6 = 18 条）──
    // 派生量推导：step(timeSec*1000, 0, 30) = floor(floor(timeSec*1000/1000)/30) = floor(timeSec/30)
    it('rfc6238_sha1_t59', 0, () => {
      expect(step(RFC6238_SHA1[0].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA1[0].counter);
      expect(generate(fixture, p8, RFC6238_SHA1[0].counter)).assertEqual(RFC6238_SHA1[0].code8);
    });
    it('rfc6238_sha1_t1111111109', 0, () => {
      expect(step(RFC6238_SHA1[1].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA1[1].counter);
      expect(generate(fixture, p8, RFC6238_SHA1[1].counter)).assertEqual(RFC6238_SHA1[1].code8);
    });
    it('rfc6238_sha1_t1111111111', 0, () => {
      expect(step(RFC6238_SHA1[2].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA1[2].counter);
      expect(generate(fixture, p8, RFC6238_SHA1[2].counter)).assertEqual(RFC6238_SHA1[2].code8);
    });
    it('rfc6238_sha1_t1234567890', 0, () => {
      expect(step(RFC6238_SHA1[3].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA1[3].counter);
      expect(generate(fixture, p8, RFC6238_SHA1[3].counter)).assertEqual(RFC6238_SHA1[3].code8);
    });
    it('rfc6238_sha1_t2000000000', 0, () => {
      expect(step(RFC6238_SHA1[4].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA1[4].counter);
      expect(generate(fixture, p8, RFC6238_SHA1[4].counter)).assertEqual(RFC6238_SHA1[4].code8);
    });
    it('rfc6238_sha1_t20000000000', 0, () => {
      expect(step(RFC6238_SHA1[5].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA1[5].counter);
      expect(generate(fixture, p8, RFC6238_SHA1[5].counter)).assertEqual(RFC6238_SHA1[5].code8);
    });
    it('rfc6238_sha256_t59', 0, () => {
      expect(step(RFC6238_SHA256[0].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA256[0].counter);
      expect(generate(fixture, p256_8, RFC6238_SHA256[0].counter)).assertEqual(RFC6238_SHA256[0].code8);
    });
    it('rfc6238_sha256_t1111111109', 0, () => {
      expect(step(RFC6238_SHA256[1].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA256[1].counter);
      expect(generate(fixture, p256_8, RFC6238_SHA256[1].counter)).assertEqual(RFC6238_SHA256[1].code8);
    });
    it('rfc6238_sha256_t1111111111', 0, () => {
      expect(step(RFC6238_SHA256[2].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA256[2].counter);
      expect(generate(fixture, p256_8, RFC6238_SHA256[2].counter)).assertEqual(RFC6238_SHA256[2].code8);
    });
    it('rfc6238_sha256_t1234567890', 0, () => {
      expect(step(RFC6238_SHA256[3].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA256[3].counter);
      expect(generate(fixture, p256_8, RFC6238_SHA256[3].counter)).assertEqual(RFC6238_SHA256[3].code8);
    });
    it('rfc6238_sha256_t2000000000', 0, () => {
      expect(step(RFC6238_SHA256[4].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA256[4].counter);
      expect(generate(fixture, p256_8, RFC6238_SHA256[4].counter)).assertEqual(RFC6238_SHA256[4].code8);
    });
    it('rfc6238_sha256_t20000000000', 0, () => {
      expect(step(RFC6238_SHA256[5].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA256[5].counter);
      expect(generate(fixture, p256_8, RFC6238_SHA256[5].counter)).assertEqual(RFC6238_SHA256[5].code8);
    });
    it('rfc6238_sha512_t59', 0, () => {
      expect(step(RFC6238_SHA512[0].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA512[0].counter);
      expect(generate(fixture, p512_8, RFC6238_SHA512[0].counter)).assertEqual(RFC6238_SHA512[0].code8);
    });
    it('rfc6238_sha512_t1111111109', 0, () => {
      expect(step(RFC6238_SHA512[1].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA512[1].counter);
      expect(generate(fixture, p512_8, RFC6238_SHA512[1].counter)).assertEqual(RFC6238_SHA512[1].code8);
    });
    it('rfc6238_sha512_t1111111111', 0, () => {
      expect(step(RFC6238_SHA512[2].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA512[2].counter);
      expect(generate(fixture, p512_8, RFC6238_SHA512[2].counter)).assertEqual(RFC6238_SHA512[2].code8);
    });
    it('rfc6238_sha512_t1234567890', 0, () => {
      expect(step(RFC6238_SHA512[3].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA512[3].counter);
      expect(generate(fixture, p512_8, RFC6238_SHA512[3].counter)).assertEqual(RFC6238_SHA512[3].code8);
    });
    it('rfc6238_sha512_t2000000000', 0, () => {
      expect(step(RFC6238_SHA512[4].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA512[4].counter);
      expect(generate(fixture, p512_8, RFC6238_SHA512[4].counter)).assertEqual(RFC6238_SHA512[4].code8);
    });
    it('rfc6238_sha512_t20000000000', 0, () => {
      expect(step(RFC6238_SHA512[5].timeSec * 1000, 0, 30)).assertEqual(RFC6238_SHA512[5].counter);
      expect(generate(fixture, p512_8, RFC6238_SHA512[5].counter)).assertEqual(RFC6238_SHA512[5].code8);
    });

    // ── 边界 counter（A.4，3 条 × 三算法 × {6 位, 8 位} = 18 条；覆盖 2^32 / 2^32+1 / 2^53-1）──
    it('boundary_2pow32_sha1_6', 0, () => {
      expect(generate(fixture, p6, BOUNDARY_COUNTERS[0].counter)).assertEqual(BOUNDARY_COUNTERS[0].sha1.code6);
    });
    it('boundary_2pow32_sha1_8', 0, () => {
      expect(generate(fixture, p8, BOUNDARY_COUNTERS[0].counter)).assertEqual(BOUNDARY_COUNTERS[0].sha1.code8);
    });
    it('boundary_2pow32_sha256_6', 0, () => {
      expect(generate(fixture, p256_6, BOUNDARY_COUNTERS[0].counter)).assertEqual(BOUNDARY_COUNTERS[0].sha256.code6);
    });
    it('boundary_2pow32_sha256_8', 0, () => {
      expect(generate(fixture, p256_8, BOUNDARY_COUNTERS[0].counter)).assertEqual(BOUNDARY_COUNTERS[0].sha256.code8);
    });
    it('boundary_2pow32_sha512_6', 0, () => {
      expect(generate(fixture, p512_6, BOUNDARY_COUNTERS[0].counter)).assertEqual(BOUNDARY_COUNTERS[0].sha512.code6);
    });
    it('boundary_2pow32_sha512_8', 0, () => {
      expect(generate(fixture, p512_8, BOUNDARY_COUNTERS[0].counter)).assertEqual(BOUNDARY_COUNTERS[0].sha512.code8);
    });
    it('boundary_2pow32_plus1_sha1_6', 0, () => {
      expect(generate(fixture, p6, BOUNDARY_COUNTERS[1].counter)).assertEqual(BOUNDARY_COUNTERS[1].sha1.code6);
    });
    it('boundary_2pow32_plus1_sha1_8', 0, () => {
      expect(generate(fixture, p8, BOUNDARY_COUNTERS[1].counter)).assertEqual(BOUNDARY_COUNTERS[1].sha1.code8);
    });
    it('boundary_2pow32_plus1_sha256_6', 0, () => {
      expect(generate(fixture, p256_6, BOUNDARY_COUNTERS[1].counter)).assertEqual(BOUNDARY_COUNTERS[1].sha256.code6);
    });
    it('boundary_2pow32_plus1_sha256_8', 0, () => {
      expect(generate(fixture, p256_8, BOUNDARY_COUNTERS[1].counter)).assertEqual(BOUNDARY_COUNTERS[1].sha256.code8);
    });
    it('boundary_2pow32_plus1_sha512_6', 0, () => {
      expect(generate(fixture, p512_6, BOUNDARY_COUNTERS[1].counter)).assertEqual(BOUNDARY_COUNTERS[1].sha512.code6);
    });
    it('boundary_2pow32_plus1_sha512_8', 0, () => {
      expect(generate(fixture, p512_8, BOUNDARY_COUNTERS[1].counter)).assertEqual(BOUNDARY_COUNTERS[1].sha512.code8);
    });
    it('boundary_2pow53minus1_sha1_6', 0, () => {
      expect(generate(fixture, p6, BOUNDARY_COUNTERS[2].counter)).assertEqual(BOUNDARY_COUNTERS[2].sha1.code6);
    });
    it('boundary_2pow53minus1_sha1_8', 0, () => {
      expect(generate(fixture, p8, BOUNDARY_COUNTERS[2].counter)).assertEqual(BOUNDARY_COUNTERS[2].sha1.code8);
    });
    it('boundary_2pow53minus1_sha256_6', 0, () => {
      expect(generate(fixture, p256_6, BOUNDARY_COUNTERS[2].counter)).assertEqual(BOUNDARY_COUNTERS[2].sha256.code6);
    });
    it('boundary_2pow53minus1_sha256_8', 0, () => {
      expect(generate(fixture, p256_8, BOUNDARY_COUNTERS[2].counter)).assertEqual(BOUNDARY_COUNTERS[2].sha256.code8);
    });
    it('boundary_2pow53minus1_sha512_6', 0, () => {
      expect(generate(fixture, p512_6, BOUNDARY_COUNTERS[2].counter)).assertEqual(BOUNDARY_COUNTERS[2].sha512.code6);
    });
    it('boundary_2pow53minus1_sha512_8', 0, () => {
      expect(generate(fixture, p512_8, BOUNDARY_COUNTERS[2].counter)).assertEqual(BOUNDARY_COUNTERS[2].sha512.code8);
    });

    // ── 7 位（A.6：SHA1 / digits=7，counter 0/1/9，3 条）──
    it('digits7_sha1_counter_0', 0, () => {
      expect(generate(fixture, p7, DIGITS7_SHA1[0].counter)).assertEqual(DIGITS7_SHA1[0].code7);
    });
    it('digits7_sha1_counter_1', 0, () => {
      expect(generate(fixture, p7, DIGITS7_SHA1[1].counter)).assertEqual(DIGITS7_SHA1[1].code7);
    });
    it('digits7_sha1_counter_9', 0, () => {
      expect(generate(fixture, p7, DIGITS7_SHA1[2].counter)).assertEqual(DIGITS7_SHA1[2].code7);
    });

    // ── A.6 第 1 行：SHA256 / digits=8 / counter=0（period=60 → floor(59/60)=0）──
    it('sha256_c0_8digit', 0, () => {
      expect(generate(fixture, p256_8, 0)).assertEqual(SHA256_C0_8DIGIT);
    });

    // ── verify 正例（窗口语义：扫完才返回首个命中 delta）──
    it('verify_positive_delta0', 0, () => {
      // base counter=1、window=0：命中 counter=1 → delta 0
      expect(verify(fixture, p6, '287082', 1, 0)).assertEqual(0);
    });
    it('verify_positive_delta_minus1', 0, () => {
      // base counter=2、window=1：候选 1/2/3；counter=1 命中 → delta -1
      expect(verify(fixture, p6, '287082', 2, 1)).assertEqual(-1);
    });
    it('verify_positive_delta_plus1', 0, () => {
      // base counter=0、window=1：候选 -1(跳过)/0/1；counter=1 命中 → delta 1
      expect(verify(fixture, p6, '287082', 0, 1)).assertEqual(1);
    });

    // ── verify 负例 ──
    it('verify_negative_window0_prevStepCode', 0, () => {
      // base counter=1、window=0：只查 counter=1（287082）；上一步 counter=0 的码 755224 不命中 → null
      expect(verify(fixture, p6, '755224', 1, 0)).assertEqual(null);
    });
    it('verify_negative_wrongCode', 0, () => {
      expect(verify(fixture, p6, '123456', 1, 0)).assertEqual(null);
    });

    // ── verify 边界：负候选被跳过且不崩溃 ──
    it('verify_boundary_negativeCandidatesSkipped', 0, () => {
      // base counter=0、window=2：候选 -2/-1 跳过；counter=0 命中 → delta 0
      expect(verify(fixture, p6, '755224', 0, 2)).assertEqual(0);
    });

    // ── verify 入参校验 ──
    it('verify_invalidToken_short', 0, () => {
      // '12345' 长度 5 ≠ digits 6 → INVALID_TOKEN
      expect(() => { verify(fixture, p6, '12345', 1, 0); }).assertThrowError('INVALID_TOKEN');
    });
    it('verify_invalidToken_nondigit', 0, () => {
      // '12a456' 含非数字字符 → INVALID_TOKEN
      expect(() => { verify(fixture, p6, '12a456', 1, 0); }).assertThrowError('INVALID_TOKEN');
    });
    it('verify_invalidWindow_negative', 0, () => {
      // window=-1 不满足 ≥0 → INVALID_WINDOW
      expect(() => { verify(fixture, p6, '287082', 1, -1); }).assertThrowError('INVALID_WINDOW');
    });
    it('verify_invalidCounter_negative', 0, () => {
      // base counter=-1 不满足 isSafeCounter → INVALID_COUNTER（不再静默 null）
      expect(() => { verify(fixture, p6, '287082', -1, 1); }).assertThrowError('INVALID_COUNTER');
    });
    it('verify_invalidWindow_fraction', 0, () => {
      // window=1.5 不满足整数 → INVALID_WINDOW
      expect(() => { verify(fixture, p6, '287082', 1, 1.5); }).assertThrowError('INVALID_WINDOW');
    });

    // ── fixture 未命中必须抛错（绝不返回零值数组）──
    it('fixture_miss_throws', 0, () => {
      // counter=42 不在黄金表内 → fixture 抛错
      expect(() => { generate(fixture, p6, 42); }).assertThrowError('HmacFixture 未命中');
    });
  });
}
