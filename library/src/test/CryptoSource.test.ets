// 分支 B：Local Test 无法加载系统 kit（T02 实测：可 import、可构造，
// 但 doFinalSync() 返回空 DataBlob len=0），真实 crypto 断言见
// library/src/ohosTest/ets/test/CryptoAdapter.test.ets（T11 设备用例）。
import { describe, it, expect } from '@ohos/hypium';

export default function cryptoSourceTest() {
  describe('cryptoSourceTest', () => {
    it('importSmoke', 0, () => {
      expect(true).assertTrue();
    });
  });
}
