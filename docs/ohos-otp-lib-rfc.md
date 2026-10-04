# ohos-otp v1 技术设计文档 —— RFC 4226/6238 通用 OTP 库

> **时间**：2026-10-01（2026-10-02 重构为结论态）
> **作者**：DeepSeek V4.1 Flash + yansongda
> **状态**：已实现并验证（v1.0.0；验证结果见附录 B）
> **代码事实来源**：`library/`（源码即契约，本文件与其冲突时以源码为准）

---

## 1. 背景与目标

**背景**：旧 MFA 元服务的端内算码实现内嵌在元服务 `entry` 模块——单文件、仅 TOTP + SHA1 + 6 位、只有「生成」没有「校验」、顶层 import 系统 kit 导致 PC 不可测、无 README/CHANGELOG/LICENSE 因而不是可分发的库形态；同一算法在微信端另 vendor 了一份第三方实现，语义漂移无人守。本仓库把该能力抽取为独立、可发布、可跨端复用的 HAR 库。

**目标（约束条件）**

- **规范对齐**：RFC 4226 / RFC 6238 能力完整，两 RFC 附录官方测试向量 **100% 通过**
- **零运行时依赖**（除系统 `@kit.CryptoArchitectureKit`）
- **可发布**：满足 OHPM 中心仓上架硬性要求（四件套文件 + 元信息字段）
- **本地可测**：核心算法逻辑在 **PC 上无需设备**即可全量单测
- **绝不外泄**：无日志、无上报、异常消息不含 secret、序列化自动脱敏
- **API 稳定**：v1 起语义冻结，仅允许新增可选字段
- **兼容性**：`compatibleSdkVersion` 保持工程默认 `6.0.0(20)`

---

## 2. 整体方案

### 2.1 核心思路

**把「算码」拆成「纯算法核心（零系统依赖、PC 可全量测试）」+「系统加密实现（cryptoFramework 单点偶联、藏在 kit-only 文件里）」两层，中间用 kit-free 的接口 + 注册表解耦，用统一选项对象驱动 HOTP / TOTP / OTPAuthURI 三个对外能力，并按 OHPM 发布规范补齐元信息与四件套文档。**

**为什么必须用注册表而不是「公开类直接 import 实现类」**：ArkTS/ESM 的 `import` 是静态且传递的。若 `HOTP.ets` 顶层从「含 `@kit` 导入的文件」里值导入任何符号（哪怕是 `requireDefaultHmac()` 这种函数），加载 `HOTP.ets` 就会连带加载 `@kit.CryptoArchitectureKit`；而官方文档明确「本地测试当前不支持测试 C/C++ 方法及系统 API」，这将使 `Hotp.test`/`Totp.test`/`Secret.test` 在**模块加载期**整体失败（不是少数用例失败）。因此 kit-free 层必须**不含任何 kit 导入**，且公开类只能从 kit-free 层导入。

### 2.2 架构图

```
        ┌──────────────────── 消费者：HarmonyOS 应用 / 元服务 ────────────────────┐
        │   import { TOTP, HOTP, Secret, OTPAuthURI, OtpError, OtpAlgorithm }    │
        │            from '@yansongda/otp'      ← library/Index.ets (唯一 barrel) │
        │   副作用：installCryptoDefaults() 注册默认 crypto 实现（仅构造对象，不调用） │
        └────────────────────────────────┬───────────────────────────────────────┘
                                         │
     ┌───────────────────────────────────┼─────────────────────────────────────────┐
     │  HOTP（RFC 4226）                  TOTP（RFC 6238）            OTPAuthURI / Secret │
     │  generate / verify                 generate / verify           parse / build        │
     │                                    remaining / progress /      规范化 / 校验 / 生成 │
     │                                    syncClockOffset                                  │
     └───────────────┬───────────────────────────────────────┬───────────────────────────┘
                     │ 值导入（kit-free，无传递 kit 风险）      │ 纯函数调用
     ┌───────────────▼───────────────────────┐   ┌───────────▼────────────────────┐
     │ internal/ 纯算法核心（无 @kit）        │   │ internal/ 纯解析层（无 @kit）   │
     │ Base32 · Counter · Truncate · Digits  │   │ OTPAuthURI · Secret             │
     │ TimeStep · 恒定时间比较               │   │ OtpError / OtpOptions 类型      │
     │ OtpEngine（编排：counter→code）       │   └────────────────────────────────┘
     │ HmacProvider.ets：接口 + 注册表        │
     │   ├ HmacProvider 接口                 │
     │   ├ RandomSource 接口                 │
     │   ├ registerHmac / requireHmac        │   ← 公开类与 Secret 只依赖这一层
     │   └ registerRandom / requireRandom    │
     └───────────────▲───────────────────────┘
                     │ installCryptoDefaults() 注册（值导入，仅此处）
     ┌───────────────┴───────────────────────┐
     │ internal/CryptoSource.ets             │
     │ ← 全库唯一 @kit 导入点（含 Index.ets 也不再直接 import kit）│
     │ CryptoFrameworkHmac / CryptoFrameworkRandom │
     │ createSymKeyGenerator('HMAC') + createMac('SHAx') │
     │ + convertKeySync/initSync/updateSync/doFinalSync  │
     └────────────────────────────────────────┘
```

