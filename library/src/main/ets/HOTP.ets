/**
 * HOTP（RFC 4226）公开类。
 *
 * 本文件禁止 import kit（kit-free）；
 * 默认 provider 经 internal/HmacProvider 的 requireHmac() 取用。
 * TODO(T10): 由对应 todo 替换为真实实现
 */
import { OtpError, OtpErrorCode } from './OtpError';
import { HotpOptions, VerifyOptions } from './OtpOptions';
import { HmacProvider } from './internal/HmacProvider';

export class HOTP {
  /**
   * @internal 仅测试注入
   */
  constructor(options: HotpOptions, provider?: HmacProvider) {
    // TODO(T10): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  generate(counter?: number): string {
    // TODO(T10): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  verify(token: string, options?: VerifyOptions): number | null {
    // TODO(T10): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  toURI(): string {
    // TODO(T10): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  static fromURI(uri: string): HOTP {
    // TODO(T10): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }
}
