/**
 * kit-only 实现层：cryptoFramework 的 HMAC / 随机源实现。
 *
 * ⚠️ 本文件是**全库唯一允许** `import { cryptoFramework } from '@kit.CryptoArchitectureKit'`
 * 的地方；只被 library/Index.ets 值导入（installCryptoDefaults），
 * 公开类与 Secret 严禁 import 本文件。
 *
 * TODO(T07): 由对应 todo 替换为真实 cryptoFramework 调用（*Sync 链路 + CRYPTO_FAILED 包装）
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { OtpError, OtpErrorCode } from '../OtpError';
import { OtpAlgorithm } from '../OtpOptions';
import { HmacProvider, RandomSource, registerHmac, registerRandom } from './HmacProvider';

/**
 * cryptoFramework HMAC 实现。
 */
export class CryptoFrameworkHmac implements HmacProvider {
  sign(algorithm: OtpAlgorithm, key: Uint8Array, message: Uint8Array): Uint8Array {
    // TODO(T07): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }
}

/**
 * cryptoFramework 随机源实现。
 */
export class CryptoFrameworkRandom implements RandomSource {
  random(bytes: number): Uint8Array {
    // TODO(T07): 由对应 todo 替换为真实实现
    throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
  }
}

/**
 * 注册默认 crypto 实现（只 new + 注册，不得发起任何 crypto 调用）。
 */
export function installCryptoDefaults(): void {
  // TODO(T07): 由对应 todo 替换为 new + registerHmac/registerRandom
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}