数据流（生成一个码）：

```
secret(base32 字符串)
  → Secret 规范化（去空白/填充、转大写、字符合法性校验）→ bytes
  → Counter.toBytes(counter)  8 字节大端（high/low 拆分，规避 32 位位运算溢出）
  → HmacProvider.sign(SHAx, keyBytes, counterBytes) → digest
  → Truncate.apply(digest)    RFC 4226 §5.3 动态截断 → 31 位非负整数
  → Digits.format(v, digits)  v mod 10^digits + 左补零 → code
```

### 2.3 文件结构

```
ohos-otp/
├── AGENTS.md                            agent 工程上下文入口（分层不变量 + 实测命令）
├── build-profile.json5                  compatibleSdkVersion 6.0.0(20) / targetSdkVersion 6.1.1(24)
├── code-linter.json5                    @security/no-unsafe-mac 为 warn（HMAC-SHA1 互操作依据，不放宽）
├── docs/
│   └── ohos-otp-lib-rfc.md              本文件（设计结论唯一入库文档）
├── library/                             HAR 库 @yansongda/otp（零运行时依赖）
│   ├── Index.ets                        唯一 barrel：注册默认实现 + 导出公开符号
│   ├── oh-package.json5                 包元信息（name/version/description/author/repository/license）
│   ├── README.md / README-cn.md         OHPM 上架硬性要求（README 必含 ohpm install 命令）
│   ├── CHANGELOG.md / LICENSE           OHPM 上架硬性要求（CHANGELOG 必含当前版本号；MIT）
│   └── src/
│       ├── main/ets/
│       │   ├── OtpError.ets             17 个错误码 + OtpError
│       │   ├── OtpOptions.ets           全部对外选项/返回类型（字段冻结）
│       │   ├── Secret.ets               base32/bytes 构造、随机生成、强度自省、toJSON 脱敏
│       │   ├── HOTP.ets / TOTP.ets      RFC 4226 / RFC 6238 公开类（TOTP 含 remaining/progress/syncClockOffset）
│       │   ├── OTPAuthURI.ets           otpauth:// 解析与生成
│       │   └── internal/                （不对外导出）
│       │       ├── Base32.ets · Counter.ets · Truncate.ets · Digits.ets · TimeStep.ets   纯算法核心
│       │       ├── OtpEngine.ets        编排（纯，接收注入 provider）
│       │       ├── HmacProvider.ets     接口 + 注册表（kit-free）
│       │       └── CryptoSource.ets     cryptoFramework 实现（全库唯一 @kit 导入点）
│       ├── test/                        PC 本地单测（kit-free 全链路 + 黄金向量 + fixture）
│       └── ohosTest/                    设备端真实 crypto 验证（JsUnit）
└── entry/                               消费方 smoke demo（仅依赖 barrel，不参与 HAR 打包）
```

---

## 3. 详细设计

### 3.1 分层与依赖边界（本方案的核心决策）

| 层 | 文件 | 允许依赖 | 理由 |
|---|---|---|---|
| 纯算法核心 | `internal/{Base32,Counter,Truncate,Digits,TimeStep,OtpEngine}.ets` | `OtpError`、`OtpOptions`、`HmacProvider`（仅类型） | 零系统依赖 → PC 上 100% 可单测 |
| 解析/规范化 | `OTPAuthURI.ets`、`Secret.ets` | 纯核心 + `OtpError` + `HmacProvider`（仅 RandomSource 接口） | URI 解析与 secret 规范化最易写错，必须可离线测 |
| **kit-free 解耦层** | `internal/HmacProvider.ets` | 仅 `OtpError`/`OtpOptions` | 接口 + 注册表；**绝不 import kit**；公开类与 Secret 只依赖它 |
| **kit-only 实现层** | `internal/CryptoSource.ets` | `@kit.CryptoArchitectureKit` + kit-free 层 | **全库唯一 `@kit` 导入点**；只被 `Index.ets` 值导入 |
| 公开封装 | `HOTP.ets`、`TOTP.ets` | 以上（**不含 kit-only 层**） | 薄封装：默认 provider 经注册表取 + 选项校验 + 时间/偏移逻辑委托纯核心 |
| 出口 | `Index.ets` | 公开符号 + `CryptoSource`（仅注册用） | 唯一对外 barrel，`internal/*` 与 `HmacProvider` **不导出** |

**注册表契约**（`internal/HmacProvider.ets`）：

| 符号 | 语义 |
|---|---|
| `interface HmacProvider { sign(algorithm: OtpAlgorithm, key: Uint8Array, message: Uint8Array): Uint8Array; }` | HMAC 抽象 |
| `interface RandomSource { random(bytes: number): Uint8Array; }` | 随机数抽象 |
| `registerHmac(p: HmacProvider): void` / `registerRandom(r: RandomSource): void` | 注册（幂等覆盖） |
| `requireHmac(): HmacProvider` / `requireRandom(): RandomSource` | 取用；**未注册时抛 `OtpError(CRYPTO_NOT_INITIALIZED)`** |
| `installCryptoDefaults()`（在 `CryptoSource.ets` 内，由 `Index.ets` 调用） | 只 `new` 实现类并注册，**不发起任何 crypto 调用**，因此 barrel 导入期不会失败 |

