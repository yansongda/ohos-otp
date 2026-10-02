/**
 * 设备端真实 crypto 验证（ohosTest / JsUnit）。
 *
 * Local Test 环境 crypto 返回空数据，本套件是真实 cryptoFramework 与
 * barrel 注册链路的唯一覆盖点：全部用例走默认 provider，不注入任何 fixture。
 * 期望值来自 RFC 官方附录（RFC 4226 Appendix D / RFC 6238 Appendix B），禁止自行推导或临时拼装。
 *
 * barrel（模块根 Index.ets）在模块加载期执行 installCryptoDefaults()，
 * 因此本套件所有「不注入 provider」的公开类调用即是对注册链路的真实验证。
 */
import { describe, it, expect } from '@ohos/hypium';
import { OtpAlgorithm } from '../../../main/ets/OtpOptions';
import { Secret } from '../../../main/ets/Secret';
import { HOTP } from '../../../main/ets/HOTP';
import { TOTP } from '../../../main/ets/TOTP';
import { CryptoFrameworkHmac } from '../../../main/ets/internal/CryptoSource';
import { TOTP as BarrelTOTP } from '../../../../Index.ets';

// ── seed 的 base32 规范形（RFC 官方 seed 串，逐字，不得改动）──
const SHA1_B32: string = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
const SHA256_B32: string = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA';
const SHA512_B32: string = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA';

/** counter=1 的 8 字节大端 message（0000000000000001）。 */
const MSG_COUNTER_1: Uint8Array = new Uint8Array([0, 0, 0, 0, 0, 0, 0, 1]);

/** 字节数组 → 小写 hex（用于 digest 断言）。 */
function toHex(bytes: Uint8Array): string {
  let out: string = '';
  for (let i = 0; i < bytes.length; i++) {
    const h: string = bytes[i].toString(16);
    out += h.length === 1 ? '0' + h : h;
  }
  return out;
}

/** 是否为纯数字串（80 bit 密钥出码的格式断言用）。 */
function isAllDigits(s: string): boolean {
  if (s.length === 0) {
    return false;
  }
  for (let i = 0; i < s.length; i++) {
    const c: number = s.charCodeAt(i);
    if (c < 48 || c > 57) {
      return false;
    }
  }
  return true;
}

