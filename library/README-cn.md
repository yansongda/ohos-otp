# @yansongda/otp

面向 ArkTS（HarmonyOS）的 RFC 4226（HOTP）与 RFC 6238（TOTP）一次性密码库。

> **兼容性**：需要 `compatibleSdkVersion >= 6.0.0(20)`。

## 特性

- RFC 4226 HOTP 与 RFC 6238 TOTP
- SHA1 / SHA256 / SHA512（`OtpAlgorithm`，RFC 6238 §1.2）
- 6 / 7 / 8 位验证码（RFC 4226 §5.3）
- 漂移窗口校验（`VerifyOptions.window`）与时钟偏移校准（`syncClockOffset`）
- `Secret` 规范化、校验、随机生成与 `toJSON()` 序列化脱敏
- `otpauth://` URI 解析与生成（`OTPAuthURI`）
- 统一错误模型：`OtpError` + `OtpErrorCode`
- 全同步 API，零运行时依赖（仅系统 `@kit.CryptoArchitectureKit`）

## 安装

```bash
ohpm install @yansongda/otp
```

## 快速开始

```ets
import { TOTP, HOTP, Secret, OTPAuthURI, OtpError } from '@yansongda/otp';

// ---- TOTP：默认 SHA1 / 6 位 / 30 秒周期 ----
const totp = new TOTP({ secret: 'JBSWY3DPEHPK3PXP' });

const code: string = totp.generate();        // 当前 6 位验证码
const remaining: number = totp.remaining();  // 本窗口剩余整秒（1..30）
const progress: number = totp.progress();    // 本窗口进度（0..1）

// 带 1 步漂移窗口校验：返回漂移 delta，未命中返回 null
const delta: number | null = totp.verify(code, { window: 1 });
if (delta !== null) {
  totp.syncClockOffset(delta);               // 按 delta 个时间步校准本地时钟
}

// 序列化为 / 从 otpauth:// URI 恢复
const uri: string = totp.toURI();
const restored: TOTP = TOTP.fromURI(uri);

// ---- HOTP：基于计数器（RFC 4226）----
const hotp = new HOTP({ secret: 'JBSWY3DPEHPK3PXP', counter: 0 });
const hotpCode: string = hotp.generate();
const hotpDelta: number | null = hotp.verify(hotpCode, { window: 5 });

// ---- Secret 工具 ----
const secret = Secret.fromBase32('JBSWY3DPEHPK3PXP');
const randomSecret = Secret.generate();      // 20 字节 = 160 bit（RFC 4226 §4 R6 推荐）
const b32: string = secret.toBase32();       // 规范化大写、无填充
const bits: number = secret.bitLength;       // 该 10 字节密钥为 80

// ---- 错误处理：一切失败均抛 OtpError ----
try {
  new TOTP({ secret: 'JBSWY3DPEHPK3PXP', digits: 5 }); // digits 非法
} catch (e) {
  if (e instanceof OtpError) {
    const code = e.code;                     // 例如 'INVALID_DIGITS'（OtpErrorCode 之一）
  }
}
```

## API

### 选项

| 类型 | 字段 | 默认值 |
|---|---|---|
| `HmacOptions` | `secret: string`（必填，base32 宽松解析） | — |
| | `algorithm?: OtpAlgorithm` | `SHA1` |
| | `digits?: number`（仅 6 / 7 / 8） | `6` |
| | `minSecretBits?: number` | `0`（不强制） |
| `TotpOptions` | `period?: number`（秒） | `30` |
| | `t0?: number`（秒） | `0` |
| | `clockOffsetMs?: number` | `0` |
| | `issuer?` / `account?: string`（仅 `toURI()` 使用） | 空 |
| `HotpOptions` | `counter?: number` | `0` |
| | `issuer?` / `account?: string`（仅 `toURI()` 使用） | 空 |
| `VerifyOptions` | `timestamp?: number`（epoch ms，仅 TOTP） | `Date.now()` |
| | `counter?: number`（仅 HOTP） | 构造时的 counter |
| | `window?: number`（步） | `0`（严格） |

### 类与方法

