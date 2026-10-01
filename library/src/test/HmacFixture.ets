/**
 * 可注入 HMAC fixture（黄金 digest 查表）。
 * 占位：由 T09 补实现（未命中必须抛错，绝不返回零值数组）。
 */
import { HmacProvider } from '../main/ets/internal/HmacProvider';
import { OtpAlgorithm } from '../main/ets/OtpOptions';

export class HmacFixture implements HmacProvider {
  sign(algorithm: OtpAlgorithm, key: Uint8Array, message: Uint8Array): Uint8Array {
    // TODO(T09): 由对应 todo 替换为真实查表实现
    throw new Error('HmacFixture 占位：由 T09 实现');
  }
}

export function buildRfcFixture(): HmacFixture {
  // TODO(T09): 由对应 todo 替换为真实装表实现
  throw new Error('buildRfcFixture 占位：由 T09 实现');
}
