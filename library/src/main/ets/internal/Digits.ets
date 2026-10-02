/**
 * 取模 + 左补零格式化（纯函数，kit-free）。
 * 取模是本库唯一发生点；补零用逐字符前置 '0'，规避 ArkTS 字符串补位 API 的可用性不确定性。
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
