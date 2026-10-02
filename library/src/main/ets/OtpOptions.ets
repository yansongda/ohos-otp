/**
 * 对外选项/返回类型（DTO）。字段名与可选性为冻结契约，仅允许新增可选字段。
 */

/**
 * 算法枚举（字符串值，RFC 6238 §1.2）。
 */
export enum OtpAlgorithm {
  SHA1 = 'SHA1',
  SHA256 = 'SHA256',
  SHA512 = 'SHA512'
}

/**
 * OTP 类型枚举（otpauth URI 的 type 参数）。
 */
export enum OtpType {
  TOTP = 'totp',
  HOTP = 'hotp'
}

/** HMAC 通用选项（HOTP/TOTP 共用基类字段）。 */
export interface HmacOptions {
  secret: string; // 必填；base32，宽松解析（容忍大小写/空白/填充）
  algorithm?: OtpAlgorithm; // 默认 SHA1；SHA1 | SHA256 | SHA512
  digits?: number; // 默认 6；仅允许 6 | 7 | 8（RFC 4226 §5.3）
  minSecretBits?: number; // 默认 0=不强制；设 128 启用 RFC 4226 §4 R6 校验
}

/** TOTP 选项（RFC 6238）。 */
export interface TotpOptions extends HmacOptions {
  period?: number; // 默认 30（RFC 6238 §5.2 推荐值），正整数秒
  t0?: number; // 默认 0（RFC 6238 §4.1 的 T0，单位秒）
  clockOffsetMs?: number; // 默认 0；时钟偏移补偿，仅 TOTP 有效（见 syncClockOffset）
  issuer?: string; // 仅用于 toURI()
  account?: string; // 仅用于 toURI()
}

/** HOTP 选项（RFC 4226）。 */
export interface HotpOptions extends HmacOptions {
  counter?: number; // 默认 0
  issuer?: string; // 仅用于 toURI()
  account?: string; // 仅用于 toURI()
}

/** verify 校验选项。 */
export interface VerifyOptions {
  timestamp?: number; // epoch ms，仅 TOTP，默认 Date.now()
  counter?: number; // 仅 HOTP，默认构造时的 counter
  window?: number; // 漂移窗口（步），默认 0
}

/** otpauth URI 解析/构建的中间参数形态。 */
export interface OtpAuthParams {
  type: OtpType; // 必填
  secret: string; // 必填；规范化大写无填充 base32
  algorithm: OtpAlgorithm; // 解析/构建均填实值
  digits: number; // 解析/构建均填实值
  period?: number; // 仅 TOTP，默认 30
  counter?: number; // 仅 HOTP，默认 0
  issuer?: string; // 可选
  account?: string; // 可选
  label?: string; // 可选
}
