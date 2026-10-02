/**
 * RFC 4648 §6 base32 编解码（纯函数，kit-free）。
 * 字母表 A-Z + 2-7；解码宽松（容忍空白/大小写/尾部 '='），编码输出大写无填充。
 */
import { OtpError, OtpErrorCode } from '../OtpError';

const BASE32_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/**
 * RFC 4648 §6 解码：去空白 → 去尾部 '=' → 转大写。
 * 空串抛 EMPTY_SECRET；非法字符抛 INVALID_BASE32_CHAR；解码长度 0 抛 SECRET_TOO_SHORT。
 * 实现：按 8 字符一组（组宽 5 字节）位拼接，缺位补 0，末组按剩余有效位截断。
 */
export function decode(input: string): Uint8Array {
  const normalized: string = input.replace(/\s/g, '').replace(/=+$/, '').toUpperCase();

  if (0 === normalized.length) {
    throw new OtpError(OtpErrorCode.EMPTY_SECRET, 'EMPTY_SECRET');
  }

  for (let i = 0; i < normalized.length; i++) {
    if (-1 === BASE32_ALPHABET.indexOf(normalized.charAt(i))) {
      throw new OtpError(OtpErrorCode.INVALID_BASE32_CHAR, 'INVALID_BASE32_CHAR');
    }
  }

  const length: number = Math.floor(normalized.length * 5 / 8);
  if (0 === length) {
    throw new OtpError(OtpErrorCode.SECRET_TOO_SHORT, 'SECRET_TOO_SHORT');
  }

  const result: Uint8Array = new Uint8Array(length);
  let outIndex: number = 0;

  for (let start = 0; start < normalized.length; start += 8) {
    const end: number = Math.min(start + 8, normalized.length);
    const groupLength: number = end - start;

    const buf: number[] = [];
    for (let i = start; i < end; i++) {
      buf.push(BASE32_ALPHABET.indexOf(normalized.charAt(i)));
    }
    for (let i = 0; i < 8 - groupLength; i++) {
      buf.push(0);
    }

    const bytesInGroup: number = Math.floor(groupLength * 5 / 8);

    // RFC 4648 位拼接；每字节 & 0xff 收敛为无符号字节。
    if (bytesInGroup >= 1) {
      result[outIndex] = (buf[0] << 3 | buf[1] >> 2) & 0xff;
    }
    if (bytesInGroup >= 2) {
      result[outIndex + 1] = (buf[1] << 6 | buf[2] << 1 | buf[3] >> 4) & 0xff;
    }
    if (bytesInGroup >= 3) {
      result[outIndex + 2] = (buf[3] << 4 | buf[4] >> 1) & 0xff;
    }
    if (bytesInGroup >= 4) {
      result[outIndex + 3] = (buf[4] << 7 | buf[5] << 2 | buf[6] >> 3) & 0xff;
    }
    if (bytesInGroup >= 5) {
      result[outIndex + 4] = (buf[6] << 5 | buf[7]) & 0xff;
    }
    outIndex += bytesInGroup;
  }

  return result;
}

/**
 * RFC 4648 §6 编码（大写、无填充）。输出字符数 = ceil(len*8/5)；空数组返回空串（不抛错，语义由调用方定）。
 * 实现：8 位进 / 5 位出的位缓冲拼接，不经过逐字符二进制字符串。
 */
export function encode(bytes: Uint8Array): string {
  if (0 === bytes.length) {
    return '';
  }

  let result: string = '';
  let buffer: number = 0;
  let bitsLeft: number = 0;
  for (let i = 0; i < bytes.length; i++) {
    buffer = (buffer << 8) | bytes[i];
    bitsLeft += 8;
    while (bitsLeft >= 5) {
      result += BASE32_ALPHABET.charAt((buffer >>> (bitsLeft - 5)) & 31);
      bitsLeft -= 5;
    }
  }
  // 末组余量左移补 0（无填充）。
  if (bitsLeft > 0) {
    result += BASE32_ALPHABET.charAt((buffer << (5 - bitsLeft)) & 31);
  }
  return result;
}
