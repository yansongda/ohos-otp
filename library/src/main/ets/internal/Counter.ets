/**
 * 计数器 → 8 字节大端字节数组（纯函数，kit-free）。
 * TODO(T05): 由对应 todo 替换为真实实现
 */
import { OtpError, OtpErrorCode } from '../OtpError';

export function toBytes(counter: number): Uint8Array {
  // TODO(T05): 由对应 todo 替换为真实实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}

export function isSafeCounter(value: number): boolean {
  // TODO(T05): 由对应 todo 替换为真实实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}
