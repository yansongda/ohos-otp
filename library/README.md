# @yansongda/otp

RFC 4226 (HOTP) and RFC 6238 (TOTP) one-time password library for ArkTS (HarmonyOS).

> **Compatibility**: Requires `compatibleSdkVersion >= 6.0.0(20)`.

## Features

- RFC 4226 HOTP and RFC 6238 TOTP
- SHA1 / SHA256 / SHA512 (`OtpAlgorithm`, RFC 6238 §1.2)
- 6 / 7 / 8 digit codes (RFC 4226 §5.3)
- Drift-window verification (`VerifyOptions.window`) and clock-offset calibration (`syncClockOffset`)
- `Secret` normalization, validation, random generation and `toJSON()` redaction
- `otpauth://` URI parse and build (`OTPAuthURI`)
- Unified error model: `OtpError` with `OtpErrorCode`
- Synchronous API, zero runtime dependencies (system `@kit.CryptoArchitectureKit` only)

## Install

```bash
ohpm install @yansongda/otp
```

## Quick start

```ets
import { TOTP, HOTP, Secret, OTPAuthURI, OtpError } from '@yansongda/otp';

// ---- TOTP: SHA1 / 6 digits / 30s period by default ----
const totp = new TOTP({ secret: 'JBSWY3DPEHPK3PXP' });

const code: string = totp.generate();        // current 6-digit code
const remaining: number = totp.remaining();  // seconds until the window expires (1..30)
const progress: number = totp.progress();    // window progress (0..1)

// Verify with a drift window of 1 step; returns the drift delta, or null when no window matches
const delta: number | null = totp.verify(code, { window: 1 });
if (delta !== null) {
  totp.syncClockOffset(delta);               // calibrate the local clock by `delta` time steps
}

// Serialize to / restore from an otpauth:// URI
const uri: string = totp.toURI();
const restored: TOTP = TOTP.fromURI(uri);

// ---- HOTP: counter-based (RFC 4226) ----
const hotp = new HOTP({ secret: 'JBSWY3DPEHPK3PXP', counter: 0 });
const hotpCode: string = hotp.generate();
const hotpDelta: number | null = hotp.verify(hotpCode, { window: 5 });

// ---- Secret helpers ----
const secret = Secret.fromBase32('JBSWY3DPEHPK3PXP');
const randomSecret = Secret.generate();      // 20 bytes = 160 bits (RFC 4226 §4 R6 recommendation)
const b32: string = secret.toBase32();       // normalized uppercase, no padding
const bits: number = secret.bitLength;       // 80 for this 10-byte key

// ---- Error handling: all failures throw OtpError ----
try {
  new TOTP({ secret: 'JBSWY3DPEHPK3PXP', digits: 5 }); // invalid digits
} catch (e) {
  if (e instanceof OtpError) {
    const code = e.code;                     // e.g. 'INVALID_DIGITS' (one of OtpErrorCode)
  }
}
```

## API

### Options

| Type | Field | Default |
|---|---|---|
| `HmacOptions` | `secret: string` (required, base32, lenient parse) | — |
| | `algorithm?: OtpAlgorithm` | `SHA1` |
| | `digits?: number` (6 / 7 / 8 only) | `6` |
| | `minSecretBits?: number` | `0` (not enforced) |
| `TotpOptions` | `period?: number` (seconds) | `30` |
| | `t0?: number` (seconds) | `0` |
| | `clockOffsetMs?: number` | `0` |
| | `issuer?` / `account?: string` (used by `toURI()`) | empty |
| `HotpOptions` | `counter?: number` | `0` |
| | `issuer?` / `account?: string` (used by `toURI()`) | empty |
| `VerifyOptions` | `timestamp?: number` (epoch ms, TOTP only) | `Date.now()` |
| | `counter?: number` (HOTP only) | constructor counter |
| | `window?: number` (steps) | `0` (strict) |

### Classes and methods