| API | 说明 |
|---|---|
| `new TOTP(options: TotpOptions)` | 构造 TOTP；选项在构造期同步校验，非法即抛 `OtpError` |
| `totp.generate(timestampMs?: number): string` | 生成当前（或指定时刻）验证码；`digits` 位零填充字符串 |
| `totp.verify(token: string, options?: VerifyOptions): number \| null` | 恒定时间比对；返回漂移 delta（`0`=当前步，`-1`=上一步），未命中返回 `null` |
| `totp.remaining(timestampMs?: number): number` | 当前窗口剩余整秒，取值 `[1, period]` |
| `totp.progress(timestampMs?: number): number` | 当前窗口进度，取值 `[0, 1)` |
| `totp.syncClockOffset(delta: number): void` | 按 `delta` 个时间步校准时钟（单参数；`clockOffsetMs -= delta * period * 1000`） |
| `totp.clockOffsetMs: number` | 当前时钟偏移（毫秒） |
| `totp.toURI(): string` / `TOTP.fromURI(uri: string): TOTP` | 序列化为 / 从 `otpauth://totp/...` URI 恢复 |
| `new HOTP(options: HotpOptions)` | 构造 HOTP |
| `hotp.generate(counter?: number): string` | 生成验证码（缺省用构造值） |
| `hotp.verify(token: string, options?: VerifyOptions): number \| null` | 恒定时间比对；返回 counter 偏移或 `null` |
| `hotp.toURI(): string` / `HOTP.fromURI(uri: string): HOTP` | 序列化为 / 从 `otpauth://hotp/...` URI 恢复 |
| `Secret.fromBase32(s: string): Secret` | 从 base32 字符串构造（宽松：大小写/空白/填充） |
| `Secret.fromBytes(bytes: Uint8Array): Secret` | 从字节数组构造（拷贝语义） |
| `Secret.generate(bytes: number = 20): Secret` | 经注册的随机源生成随机 secret |
| `secret.toBase32(): string` | 规范化大写、无填充 base32 |
| `secret.bytes` / `secret.byteLength` / `secret.bitLength` | 强度自省（bytes 为拷贝） |
| `secret.toJSON(): string` | 序列化脱敏——`JSON.stringify` 时返回 `'[REDACTED]'` |
| `OTPAuthURI.parse(uri: string): OtpAuthParams` | 解析 `otpauth://` URI（未知 query 参数忽略） |
| `OTPAuthURI.build(params: OtpAuthParams): string` | 生成规范 `otpauth://` URI |
| `enum OtpAlgorithm { SHA1, SHA256, SHA512 }` | 算法枚举（字符串值） |
| `enum OtpType { TOTP = 'totp', HOTP = 'hotp' }` | URI 类型枚举（字符串值） |
| `class OtpError extends Error { readonly code: OtpErrorCode }` | 统一错误模型；按 `code` 精确分支 |

## RFC 符合性

- **RFC 4226 §4 R6 —— secret 长度**：RFC 建议至少 128 bit（推荐 160 bit）。本库默认不强制（`minSecretBits` 默认 `0`），因为大量存量后端密钥只有 80 bit（10 字节）；需要时显式设 `minSecretBits: 128` 启用该校验，`Secret.bitLength` 可自省强度。
- **RFC 4226 §5.3 —— 6/7/8 位**：`digits` 仅接受 6、7、8，其余抛 `INVALID_DIGITS`。
- **RFC 6238 §4.2 —— T 超过 32 位**：时间步计数器使用安全整数运算（上限 2^53-1）；官方向量至 `T = 20000000000` 已由测试套件覆盖。
- **RFC 6238 §5.2 —— 30 秒步长与网络延迟**：默认周期 30 秒。RFC 6238 §5.2 预期最多 1 个时间步的网络延迟——`verify` 默认 `window: 0`（严格，默认安全）；要复现服务端接受范围须显式传 `window: 1`。
- **RFC 6238 §6 —— 重新同步**：`verify` 返回漂移 delta，`syncClockOffset(delta)` 应用该偏移，客户端可跟踪快/慢的设备时钟。
- **RFC 6238 §1.2 —— 算法**：SHA1 是所有实现必须支持的互操作默认；SHA256/SHA512 为可选。本库三者均支持。
- **RFC 4226 §7.3 —— throttling**：失败退避/锁定属校验服务端职责，**本库不提供**。

## 错误处理与故障排查

一切失败均抛 `OtpError`，携带固定 `code`（字符串）；错误消息绝不包含 secret、token 或密钥材料。下表覆盖全部 16 个对外错误码（`NOT_IMPLEMENTED` 为内部脚手架占位，交付产物中已清零、不对外）。

