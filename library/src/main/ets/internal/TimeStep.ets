/**
 * 时间步/剩余秒/进度/恒定时间比较（纯函数，kit-free）。
 * TODO(T06): 由对应 todo 替换为真实实现
 */
import { OtpError, OtpErrorCode } from '../OtpError';

export function step(epochMs: number, t0: number, period: number): number {
  // TODO(T06): 由对应 todo 替换为真实实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}

export function remainingSec(epochMs: number, t0: number, period: number): number {
  // TODO(T06): 由对应 todo 替换为真实实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}

export function progress(epochMs: number, t0: number, period: number): number {
  // TODO(T06): 由对应 todo 替换为真实实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}

export function constantTimeEquals(a: string, b: string): boolean {
  // TODO(T06): 由对应 todo 替换为真实实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}
