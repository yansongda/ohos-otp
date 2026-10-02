/**
 * 取模 + 左补零位数格式化（纯函数，kit-free）。
 * 左补零用逐字符前置 '0' 实现，不依赖运行时字符串补位 API（规避 ArkTS 兼容性不确定性）。
 */
import { OtpError, OtpErrorCode } from '../OtpError';

export function isValidDigits(digits: number): boolean {
  return digits === 6 || digits === 7 || digits === 8;
}

export function format(value: number, digits: number): string {
  if (!isValidDigits(digits)) {
    throw new OtpError(OtpErrorCode.INVALID_DIGITS, 'INVALID_DIGITS');
  }

  let text: string = String(value % Math.pow(10, digits));
  while (text.length < digits) {
    text = '0' + text;
  }
  return text;
}
