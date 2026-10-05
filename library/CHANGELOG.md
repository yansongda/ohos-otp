# Changelog

## 1.0.2 - 2026-10-05

> 仅打包与元数据变更，**无源码 / API 行为变化**；本版用于补齐 OHPM 包质量分的两个失分项。

#### Added

- `example/README.md`：随 HAR 一起分发的用法示例（TOTP 校验闭环、HOTP 计数器持久化、`otpauth://` URI、错误码分支）。hvigor 对 bytecode HAR 的 release 白名单目录恰好名为 `example`，因此该目录会原样进入包内 `package/example/`
- `oh-package.json5` 新增 `homepage` 字段（与 `repository` 同址）

#### Changed

- HAR 文件数 26 → 27（新增 `package/example/README.md`），压缩后体积 31 805 → 34 133 字节（+2.3 KB）
- 无公开签名、选项字段、错误码变化；`Secret` 脱敏与恒定时间比对等既有不变量不变

---

## 1.0.1 - 2026-10-05

> 升级提示：本版把**非法入参**从「静默返回 `null` / 穿透到 crypto 层」收紧为显式抛错（未新增错误码、未改公开签名与选项字段），合法入参行为不变。

#### Fixed

- `TOTP.syncClockOffset` 校准方向修正：公式由 `clockOffsetMs -= delta * period * 1000` 改为 `+=`，使「verify → syncClockOffset(返回的 delta) → verify(window=0) 命中 delta=0」闭环成立（与 RFC 6238 §6 resync 方向一致；配套闭环不变量用例）

#### Changed

- 构造期校验 `algorithm`（非法值抛 `INVALID_ALGORITHM`，此前穿透到 crypto 层抛 `CRYPTO_FAILED`）
- `verify` 入口（HOTP/TOTP 共享引擎）的 counter 非法（负数 / 超 2^53-1）抛 `INVALID_COUNTER`（此前静默返回 null）；因引擎为两者共用，`TOTP.verify` 在 `t0` 取大值 / 极小 timestamp / 负 offset 使计算 counter 为负时同样抛出
- `OTPAuthURI.build` 对 `secret` 先做 base32 规范化（大写无填充；非法字符抛 `INVALID_BASE32_CHAR`），与 `parse` 对称

---

## 1.0.0 - 2026-10-01

### Added

- RFC 4226 HOTP / RFC 6238 TOTP 完整实现（SHA1/SHA256/SHA512，6/7/8 位验证码）
- `verify` 漂移窗口校验（`VerifyOptions.window`）与 `syncClockOffset` 时钟偏移校准（`clockOffsetMs` getter）
- `Secret` 规范化（fromBase32 / fromBytes）、随机生成（generate，默认 20 字节）、强度自省（bytes / byteLength / bitLength）与序列化脱敏（`toJSON()` 返回 `'[REDACTED]'`）
- `otpauth://` URI 解析与生成（`OTPAuthURI.parse` / `OTPAuthURI.build`），`TOTP.fromURI` / `HOTP.fromURI`
- 统一错误模型 `OtpError`（`extends Error`，`readonly code: OtpErrorCode`，17 个字符串错误码）
- `OtpAlgorithm` / `OtpType` 枚举与全部选项类型（`HmacOptions` / `TotpOptions` / `HotpOptions` / `VerifyOptions` / `OtpAuthParams`）
- 全同步 API、恒定时间 token 比对、kit-free 分层（本地单测可覆盖全链路）
- 通过 RFC 4226 Appendix D（10 条）与 RFC 6238 Appendix B（18 条）全量官方向量

### Changed

- 明确「RFC 4226 §7.3 throttling 由校验服务端实现，本库不提供」的边界
- 明确兼容性要求：`compatibleSdkVersion >= 6.0.0(20)`
