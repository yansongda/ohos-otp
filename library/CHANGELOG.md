# Changelog

## 1.0.0

- Added: RFC 4226 HOTP / RFC 6238 TOTP（SHA1/SHA256/SHA512，6/7/8 位）
- Added: `verify` 漂移窗口与 `syncClockOffset` 时钟偏移校准
- Added: `Secret` 规范化/校验/随机生成/序列化脱敏
- Added: `otpauth://` URI 解析与生成
- Added: 统一错误模型 `OtpError`（17 个错误码）
