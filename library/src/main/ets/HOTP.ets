/**
 * HOTP（RFC 4226）公开类。kit-free：默认 provider 经 requireHmac() 取用。
 */
import { OtpError, OtpErrorCode } from './OtpError';
import { HotpOptions, OtpAlgorithm, OtpType, VerifyOptions } from './OtpOptions';
import { HmacProvider, requireHmac } from './internal/HmacProvider';
import { isSafeCounter } from './internal/Counter';
import { isValidDigits } from './internal/Digits';
import { generate as engineGenerate, verify as engineVerify, EngineParams } from './internal/OtpEngine';
import { Secret } from './Secret';
import { OTPAuthURI } from './OTPAuthURI';

export class HOTP {
  private readonly _provider: HmacProvider;
  private readonly _secret: Secret;
  private readonly _algorithm: OtpAlgorithm;
  private readonly _digits: number;
  private readonly _counter: number;
  private readonly _issuer: string | undefined;
  private readonly _account: string | undefined;

  /** @internal 仅供测试注入 */
  constructor(options: HotpOptions, provider?: HmacProvider) {
    const secret: Secret = Secret.fromBase32(options.secret);
    const algorithm: OtpAlgorithm = options.algorithm === undefined ? OtpAlgorithm.SHA1 : options.algorithm;
    const digits: number = options.digits === undefined ? 6 : options.digits;
    const counter: number = options.counter === undefined ? 0 : options.counter;
    const minSecretBits: number = options.minSecretBits === undefined ? 0 : options.minSecretBits;

    if (!isValidDigits(digits)) {
      throw new OtpError(OtpErrorCode.INVALID_DIGITS, 'INVALID_DIGITS');
    }
    if (!isSafeCounter(counter)) {
      throw new OtpError(OtpErrorCode.INVALID_COUNTER, 'INVALID_COUNTER');
    }
    if (minSecretBits > 0 && secret.bitLength < minSecretBits) {
      throw new OtpError(OtpErrorCode.SECRET_TOO_WEAK, 'SECRET_TOO_WEAK');
    }

    this._provider = provider === undefined ? requireHmac() : provider;
    this._secret = secret;
    this._algorithm = algorithm;
    this._digits = digits;
    this._counter = counter;
    this._issuer = options.issuer;
    this._account = options.account;
  }

  private params(): EngineParams {
    return { algorithm: this._algorithm, digits: this._digits, key: this._secret.bytes };
  }

  /** 生成验证码；counter 缺省用构造值。 */
  generate(counter?: number): string {
    const c: number = counter === undefined ? this._counter : counter;
    return engineGenerate(this._provider, this.params(), c);
  }

  /**
   * 恒定时间比对；counter 缺省用构造值、window 缺省 0。
   * 返回命中 counter 相对基准的偏移（步=1），未命中 null。
   */
  verify(token: string, options?: VerifyOptions): number | null {
    const c: number = options === undefined || options.counter === undefined ? this._counter : options.counter;
    const window: number = options === undefined || options.window === undefined ? 0 : options.window;
    return engineVerify(this._provider, this.params(), token, c, window);
  }

  /** 输出规范 otpauth://hotp/ URI。 */
  toURI(): string {
    return OTPAuthURI.build({
      type: OtpType.HOTP,
      secret: this._secret.toBase32(),
      algorithm: this._algorithm,
      digits: this._digits,
      counter: this._counter,
      issuer: this._issuer,
      account: this._account
    });
  }

  /** 从 otpauth URI 构造；URI 类型非 hotp（如 totp）抛 UNSUPPORTED_OTPAUTH_TYPE。 */
  static fromURI(uri: string): HOTP {
    const params = OTPAuthURI.parse(uri);
    if (params.type !== OtpType.HOTP) {
      throw new OtpError(OtpErrorCode.UNSUPPORTED_OTPAUTH_TYPE, 'UNSUPPORTED_OTPAUTH_TYPE');
    }
    return new HOTP({
      secret: params.secret,
      algorithm: params.algorithm,
      digits: params.digits,
      counter: params.counter === undefined ? 0 : params.counter,
      issuer: params.issuer,
      account: params.account
    });
  }
}
