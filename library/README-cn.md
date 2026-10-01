# @yansongda/otp

面向 ArkTS（HarmonyOS）的 RFC 4226/6238 兼容 HOTP 与 TOTP 库。

> 需要 `compatibleSdkVersion >= 6.0.0(20)`。

## 安装

```bash
ohpm install @yansongda/otp
```

## 快速开始

```ets
import { TOTP, HOTP, Secret, OtpError } from '@yansongda/otp';

// TOTP：默认 SHA1 / 6 位 / 30 秒周期
let totp = new TOTP({ secret: 'JBSWY3DPEHPK3PXP' });
let code = totp.generate();

// 带漂移窗口校验
let delta = totp.verify(code, { window: 1 });

// HOTP
let hotp = new HOTP({ secret: 'JBSWY3DPEHPK3PXP', counter: 0 });
let hotpCode = hotp.generate();
```

## 特性

- RFC 4226 HOTP 与 RFC 6238 TOTP
- SHA1 / SHA256 / SHA512
- 6 / 7 / 8 位验证码
- 校验漂移窗口与时钟偏移校准
- `otpauth://` URI 解析与生成
- Secret 规范化、校验、随机生成与 `toJSON()` 脱敏
- 零运行时依赖（仅系统 `@kit.CryptoArchitectureKit`）

## 文档

完整文档（API 参考、RFC 符合性说明、故障排查表、发布检查清单）将在后续发布里程碑定稿。

## 许可证

MIT
