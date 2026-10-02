/**
 * Secret：secret 规范化 / 校验 / 随机生成 / toJSON 脱敏。
 *
 * 本文件禁止 import kit（kit-free）；
 * 随机源经 internal/HmacProvider 的 requireRandom() 取用。
 * 刻意不实现 toString()：避免 String()/模板字符串把密钥明文暴露给日志或 UI
 * （脱敏统一由 toJSON() 承担，JSON.stringify 会调用它，T02 已实测）。
 */
import { OtpError, OtpErrorCode } from './OtpError';
import { decode, encode } from './internal/Base32';
import { requireRandom } from './internal/HmacProvider';

export class Secret {
  private _bytes: Uint8Array;

  private constructor(bytes: Uint8Array) {
    this._bytes = bytes;
  }

  /**
   * 从 base32 字符串构造：Base32.decode 宽松解析（容忍大小写/空白/填充）。
   * 解码结果长度为 0 抛 EMPTY_SECRET（decode 对空串本身抛 EMPTY_SECRET，此处兜底防御）。
   */
  static fromBase32(input: string): Secret {
    const bytes: Uint8Array = decode(input);
    if (0 === bytes.length) {
      throw new OtpError(OtpErrorCode.EMPTY_SECRET, 'EMPTY_SECRET');
    }
    return new Secret(bytes);
  }

  /**
   * 从字节数组构造：空数组抛 EMPTY_SECRET；必须拷贝入参，杜绝外部引用共享。
   */
  static fromBytes(bytes: Uint8Array): Secret {
    if (0 === bytes.length) {
      throw new OtpError(OtpErrorCode.EMPTY_SECRET, 'EMPTY_SECRET');
    }
    return new Secret(new Uint8Array(bytes));
  }

  /**
   * 随机生成 bytes 字节的 secret（默认 20 字节 = RFC 4226 推荐 160 bit）。
   * 校验 bytes 为 [1, 4096] 整数，否则抛 SECRET_TOO_WEAK
   * （该错误码选择理由见 evidence：与内部随机源实现对 [1, 4096] 边界使用同一错误码，
   *  且设计 §3.3 把「随机强度不足」归入 SECRET_TOO_WEAK）。
   * 随机源经注册表 requireRandom() 取用（本文件不 import kit）。
   */
  static generate(bytes: number = 20): Secret {
    if (!Number.isInteger(bytes) || bytes < 1 || bytes > 4096) {
      throw new OtpError(OtpErrorCode.SECRET_TOO_WEAK, 'SECRET_TOO_WEAK');
    }
    return new Secret(new Uint8Array(requireRandom().random(bytes)));
  }

  /**
   * 字节视图：返回拷贝，外部改动不影响内部。
   */
  get bytes(): Uint8Array {
    return new Uint8Array(this._bytes);
  }

  get byteLength(): number {
    return this._bytes.length;
  }

  get bitLength(): number {
    return this._bytes.length * 8;
  }

  /**
   * 规范化输出：大写、无填充 base32。
   */
  toBase32(): string {
    return encode(this._bytes);
  }

  /**
   * 序列化脱敏：JSON.stringify 会调用本方法（T02 实测），返回固定 '[REDACTED]'，不泄漏密钥。
   */
  toJSON(): string {
    return '[REDACTED]';
  }
}
