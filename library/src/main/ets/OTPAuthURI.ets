/**
 * OTPAuthURI：otpauth:// URI 解析与生成（纯解析层，kit-free）。
 * TODO(T08): 由对应 todo 替换为真实实现
 */
import { OtpError, OtpErrorCode } from './OtpError';
import { OtpAuthParams } from './OtpOptions';

export class OTPAuthURI {
  static parse(uri: string): OtpAuthParams {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }

  static build(params: OtpAuthParams): string {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }
}
