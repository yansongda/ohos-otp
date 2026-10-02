/**
 * Digits 取模 + 左补零位数格式化测试。
 * 期望值来自执行计划附录 A.2/A.6 的权威码值（取模于 10^digits 后左补零），照抄，不自行推导。
 */
import { describe, it, expect } from '@ohos/hypium';
import { format, isValidDigits } from '../main/ets/internal/Digits';
import { OtpErrorCode } from '../main/ets/OtpError';

export default function digitsTest() {
  describe('digitsTest', () => {
    it('format(287082,6) === 287082', 0, () => {
      expect(format(287082, 6)).assertEqual('287082');
    });

    it('format(1234,6) === 001234', 0, () => {
      expect(format(1234, 6)).assertEqual('001234');
    });

    it('format(0,6) === 000000', 0, () => {
      expect(format(0, 6)).assertEqual('000000');
    });

    it('format(755224,6) === 755224', 0, () => {
      expect(format(755224, 6)).assertEqual('755224');
    });

    it('format(4287082,7) === 4287082', 0, () => {
      expect(format(4287082, 7)).assertEqual('4287082');
    });

    it('format(84755224,8) === 84755224', 0, () => {
      expect(format(84755224, 8)).assertEqual('84755224');
    });

    it('format(137359152,8) === 37359152', 0, () => {
      expect(format(137359152, 8)).assertEqual('37359152');
    });

    it('format(1,5) → INVALID_DIGITS', 0, () => {
      expect(() => format(1, 5)).assertThrowError(OtpErrorCode.INVALID_DIGITS);
    });

    it('format(1,9) → INVALID_DIGITS', 0, () => {
      expect(() => format(1, 9)).assertThrowError(OtpErrorCode.INVALID_DIGITS);
    });

    it('isValidDigits：6/7/8 为 true，5/9 为 false', 0, () => {
      expect(isValidDigits(6)).assertTrue();
      expect(isValidDigits(7)).assertTrue();
      expect(isValidDigits(8)).assertTrue();
      expect(isValidDigits(5)).assertFalse();
      expect(isValidDigits(9)).assertFalse();
    });
  });
}