**测试覆盖边界（实测结论）**：Local Test 运行在 PC 本地 Simulator，**可以 import 并可构造** cryptoFramework 对象，但 `doFinalSync()` 返回空 DataBlob（`len=0`）——即本地测试环境 crypto 计算不可用。因此：

- `src/test`（PC，kit-free）：覆盖纯算法核心全链路 + 公开类（注入 `HmacFixture`/`RandomFixture`，模块图内**不存在** `CryptoSource.ets`）；
- `src/ohosTest`（设备/模拟器）：覆盖真实 `CryptoFrameworkHmac`、barrel 注册链路与默认 provider 路径（不注入任何 fixture）。

本库为**同步 API**：全部走 `*Sync`（`convertKeySync`/`initSync`/`updateSync`/`doFinalSync`/`generateRandomSync`），8 字节 HMAC 为微秒级计算，避免 Promise 传染与竞态。

### 3.2 公共 API 契约

**选项类型字段表**（字段名不得增删改；v1 起仅允许新增可选字段）：

| 类型 | 字段（`?` = 可选） | 默认值 |
|---|---|---|
| `HmacOptions` | `secret: string`（必填） | — |
| | `algorithm?: OtpAlgorithm` | `SHA1` |
| | `digits?: number` | `6` |
| | `minSecretBits?: number` | `0`（不强制） |
| `TotpOptions extends HmacOptions` | `period?: number` | `30` |
| | `t0?: number`（秒） | `0` |
| | `clockOffsetMs?: number` | `0`（**仅 TOTP 有效**；HOTP 无时间语义，故不放在基类） |
| | `issuer?: string` | 空（仅 `toURI`） |
| | `account?: string` | 空（仅 `toURI`） |
| `HotpOptions extends HmacOptions` | `counter?: number` | `0` |
| | `issuer?: string` / `account?: string` | 空（仅 `toURI`） |
| `VerifyOptions` | `timestamp?: number`（epoch ms，仅 TOTP） | `Date.now()` |
| | `counter?: number`（仅 HOTP） | 构造时的 counter |
| | `window?: number`（步） | `0` |
| `OtpAuthParams` | `type: OtpType`（必填） | — |
| | `secret: string`（必填，规范化大写无填充 base32） | — |
| | `algorithm: OtpAlgorithm` | 解析/构建均填实值 |
| | `digits: number` | 解析/构建均填实值 |
| | `period?: number`（仅 TOTP） | `30` |
| | `counter?: number`（仅 HOTP） | `0` |
| | `issuer?: string` / `account?: string` / `label?: string` | 空 |

```json5
// TotpOptions 的 JSON 形态示意
{
  "secret": "JBSWY3DPEHPK3PXP",   // 必填；base32，宽松解析（容忍大小写/空白/填充）
  "algorithm": "SHA1",            // 可选，默认 SHA1；SHA1 | SHA256 | SHA512
  "digits": 6,                    // 可选，默认 6；仅允许 6 | 7 | 8（RFC 4226 §5.3）
  "period": 30,                   // 可选，默认 30（RFC 6238 §5.2 推荐值），正整数秒
  "t0": 0,                        // 可选，默认 0（RFC 6238 §4.1 的 T0，**单位为秒**）
  "minSecretBits": 0,             // 可选，默认 0=不强制；设 128 即启用 RFC 4226 §4 R6 校验
  "clockOffsetMs": 0,             // 可选，默认 0；时钟偏移补偿（见 syncClockOffset）
  "issuer": "MyService",          // 可选，仅用于 toURI()
  "account": "alice@example.com"  // 可选，仅用于 toURI()
}
```

公共 API（签名与语义）：

