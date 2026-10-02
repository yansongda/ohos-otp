/**
 * Counter 整数原语测试。
 * 期望值取自 counterToBytes 对照表（已与 writeBigUInt64BE 参考实现逐位一致），逐字照抄，禁止自行推导。
 */
import { describe, it, expect } from '@ohos/hypium';
import { toBytes, isSafeCounter } from '../main/ets/internal/Counter';
import { OtpErrorCode } from '../main/ets/OtpError';

function expectBytes(actual: Uint8Array, expected: number[]): void {
  expect(actual.length).assertEqual(expected.length);
  for (let i = 0; i < expected.length; i++) {
    expect(actual[i]).assertEqual(expected[i]);
  }
}

export default function counterTest() {
  describe('counterTest', () => {
    it('toBytes(0) 逐字节 == 0000000000000000', 0, () => {
      expectBytes(toBytes(0), [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    });

    it('toBytes(1) 逐字节 == 0000000000000001', 0, () => {
      expectBytes(toBytes(1), [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]);
    });

    it('toBytes(9) 逐字节 == 0000000000000009', 0, () => {
      expectBytes(toBytes(9), [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x09]);
    });

    it('toBytes(666666666) 逐字节 == 0000000027bc86aa', 0, () => {
      expectBytes(toBytes(666666666), [0x00, 0x00, 0x00, 0x00, 0x27, 0xbc, 0x86, 0xaa]);
    });

    it('toBytes(4294967295) 逐字节 == 00000000ffffffff', 0, () => {
      expectBytes(toBytes(4294967295), [0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff]);
    });

    it('toBytes(4294967296) 逐字节 == 0000000100000000', 0, () => {
      expectBytes(toBytes(4294967296), [0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]);
    });

    it('toBytes(4294967297) 逐字节 == 0000000100000001', 0, () => {
      expectBytes(toBytes(4294967297), [0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01]);
    });

    it('toBytes(4294967391) 逐字节 == 000000010000005f', 0, () => {
      expectBytes(toBytes(4294967391), [0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x5f]);
    });

    it('toBytes(9007199254740991) 逐字节 == 001fffffffffffff', 0, () => {
      expectBytes(toBytes(9007199254740991), [0x00, 0x1f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);
    });

    it('toBytes(-1) → INVALID_COUNTER', 0, () => {
      expect(() => toBytes(-1)).assertThrowError(OtpErrorCode.INVALID_COUNTER);
    });

    it('toBytes(1.5) → INVALID_COUNTER', 0, () => {
      expect(() => toBytes(1.5)).assertThrowError(OtpErrorCode.INVALID_COUNTER);
    });

    it('toBytes(9007199254740992)（2^53）→ INVALID_COUNTER', 0, () => {
      expect(() => toBytes(9007199254740992)).assertThrowError(OtpErrorCode.INVALID_COUNTER);
    });

    it('isSafeCounter 正例：0 / 1 / 4294967296 / 9007199254740991 均为 true', 0, () => {
      expect(isSafeCounter(0)).assertTrue();
      expect(isSafeCounter(1)).assertTrue();
      expect(isSafeCounter(4294967296)).assertTrue();
      expect(isSafeCounter(9007199254740991)).assertTrue();
    });

    it('isSafeCounter 反例：-1 / 1.5 / 9007199254740992 / NaN 均为 false', 0, () => {
      expect(isSafeCounter(-1)).assertFalse();
      expect(isSafeCounter(1.5)).assertFalse();
      expect(isSafeCounter(9007199254740992)).assertFalse();
      expect(isSafeCounter(NaN)).assertFalse();
    });
  });
}
