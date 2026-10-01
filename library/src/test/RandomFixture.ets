/**
 * 可注入随机源 fixture（固定递增序列）。
 * 占位：本文件唯一所有者是 T08，由 T08 补实现（T09 不得创建或修改）。
 */
import { RandomSource } from '../main/ets/internal/HmacProvider';

export class RandomFixture implements RandomSource {
  random(bytes: number): Uint8Array {
    // TODO(T08): 由对应 todo 替换为真实实现
    throw new Error('RandomFixture 占位：由 T08 实现');
  }
}
