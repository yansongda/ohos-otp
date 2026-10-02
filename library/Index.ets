/**
 * @yansongda/otp 全量 barrel（唯一对外入口）。
 *
 * 顶层导入并立即注册默认 crypto 实现：全库唯一经 barrel 引入 kit 的路径，
 * 也是消费者零配置的前提（只 new 实现并注册，不发起任何 crypto 调用）；
 * internal/* 与 HmacProvider 一律不导出（测试经深路径直接 import）。
 */
import { installCryptoDefaults } from './src/main/ets/internal/CryptoSource';

// 幂等注册；仅构造对象并注册，不发起 crypto 调用
installCryptoDefaults();

export { OtpError, OtpErrorCode } from './src/main/ets/OtpError';
export { OtpAlgorithm, OtpType, HmacOptions, TotpOptions, HotpOptions, VerifyOptions, OtpAuthParams } from './src/main/ets/OtpOptions';
export { Secret } from './src/main/ets/Secret';
export { HOTP } from './src/main/ets/HOTP';
export { TOTP } from './src/main/ets/TOTP';
export { OTPAuthURI } from './src/main/ets/OTPAuthURI';
