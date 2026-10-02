/**
 * OtpError 错误模型测试：instanceof 双真 + 17 个枚举成员逐一断言（防枚举改动）。
 * 若 instanceof OtpError 断言失败，属设计性偏差，须停下上报，不静默改设计。
 */
import { describe, it, expect } from '@ohos/hypium';
import { OtpError, OtpErrorCode } from '../main/ets/OtpError';

export default function otpErrorTest() {
  describe('otpErrorTest', () => {
    it('otpError_instanceofAndFields', 0, () => {
      const err: OtpError = new OtpError(OtpErrorCode.INVALID_DIGITS, 'x');
      expect(err instanceof Error).assertTrue();
      expect(err instanceof OtpError).assertTrue();
      expect(err.code).assertEqual(OtpErrorCode.INVALID_DIGITS);
      expect(err.message).assertEqual('x');
    });

    it('otpErrorCode_all17MembersExactValues', 0, () => {
      const expected: string[] = [
        'EMPTY_SECRET', 'INVALID_BASE32_CHAR', 'SECRET_TOO_SHORT', 'SECRET_TOO_WEAK',
        'INVALID_ALGORITHM', 'INVALID_DIGITS', 'INVALID_PERIOD', 'INVALID_T0',
        'INVALID_COUNTER', 'INVALID_TIMESTAMP', 'INVALID_WINDOW', 'INVALID_TOKEN',
        'CRYPTO_FAILED', 'CRYPTO_NOT_INITIALIZED', 'INVALID_OTPAUTH_URI',
        'UNSUPPORTED_OTPAUTH_TYPE', 'NOT_IMPLEMENTED'
      ];
      const codes: OtpErrorCode[] = [
        OtpErrorCode.EMPTY_SECRET, OtpErrorCode.INVALID_BASE32_CHAR,
        OtpErrorCode.SECRET_TOO_SHORT, OtpErrorCode.SECRET_TOO_WEAK,
        OtpErrorCode.INVALID_ALGORITHM, OtpErrorCode.INVALID_DIGITS,
        OtpErrorCode.INVALID_PERIOD, OtpErrorCode.INVALID_T0,
        OtpErrorCode.INVALID_COUNTER, OtpErrorCode.INVALID_TIMESTAMP,
        OtpErrorCode.INVALID_WINDOW, OtpErrorCode.INVALID_TOKEN,
        OtpErrorCode.CRYPTO_FAILED, OtpErrorCode.CRYPTO_NOT_INITIALIZED,
        OtpErrorCode.INVALID_OTPAUTH_URI, OtpErrorCode.UNSUPPORTED_OTPAUTH_TYPE,
        OtpErrorCode.NOT_IMPLEMENTED
      ];
      expect(codes.length).assertEqual(17);
      for (let i = 0; i < codes.length; i++) {
        expect(codes[i]).assertEqual(expected[i]);
      }
    });

    it('otpError_thrownCaughtPreservesCode', 0, () => {
      let isInstance: boolean = false;
      let code: string = '';
      try {
        throw new OtpError(OtpErrorCode.INVALID_COUNTER, 'INVALID_COUNTER');
      } catch (e) {
        isInstance = e instanceof OtpError;
        code = (e as OtpError).code;
      }
      expect(isInstance).assertTrue();
      expect(code).assertEqual(OtpErrorCode.INVALID_COUNTER);
    });

    it('otpError_messageCustomizableSeparateFromCode', 0, () => {
      const err: OtpError = new OtpError(OtpErrorCode.SECRET_TOO_SHORT, '自定义文案');
      expect(err.code).assertEqual(OtpErrorCode.SECRET_TOO_SHORT);
      expect(err.message).assertEqual('自定义文案');
      expect(err.message === err.code).assertFalse();
    });
  });
}