| API | 语义 | 规范依据 |
|---|---|---|
| `new TOTP(options: TotpOptions, provider?: HmacProvider)` | 构造；**同步**校验选项，非法即抛 `OtpError`；`provider` 为仅供库内测试注入的可选参数（`HmacProvider` 不随 barrel 导出），缺省走 `requireHmac()` | — |
| `totp.generate(timestampMs?: number): string` | 生成当前（或指定时刻）验证码；返回 `digits` 位零填充字符串 | RFC 6238 §4.2 |
| `totp.verify(token: string, options?: VerifyOptions): number \| null` | 恒定时间比对；返回命中窗口相对当前步的**偏移 delta**（0=当前步，-1=上一步），未命中返回 `null` | RFC 6238 §5.2/§6 |
| `totp.remaining(timestampMs?: number): number` | 当前窗口剩余**整秒**，取值 `[1, period]` | — |
| `totp.progress(timestampMs?: number): number` | 当前窗口进度 `[0, 1)`，供环形进度条 | — |
| `totp.syncClockOffset(delta: number): void` | **单参数**；`clockOffsetMs += delta * period * 1000`（符号约定见下）；向码源时钟对齐 | RFC 6238 §6 |
| `totp.clockOffsetMs` (getter) | 当前偏移 | — |
| `totp.toURI(): string` | 输出规范 `otpauth://totp/...` | GA Key URI |
| `TOTP.fromURI(uri: string): TOTP` | 从 URI 构造（含 algorithm/digits/period/issuer/label） | GA Key URI |
| `new HOTP(options: HotpOptions, provider?: HmacProvider)` | 同上 | — |
| `hotp.generate(counter?: number): string` | RFC 4226 算码 | RFC 4226 §5.3 |
| `hotp.verify(token: string, options?: VerifyOptions): number \| null` | 返回命中 counter 偏移（窗口以**步**=1 计数） | RFC 4226 §7.4 |
| `HOTP.fromURI(uri: string): HOTP` / `hotp.toURI()` | 同上（`counter` 为 URI 必填参数） | GA Key URI |
| `Secret.fromBase32(s)` / `.fromBytes(u8)` / `.generate(bytes = 20)` | 规范化 / 构造 / 随机生成（默认 20 字节 = RFC 4226 推荐 160 bit）；随机源经 `requireRandom()` | RFC 4226 §4 R6 |
| `secret.toBase32()` / `.bytes` / `.byteLength` / `.bitLength` / `.toJSON()` | 规范化输出、强度自省、**序列化脱敏**（`toJSON()` 返回 `'[REDACTED]'`） | — |
| `OTPAuthURI.parse(uri): OtpAuthParams` / `OTPAuthURI.build(p): string` | 纯解析/生成（不做实例构造） | GA Key URI |
| `enum OtpAlgorithm { SHA1, SHA256, SHA512 }` | 算法枚举（字符串值 `'SHA1'`/`'SHA256'`/`'SHA512'`） | RFC 6238 §1.2 |
| `enum OtpType { TOTP = 'totp', HOTP = 'hotp' }` | URI 类型枚举 | GA Key URI |
| `class OtpError extends Error { readonly code: OtpErrorCode }` | 统一错误模型（见 §3.5） | — |

**关键 API 决策**

1. **同步 API（非 Promise）**：`*Sync` 接口已确认可用；8 字节 HMAC 是微秒级计算；避免 Promise 传染与竞态。
2. **`verify` 返回 delta 而非 boolean**：布尔无法支撑时钟偏移估算，delta 是 `boolean + 校准量` 的超集。
3. **`verify` 默认 `window = 0`（严格）**：客户端要复现服务端接受范围（RFC 6238 §5.2 允许 1 步网络延迟）时必须显式传 `window: 1`；默认严格 = 默认安全。
4. **不缓存 `Mac`/`SymKey`**（v1）：避免实例状态与生命周期复杂度，性能优化留待有 profile 证据再做。
5. **`internal/*` 与 `HmacProvider` 不进 barrel**，但测试通过深路径直接注入 fixture。
6. **`Secret.generate()` 经 kit-free 注册表取随机源**：`Secret.ets` 永不 import kit。
7. **`Secret.toJSON()` 返回 `'[REDACTED]'`**：ArkTS 的 `private` 只是编译期约束，`_bytes` 是可枚举自有属性，宿主 `JSON.stringify(secret)` 会泄漏密钥；实现 `toJSON` 是唯一可靠且可单测的堵漏手段（README 同步明示该限制）。

**`syncClockOffset` 符号约定**：

| 场景 | 本地(运行库一方) | 码源时钟 | 码源 counter | 本地 verify(码, window:1) | 校准公式 | 校准后 |
|---|---|---|---|---|---|---|
| A 本地**慢** 30s | 59s(counter 1) | 89s | 2 | delta = **+1** | `+= 1*30000 = +30000` | effectiveTs 对齐 89s,window=0 直接命中 ✓ |
| B 本地**快** 30s | 89s(counter 2) | 59s | 1 | delta = **-1** | `+= (-1)*30000 = -30000` | effectiveTs 对齐 59s,window=0 直接命中 ✓ |
> 即 delta = 码源 counter − 本地 counter;校准把本地 effectiveTs 向码源对齐(RFC 6238 §6
> "adjusted with the recorded number of time-step clock drifts";与 Google Authenticator
> TotpClock 的 timeCorrection 语义一致)。闭环不变量:verify→sync→verify(window=0) 命中 delta=0,
> 由 `syncClockOffset_closure_slowLocal` / `syncClockOffset_closure_fastLocal` 用例锁死。

### 3.3 算法设计与 RFC 对应关系

```
counter  = floor((floor(epochMs/1000) - t0) / period)   # RFC 6238 §4.2，T0 缺省 0，t0 单位秒
bytes    = uint64_be(counter)                           # 8 字节大端
digest   = HMAC(alg, secretBytes, bytes)                # RFC 4226 §5.3 Step 1
offset   = digest[last] & 0x0f                          # 动态截断
v        = (digest[offset] & 0x7f) << 24 | ...          # 31 位非负，屏蔽最高位
code     = (v mod 10^digits) 左补零至 digits 位          # §5.3 Step 3
```

