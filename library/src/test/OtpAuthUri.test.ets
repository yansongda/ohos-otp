/**
 * OTPAuthURI 解析 / 生成 / round-trip 测试。
 * 解析与生成遵循 Google Authenticator Key URI Format（IANA Provisional #13829）。
 */
import { describe, it, expect } from '@ohos/hypium';
import { OTPAuthURI } from '../main/ets/OTPAuthURI';
import { OtpAlgorithm, OtpAuthParams, OtpType } from '../main/ets/OtpOptions';
import { OtpError, OtpErrorCode } from '../main/ets/OtpError';

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

/**
 * 语义等价断言：type/secret/algorithm/digits/period/counter/issuer/account 逐项相等。
 * 缺省语义：TOTP period 缺省 30、HOTP counter 缺省 0（parse(build(p)) 会补齐默认值）。
 */
function assertParamsEqual(actual: OtpAuthParams, expected: OtpAuthParams): void {
  expect(actual.type).assertEqual(expected.type);
  expect(actual.secret).assertEqual(expected.secret);
  expect(actual.algorithm).assertEqual(expected.algorithm);
  expect(actual.digits).assertEqual(expected.digits);
  const expPeriod: number | undefined = expected.period === undefined
    ? (expected.type === OtpType.TOTP ? 30 : undefined) : expected.period;
  const expCounter: number | undefined = expected.counter === undefined
    ? (expected.type === OtpType.HOTP ? 0 : undefined) : expected.counter;
  expect(actual.period).assertEqual(expPeriod);
  expect(actual.counter).assertEqual(expCounter);
  expect(actual.issuer).assertEqual(expected.issuer === undefined ? undefined : expected.issuer);
  expect(actual.account).assertEqual(expected.account === undefined ? undefined : expected.account);
}