| API | Description |
|---|---|
| `new TOTP(options: TotpOptions)` | Construct a TOTP; options are validated synchronously, invalid input throws `OtpError` |
| `totp.generate(timestampMs?: number): string` | Generate the code for now (or the given time); zero-padded `digits` characters |
| `totp.verify(token: string, options?: VerifyOptions): number \| null` | Constant-time comparison; returns the drift delta (`0` = current step, `-1` = previous step) or `null` |
| `totp.remaining(timestampMs?: number): number` | Whole seconds left in the current window, `[1, period]` |
| `totp.progress(timestampMs?: number): number` | Progress of the current window, `[0, 1)` |
| `totp.syncClockOffset(delta: number): void` | Calibrate the clock by `delta` time steps (single argument; `clockOffsetMs -= delta * period * 1000`) |
| `totp.clockOffsetMs: number` | Current clock offset in milliseconds |
| `totp.toURI(): string` / `TOTP.fromURI(uri: string): TOTP` | Serialize to / restore from an `otpauth://totp/...` URI |
| `new HOTP(options: HotpOptions)` | Construct a HOTP |
| `hotp.generate(counter?: number): string` | Generate the code (default: constructor counter) |
| `hotp.verify(token: string, options?: VerifyOptions): number \| null` | Constant-time comparison; returns the counter offset or `null` |
| `hotp.toURI(): string` / `HOTP.fromURI(uri: string): HOTP` | Serialize to / restore from an `otpauth://hotp/...` URI |
| `Secret.fromBase32(s: string): Secret` | Build from a base32 string (lenient: case / whitespace / padding) |
| `Secret.fromBytes(bytes: Uint8Array): Secret` | Build from raw bytes (copied) |
| `Secret.generate(bytes: number = 20): Secret` | Generate a random secret via the registered random source |
| `secret.toBase32(): string` | Normalized uppercase base32 without padding |
| `secret.bytes` / `secret.byteLength` / `secret.bitLength` | Strength introspection (bytes are a copy) |
| `secret.toJSON(): string` | Redaction hook — returns `'[REDACTED]'` under `JSON.stringify` |
| `OTPAuthURI.parse(uri: string): OtpAuthParams` | Parse an `otpauth://` URI (unknown query params are ignored) |
| `OTPAuthURI.build(params: OtpAuthParams): string` | Build a canonical `otpauth://` URI |
| `enum OtpAlgorithm { SHA1, SHA256, SHA512 }` | Algorithm enum (string values) |
| `enum OtpType { TOTP = 'totp', HOTP = 'hotp' }` | URI type enum (string values) |
| `class OtpError extends Error { readonly code: OtpErrorCode }` | Unified error model; branch on `code` |

## RFC compliance

- **RFC 4226 §4 R6 — secret length**: RFC recommends at least 128 bits (160 bits preferred). This library enforces nothing by default (`minSecretBits` defaults to `0`) because many existing backend keys are only 80 bits (10 bytes). Set `minSecretBits: 128` explicitly to enforce the recommendation. The `Secret.bitLength` getter lets you introspect strength.
- **RFC 4226 §5.3 — 6 / 7 / 8 digits**: `digits` accepts only 6, 7 or 8; anything else throws `INVALID_DIGITS`.
- **RFC 6238 §4.2 — T beyond 32 bits**: the time-step counter is computed with safe integer arithmetic (up to 2^53-1); the official RFC 6238 vectors up to `T = 20000000000` are covered by the test suite.
- **RFC 6238 §5.2 — 30s step and network latency**: the default period is 30 seconds. RFC 6238 §5.2 expects at most one time step of network latency — `verify` defaults to `window: 0` (strict, secure by default); pass `window: 1` to reproduce a server-side acceptance window.
- **RFC 6238 §6 — resynchronization**: `verify` returns the drift delta and `syncClockOffset(delta)` applies it, so a client can track slow/fast device clocks.
- **RFC 6238 §1.2 — algorithms**: SHA1 is the interoperability default that every implementation must support; SHA256/SHA512 are optional. This library supports all three.
- **RFC 4226 §7.3 — throttling**: throttling (failed-attempt back-off / lockout) is the responsibility of the validating server and is **not provided** by this library.

## Error handling and troubleshooting

All failures throw `OtpError` with a fixed `code` (string). Messages never contain the secret, token or key material. The table below covers all 16 codes exposed to consumers (`NOT_IMPLEMENTED` is an internal scaffold placeholder and is gone from the delivered build).