| RFC 要求 | 出处 | 本库实现点 |
|---|---|---|
| secret ≥ 128 bit，推荐 160 bit | RFC 4226 §4 R6 | `Secret.bitLength` + 可选 `minSecretBits`（**默认不强制**，见 §5） |
| 最少 6 位，可能 7/8 位 | RFC 4226 §5.3 | `digits` 允许 6/7/8，其余抛错 |
| 动态截断屏蔽最高位 | RFC 4226 §5.3 | `Truncate.apply` 的 `& 0x7f` |
| **必须支持 T 超过 32 位整数** | RFC 6238 §4.2 | `Counter.toBytes` 用 high/low 拆分（**不得用 `<<` 拼 32 位**，ArkTS 位运算是 32 位有符号） |
| 默认步长 30s | RFC 6238 §5.2 | `period` 默认 30 |
| 最多允许 1 个时间步网络延迟 | RFC 6238 §5.2 | `verify` 的 `window` 参数（默认 0，文档引导服务端型用法传 1） |
| 校验侧限制漂移步数并记录 | RFC 6238 §6 | `verify` 返回 delta + `syncClockOffset` |
| SHA256/SHA512 可选 | RFC 6238 §1.2 | `OtpAlgorithm` 三值 |
| Throttling（失败退避/锁定，跨会话） | RFC 4226 §7.3 | **不实现**：需要跨会话服务端状态，属校验服务职责，README 引用条款说明 |

**恒定时间比较**：`TimeStep.constantTimeEquals(a, b)` 逐字符异或累加，不早退；`verify` 在整个 window 范围内**扫完所有候选后再返回首个命中的 delta**，避免用提前返回泄漏「命中了第几个窗口」。

**统一约束**（全部纯函数，本地可测）：

| 输入 | 规则 | 违规错误码 |
|---|---|---|
| `digits` | 必须是 6/7/8 整数 | `INVALID_DIGITS` |
| `period` | 正整数 | `INVALID_PERIOD` |
| `t0` | ≥0 整数（**单位秒**） | `INVALID_T0` |
| `counter` | ≥0 整数，≤ `Number.MAX_SAFE_INTEGER`（2^53-1） | `INVALID_COUNTER` |
| `timestampMs` | >0 有限数 | `INVALID_TIMESTAMP` |
| `window` | ≥0 整数 | `INVALID_WINDOW` |
| `token`（verify 入参） | 纯数字且长度 = `digits` | `INVALID_TOKEN` |
| `minSecretBits` | ≥0 整数；非 0 时不足即抛 | `SECRET_TOO_WEAK` |

> **counter 上限说明**：RFC 4226 的 counter 是 64 位，ArkTS `number` 精确整数上限 2^53-1。2^53-1 步 × 30s ≈ 8.5×10⁹ 年，实践中不可触及，故**不做 BigInt 支持**，超限直接抛错（README 量化说明）。RFC 6238 §4.2 的「T 超 32 位」要求由 timestamp 路径满足（官方向量含 T=20000000000 → counter=666666666），并额外用 counter=2^32、2^32+1、2^53-1 三个边界用例覆盖。

**verify 窗口语义**：

- TOTP：`window` 单位为**时间步**；候选 counter 从 `counter - window` 扫到 `counter + window`；**counter < 0 的候选直接跳过**（epoch 之前无定义，不报错）。
- HOTP：`window` 单位为**步（=1 counter）**，语义同上。
- 返回值：命中候选的相对偏移（`candidate - base`），最负为 `-window`；未命中 `null`。

**`remaining` / `progress` 公式**（**`t0` 偏移与负值归一化必须有 `t0≠0` 的专项用例锁定**）：

```
s = floor(epochMs / 1000)
remainingSec = period - (((s - t0) % period) + period) % period   // 落在 [1, period]
progress     = (((s - t0) % period) + period) % period / period   // 落在 [0, 1)

参照点：s=59,p=30 → 1；s=60,p=30 → 30；s=1,p=30 → 29；s=45,p=45 → 45
 t0≠0 参照点：s=31,t0=1,p=30 → 30；s=1,t0=5,p=30 → 4（负值归一化：((1-5)%30+30)%30=26 → 30-26=4）
```

### 3.4 otpauth URI 解析规则

`otpauth://TYPE/LABEL?PARAMETERS`，`TYPE ∈ {totp, hotp}`（Google Authenticator Key URI Format，IANA 状态 **Provisional #13829，非 RFC**）。

| 字段 | 缺省 | 非法处理 |
|---|---|---|
| `type` | — | 非 `totp`/`hotp` → `UNSUPPORTED_OTPAUTH_TYPE` |
| `secret` | — | 缺失/空 → `EMPTY_SECRET`；非法字符 → `INVALID_BASE32_CHAR`；合法但不足 1 字节 → `SECRET_TOO_SHORT` |
| `issuer` | 空 | 与 label 前缀不一致时**以 query 参数为准**（宽容策略，README 注明） |
| label | 空 | 支持 `issuer:account` 与 `issuer%3Aaccount` 两种分隔；issuer 与 account 内部不再按冒号切分 |
| `algorithm` | `SHA1` | 大小写不敏感映射；非 SHA1/SHA256/SHA512 → `INVALID_ALGORITHM` |
| `digits` | `6` | 非 6/7/8 → `INVALID_DIGITS` |
| `period` | `30`（仅 totp） | 非正整数 → `INVALID_PERIOD` |
| `counter` | `0`（仅 hotp，规范要求必填） | 非非负整数 → `INVALID_COUNTER` |
| 未知 query 参数 | — | **忽略**（最大化互操作；不报错） |

