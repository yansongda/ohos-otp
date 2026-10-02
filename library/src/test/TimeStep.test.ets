/**
 * 时间步/剩余秒/进度/恒定时间比较 单测。
 * 期望值来自设计 §3.3 参照点表；每条断言前先写出 s = floor(ms/1000) 的推导。
 */
import { describe, it, expect } from '@ohos/hypium';
import { step, remainingSec, progress, constantTimeEquals } from '../main/ets/internal/TimeStep';

export default function timeStepTest() {
  describe('timeStepTest', () => {
    // ── step：s = floor(epochMs/1000)，返回 floor((s - t0) / period) ──
    it('step59000_0_30', 0, () => {
      // s = floor(59000/1000) = 59；floor((59-0)/30) = floor(59/30) = 1
      expect(step(59000, 0, 30)).assertEqual(1);
    });
    it('step30000_0_30', 0, () => {
      // s = floor(30000/1000) = 30；floor(30/30) = 1
      expect(step(30000, 0, 30)).assertEqual(1);
    });
    it('step29999_0_30', 0, () => {
      // s = floor(29999/1000) = 29；floor(29/30) = 0
      expect(step(29999, 0, 30)).assertEqual(0);
    });
    it('step20000000000000_0_30', 0, () => {
      // RFC 6238 最大向量：s = 20000000000000/1000 = 20000000000；
      // floor(20000000000/30) = 666666666.66… → 666666666
      expect(step(20000000000000, 0, 30)).assertEqual(666666666);
    });
    it('step1000_0_30', 0, () => {
      // s = floor(1000/1000) = 1；floor(1/30) = 0
      expect(step(1000, 0, 30)).assertEqual(0);
    });
    it('step31000_1_30', 0, () => {
      // s = floor(31000/1000) = 31；t0=1；floor((31-1)/30) = floor(30/30) = 1
      expect(step(31000, 1, 30)).assertEqual(1);
    });
    it('step1000_5_30_negative', 0, () => {
      // s = floor(1000/1000) = 1；t0=5（大于当前秒）；
      // floor((1-5)/30) = floor(-0.133…) = -1（负 step，供上层抛 INVALID_COUNTER）
      expect(step(1000, 5, 30)).assertEqual(-1);
    });

    // ── remainingSec：period - (((s - t0) % period) + period) % period，落在 [1, period] ──
    it('remainingSec59000_0_30', 0, () => {
      // s = 59；((59%30)+30)%30 = (29+30)%30 = 29；30-29 = 1（参照点 s=59,p=30 → 1）
      expect(remainingSec(59000, 0, 30)).assertEqual(1);
    });
    it('remainingSec60000_0_30', 0, () => {
      // s = 60；((60%30)+30)%30 = 0；30-0 = 30（参照点 s=60,p=30 → 30）
      expect(remainingSec(60000, 0, 30)).assertEqual(30);
    });
    it('remainingSec1000_0_30', 0, () => {
      // s = 1；((1%30)+30)%30 = 1；30-1 = 29（参照点 s=1,p=30 → 29）
      expect(remainingSec(1000, 0, 30)).assertEqual(29);
    });
    it('remainingSec1000_0_45', 0, () => {
      // s = 1；((1%45)+45)%45 = 1；45-1 = 44
      expect(remainingSec(1000, 0, 45)).assertEqual(44);
    });
    it('remainingSec45000_0_45', 0, () => {
      // s = 45；((45%45)+45)%45 = 0；45-0 = 45（参照点 s=45,p=45 → 45）
      expect(remainingSec(45000, 0, 45)).assertEqual(45);
    });

    // ── t0≠0 专项：锁定 t0 偏移与负值归一化（无此组用例时，实现丢掉 t0 也不会红）──
    it('remainingSec31000_1_30', 0, () => {
      // s = 31；((31-1)%30+30)%30 = (0+30)%30 = 0 → 30-0 = 30
      expect(remainingSec(31000, 1, 30)).assertEqual(30);
    });
    it('remainingSec1000_5_30', 0, () => {
      // s = 1；((1-5)%30+30)%30 = ((-4)+30)%30 = 26 → 30-26 = 4（负值归一化）
      expect(remainingSec(1000, 5, 30)).assertEqual(4);
    });

    // ── progress：(((s - t0) % period) + period) % period / period，落在 [0, 1) ──
    it('progress15000_0_30', 0, () => {
      // s = 15；((15%30)+30)%30 = 15；15/30 = 0.5
      expect(progress(15000, 0, 30)).assertEqual(0.5);
    });
    it('progress1000_0_30_close_1over30', 0, () => {
      // s = 1；((1%30)+30)%30 = 1；1/30 ≈ 0.0333。
      // 用相对误差断言（容差 1e-6）：1/30 的二进制表示与 JS 除法结果一致，diff=0。
      expect(progress(1000, 0, 30)).assertClose(1 / 30, 1e-6);
    });
    it('progress45000_0_45', 0, () => {
      // s = 45；((45%45)+45)%45 = 0；0/45 = 0
      expect(progress(45000, 0, 45)).assertEqual(0);
    });
    it('progress31000_1_30', 0, () => {
      // s = 31；((31-1)%30+30)%30 = 0；0/30 = 0（t0≠0 偏移后回到步起点）
      expect(progress(31000, 1, 30)).assertEqual(0);
    });

    // ── constantTimeEquals：恒定时间比较，长度不等才早退 ──
    it('constantTimeEquals_same', 0, () => {
      expect(constantTimeEquals('123456', '123456')).assertTrue();
    });
    it('constantTimeEquals_diff_last_char', 0, () => {
      expect(constantTimeEquals('123456', '123457')).assertFalse();
    });
    it('constantTimeEquals_diff_length', 0, () => {
      expect(constantTimeEquals('12345', '123456')).assertFalse();
    });
    it('constantTimeEquals_empty', 0, () => {
      expect(constantTimeEquals('', '')).assertTrue();
    });
    it('constantTimeEquals_multibyte', 0, () => {
      // charCodeAt 按 UTF-16 码元逐字符异或，多字节字符同样可比较
      expect(constantTimeEquals('你', '你')).assertTrue();
    });

    // ── 非法输入 ──
    it('stepInvalidTimestamp', 0, () => {
      // epochMs = 0 不满足 > 0 → INVALID_TIMESTAMP
      expect(() => { step(0, 0, 30); }).assertThrowError('INVALID_TIMESTAMP');
    });
    it('stepInvalidT0', 0, () => {
      // t0 = -1 不满足 ≥ 0 → INVALID_T0
      expect(() => { step(1, -1, 30); }).assertThrowError('INVALID_T0');
    });
    it('stepInvalidPeriodZero', 0, () => {
      // period = 0 不满足正整数 → INVALID_PERIOD
      expect(() => { step(1, 0, 0); }).assertThrowError('INVALID_PERIOD');
    });
    it('stepInvalidPeriodFraction', 0, () => {
      // period = 1.5 不满足整数 → INVALID_PERIOD
      expect(() => { step(1, 0, 1.5); }).assertThrowError('INVALID_PERIOD');
    });
  });
}
