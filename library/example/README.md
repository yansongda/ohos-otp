# Example — `@yansongda/otp`

Copy-paste snippets for the most common flows. The complete API surface, options and the
error-code troubleshooting table live in the package `README.md` (`library/README.md`).

> Everything below is synchronous, has zero runtime dependencies, and never logs the secret.

## 1. Verify a TOTP token (server-side style)

```ets
import { TOTP } from '@yansongda/otp';

const totp = new TOTP({ secret: 'JBSWY3DPEHPK3PXP' }); // SHA1 / 6 digits / 30s

export function checkToken(token: string): boolean {
  // window = 1 accepts the previous, current and next step; returns the drift delta or null.
  // The comparison is constant-time and always scans the whole window before returning.
  const delta: number | null = totp.verify(token, { window: 1 });
  if (delta === null) {
    return false;
  }
  // Align the local clock with the token source so the next call can use a tighter window.
  totp.syncClockOffset(delta);
  return true;
}
```

## 2. Show a code with a countdown (client-side style)

```ets
import { TOTP } from '@yansongda/otp';

const totp = new TOTP({ secret: 'JBSWY3DPEHPK3PXP' });

totp.generate();    // e.g. '287082' — zero-padded to `digits` characters
totp.remaining();   // seconds left in the current window, 1..30
totp.progress();    // window progress, 0..1 (drive a progress ring from this)
```

## 3. HOTP (RFC 4226) and the counter you must persist

```ets
import { HOTP } from '@yansongda/otp';

let counter = 0; // you own this value and persist it; the library never advances it
const hotp = new HOTP({ secret: 'JBSWY3DPEHPK3PXP', counter });
hotp.generate();                              // code for the current counter

const delta: number | null = hotp.verify(userToken, { window: 5 });
if (delta !== null) {
  // Anti-replay (RFC 4226 §7.4): accept once, then move past the matched step and persist it.
  counter = counter + delta + 1;
}
```

## 4. Import and export `otpauth://` URIs

```ets
import { TOTP, OTPAuthURI, OtpType, OtpAlgorithm } from '@yansongda/otp';

// From a QR-code payload scanned by the user
const totp: TOTP = TOTP.fromURI('otpauth://totp/ACME:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=ACME');

// Build one for a QR code
const uri: string = OTPAuthURI.build({
  type: OtpType.TOTP,
  secret: 'JBSWY3DPEHPK3PXP',
  issuer: 'ACME',
  account: 'alice@example.com',
  algorithm: OtpAlgorithm.SHA1,
  digits: 6,
  period: 30,
});
```

## 5. Handle failures by error code

```ets
import { Secret, TOTP, OtpError } from '@yansongda/otp';

try {
  const secret = Secret.fromBase32(userInput);  // invalid characters / too short -> throws
  new TOTP({ secret: secret.toBase32(), digits: 6 });
} catch (e) {
  if (e instanceof OtpError) {
    // Branch on the stable string code, never on the message text.
    // e.code === 'INVALID_BASE32_CHAR' | 'INVALID_DIGITS' | 'INVALID_ALGORITHM' | ...
  }
}
```

## Run the sample app in this repository

`entry/` is a HarmonyOS smoke app that consumes the published barrel (it is not part of the
HAR). Open the repository in DevEco Studio, run the `entry` module, and compare its output
against the RFC vectors in `library/src/test/vectors/RfcVectors.ets`.

## 中文摘要

- 本目录只是「用法示例」，随包发布，不含可运行工程；完整 API 见包内 `README.md` / `README-cn.md`。
- 典型流程：`new TOTP({ secret })` → `verify(token, { window: 1 })` → 命中时 `syncClockOffset(delta)`；
  `window` 越大越宽松，校准后应尽快收紧。
- HOTP 必须由调用方持久化下一个计数器（`base + delta + 1`），库不会自动推进。
- 所有失败都抛 `OtpError`，请按 `e.code`（17 个稳定字符串码）分支，不要匹配 message 文案。
- 密钥请用 `Secret.generate()` 生成（默认 20 字节 / 160 bit）；`Secret` 已做序列化脱敏。
