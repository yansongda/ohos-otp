/**
 * 可注入随机源 fixture（固定递增序列）。
 * random(bytes) 返回 bytes 个连续字节 0x00,0x01,…；lastRequestedBytes 记录最近一次请求长度供断言。
 */
import { RandomSource } from '../main/ets/internal/HmacProvider';

export class RandomFixture implements RandomSource {
  lastRequestedBytes: number = -1;

  random(bytes: number): Uint8Array {
    this.lastRequestedBytes = bytes;
    const result: Uint8Array = new Uint8Array(bytes);
    for (let i = 0; i < bytes; i++) {
      result[i] = i & 0xff;
    }
    return result;
  }
}
