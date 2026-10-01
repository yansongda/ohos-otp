/**
 * Secret：secret 规范化 / 校验 / 编解码 / 随机生成 / toJSON 脱敏。
 *
 * 本文件禁止 import kit（kit-free）；
 * 随机源经 internal/HmacProvider 的 requireRandom() 取用。
 * TODO(T08): 由对应 todo 替换为真实实现
 */
import { OtpError, OtpErrorCode } from './OtpError';

export class Secret {
  static fromBase32(input: string): Secret {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  static fromBytes(bytes: Uint8Array): Secret {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  static generate(byteLength: number = 20): Secret {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  toBase32(): string {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  get bytes(): Uint8Array {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  get byteLength(): number {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  get bitLength(): number {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  toJSON(): string {
    // TODO(T08): 由对应 todo 替换为真实实现（返回 '[REDACTED]'）
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }
}
