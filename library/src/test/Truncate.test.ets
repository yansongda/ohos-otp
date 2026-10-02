/**
 * Truncate 动态截断测试。
 * 期望值（Truncate 原始值）逐字照抄执行计划附录 A.2 第 4 列（RFC 4226 Appendix D 的权威中间值），
 * 禁止用 digest 自行推导（推导会与被测实现同源，变成自证）。
 */
import { describe, it, expect } from '@ohos/hypium';
import { apply } from '../main/ets/internal/Truncate';
import { OtpErrorCode } from '../main/ets/OtpError';

function hexToBytes(hex: string): Uint8Array {
  const bytes: Uint8Array = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

export default function truncateTest() {
  describe('truncateTest', () => {
    it('counter=0 digest → 1284755224', 0, () => {
      expect(apply(hexToBytes('cc93cf18508d94934c64b65d8ba7667fb7cde4b0'))).assertEqual(1284755224);
    });

    it('counter=1 digest → 1094287082', 0, () => {
      expect(apply(hexToBytes('75a48a19d4cbe100644e8ac1397eea747a2d33ab'))).assertEqual(1094287082);
    });

    it('counter=2 digest → 137359152', 0, () => {
      expect(apply(hexToBytes('0bacb7fa082fef30782211938bc1c5e70416ff44'))).assertEqual(137359152);
    });

    it('counter=3 digest → 1726969429', 0, () => {
      expect(apply(hexToBytes('66c28227d03a2d5529262ff016a1e6ef76557ece'))).assertEqual(1726969429);
    });

    it('counter=4 digest → 1640338314', 0, () => {
      expect(apply(hexToBytes('a904c900a64b35909874b33e61c5938a8e15ed1c'))).assertEqual(1640338314);
    });

    it('counter=5 digest → 868254676', 0, () => {
      expect(apply(hexToBytes('a37e783d7b7233c083d4f62926c7a25f238d0316'))).assertEqual(868254676);
    });

    it('counter=6 digest → 1918287922', 0, () => {
      expect(apply(hexToBytes('bc9cd28561042c83f219324d3c607256c03272ae'))).assertEqual(1918287922);
    });

    it('counter=7 digest → 82162583', 0, () => {
      expect(apply(hexToBytes('a4fb960c0bc06e1eabb804e5b397cdc4b45596fa'))).assertEqual(82162583);
    });

    it('counter=8 digest → 673399871', 0, () => {
      expect(apply(hexToBytes('1b3c89f65e6c9e883012052823443f048b4332db'))).assertEqual(673399871);
    });

    it('counter=9 digest → 645520489', 0, () => {
      expect(apply(hexToBytes('1637409809a679dc698207310c8c7fc07290d9e5'))).assertEqual(645520489);
    });

    it('长度 19 的 digest → CRYPTO_FAILED', 0, () => {
      const short: Uint8Array = new Uint8Array(19);
      expect(() => apply(short)).assertThrowError(OtpErrorCode.CRYPTO_FAILED);
    });
  });
}
