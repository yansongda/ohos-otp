/**
 * kit-only 实现层：cryptoFramework 的 HMAC / 随机源实现。
 *
 * ⚠️ 本文件是全库唯一允许 `import { cryptoFramework } from '@kit.CryptoArchitectureKit'`
 * 的地方；只被 library/Index.ets 值导入（installCryptoDefaults），
 * 公开类与 Secret 严禁 import 本文件。
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { OtpError, OtpErrorCode } from '../OtpError';
import { OtpAlgorithm } from '../OtpOptions';
import { HmacProvider, RandomSource, registerHmac, registerRandom } from './HmacProvider';

/**
 * 将 OtpAlgorithm 映射为 cryptoFramework 的 HMAC 算法名（'SHA1'|'SHA256'|'SHA512'）。
 */
function toMacAlgName(algorithm: OtpAlgorithm): string {
  switch (algorithm) {
    case OtpAlgorithm.SHA1:
      return 'SHA1';
    case OtpAlgorithm.SHA256:
      return 'SHA256';
    case OtpAlgorithm.SHA512:
      return 'SHA512';
  }
}

/**
 * cryptoFramework HMAC 实现（同步 *Sync 链路）。
 *
 * 密钥生成器必须用通用 'HMAC' 规格（官方支持 [1, 4096] 字节任意长度密钥）；
 * 严禁用管道符拼接算法名的组合规格（如 HMAC 管道符 SHA1）——该组合规格
 * 要求密钥长度恰等于摘要长度，会拒绝 80 bit（10 字节）的真实 secret（历史坑）。
 */
export class CryptoFrameworkHmac implements HmacProvider {
  sign(algorithm: OtpAlgorithm, key: Uint8Array, message: Uint8Array): Uint8Array {
    try {
      const gen = cryptoFramework.createSymKeyGenerator('HMAC');
      const symKey = gen.convertKeySync({ data: key });
      const mac = cryptoFramework.createMac(toMacAlgName(algorithm));
      mac.initSync(symKey);
      mac.updateSync({ data: message });
      return new Uint8Array(mac.doFinalSync().data);
    } catch (e) {
      // 固定文案：不透传原生错误、不打日志、不含 key/message
      throw new OtpError(OtpErrorCode.CRYPTO_FAILED, 'CRYPTO_FAILED');
    }
  }
}

/**
 * cryptoFramework 随机源实现。
 */
export class CryptoFrameworkRandom implements RandomSource {
  random(bytes: number): Uint8Array {
    if (!(Number.isInteger(bytes) && bytes >= 1 && bytes <= 4096)) {
      throw new OtpError(OtpErrorCode.SECRET_TOO_WEAK, 'SECRET_TOO_WEAK');
    }
    try {
      return new Uint8Array(cryptoFramework.createRandom().generateRandomSync(bytes).data);
    } catch (e) {
      throw new OtpError(OtpErrorCode.CRYPTO_FAILED, 'CRYPTO_FAILED');
    }
  }
}

/**
 * 注册默认 crypto 实现（只 new + 注册，不得发起任何 crypto 调用）。
 */
export function installCryptoDefaults(): void {
  registerHmac(new CryptoFrameworkHmac());
  registerRandom(new CryptoFrameworkRandom());
}
