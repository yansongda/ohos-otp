/**
 * HOTP 公开类 单测（T10）：全部经 HmacFixture 注入，深路径 import，不碰系统能力。
 * 期望值全部来自计划附录 A.2/A.6（黄金向量）；每条断言前先写 counter/码 推导。
 */
import { describe, it, expect } from '@ohos/hypium';
import { HOTP } from '../main/ets/HOTP';
import { OtpError, OtpErrorCode } from '../main/ets/OtpError';
import { registerHmac } from '../main/ets/internal/HmacProvider';
import { buildRfcFixture } from './HmacFixture';
import { RFC4226_SHA1_6DIGIT, SEEDS } from './vectors/RfcVectors';

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

export default function hotpTest() {
  const fixture = buildRfcFixture();
  registerHmac(fixture); // fromURI() 走默认 provider（requireHmac），本地测试注册 fixture 兜底
  const SECRET: string = SEEDS.SHA1_BASE32; // A.1 规范形 = RFC 4226 20B seed

  describe('hotpTest', () => {
    // ── RFC 4226 Appendix D（A.2）：SHA1 / seed 20B / digits=6，counter 0..9（10 条）──
    // 推导：new HOTP({counter:n}) → generate() 缺省用构造 counter=n → 命中 A.2 第 n 条
    it('rfc4226_counter_0', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 0 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[0].code);
    });
    it('rfc4226_counter_1', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 1 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[1].code);
    });
    it('rfc4226_counter_2', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 2 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[2].code);
    });
    it('rfc4226_counter_3', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 3 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[3].code);
    });
    it('rfc4226_counter_4', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 4 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[4].code);
    });
    it('rfc4226_counter_5', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 5 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[5].code);
    });
    it('rfc4226_counter_6', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 6 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[6].code);
    });
    it('rfc4226_counter_7', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 7 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[7].code);
    });
    it('rfc4226_counter_8', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 8 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[8].code);
    });
    it('rfc4226_counter_9', 0, () => {
      expect(new HOTP({ secret: SECRET, counter: 9 }, fixture).generate()).assertEqual(RFC4226_SHA1_6DIGIT[9].code);
    });

    // ── generate(counter) 显式覆盖（A.6：SHA1 / digits=8 / counter=1）──
    it('generate_override_counter1_digits8', 0, () => {
      // 构造 counter=0，显式 generate(1) → counter=1 → 8 位码 94287082
      expect(new HOTP({ secret: SECRET, digits: 8 }, fixture).generate(1)).assertEqual('94287082');
    });

    // ── digits 变体（A.6：SHA1 / digits=7 / counter=1）──
    it('digits7_counter1', 0, () => {
      // counter=1 → A.2 的 287082 动态截断值，7 位形态 = 4287082
      expect(new HOTP({ secret: SECRET, digits: 7, counter: 1 }, fixture).generate()).assertEqual('4287082');
    });

    // ── toURI() 逐字断言（T08 build 惯例：digits 默认 6 省略、HOTP 恒输出 counter）──
    it('toURI_verbatim', 0, () => {
      const uri: string = new HOTP({ secret: SECRET, counter: 0 }, fixture).toURI();
      expect(uri).assertEqual('otpauth://hotp/?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&algorithm=SHA1&counter=0');
    });

    // ── fromURI(toURI()) 往返：generate() 结果一致 ──
    it('fromURI_roundtrip_generate_consistent', 0, () => {
      const original: HOTP = new HOTP({ secret: SECRET, digits: 8, counter: 1, issuer: 'ACME Co', account: 'alice' }, fixture);
      const restored: HOTP = HOTP.fromURI(original.toURI());
      // 往返后 algorithm=SHA1/digits=8/counter=1 保持 → generate() 命中 counter=1 的 8 位码
      expect(restored.generate()).assertEqual(original.generate());
      expect(restored.generate()).assertEqual('94287082');
    });

    // ── verify 正例/窗口/负例（窗口单位=步=1 counter，与 T09 同语义）──
    it('verify_positive_delta0', 0, () => {
      // 构造 counter=1、window 缺省 0 → 候选 counter=1，'287082' 命中 → delta 0
      expect(new HOTP({ secret: SECRET, counter: 1 }, fixture).verify('287082')).assertEqual(0);
    });
    it('verify_window_delta_minus1', 0, () => {
      // 构造 counter=2、window:1 → 候选 1/2/3；'287082'（counter=1）命中 → delta -1
      expect(new HOTP({ secret: SECRET, counter: 2 }, fixture).verify('287082', { window: 1 })).assertEqual(-1);
    });
    it('verify_negative_window0_prevStepCode', 0, () => {
      // 构造 counter=1、window 缺省 0 → 只查 counter=1（287082）；上一步 counter=0 的 755224 不命中 → null
      expect(new HOTP({ secret: SECRET, counter: 1 }, fixture).verify('755224')).assertEqual(null);
    });

    // ── 构造期即抛错（设计 §3.3 统一约束）──
    it('ctor_digits5_throws', 0, () => {
      // digits 仅允许 6/7/8，5 非法 → INVALID_DIGITS
      expectThrowsCode(() => { new HOTP({ secret: SECRET, digits: 5 }, fixture); }, OtpErrorCode.INVALID_DIGITS);
    });
    it('ctor_counterNeg1_throws', 0, () => {
      // counter=-1 不满足 ≥0 整数 → INVALID_COUNTER
      expectThrowsCode(() => { new HOTP({ secret: SECRET, counter: -1 }, fixture); }, OtpErrorCode.INVALID_COUNTER);
    });
    it('ctor_minSecretBits128_80bit_throws', 0, () => {
      // 80 bit secret（10 字节 JBSWY3DPEHPK3PXP）< 128 → SECRET_TOO_WEAK
      expectThrowsCode(() => {
        new HOTP({ secret: 'JBSWY3DPEHPK3PXP', minSecretBits: 128 }, fixture);
      }, OtpErrorCode.SECRET_TOO_WEAK);
    });
    it('ctor_minSecretBits128_160bit_ok', 0, () => {
      // 160 bit secret（20 字节）≥ 128 → 构造不抛错，且能正常出码（counter=0 → A.2 的 755224）
      const h: HOTP = new HOTP({ secret: SECRET, minSecretBits: 128 }, fixture);
      expect(h.generate()).assertEqual('755224');
    });

    // ── fromURI 类型守卫：totp URI 拒绝 ──
    it('fromURI_totpType_throws', 0, () => {
      expectThrowsCode(() => {
        HOTP.fromURI('otpauth://totp/alice?secret=' + SECRET);
      }, OtpErrorCode.UNSUPPORTED_OTPAUTH_TYPE);
    });
  });
}
