# @yansongda/otp

RFC 4226/6238 compliant HOTP and TOTP library for ArkTS (HarmonyOS).

> Requires `compatibleSdkVersion >= 6.0.0(20)`.

## Install

```bash
ohpm install @yansongda/otp
```

## Quick start

```ets
import { TOTP, HOTP, Secret, OtpError } from '@yansongda/otp';

// TOTP: SHA1 / 6 digits / 30s period by default
let totp = new TOTP({ secret: 'JBSWY3DPEHPK3PXP' });
let code = totp.generate();

// Verify with drift window
let delta = totp.verify(code, { window: 1 });

// HOTP
let hotp = new HOTP({ secret: 'JBSWY3DPEHPK3PXP', counter: 0 });
let hotpCode = hotp.generate();
```

## Features

- RFC 4226 HOTP and RFC 6238 TOTP
- SHA1 / SHA256 / SHA512
- 6 / 7 / 8 digit codes
- Verify drift window and clock offset calibration
- `otpauth://` URI parse and build
- Secret normalization, validation, random generation and `toJSON()` redaction
- Zero runtime dependencies (system `@kit.CryptoArchitectureKit` only)

## Documentation

Full documentation (API reference, RFC compliance notes, troubleshooting table,
release checklist) will be finalized in a later release milestone.

## License

MIT