解析要点：scheme 大小写不敏感（`OTPAUTH://`）；不做 `URLSearchParams` 假设（ArkTS 可用性不确定），手写 query 拆分；百分号解码失败回退原串；secret 输出统一规范化为**大写无填充 base32**。

> **实现注意**：`period` 会改变 counter 的取值——`fromURI` 带 `period=60` 时，`generate(59000)` 的 counter 是 `floor(59/60)=0`，**不是** 1。

### 3.5 错误模型

```ts
export enum OtpErrorCode {
  EMPTY_SECRET = 'EMPTY_SECRET',
  INVALID_BASE32_CHAR = 'INVALID_BASE32_CHAR',
  SECRET_TOO_SHORT = 'SECRET_TOO_SHORT',
  SECRET_TOO_WEAK = 'SECRET_TOO_WEAK',
  INVALID_ALGORITHM = 'INVALID_ALGORITHM',
  INVALID_DIGITS = 'INVALID_DIGITS',
  INVALID_PERIOD = 'INVALID_PERIOD',
  INVALID_T0 = 'INVALID_T0',
  INVALID_COUNTER = 'INVALID_COUNTER',
  INVALID_TIMESTAMP = 'INVALID_TIMESTAMP',
  INVALID_WINDOW = 'INVALID_WINDOW',
  INVALID_TOKEN = 'INVALID_TOKEN',
  CRYPTO_FAILED = 'CRYPTO_FAILED',
  CRYPTO_NOT_INITIALIZED = 'CRYPTO_NOT_INITIALIZED',
  INVALID_OTPAUTH_URI = 'INVALID_OTPAUTH_URI',
  UNSUPPORTED_OTPAUTH_TYPE = 'UNSUPPORTED_OTPAUTH_TYPE',
  NOT_IMPLEMENTED = 'NOT_IMPLEMENTED'
}
```

**共 17 个成员，取值必须为上述字符串字面量**（字符串枚举在本机 SDK 的 `.d.ts` 中有实际使用；调用方按字符串比较 `e.code`）。

| 规则 | 说明 |
|---|---|
| 一切失败都抛 `OtpError`（`extends Error`），携带 `code` | 调用方可 `switch (e.code)` 精确分支；不用字符串匹配 |
| **消息不含 secret、不含派生密钥** | 硬约束；`CRYPTO_FAILED` 统一为固定文案，不透传原生错误对象 |
| `CRYPTO_NOT_INITIALIZED` 专用于「注册表未注册」 | 与「平台调用失败」(`CRYPTO_FAILED`) 分开，便于宿主排障（深路径导入且未注入 provider 时会遇到） |
| 选项校验在**构造期**完成 | 失败尽早暴露；对 `secret` 只解析一次并缓存 bytes |
| 不吞错、不打日志、不上报 | 库零 hilog 依赖，错误归属调用方 |
| `NOT_IMPLEMENTED` 为枚举占位，无任何代码路径抛出 | 保证错误码表完整性 |

### 3.6 发布形态与兼容性

| 项 | 决策 | 依据/风险 |
|---|---|---|
| 包名 | `@yansongda/otp` | `@group/name` 合法（group 小写字母开头） |
| 版本 | `1.0.0` | 强制 semver；**同版本发布后不可覆盖/不可复用**，只能发新版本 |
| 必填字段 | `description`(6–512) / `author`(对象：name + email 或 url，**必须为对象**) / `repository`(开源包必填) | OHPM《发包规则汇总》比官方字段表更严，以后者为准 |
| 推荐字段 | `keywords`（**非必填**，仅影响检索） | — |
| 四件套 | `oh-package.json5` + `README.md` + `CHANGELOG.md` + `LICENSE`（均非空） | 缺任一个上架失败；README **必须包含 `ohpm install @yansongda/otp`**，CHANGELOG **必须含当前版本号** |
| README 多语言 | `README.md`（英文，必交）+ `README-cn.md`（中文，附加） | OHPM 必交项只有 `README.md` |
| LICENSE | MIT（与 `oh-package.json5` 一致） | MIT/Apache-2.0 均可 |
| 依赖 | `dependencies: {}` 保持零依赖 | 三方库引用本库时**代码级不传递**依赖 |
| 测试依赖 | `@ohos/hypium 1.0.25`、`@ohos/hamock 1.0.0` 位于 `library/oh-package.json5` 的 `devDependencies` | `devDependencies` 不随 HAR 分发 |
| HAR 产物 | 字节码 HAR：`ets/modules.abc` + 构建自动生成的 `Index.d.ets` 与各 `.d.ets` 声明（无需手工补 `types`）；`obfuscation.enable: false` | `ohpm prepublish` 会对「包含源码」给出 WARN，属预期 |
| 本地包预检 | `ohpm prepublish <产物.har>`（`ohpm` 子命令清单含 `prepublish`、**不含 `pack`**） | — |
| compatibleSdkVersion | **`6.0.0(20)`** | 代价：API 12–19 的工程无法消费（HAR 的 compatibleSdkVersion 不得大于使用方）。README 顶部已声明 |
| 混淆 | 不开启（v1） | 开源 HAR 更可调试 |
| 发布动作 | **不在本方案范围**：只产出可发布产物（`assembleHar`）+ 物料 | 需 OHPM 账号 + RSA 密钥 + publish_id，且**版本号一次性占用**；发布为人工闸门 |

