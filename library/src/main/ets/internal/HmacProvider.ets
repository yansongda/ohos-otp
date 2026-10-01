/**
 * kit-free 解耦层：HMAC / 随机源接口 + 注册表。
 *
 * 本文件是全库唯一的「接口 + 注册表」所在地，**禁止任何 @kit 导入**
 * （T03 已完整实现；T07 不得修改本文件，如发现缺陷向编排方报告）。
 * 公开类与 Secret 只依赖本层，通过注册表取用默认实现；
 * 真实 cryptoFramework 实现见 internal/CryptoSource.ets（全库唯一 @kit 导入点）。
 */
import { OtpError, OtpErrorCode } from '../OtpError';
import { OtpAlgorithm } from '../OtpOptions';

/**
 * HMAC 抽象接口。
 */
export interface HmacProvider {
  sign(algorithm: OtpAlgorithm, key: Uint8Array, message: Uint8Array): Uint8Array;
}

/**
 * 随机数抽象接口。
 */
export interface RandomSource {
  random(bytes: number): Uint8Array;
}

// 模块级单例（默认未注册；由 installCryptoDefaults 或测试注入）
let hmacProvider: HmacProvider | null = null;
let randomSource: RandomSource | null = null;

/**
 * 注册 HMAC 实现（幂等覆盖）。
 */
export function registerHmac(provider: HmacProvider): void {
  hmacProvider = provider;
}

/**
 * 取用 HMAC 实现；未注册时抛 CRYPTO_NOT_INITIALIZED。
 */
export function requireHmac(): HmacProvider {
  if (hmacProvider === null) {
    throw new OtpError(OtpErrorCode.CRYPTO_NOT_INITIALIZED, 'CRYPTO_NOT_INITIALIZED');
  }
  return hmacProvider;
}

/**
 * 注册随机源实现（幂等覆盖）。
 */
export function registerRandom(source: RandomSource): void {
  randomSource = source;
}

/**
 * 取用随机源；未注册时抛 CRYPTO_NOT_INITIALIZED。
 */
export function requireRandom(): RandomSource {
  if (randomSource === null) {
    throw new OtpError(OtpErrorCode.CRYPTO_NOT_INITIALIZED, 'CRYPTO_NOT_INITIALIZED');
  }
  return randomSource;
}

/**
 * 测试专用：清空两个单例，供测试验证未注册分支。
 * @internal
 */
export function resetForTest(): void {
  hmacProvider = null;
  randomSource = null;
}
