/**
 * RFC 4648 base32 编解码（纯函数，kit-free）。
 * TODO(T04): 由对应 todo 替换为真实实现
 */
import { OtpError, OtpErrorCode } from '../OtpError';

export function decode(input: string): Uint8Array {
  // TODO(T04): 由对应 todo 替换为真实解码实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}

export function encode(bytes: Uint8Array): string {
  // TODO(T04): 由对应 todo 替换为真实编码实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}
