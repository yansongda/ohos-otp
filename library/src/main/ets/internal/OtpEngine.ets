/**
 * 编排层：counter → code 全链路（纯函数，接收注入 provider，kit-free）。
 * TODO(T09): 由对应 todo 替换为真实实现
 */
import { OtpError, OtpErrorCode } from '../OtpError';
import { OtpAlgorithm } from '../OtpOptions';
import { HmacProvider } from './HmacProvider';

export interface EngineParams {
  algorithm: OtpAlgorithm;
  digits: number;
  key: Uint8Array;
}

export function generate(provider: HmacProvider, params: EngineParams, counter: number): string {
  // TODO(T09): 由对应 todo 替换为真实实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}

export function verify(provider: HmacProvider, params: EngineParams, token: string, counter: number, window: number): number | null {
  // TODO(T09): 由对应 todo 替换为真实实现
  throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');
}