### 3.7 失败场景与降级

| 环节 | 失败场景 | 表现 | 降级/处置 |
|---|---|---|---|
| 构造 | secret 含非法字符/为空 | 抛 `OtpError` | 调用方决定是否回落服务端（旧 `/totp/detail` 兜底模式在宿主持有） |
| 生成 | cryptoFramework 调用失败 | 抛 `OtpError(CRYPTO_FAILED)`，固定文案 | 同上；库内不重试（失败是平台级的） |
| 生成 | 注册表未注册（深路径导入且未注入） | 抛 `OtpError(CRYPTO_NOT_INITIALIZED)` | 消费者经 barrel 导入即自动注册；深路径导入者须显式注入 provider |
| 校验 | token 非法格式 | 抛 `INVALID_TOKEN` | 调用方按输入校验处理（提示用户重新输入） |
| 校验 | 未命中任何窗口 | 返回 `null` | 调用方可放大 `window` 或判定失败 |
| 解析 | URI 非法/类型不支持 | 抛 `OtpError` | 调用方提示「二维码格式不支持」 |
| 本地测试 | Local Test 环境 crypto 不可用 | 仅影响默认 provider 路径 | kit-free 全链路用例仍全绿；真实 crypto 由 `ohosTest` 设备用例覆盖 |

---

## 4. 监控与可观测性

**本库的设计立场：库内零日志、零上报、零埋点**（避免 secret 泄漏面、避免与宿主日志策略冲突、避免成为三方库的隐私风险点）。可观测性通过「可分类的错误码 + README 故障排查表」交付给宿主。

- **错误分类**（宿主可据此打点）：`OtpError.code` 共 17 个枚举值（见 §3.5；README 故障排查表覆盖 16 个对外码），宿主若需上报，只需上报 `code` 字符串，**禁止上报 secret/token**。
- **强度自省**：`Secret.bitLength` / `byteLength` 供宿主在账户导入时做一次性合规检查（例如提示「该密钥低于 RFC 4226 建议的 128 bit」）。
- **漂移可观测**：`verify()` 返回的 delta 是宿主的可观测信号——持续非 0 说明设备时钟漂移，宿主可据此提示或调用 `syncClockOffset`。建议宿主指标：`otpVerifyDeltaHistogram`（按绝对值分布）、`otpVerifyFailureRate`（null 占比）。
- **README 故障排查表**：`错误码 → 现象 → 根因 → 处置`（例：`CRYPTO_NOT_INITIALIZED` → 深路径导入后调用报错 → 未经 barrel 导入或未注入 provider → 改从 `@yansongda/otp` 导入）。
- **不设计的部分**：不做内置埋点、不做 hilog、不写入任何持久化存储。

---

## 5. 风险与已知限制

| 风险 / 限制 | 严重度 | 现状与对策 |
|---|---|---|
| **静态导入传递性**使「公开类 PC 可测」失效（kit 被连带加载，测试套件在模块加载期整体失败） | 高 | 已按 kit-free 接口层 + 注册表 + kit-only 实现层分离落地；公开类与 `Secret` 只值导入 kit-free 层；`grep` 断言全库仅 `internal/CryptoSource.ets` 一处 `@kit` |
| **Local Test 不支持系统 API**，真实 crypto 路径无法在 PC 测 | 中 | 实测本地 crypto 返回空数据：`src/test` 只覆盖 kit-free 全链路，真实适配器由 `ohosTest` 设备用例兜底；README 已声明该覆盖边界 |
| 真实后端 secret 仅 80 bit（`JBSWY3DPEHPK3PXP`），若强制 RFC 4226 §4 R6 的 128 bit 会误伤存量账户 | 中 | `minSecretBits` **默认 0（不强制）**，只暴露 `Secret.bitLength` 让调用方自决策；README 解释取舍 |
| `Secret` 被 `JSON.stringify` 时泄漏密钥（`private` 仅编译期） | 高 | `toJSON()` 返回 `'[REDACTED]'` + 单测断言 `JSON.stringify({s: secret})` 不含密钥；README 明示限制 |
| `compatibleSdkVersion` 为 (20)，API 12–19 工程无法消费 | 中 | 已决策；README 顶部显式声明；放宽兼容性需另开任务 |
| secret 泄漏（异常消息 / toString / 日志） | 高 | 硬约束：库内零 hilog、异常消息固定文案、`toJSON` 脱敏、刻意不实现 `toString()`；最终验证用 grep 机械检查 |
| 与后端/微信端语义漂移（后端硬编码 SHA1 + 6） | 中 | 默认值对齐三方共识（SHA1/6/30）；README 明示默认值；RFC 向量跨端一致性用例固定 |
| `@security/no-unsafe-mac` lint 告警（HMAC-SHA1 命中） | 低 | 与旧仓库立场一致：**接受告警、不放宽规则、不加 disable 注释**；README 引用 RFC 6238 §1.2 说明 SHA1 的互操作依据 |
| 发布后发现问题无法覆盖同版本 | 中 | 发布前检查清单 + 同版本不可覆盖规则写入 README/CHANGELOG 流程；首次发布前 `ohpm prepublish` 预检 |
| `entry` 消费方 demo 含 UI 代码，可能污染库范围 | 低 | demo 仅 1 个文件、只依赖 barrel 导出、不参与 HAR 打包；Must NOT 清单禁止其被 `library` 反向依赖 |
| 设备端 `hvigorw onDeviceTest` 包装命令需签名前置（`signingConfigs` 非空） | 低 | 已实测：无签名时 `PackageHap`/`SignHap` 受阻；设备用例可经 DevEco IDE Run 或 `hdc install` + `aa test` 执行（后者已跑通） |