export default function cryptoAdapterTest() {
  describe('cryptoAdapterTest', () => {
    // ── 1. CryptoFrameworkHmac 三算法 counter=1 digest（A.3 第 1 行，A.1 key）──

    it('hmacSha1_counter1_digest', 0, () => {
      const digest: Uint8Array = new CryptoFrameworkHmac().sign(
        OtpAlgorithm.SHA1, Secret.fromBase32(SHA1_B32).bytes, MSG_COUNTER_1);
      expect(toHex(digest)).assertEqual('75a48a19d4cbe100644e8ac1397eea747a2d33ab');
    });

    it('hmacSha256_counter1_digest', 0, () => {
      const digest: Uint8Array = new CryptoFrameworkHmac().sign(
        OtpAlgorithm.SHA256, Secret.fromBase32(SHA256_B32).bytes, MSG_COUNTER_1);
      expect(toHex(digest)).assertEqual('392514c9dd4165d4709456062c78e04e16e68718515951333bdb8b26caa3053c');
    });

    it('hmacSha512_counter1_digest', 0, () => {
      const digest: Uint8Array = new CryptoFrameworkHmac().sign(
        OtpAlgorithm.SHA512, Secret.fromBase32(SHA512_B32).bytes, MSG_COUNTER_1);
      expect(toHex(digest)).assertEqual(
        '6f76f324230cefda1d3f65309a0badb36efce9528ada64967d71e4e9d74c4aa37fe7650f931ab86ddccc2d38962d720ee626a20feb311b485a92e3bb0796df28');
    });

    // ── 2. TOTP 三算法 × 6 时间点 = 18 条（A.3 全表，digits=8，默认 provider）──

    it('totpSha1_t59_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA1_B32, digits: 8, algorithm: OtpAlgorithm.SHA1 }).generate(59000);
      expect(code).assertEqual('94287082');
    });

    it('totpSha1_t1111111109_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA1_B32, digits: 8, algorithm: OtpAlgorithm.SHA1 }).generate(1111111109000);
      expect(code).assertEqual('07081804');
    });

    it('totpSha1_t1111111111_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA1_B32, digits: 8, algorithm: OtpAlgorithm.SHA1 }).generate(1111111111000);
      expect(code).assertEqual('14050471');
    });

    it('totpSha1_t1234567890_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA1_B32, digits: 8, algorithm: OtpAlgorithm.SHA1 }).generate(1234567890000);
      expect(code).assertEqual('89005924');
    });

    it('totpSha1_t2000000000_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA1_B32, digits: 8, algorithm: OtpAlgorithm.SHA1 }).generate(2000000000000);
      expect(code).assertEqual('69279037');
    });

    it('totpSha1_t20000000000_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA1_B32, digits: 8, algorithm: OtpAlgorithm.SHA1 }).generate(20000000000000);
      expect(code).assertEqual('65353130');
    });

    it('totpSha256_t59_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA256_B32, digits: 8, algorithm: OtpAlgorithm.SHA256 }).generate(59000);
      expect(code).assertEqual('46119246');
    });

    it('totpSha256_t1111111109_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA256_B32, digits: 8, algorithm: OtpAlgorithm.SHA256 }).generate(1111111109000);
      expect(code).assertEqual('68084774');
    });

    it('totpSha256_t1111111111_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA256_B32, digits: 8, algorithm: OtpAlgorithm.SHA256 }).generate(1111111111000);
      expect(code).assertEqual('67062674');
    });

    it('totpSha256_t1234567890_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA256_B32, digits: 8, algorithm: OtpAlgorithm.SHA256 }).generate(1234567890000);
      expect(code).assertEqual('91819424');
    });

    it('totpSha256_t2000000000_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA256_B32, digits: 8, algorithm: OtpAlgorithm.SHA256 }).generate(2000000000000);
      expect(code).assertEqual('90698825');
    });

    it('totpSha256_t20000000000_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA256_B32, digits: 8, algorithm: OtpAlgorithm.SHA256 }).generate(20000000000000);
      expect(code).assertEqual('77737706');
    });

    it('totpSha512_t59_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA512_B32, digits: 8, algorithm: OtpAlgorithm.SHA512 }).generate(59000);
      expect(code).assertEqual('90693936');
    });

    it('totpSha512_t1111111109_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA512_B32, digits: 8, algorithm: OtpAlgorithm.SHA512 }).generate(1111111109000);
      expect(code).assertEqual('25091201');
    });

    it('totpSha512_t1111111111_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA512_B32, digits: 8, algorithm: OtpAlgorithm.SHA512 }).generate(1111111111000);
      expect(code).assertEqual('99943326');
    });

    it('totpSha512_t1234567890_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA512_B32, digits: 8, algorithm: OtpAlgorithm.SHA512 }).generate(1234567890000);
      expect(code).assertEqual('93441116');
    });

    it('totpSha512_t2000000000_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA512_B32, digits: 8, algorithm: OtpAlgorithm.SHA512 }).generate(2000000000000);
      expect(code).assertEqual('38618901');
    });

    it('totpSha512_t20000000000_code8', 0, () => {
      const code: string = new TOTP({ secret: SHA512_B32, digits: 8, algorithm: OtpAlgorithm.SHA512 }).generate(20000000000000);
      expect(code).assertEqual('47863826');
    });

    // ── 3. HOTP counter 0..9 = 10 条（A.2 全表，digits=6，默认 provider）──

    it('hotp_c0', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(0);
      expect(code).assertEqual('755224');
    });

    it('hotp_c1', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(1);
      expect(code).assertEqual('287082');
    });

    it('hotp_c2', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(2);
      expect(code).assertEqual('359152');
    });

    it('hotp_c3', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(3);
      expect(code).assertEqual('969429');
    });

    it('hotp_c4', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(4);
      expect(code).assertEqual('338314');
    });

    it('hotp_c5', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(5);
      expect(code).assertEqual('254676');
    });

    it('hotp_c6', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(6);
      expect(code).assertEqual('287922');
    });

    it('hotp_c7', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(7);
      expect(code).assertEqual('162583');
    });

    it('hotp_c8', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(8);
      expect(code).assertEqual('399871');
    });

    it('hotp_c9', 0, () => {
      const code: string = new HOTP({ secret: SHA1_B32, digits: 6 }).generate(9);
      expect(code).assertEqual('520489');
    });

    // ── 4. Secret.generate(20)：真实随机源（默认 provider 注册的随机实现）──

    it('secretGenerate20_byteLength', 0, () => {
      const s: Secret = Secret.generate(20);
      expect(s.byteLength).assertEqual(20);
    });

    it('secretGenerate20_twiceDifferent', 0, () => {
      const a: Uint8Array = Secret.generate(20).bytes;
      const b: Uint8Array = Secret.generate(20).bytes;
      let same: boolean = true;
      for (let i = 0; i < 20; i++) {
        if (a[i] !== b[i]) {
          same = false;
          break;
        }
      }
      expect(same).assertFalse();
    });

    it('secretGenerate20_base32RoundTrip', 0, () => {
      const s: Secret = Secret.generate(20);
      const restored: Secret = Secret.fromBase32(s.toBase32());
      expect(restored.byteLength).assertEqual(20);
      expect(toHex(restored.bytes)).assertEqual(toHex(s.bytes));
    });

    // ── 5. 80 bit 真实密钥（RFC 4648 示例 'Hello!\xDE\xAD\xBE\xEF' 的 base32）──

    it('totp_80bitKey_JBSWY3DPEHPK3PXP_generates', 0, () => {
      const code: string = new TOTP({ secret: 'JBSWY3DPEHPK3PXP' }).generate(59000);
      expect(code.length).assertEqual(6);
      expect(isAllDigits(code)).assertTrue();
    });

    it('hotp_80bitKey_JBSWY3DPEHPK3PXP_generates', 0, () => {
      const code: string = new HOTP({ secret: 'JBSWY3DPEHPK3PXP' }).generate(0);
      expect(code.length).assertEqual(6);
      expect(isAllDigits(code)).assertTrue();
    });

    // ── 6. barrel 注册链路：经模块根 Index.ets 导入的符号，不注入 provider ──
    // 模块加载期 installCryptoDefaults() 已执行；本用例同时是 SHA1/digits=8/counter=1 的 A.3 向量。

    it('barrel_totp_defaultProvider_generates', 0, () => {
      const code: string = new BarrelTOTP({ secret: SHA1_B32, digits: 8, algorithm: OtpAlgorithm.SHA1 }).generate(59000);
      expect(code).assertEqual('94287082');
    });
  });
}