| `OtpErrorCode` | 现象 | 根因 | 处置 |
|---|---|---|---|
| `EMPTY_SECRET` | 构造 / URI 解析抛错，secret 为空 | secret 缺失或空串 | 提供非空 base32 secret |
| `INVALID_BASE32_CHAR` | secret 含非法字符 | 字符不在 base32 字母表 | 仅使用 `A–Z` 与 `2–7` |
| `SECRET_TOO_SHORT` | secret 解码后不足 1 字节 | base32 串过短 | 至少提供 8 个字符（1 字节） |
| `SECRET_TOO_WEAK` | `minSecretBits` 校验失败 | `secret.bitLength < minSecretBits` | 换更强的密钥或调低 `minSecretBits` |
| `INVALID_ALGORITHM` | 算法不被接受 | 非 SHA1 / SHA256 / SHA512 | 使用三种受支持算法之一 |
| `INVALID_DIGITS` | 位数不被接受 | 非 6 / 7 / 8 | 使用 6、7 或 8 |
| `INVALID_PERIOD` | 周期不被接受 | 非正整数 | 使用正整数秒 |
| `INVALID_T0` | `t0` 不被接受 | 非 ≥0 整数 | 使用 ≥0 整数（秒） |
| `INVALID_COUNTER` | 计数器不被接受 | 非 ≥0 整数，或超过 2^53-1 | 使用 `[0, 2^53-1]` 内的合法值 |
| `INVALID_TIMESTAMP` | 时间戳不被接受 | 非正有限数（或 `clockOffsetMs` 非有限） | 使用合法 epoch 毫秒时间戳 |
| `INVALID_WINDOW` | 窗口 / delta 不被接受 | 非 ≥0 整数（`syncClockOffset` 要求整数） | 使用合法整数 |
| `INVALID_TOKEN` | token 格式非法 | 非纯数字，或长度 ≠ `digits` | 调用 `verify` 前先校验用户输入 |
| `CRYPTO_FAILED` | 运行期 crypto 调用失败 | 平台 `cryptoFramework` 异常 | 检查系统能力后重试；错误文案固定，不泄漏密钥材料 |
| `CRYPTO_NOT_INITIALIZED` | crypto 注册表未注册 | 经深路径导入公开类且未注入 provider，默认注册从未执行 | 从包 barrel（`@yansongda/otp`）导入以自动触发 `installCryptoDefaults()` |
| `INVALID_OTPAUTH_URI` | URI 前缀非法 | 不以 `otpauth://` 开头（大小写不敏感） | 提供合法 `otpauth://` URI |
| `UNSUPPORTED_OTPAUTH_TYPE` | URI 类型不支持 | 类型非 `totp` / `hotp` | 使用 `totp` 或 `hotp` |

## 测试与限制说明

- **本地单测（Local Test）覆盖 kit-free 全链路**：Base32、counter/truncate/digits 原语、时间步计算、OTP 引擎、`Secret`、`OTPAuthURI` 与 `HOTP`/`TOTP` 公开类——全部经注入测试 fixture（伪 HMAC provider 与伪随机源）。RFC 4226 Appendix D（10 条）与 RFC 6238 Appendix B（18 条）全量官方向量通过。
- **真实 crypto 路径由设备端用例覆盖（PC 无法执行）**：HarmonyOS Local Test 无法执行真实系统 crypto——`@kit.CryptoArchitectureKit` 可 import 但调用返回空数据。因此**真实 crypto 路径**（`CryptoFrameworkHmac` / `CryptoFrameworkRandom`）与 **barrel 注册链路**（`Index.ets` → `installCryptoDefaults()`）由 `ohosTest` 设备套件（`CryptoAdapter.test.ets`，37 条）覆盖，需要设备/模拟器。**已在 HarmonyOS 模拟器上实测全绿：`Tests run: 37, Failure: 0, Error: 0, Pass: 37`**——含 3 条 HMAC digest、RFC 4226 Appendix D / RFC 6238 Appendix B 全量向量，以及不注入 fixture 的默认 provider 链路。
- 本库不宣称任何未经本地套件实际执行的覆盖率数字。

## 已知限制

- **counter ≤ 2^53-1**：ArkTS `number` 精确整数上限为 53 位。`2^53-1` 步 × 30 秒 ≈ 8.5×10⁹ 年，实践中不可触及，故不提供 BigInt 支持；超限抛 `INVALID_COUNTER`。
- **`otpauth://` 并非 RFC**：遵循 Google Authenticator Key URI Format 这一事实标准（IANA Provisional #13829 注册）。
- **未知 query 参数被忽略**（最大化互操作）。
- **脱敏是安全网而非日志许可**：`Secret.toJSON()` 返回 `'[REDACTED]'` 保证 `JSON.stringify` 不泄漏密钥，但你仍不得主动把 secret 交给日志或上报。
- **不提供**：Steam Guard、SHA224 / SHA384 / SM3、BigInt / 完整 64 位 counter、throttling（RFC 4226 §7.3，服务端职责）、二维码渲染与扫码。
- **默认严格校验**：`verify` 使用 `window: 0`；相邻时间步的 token 返回 `null`，除非显式传 window。

## 安全说明

- **不使用 `@security/no-unsafe-mac` 豁免**。本库有意使用 HMAC——它是 RFC 6238 §1.2 为 TOTP（以及 RFC 4226 为 HOTP）规定的算法——且未添加任何 lint 豁免注释来掩盖该用法。
- token 比对为恒定时间（异或累加、不提前返回），`verify` 扫完全部窗口才返回。
- 错误消息为固定文案，绝不包含 secret、token 或派生密钥。

## 发布前检查清单

- [ ] 四件套非空：`oh-package.json5`、`README.md`、`CHANGELOG.md`、`LICENSE`
- [ ] `README.md` 含安装命令 `ohpm install @yansongda/otp`
- [ ] `CHANGELOG.md` 含当前版本号
- [ ] `dependencies` 为空（`{}`）——零运行时依赖
- [ ] `ohpm prepublish <har>` 本地预检通过
- [ ] 注意：已发布版本不可覆盖、不可复用——请发新版本

## 许可证

MIT —— 见 [LICENSE](LICENSE)。
