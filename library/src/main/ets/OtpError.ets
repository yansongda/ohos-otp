/**
 * 统一错误模型：错误码枚举（18 个，字符串值）+ OtpError。
 * 消息文案固定，绝不包含 secret/token/派生密钥等用户输入。
 */
export enum OtpErrorCode {
  EMPTY_SECRET = 'EMPTY_SECRET',
  INVALID_BASE32_CHAR = 'INVALID_BASE32_CHAR',
  // 严格 base32 专用：归一化后尾长 ∉ {0,2,4,5,7}，或末尾填充位非 0（宽松模式静默补 0）
  INVALID_BASE32_PADDING = 'INVALID_BASE32_PADDING',
  SECRET_TOO_SHORT = 'SECRET_TOO_SHORT',
  SECRET_TOO_WEAK = 'SECRET_TOO_WEAK',
  INVALID_ALGORITHM = 'INVALID_ALGORITHM',
  INVALID_DIGITS = 'INVALID_DIGITS',
  INVALID_PERIOD = 'INVALID_PERIOD',
  INVALID_T0 = 'INVALID_T0',
  INVALID_COUNTER = 'INVALID_COUNTER',
  INVALID_TIMESTAMP = 'INVALID_TIMESTAMP',
  INVALID_WINDOW = 'INVALID_WINDOW',
  INVALID_TOKEN = 'INVALID_TOKEN',
  CRYPTO_FAILED = 'CRYPTO_FAILED',
  CRYPTO_NOT_INITIALIZED = 'CRYPTO_NOT_INITIALIZED',
  INVALID_OTPAUTH_URI = 'INVALID_OTPAUTH_URI',
  UNSUPPORTED_OTPAUTH_TYPE = 'UNSUPPORTED_OTPAUTH_TYPE',
  NOT_IMPLEMENTED = 'NOT_IMPLEMENTED'
}

/** 统一错误类：调用方可通过 code 精确分支处理。 */
export class OtpError extends Error {
  readonly code: OtpErrorCode;

  constructor(code: OtpErrorCode, message: string) {
    super(message);
    this.code = code;
  }
}