---

## 附录 A：RFC 官方向量

**RFC 6238 Appendix B**（`X=30`，`T0=0`，**digits=8**；⚠️ 三种算法 seed 长度不同）

| T(s) | counter | SHA1 (seed 20B `12345678901234567890`) | SHA256 (seed 32B `…9012`) | SHA512 (seed 64B `…01234`) |
|---|---|---|---|---|
| 59 | 1 | 94287082 | 46119246 | 90693936 |
| 1111111109 | 37037036 | 07081804 | 68084774 | 25091201 |
| 1111111111 | 37037037 | 14050471 | 67062674 | 99943326 |
| 1234567890 | 41152263 | 89005924 | 91819424 | 93441116 |
| 2000000000 | 66666666 | 69279037 | 90698825 | 38618901 |
| 20000000000 | 666666666 | 65353130 | 77737706 | 47863826 |

**RFC 4226 Appendix D**（seed = ASCII `12345678901234567890` = base32 `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`，**digits=6**）

| counter | HMAC-SHA1 digest（黄金 fixture） | code |
|---|---|---|
| 0 | `cc93cf18508d94934c64b65d8ba7667fb7cde4b0` | 755224 |
| 1 | `75a48a19d4cbe100644e8ac1397eea747a2d33ab` | 287082 |
| 2 | `0bacb7fa082fef30782211938bc1c5e70416ff44` | 359152 |
| 3 | `66c28227d03a2d5529262ff016a1e6ef76557ece` | 969429 |
| 4 | `a904c900a64b35909874b33e61c5938a8e15ed1c` | 338314 |
| 5 | `a37e783d7b7233c083d4f62926c7a25f238d0316` | 254676 |
| 6 | `bc9cd28561042c83f219324d3c607256c03272ae` | 287922 |
| 7 | `a4fb960c0bc06e1eabb804e5b397cdc4b45596fa` | 162583 |
| 8 | `1b3c89f65e6c9e883012052823443f048b4332db` | 399871 |
| 9 | `1637409809a679dc698207310c8c7fc07290d9e5` | 520489 |

> 代码内的**唯一向量来源**是 `library/src/test/vectors/RfcVectors.ets`（含 SHA256/SHA512 的 golden HMAC digest、counter 边界用例 2^32 / 2^32+1 / 2^53-1、`counterToBytes` 对照表、digits=7 抽样值）；设备端用例复用同一批期望值。

---

## 附录 B：验证结果

以 `docs/` 之外的可复现命令为准（命令见 `AGENTS.md`）：

| 项 | 结果 |
|---|---|
| 本地单测（`test --mode module -p module=library@default -p testType=local`） | `Tests run: 240, Failure: 0, Error: 0, Pass: 240, Ignore: 0`，`BUILD SUCCESSFUL` |
| 覆盖率 | lines 419/465 = **90.11%**；functions 48/55 = 87.27%；branches 183/207 = 88.41% |
| RFC 官方向量 | RFC 4226 Appendix D **10/10** + RFC 6238 Appendix B **18/18**（本地 fixture 路径） |
| 设备端 `ohosTest`（真实 cryptoFramework + barrel 链路 + 默认 provider） | **37/37 全绿**（`aa test`；`Tests run: 37, Failure: 0`） |
| HAR 产物 | `library/build/default/outputs/default/library.har`，包内 `src/test`/`ohosTest` 计数 = 0 |
| `ohpm prepublish` | `prepublish @yansongda/otp 1.0.0 succeed`（exit 0；1 条「含源码」WARN 属预期） |
| 消费方 | `entry` HAP `assembleHap` exit 0；demo 界面级核对通过 |

---

## 附录 C：不做清单（Must NOT）

- 不改动旧 MFA 仓库任何文件；不做旧工程切换（本库为独立 HAR，不反向依赖宿主）
- 不做 UI 库：`library` 内不含任何 `@Component`/ArkUI 代码
- 不做二维码渲染（只产出 `otpauth://` 字符串）；不做扫码
- 不实现 RFC 4226 §7.3 throttling（服务端职责，README 引用条款说明）
- 不支持 Steam Guard（非 RFC）、不支持 SHA224/SHA384/SM3（RFC 6238 §1.2 未列）
- 不引入任何运行时依赖；不引入 `@ohos/crypto-js` 等第三方算法库（含测试期）
- 不做 BigInt / 64 位 counter 全量支持（量化说明见 §3.3）
- 库内不打日志、不上报、不持久化、不缓存 secret 到磁盘
- 不执行 `ohpm publish`、不创建 git remote、不 push（人工闸门）
