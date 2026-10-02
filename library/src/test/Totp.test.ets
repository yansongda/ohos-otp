/**
 * TOTP 公开类 单测（T10）：全部经 HmacFixture 注入，深路径 import，不碰系统能力。
 * 期望值全部来自计划附录 A.3/A.6（黄金向量）；每条断言前先写出 counter/offset 推导。
 * 注意：syncClockOffset 公式为 clockOffsetMs -= delta * period * 1000（设计 §3.2 双场景证明表）。
 */
import { describe, it, expect } from '@ohos/hypium';
import { TOTP } from '../main/ets/TOTP';
import { OtpError, OtpErrorCode } from '../main/ets/OtpError';
import { OtpAlgorithm } from '../main/ets/OtpOptions';
import { registerHmac } from '../main/ets/internal/HmacProvider';
import { buildRfcFixture } from './HmacFixture';
import { RFC6238_SHA1, RFC6238_SHA256, RFC6238_SHA512, SEEDS, SHA256_C0_8DIGIT } from './vectors/RfcVectors';

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

export default function totpTest() {
  const fixture = buildRfcFixture();
  registerHmac(fixture); // fromURI() 走默认 provider（requireHmac），本地测试注册 fixture 兜底
  const S1: string = SEEDS.SHA1_BASE32; // 20B seed（A.1）
  const S256: string = SEEDS.SHA256_BASE32; // 32B seed（A.1）
  const S512: string = SEEDS.SHA512_BASE32; // 64B seed（A.1）

  describe('totpTest', () => {
    // ── RFC 6238 Appendix B（A.3）：X=30 / T0=0 / digits=8，三算法 × 6 时间点 = 18 条 ──
    // 推导：generate(timeSec*1000)，offset=0、t0=0 → counter = floor((timeSec*1000/1000 - 0)/30) = floor(timeSec/30)
    //   第 n 条 timeSec → counter = RFC6238_*[n].counter → code8 = RFC6238_*[n].code8
    it('rfc6238_sha1_t59', 0, () => {
      expect(new TOTP({ secret: S1, digits: 8 }, fixture).generate(RFC6238_SHA1[0].timeSec * 1000))
        .assertEqual(RFC6238_SHA1[0].code8);
    });
    it('rfc6238_sha1_t1111111109', 0, () => {
      expect(new TOTP({ secret: S1, digits: 8 }, fixture).generate(RFC6238_SHA1[1].timeSec * 1000))
        .assertEqual(RFC6238_SHA1[1].code8);
    });
    it('rfc6238_sha1_t1111111111', 0, () => {
      expect(new TOTP({ secret: S1, digits: 8 }, fixture).generate(RFC6238_SHA1[2].timeSec * 1000))
        .assertEqual(RFC6238_SHA1[2].code8);
    });
    it('rfc6238_sha1_t1234567890', 0, () => {
      expect(new TOTP({ secret: S1, digits: 8 }, fixture).generate(RFC6238_SHA1[3].timeSec * 1000))
        .assertEqual(RFC6238_SHA1[3].code8);
    });
    it('rfc6238_sha1_t2000000000', 0, () => {
      expect(new TOTP({ secret: S1, digits: 8 }, fixture).generate(RFC6238_SHA1[4].timeSec * 1000))
        .assertEqual(RFC6238_SHA1[4].code8);
    });
    it('rfc6238_sha1_t20000000000', 0, () => {
      expect(new TOTP({ secret: S1, digits: 8 }, fixture).generate(RFC6238_SHA1[5].timeSec * 1000))
        .assertEqual(RFC6238_SHA1[5].code8);
    });
    it('rfc6238_sha256_t59', 0, () => {
      expect(new TOTP({ secret: S256, algorithm: OtpAlgorithm.SHA256, digits: 8 }, fixture).generate(RFC6238_SHA256[0].timeSec * 1000))
        .assertEqual(RFC6238_SHA256[0].code8);
    });
    it('rfc6238_sha256_t1111111109', 0, () => {
      expect(new TOTP({ secret: S256, algorithm: OtpAlgorithm.SHA256, digits: 8 }, fixture).generate(RFC6238_SHA256[1].timeSec * 1000))
        .assertEqual(RFC6238_SHA256[1].code8);
    });
    it('rfc6238_sha256_t1111111111', 0, () => {
      expect(new TOTP({ secret: S256, algorithm: OtpAlgorithm.SHA256, digits: 8 }, fixture).generate(RFC6238_SHA256[2].timeSec * 1000))
        .assertEqual(RFC6238_SHA256[2].code8);
    });
    it('rfc6238_sha256_t1234567890', 0, () => {
      expect(new TOTP({ secret: S256, algorithm: OtpAlgorithm.SHA256, digits: 8 }, fixture).generate(RFC6238_SHA256[3].timeSec * 1000))
        .assertEqual(RFC6238_SHA256[3].code8);
    });
    it('rfc6238_sha256_t2000000000', 0, () => {
      expect(new TOTP({ secret: S256, algorithm: OtpAlgorithm.SHA256, digits: 8 }, fixture).generate(RFC6238_SHA256[4].timeSec * 1000))
        .assertEqual(RFC6238_SHA256[4].code8);
    });
    it('rfc6238_sha256_t20000000000', 0, () => {
      expect(new TOTP({ secret: S256, algorithm: OtpAlgorithm.SHA256, digits: 8 }, fixture).generate(RFC6238_SHA256[5].timeSec * 1000))
        .assertEqual(RFC6238_SHA256[5].code8);
    });
    it('rfc6238_sha512_t59', 0, () => {
      expect(new TOTP({ secret: S512, algorithm: OtpAlgorithm.SHA512, digits: 8 }, fixture).generate(RFC6238_SHA512[0].timeSec * 1000))
        .assertEqual(RFC6238_SHA512[0].code8);
    });
    it('rfc6238_sha512_t1111111109', 0, () => {
      expect(new TOTP({ secret: S512, algorithm: OtpAlgorithm.SHA512, digits: 8 }, fixture).generate(RFC6238_SHA512[1].timeSec * 1000))
        .assertEqual(RFC6238_SHA512[1].code8);
    });
    it('rfc6238_sha512_t1111111111', 0, () => {
      expect(new TOTP({ secret: S512, algorithm: OtpAlgorithm.SHA512, digits: 8 }, fixture).generate(RFC6238_SHA512[2].timeSec * 1000))
        .assertEqual(RFC6238_SHA512[2].code8);
    });
    it('rfc6238_sha512_t1234567890', 0, () => {
      expect(new TOTP({ secret: S512, algorithm: OtpAlgorithm.SHA512, digits: 8 }, fixture).generate(RFC6238_SHA512[3].timeSec * 1000))
        .assertEqual(RFC6238_SHA512[3].code8);
    });
    it('rfc6238_sha512_t2000000000', 0, () => {
      expect(new TOTP({ secret: S512, algorithm: OtpAlgorithm.SHA512, digits: 8 }, fixture).generate(RFC6238_SHA512[4].timeSec * 1000))
        .assertEqual(RFC6238_SHA512[4].code8);
    });
    it('rfc6238_sha512_t20000000000', 0, () => {
      expect(new TOTP({ secret: S512, algorithm: OtpAlgorithm.SHA512, digits: 8 }, fixture).generate(RFC6238_SHA512[5].timeSec * 1000))
        .assertEqual(RFC6238_SHA512[5].code8);
    });

    // ── 公开 API 全链路（QA happy 用例）：SHA1 / digits=8 / generate(59000) ──
    it('public_api_full_chain', 0, () => {
      // 推导：offset=0、t0=0 → counter = floor(floor(59000/1000)/30) = floor(59/30) = 1 → A.3 SHA1 c1 8 位码
      expect(new TOTP({ secret: S1, digits: 8 }, fixture).generate(59000)).assertEqual('94287082');
    });

    // ── digits=6 / period=30：generate(59000)（A.6：SHA1 / 6 位 / counter=1）──
    it('digits6_period30_generate59000', 0, () => {
      // 推导：counter = floor(59/30) = 1 → A.2 counter=1 的 6 位码 287082
      expect(new TOTP({ secret: S1, digits: 6 }, fixture).generate(59000)).assertEqual('287082');
    });

    // ── remaining / progress（T06 语义，参照点 s=59,p=30 → 1；s=15,p=30 → 0.5）──
    it('remaining_59000', 0, () => {
      // 推导：s=59，period - ((59%30)+30)%30 = 30 - 29 = 1
      expect(new TOTP({ secret: S1 }, fixture).remaining(59000)).assertEqual(1);
    });
    it('progress_15000', 0, () => {
      // 推导：s=15，((15%30)+30)%30/30 = 15/30 = 0.5
      expect(new TOTP({ secret: S1 }, fixture).progress(15000)).assertEqual(0.5);
    });

    // ── verify 正例/负例/窗口（T09 同语义，走公开类）──
    it('verify_positive_delta0', 0, () => {
      // 推导：timestamp=59000 → counter=floor(59/30)=1，window 缺省 0 → 候选 1；'287082' 命中 → delta 0
      expect(new TOTP({ secret: S1, digits: 6 }, fixture).verify('287082', { timestamp: 59000 })).assertEqual(0);
    });
    it('verify_negative_window0_prevStepCode', 0, () => {
      // 推导：base counter=1、window 0 → 只查 counter=1（287082）；counter=0 的 755224 不命中 → null
      expect(new TOTP({ secret: S1, digits: 6 }, fixture).verify('755224', { timestamp: 59000 })).assertEqual(null);
    });
    it('verify_window_delta_minus1', 0, () => {
      // 推导：timestamp=89000 → base counter=floor(89/30)=2，window:1 → 候选 1/2/3；'287082'（c1）命中 → delta -1
      expect(new TOTP({ secret: S1, digits: 6 }, fixture).verify('287082', { timestamp: 89000, window: 1 })).assertEqual(-1);
    });
    it('verify_window_delta_plus1', 0, () => {
      // 推导：timestamp=1000 → base counter=floor(1/30)=0，window:1 → 候选 -1(跳过)/0/1；'287082'（c1）命中 → delta 1
      expect(new TOTP({ secret: S1, digits: 6 }, fixture).verify('287082', { timestamp: 1000, window: 1 })).assertEqual(1);
    });
    it('verify_appliesClockOffset', 0, () => {
      // 推导：syncClockOffset(1) → offset = -1*30*1000 = -30000；verify(timestamp=89000) 有效时间 = 89000-30000 = 59000 → counter=1
      //   '287082'（c1）命中 → delta 0（证明显式传入 timestamp 时也叠加偏移）
      const t: TOTP = new TOTP({ secret: S1, digits: 6 }, fixture);
      t.syncClockOffset(1);
      expect(t.verify('287082', { timestamp: 89000 })).assertEqual(0);
    });

    // ── syncClockOffset 双场景（设计 §3.2 证明表；先推导再断言）──
    it('syncClockOffset_scenarioA_fastClock', 0, () => {
      // 场景 A（设备快 30s）：delta=+1 → clockOffsetMs -= 1*30*1000 = -30000。
      //   推导：generate(89000) 有效时间 = 89000 + (-30000) = 59000ms → counter = floor(59/30) = 1 → 6 位码 287082
      const t: TOTP = new TOTP({ secret: S1, digits: 6 }, fixture);
      t.syncClockOffset(1);
      expect(t.clockOffsetMs).assertEqual(-30000);
      expect(t.generate(89000)).assertEqual('287082');
    });
    it('syncClockOffset_scenarioB_slowClock', 0, () => {
      // 场景 B（设备慢 30s，新建实例）：delta=-1 → clockOffsetMs -= (-1)*30*1000 = +30000。
      //   推导：generate(59000) 有效时间 = 59000 + 30000 = 89000ms → counter = floor(89/30) = 2 → 6 位码 359152（A.2 c2）
      const t: TOTP = new TOTP({ secret: S1, digits: 6 }, fixture);
      t.syncClockOffset(-1);
      expect(t.clockOffsetMs).assertEqual(30000);
      expect(t.generate(59000)).assertEqual('359152');
    });
    it('syncClockOffset_nonInteger_throws', 0, () => {
      // delta 非整数 → INVALID_WINDOW（单参数）
      expectThrowsCode(() => {
        new TOTP({ secret: S1 }, fixture).syncClockOffset(1.5);
      }, OtpErrorCode.INVALID_WINDOW);
    });

    // ── t0 用例（A.6：t0=1、period=30、timestampMs=31000 → counter=1）──
    it('t0_1_period30_timestamp31000', 0, () => {
      // 推导：counter = floor((floor(31000/1000) - 1)/30) = floor((31-1)/30) = 1 → SHA1 c1 8 位码 94287082
      const t: TOTP = new TOTP({ secret: S1, digits: 8, period: 30, t0: 1 }, fixture);
      expect(t.generate(31000)).assertEqual('94287082');
    });

    // ── fromURI：algorithm=SHA256&digits=8&period=60 → counter=0（A.6 警示：勿写 46119246）──
    it('fromURI_period60_sha256_counter0', 0, () => {
      // 推导：URI period=60 → generate(59000) counter = floor(floor(59000/1000)/60) = floor(59/60) = 0
      //   → SHA256 / digits=8 / counter=0 的 8 位码 18920136（46119246 是 counter=1，勿混）
      const t: TOTP = TOTP.fromURI(
        'otpauth://totp/alice?secret=' + S256 + '&algorithm=SHA256&digits=8&period=60');
      expect(t.generate(59000)).assertEqual(SHA256_C0_8DIGIT);
      expect(t.generate(59000)).assertEqual('18920136');
    });

    // ── toURI() 逐字断言 + fromURI 往返 ──
    it('toURI_verbatim', 0, () => {
      // T08 build 惯例：digits=8 显式输出、period 默认 30 省略、algorithm 恒输出
      const uri: string = new TOTP({ secret: S1, digits: 8 }, fixture).toURI();
      expect(uri).assertEqual('otpauth://totp/?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&algorithm=SHA1&digits=8');
    });
    it('fromURI_roundtrip_generate_consistent', 0, () => {
      const original: TOTP = new TOTP({ secret: S256, algorithm: OtpAlgorithm.SHA256, digits: 8, period: 60 }, fixture);
      const restored: TOTP = TOTP.fromURI(original.toURI());
      // 往返后 algorithm=SHA256/digits=8/period=60 保持 → generate(59000) 命中 SHA256 c0 的 8 位码
      expect(restored.generate(59000)).assertEqual(original.generate(59000));
      expect(restored.generate(59000)).assertEqual('18920136');
    });
    it('fromURI_hotpType_throws', 0, () => {
      expectThrowsCode(() => {
        TOTP.fromURI('otpauth://hotp/alice?secret=' + S1 + '&counter=0');
      }, OtpErrorCode.UNSUPPORTED_OTPAUTH_TYPE);
    });

    // ── 构造期即抛错（设计 §3.3 统一约束）──
    it('ctor_digits5_throws', 0, () => {
      expectThrowsCode(() => { new TOTP({ secret: S1, digits: 5 }, fixture); }, OtpErrorCode.INVALID_DIGITS);
    });
    it('ctor_period0_throws', 0, () => {
      expectThrowsCode(() => { new TOTP({ secret: S1, period: 0 }, fixture); }, OtpErrorCode.INVALID_PERIOD);
    });
    it('ctor_periodNeg_throws', 0, () => {
      expectThrowsCode(() => { new TOTP({ secret: S1, period: -30 }, fixture); }, OtpErrorCode.INVALID_PERIOD);
    });
    it('ctor_t0Neg1_throws', 0, () => {
      expectThrowsCode(() => { new TOTP({ secret: S1, t0: -1 }, fixture); }, OtpErrorCode.INVALID_T0);
    });
    it('ctor_t0Fraction_throws', 0, () => {
      expectThrowsCode(() => { new TOTP({ secret: S1, t0: 1.5 }, fixture); }, OtpErrorCode.INVALID_T0);
    });
    it('ctor_clockOffsetNaN_throws', 0, () => {
      expectThrowsCode(() => { new TOTP({ secret: S1, clockOffsetMs: NaN }, fixture); }, OtpErrorCode.INVALID_TIMESTAMP);
    });
    it('ctor_clockOffsetInfinity_throws', 0, () => {
      expectThrowsCode(() => { new TOTP({ secret: S1, clockOffsetMs: Infinity }, fixture); }, OtpErrorCode.INVALID_TIMESTAMP);
    });
    it('ctor_minSecretBits128_80bit_throws', 0, () => {
      // 80 bit secret（10 字节 JBSWY3DPEHPK3PXP）< 128 → SECRET_TOO_WEAK
      expectThrowsCode(() => {
        new TOTP({ secret: 'JBSWY3DPEHPK3PXP', minSecretBits: 128 }, fixture);
      }, OtpErrorCode.SECRET_TOO_WEAK);
    });
    it('ctor_minSecretBits128_160bit_ok', 0, () => {
      // 160 bit secret（20 字节）≥ 128 → 构造不抛错，且能正常出码（59000 → counter=1 → 287082）
      const t: TOTP = new TOTP({ secret: S1, digits: 6, minSecretBits: 128 }, fixture);
      expect(t.generate(59000)).assertEqual('287082');
    });
  });
}