| `OtpErrorCode` | Symptom | Root cause | Action |
|---|---|---|---|
| `EMPTY_SECRET` | Construction / URI parse throws, secret is empty | Missing or empty secret | Provide a non-empty base32 secret |
| `INVALID_BASE32_CHAR` | Secret contains an illegal character | Character outside the base32 alphabet | Use only `A–Z` and `2–7` |
| `SECRET_TOO_SHORT` | Secret decodes to less than 1 byte | Base32 string too short | Provide at least 8 characters (1 byte) |
| `SECRET_TOO_WEAK` | `minSecretBits` check fails | `secret.bitLength < minSecretBits` | Use a stronger key or lower `minSecretBits` |
| `INVALID_ALGORITHM` | Algorithm is not accepted | Not SHA1 / SHA256 / SHA512 | Use one of the three supported algorithms |
| `INVALID_DIGITS` | Digits is not accepted | Not 6 / 7 / 8 | Use 6, 7 or 8 |
| `INVALID_PERIOD` | Period is not accepted | Not a positive integer | Use a positive integer number of seconds |
| `INVALID_T0` | `t0` is not accepted | Not a non-negative integer | Use a non-negative integer (seconds) |
| `INVALID_COUNTER` | Counter is not accepted | Not a non-negative integer, or exceeds 2^53-1 | Use a valid counter within `[0, 2^53-1]` |
| `INVALID_TIMESTAMP` | Timestamp is not accepted | Not a positive finite number (or `clockOffsetMs` not finite) | Use a valid epoch-millisecond timestamp |
| `INVALID_WINDOW` | Window / delta is not accepted | Not a non-negative integer (`syncClockOffset` requires an integer) | Use a valid integer |
| `INVALID_TOKEN` | Token format is invalid | Not all digits, or length ≠ `digits` | Validate user input before calling `verify` |
| `CRYPTO_FAILED` | Crypto call fails at runtime | Platform `cryptoFramework` error | Check system capability, retry; the error message is fixed and never leaks key material |
| `CRYPTO_NOT_INITIALIZED` | Crypto registry is not registered | You imported public classes via a deep path without injecting a provider, so the default registration never ran | Import through the package barrel (`@yansongda/otp`) so `installCryptoDefaults()` runs automatically |
| `INVALID_OTPAUTH_URI` | URI prefix is invalid | Not starting with `otpauth://` (case-insensitive) | Provide a valid `otpauth://` URI |
| `UNSUPPORTED_OTPAUTH_TYPE` | URI type is unsupported | Type is not `totp` / `hotp` | Use `totp` or `hotp` |

## Testing status

- **Local unit tests (Local Test) cover the kit-free pipeline**: Base32, counter/truncate/digits primitives, time-step math, the OTP engine, `Secret`, `OTPAuthURI` and the `HOTP`/`TOTP` public classes — all with injected test fixtures (a fake HMAC provider and a fake random source). The full RFC 4226 Appendix D (10 vectors) and RFC 6238 Appendix B (18 vectors) suites pass.
- **Branch-B gap (important)**: on a PC, HarmonyOS Local Test cannot execute the real system crypto — `@kit.CryptoArchitectureKit` imports fine but calls return empty data. Therefore the **real crypto path** (`CryptoFrameworkHmac` / `CryptoFrameworkRandom`) and the **barrel registration chain** (`Index.ets` → `installCryptoDefaults()`) are covered by the `ohosTest` device suite (`CryptoAdapter.test.ets`), which requires a device/emulator. As of this release it is pending manual verification on a device.
- No coverage figures are claimed for paths not exercised by the local suite.

## Known limitations

- **Counter ≤ 2^53-1**: ArkTS `number` has a 53-bit exact-integer range. `2^53-1` steps × 30 s ≈ 8.5 × 10⁹ years, unreachable in practice, so no BigInt support is provided; counters beyond the limit throw `INVALID_COUNTER`.
- **`otpauth://` is not an RFC**: it follows the Google Authenticator Key URI Format, an industry de-facto standard registered with IANA as Provisional #13829.
- **Unknown query parameters are ignored** when parsing URIs (maximizes interoperability).
- **Secret redaction is a safety net, not a license to log**: `Secret.toJSON()` returns `'[REDACTED]'` so `JSON.stringify` never leaks the key, but you must still never hand a secret to logs or analytics.
- **Not provided**: Steam Guard, SHA224 / SHA384 / SM3, BigInt / full 64-bit counters, throttling (RFC 4226 §7.3, a server-side concern), QR rendering or scanning.
- **Strict verification by default**: `verify` uses `window: 0`; a token from an adjacent step returns `null` unless you pass an explicit window.

## Security notes

- **No `@security/no-unsafe-mac` exemption is used.** This library deliberately uses HMAC — it is the algorithm mandated by RFC 6238 §1.2 for TOTP (and RFC 4226 for HOTP) — and no lint-supression comment is added to hide that usage.
- Token comparison is constant-time (XOR accumulation, no early exit), and `verify` scans the whole window before returning.
- Error messages are fixed strings; they never contain secrets, tokens or derived keys.

## Pre-release checklist

- [ ] All four release files are non-empty: `oh-package.json5`, `README.md`, `CHANGELOG.md`, `LICENSE`
- [ ] `README.md` contains the install command `ohpm install @yansongda/otp`
- [ ] `CHANGELOG.md` contains the current version number
- [ ] `dependencies` is empty (`{}`) — zero runtime dependencies
- [ ] `ohpm prepublish <har>` passes locally
- [ ] Remember: a published version cannot be overwritten or re-used — publish a new version instead

## License

MIT — see [LICENSE](LICENSE).