export default function otpAuthUriTest() {
  describe('otpAuthUriTest', () => {
    it('parse_standardTotpAllFields', 0, () => {
      const p: OtpAuthParams = OTPAuthURI.parse(
        'otpauth://totp/ACME%20Co:john@example.com?secret=JBSWY3DPEHPK3PXP&issuer=ACME%20Co&algorithm=SHA256&digits=8&period=60'
      );
      expect(p.type).assertEqual(OtpType.TOTP);
      expect(p.secret).assertEqual('JBSWY3DPEHPK3PXP');
      expect(p.algorithm).assertEqual(OtpAlgorithm.SHA256);
      expect(p.digits).assertEqual(8);
      expect(p.period).assertEqual(60);
      expect(p.issuer).assertEqual('ACME Co');
      expect(p.account).assertEqual('john@example.com');
    });

    it('parse_labelPercent3ASeparator', 0, () => {
      // label 用 %3A 分隔 issuer/account
      const p: OtpAuthParams = OTPAuthURI.parse(
        'otpauth://totp/ACME%3Aco@example.com?secret=JBSWY3DPEHPK3PXP'
      );
      expect(p.type).assertEqual(OtpType.TOTP);
      expect(p.issuer).assertEqual('ACME');
      expect(p.account).assertEqual('co@example.com');
    });

    it('parse_missingOptionalDefaults', 0, () => {
      // 无 algorithm/digits/period → SHA1/6/30
      const p: OtpAuthParams = OTPAuthURI.parse(
        'otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP'
      );
      expect(p.algorithm).assertEqual(OtpAlgorithm.SHA1);
      expect(p.digits).assertEqual(6);
      expect(p.period).assertEqual(30);
      expect(p.account).assertEqual('alice');
    });

    it('parse_hotpWithCounter', 0, () => {
      const p: OtpAuthParams = OTPAuthURI.parse(
        'otpauth://hotp/ACME%20Co:alice?secret=JBSWY3DPEHPK3PXP&counter=42'
      );
      expect(p.type).assertEqual(OtpType.HOTP);
      expect(p.counter).assertEqual(42);
      expect(p.period).assertUndefined();
    });

    it('parse_unknownParamsIgnored', 0, () => {
      const p: OtpAuthParams = OTPAuthURI.parse(
        'otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP&image=foo.png&lock=true'
      );
      expect(p.secret).assertEqual('JBSWY3DPEHPK3PXP');
      expect(p.digits).assertEqual(6);
    });

    it('parse_uppercaseScheme', 0, () => {
      const p: OtpAuthParams = OTPAuthURI.parse(
        'OTPAUTH://TOTP/alice?secret=JBSWY3DPEHPK3PXP'
      );
      expect(p.type).assertEqual(OtpType.TOTP);
      expect(p.secret).assertEqual('JBSWY3DPEHPK3PXP');
    });

    it('parse_queryIssuerWinsOverLabelPrefix', 0, () => {
      const p: OtpAuthParams = OTPAuthURI.parse(
        'otpauth://totp/Foo:bar?secret=JBSWY3DPEHPK3PXP&issuer=Baz'
      );
      expect(p.issuer).assertEqual('Baz'); // 以 query 为准
      expect(p.account).assertEqual('bar');
    });

    it('parse_failInvalidScheme', 0, () => {
      expectThrowsCode(() => OTPAuthURI.parse('http://example.com/x'), OtpErrorCode.INVALID_OTPAUTH_URI);
    });

    it('parse_failUnsupportedType', 0, () => {
      expectThrowsCode(() => OTPAuthURI.parse('otpauth://steam/alice?secret=JBSWY3DPEHPK3PXP'),
        OtpErrorCode.UNSUPPORTED_OTPAUTH_TYPE);
    });

    it('parse_failMissingSecret', 0, () => {
      expectThrowsCode(() => OTPAuthURI.parse('otpauth://totp/alice'), OtpErrorCode.EMPTY_SECRET);
    });

    it('parse_failInvalidAlgorithm', 0, () => {
      expectThrowsCode(() => OTPAuthURI.parse('otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP&algorithm=MD5'),
        OtpErrorCode.INVALID_ALGORITHM);
    });

    it('parse_failInvalidDigits', 0, () => {
      expectThrowsCode(() => OTPAuthURI.parse('otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP&digits=5'),
        OtpErrorCode.INVALID_DIGITS);
    });

    it('parse_failInvalidPeriod', 0, () => {
      expectThrowsCode(() => OTPAuthURI.parse('otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP&period=0'),
        OtpErrorCode.INVALID_PERIOD);
    });

    it('parse_failInvalidCounter', 0, () => {
      expectThrowsCode(() => OTPAuthURI.parse('otpauth://hotp/alice?secret=JBSWY3DPEHPK3PXP&counter=-1'),
        OtpErrorCode.INVALID_COUNTER);
    });

    it('build_exactTotpFullOutput', 0, () => {
      const p: OtpAuthParams = {
        type: OtpType.TOTP,
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: OtpAlgorithm.SHA256,
        digits: 8,
        period: 60,
        issuer: 'ACME Co',
        account: 'john@example.com'
      };
      expect(OTPAuthURI.build(p)).assertEqual(
        'otpauth://totp/ACME%20Co:john%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=ACME%20Co&algorithm=SHA256&digits=8&period=60'
      );
    });

    it('build_exactMinimalTotpOutput', 0, () => {
      const p: OtpAuthParams = {
        type: OtpType.TOTP,
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: OtpAlgorithm.SHA1,
        digits: 6
      };
      // digits=6 省略、period=30 省略、无 issuer/account 时 label 为空
      expect(OTPAuthURI.build(p)).assertEqual('otpauth://totp/?secret=JBSWY3DPEHPK3PXP&algorithm=SHA1');
    });

    it('build_exactHotpOutput', 0, () => {
      const p: OtpAuthParams = {
        type: OtpType.HOTP,
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: OtpAlgorithm.SHA1,
        digits: 6,
        counter: 42,
        issuer: 'ACME Co',
        account: 'alice'
      };
      // HOTP 输出 counter 而非 period；digits=6 省略
      expect(OTPAuthURI.build(p)).assertEqual(
        'otpauth://hotp/ACME%20Co:alice?secret=JBSWY3DPEHPK3PXP&issuer=ACME%20Co&algorithm=SHA1&counter=42'
      );
    });

    it('roundtrip_totpFullFields', 0, () => {
      const p: OtpAuthParams = {
        type: OtpType.TOTP,
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: OtpAlgorithm.SHA512,
        digits: 8,
        period: 60,
        issuer: 'ACME Co',
        account: 'john@example.com'
      };
      const back: OtpAuthParams = OTPAuthURI.parse(OTPAuthURI.build(p));
      assertParamsEqual(back, p);
    });

    it('roundtrip_hotp', 0, () => {
      const p: OtpAuthParams = {
        type: OtpType.HOTP,
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: OtpAlgorithm.SHA1,
        digits: 6,
        counter: 42,
        issuer: 'ACME Co',
        account: 'alice'
      };
      const back: OtpAuthParams = OTPAuthURI.parse(OTPAuthURI.build(p));
      assertParamsEqual(back, p);
    });

    it('roundtrip_minimalRequired', 0, () => {
      const p: OtpAuthParams = {
        type: OtpType.TOTP,
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: OtpAlgorithm.SHA1,
        digits: 6
      };
      const back: OtpAuthParams = OTPAuthURI.parse(OTPAuthURI.build(p));
      assertParamsEqual(back, p);
    });
  });
}
