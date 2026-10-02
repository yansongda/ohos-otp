/**
 * 编排层：counter → code 全链路（纯函数，接收注入 provider，kit-free）。
 * 取模只在 Digits.format 内做一次；verify 扫完全部候选后才返回首个命中 delta。
 */
import { OtpError, OtpErrorCode } from '../OtpError';
import { OtpAlgorithm } from '../OtpOptions';
import { HmacProvider } from './HmacProvider';
import { isSafeCounter, toBytes } from './Counter';
import { apply as truncateApply } from './Truncate';
import { format as formatDigits } from './Digits';
import { constantTimeEquals } from './TimeStep';

export interface EngineParams {
  algorithm: OtpAlgorithm;
  digits: number;
  key: Uint8Array;
}

export function generate(provider: HmacProvider, params: EngineParams, counter: number): string {
  const digest: Uint8Array = provider.sign(params.algorithm, params.key, toBytes(counter));
  return formatDigits(truncateApply(digest), params.digits);
}

/** token 必须为纯数字（可空串以外），逐字符校验，避免正则。 */
function isNumericToken(token: string): boolean {
  if (token.length === 0) {
    return false;
  }
  for (let i = 0; i < token.length; i++) {
    const c: number = token.charCodeAt(i);
    if (c < 48 || c > 57) {
      return false;
    }
  }
  return true;
}

export function verify(provider: HmacProvider, params: EngineParams, token: string, counter: number, window: number): number | null {
  if (!isNumericToken(token) || token.length !== params.digits) {
    throw new OtpError(OtpErrorCode.INVALID_TOKEN, 'INVALID_TOKEN');
  }
  if (!Number.isInteger(window) || window < 0) {
    throw new OtpError(OtpErrorCode.INVALID_WINDOW, 'INVALID_WINDOW');
  }

  let firstMatch: number | null = null;
  for (let delta: number = -window; delta <= window; delta++) {
    const candidate: number = counter + delta;
    if (candidate < 0 || !isSafeCounter(candidate)) {
      continue;
    }
    const candidateToken: string = generate(provider, params, candidate);
    if (constantTimeEquals(candidateToken, token)) {
      if (firstMatch === null) {
        firstMatch = delta;
      }
    }
  }
  return firstMatch;
}
