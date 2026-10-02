/**
 * Secret：secret 规范化 / 校验 / 随机生成 / toJSON 脱敏（kit-free，随机源经 requireRandom()）。
 *
 * 刻意不实现 toString()：避免 String()/模板字符串把密钥明文带入日志或 UI；
 * 脱敏由 toJSON() 承担——JSON.stringify 会调用它，而 private 只是编译期约束。
 */
import { OtpError, OtpErrorCode } from './OtpError';
import { decode, encode } from './internal/Base32';
import { requireRandom } from './internal/HmacProvider';

export class Secret {
  private _bytes: Uint8Array;

  private constructor(bytes: Uint8Array) {
    this._bytes = bytes;
  }

  /** 从 base32 字符串构造，宽松解析（容忍大小写/空白/填充）；空结果抛 EMPTY_SECRET。 */
  static fromBase32(input: string): Secret {
    const bytes: Uint8Array = decode(input);
    if (0 === bytes.length) {
      throw new OtpError(OtpErrorCode.EMPTY_SECRET, 'EMPTY_SECRET');
    }
    return new Secret(bytes);
  }

  /** 从字节数组构造（拷贝入参，杜绝外部引用共享）；空数组抛 EMPTY_SECRET。 */
  static fromBytes(bytes: Uint8Array): Secret {
    if (0 === bytes.length) {
      throw new OtpError(OtpErrorCode.EMPTY_SECRET, 'EMPTY_SECRET');
    }
    return new Secret(new Uint8Array(bytes));
  }

  /**
   * 随机生成 bytes 字节 secret（默认 20 字节 = RFC 4226 推荐 160 bit）。
   * bytes 须为 [1, 4096] 整数，否则抛 SECRET_TOO_WEAK（与内部随机源的边界同一错误码）。
   */
  static generate(bytes: number = 20): Secret {
    if (!Number.isInteger(bytes) || bytes < 1 || bytes > 4096) {
      throw new OtpError(OtpErrorCode.SECRET_TOO_WEAK, 'SECRET_TOO_WEAK');
    }
    return new Secret(new Uint8Array(requireRandom().random(bytes)));
  }

  /** 字节视图：返回拷贝，外部改动不影响内部。 */
  get bytes(): Uint8Array {
    return new Uint8Array(this._bytes);
  }

  get byteLength(): number {
    return this._bytes.length;
  }

  get bitLength(): number {
    return this._bytes.length * 8;
  }

  /** 规范化输出：大写、无填充 base32。 */
  toBase32(): string {
    return encode(this._bytes);
  }

  /** 序列化脱敏：JSON.stringify 会调用本方法，固定返回 '[REDACTED]'，不泄漏密钥。 */
  toJSON(): string {
    return '[REDACTED]';
  }
}
