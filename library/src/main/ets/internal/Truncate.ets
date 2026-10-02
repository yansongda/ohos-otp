/**
 * RFC 4226 §5.3 动态截断（纯函数，kit-free）。
 * 只做截断（屏蔽最高位，保证 31 位非负整数），不做取模——取模只在 Digits 完成。
 */
import { OtpError, OtpErrorCode } from '../OtpError';

export function apply(digest: Uint8Array): number {
  if (digest.length < 20) {
    throw new OtpError(OtpErrorCode.CRYPTO_FAILED, 'CRYPTO_FAILED');
  }

  const offset: number = digest[digest.length - 1] & 0x0f;
  // & 0x7f 清掉最高位；末尾 >>> 0 转回无符号 32 位，保证结果为 31 位非负整数。
  const v: number = ((digest[offset] & 0x7f) << 24
    | digest[offset + 1] << 16
    | digest[offset + 2] << 8
    | digest[offset + 3]) >>> 0;
  return v;
}
