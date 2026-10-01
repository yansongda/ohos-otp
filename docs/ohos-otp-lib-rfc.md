# ohos-otp v1 技术设计文档 —— RFC 4226/6238 通用 OTP 库

> **时间**：2026-10-01
> **作者**：DeepSeek V4.1 Flash + yansongda
> **状态**：经过人工审核确认（v4：已按 plan-reviewer **三轮**意见逐条独立复核后修订；下文任务编号统一为执行计划的 T01–T14。流程已到复审上限，遗留事项见 §7.4）
> **配套执行计划**：`docs/implementation/ohos-otp-lib-rfc.md`

> **v3 修订摘要**（完整处置见 §7 审查闭环）：
> - **第 1 轮（初审，2 BLOCKER / 6 MAJOR / 11 MINOR）**：① 加密层拆为「kit-free 接口层 + kit-only 实现层」，全库唯一 `@kit` 导入点收敛到 `internal/CryptoSource.ets`，修复「静态导入传递性击穿本地可测性」；② 修正计划正文 4 处可复算的事实性错误（remainingSec 期望值、fromURI 用例、t0 用例、多余参数），并**驳回**「`syncClockOffset` 符号应改 `+=`」的建议（附双向场景证明，见 §3.2）；③ 新增 `CRYPTO_NOT_INITIALIZED` 错误码；④ 新增 `Secret.toJSON()` 脱敏；⑤ `ohpm pack` → `ohpm prepublish`；⑥ 新增工程基线 commit（T01）与 `.gitignore` 修正；⑦ 重排任务依赖（Base32 独立成 T04）。
> - **第 2 轮（复审，0 BLOCKER / 4 MAJOR / 12 MINOR）**：⑧ `RandomFixture` 所有权收归 T08（原在 T08/T09 双归属，破坏 W4 并行互斥）；⑨ T12 的「README 示例可运行」验证改为**分支条件化**（分支 B 下改由 T11 的 barrel 用例覆盖，因库模块无法自解析自身包名、且相对路径导入 barrel 会拉入 kit）；⑩ 修正 3 处**破坏性验证红点不成立**的 QA（T04 红点改 `'ab0'` 用例、T06 补 `t0≠0` 用例后红点改到该用例、T07 改为函数体 grep 静态断言），其中 T06 连带补上了 `remainingSec`/`progress` 的 `t0` 路径零覆盖缺口；⑪ T05 的 Truncate 期望值改为**逐字照抄 A.2 第 4 列**（原指示「自行推导」与「禁止自证」冲突）；⑫ 其余 12 项 MINOR 逐条修入（任务编号对齐、`../../../../Index.ets` 层数、`Ability.test.ets` 处置、`fromBytes` 时序、构建令牌、`clockOffsetMs` 移出 `HmacOptions`、旧仓库行号等）。
> - **第 3 轮（最终复审，0 BLOCKER / 2 MAJOR / 12 MINOR）**：⑬ 补 `SHA256_C0_DIGEST` 常量（A.6 的 counter=0 digest 未落表，会导致 T10 的 fromURI 用例经 fixture 查表未命中而必红）；⑭ F4 的 `no-unsafe-mac` grep 范围收窄到 `library/src/` + `library/Index.ets`（原范围含 README，而 T12 要求 README 明写不使用该豁免，导致 F4 必然无法 APPROVE）；⑮ 12 项 MINOR：`BOUNDARY_COUNTERS` 记录结构改成按算法嵌套、`DIGITS7_SHA1` 补第 3 条（A.6 补 counter=9 行）、T07 标题/commit/W3 波次表述与所有权对齐、T12 故障排查表改 16 个对外码、T10 伪代码 `opts?`→`options?`、旧仓库行号 L149/L78、T03 步骤编号乱序、rule 2 授权补 T02、T02/T06/T10/T11 的验收与回退补齐、plan 头部版本与删除文件计数校正。

---

## 1. 背景与问题

### 现状

旧 MFA 元服务的端内算码实现位于 `application/huawei/atomicservice/MFA/entry/src/main/ets/utils/Totp.ets`（157 行），唯一生产调用方是 `models/Runtime.ets:194 freshCode()`；失败时回落后端 `POST api/v1/totp/detail`。后端（Rust `totp-rs 6.0.0`）硬编码 `SHA1 + 6 位 + period`（`build_noncompliant`）。同一算法在微信端另有一份实现（vendor `otpauth 9.5.2`）。

```
旧：UI(Runtime.freshCode) ──await──> TotpCode.compute(secret, period, Date.now())
                                       └─ base32Decode → counterToBytes → cryptoFramework HMAC-SHA1
                                          → truncate → zeroPad6   ← 全部挤在 1 个文件，顶层 import 系统 kit
```

### 困境

1. **不可复用**：实现内嵌在元服务 `entry` 模块，无法跨工程/跨端复用；微信端只能 vendor 第三方库 → 同算法两套实现，语义漂移无人守。
2. **能力残缺**：仅 TOTP + SHA1 + 6 位。缺 RFC 4226 HOTP、缺 RFC 6238 §1.2 允许的 SHA256/SHA512、缺 RFC 4226 §5.3 的"最少 6 位，可能 7/8 位"。
3. **无校验能力**：只有 `compute`（生成），没有 `verify`、没有时间漂移窗口（RFC 6238 §5.2/§6 明确建议校验侧允许步长漂移并记录偏移）、没有时钟偏移估算。
4. **无互操作**：不能解析/生成标准 `otpauth://` URI；旧创建页在 UI 层手工拼 URI 字符串（`pages/index/create/Index.ets:108-127`），secret 无规范化与校验。
5. **不可测试**：顶层 `import { cryptoFramework } from '@kit.CryptoArchitectureKit'` 与算法逻辑同处一文件，本地单测只能 import 纯函数子集，`TotpCode` 本身在 PC 上不可测（旧记录：这是「Plan A 已确认接受的后果」）。且旧工程 CLI 跑不了本地单测（元服务 `pages: $profile:pages` 与 hvigor 硬编码 `main_pages` 冲突）。
6. **不可发布**：无 README/CHANGELOG/LICENSE，不是 HAR 库形态，无法作为三方库对外提供。

### 目标（约束条件）

- **规范对齐**：RFC 4226 / RFC 6238 能力完整，两 RFC 附录官方测试向量 **100% 通过**
- **零运行时依赖**（除系统 `@kit.CryptoArchitectureKit`）
- **可发布**：满足 OHPM 中心仓上架硬性要求（四件套文件 + 元信息字段）
- **本地可测**：核心算法逻辑在 **PC 上无需设备**即可全量单测
- **绝不外泄**：无日志、无上报、异常消息不含 secret、序列化自动脱敏
- **API 稳定**：v1 起语义冻结，仅允许新增可选字段
- **兼容性**：`compatibleSdkVersion` 保持工程默认 `6.0.0(20)`（已由用户确认）

---

## 2. 整体方案

### 核心思路

**把「算码」拆成「纯算法核心（零系统依赖、PC 可全量测试）」+「系统加密实现（cryptoFramework 单点偶联、藏在 kit-only 文件里）」两层，中间用 kit-free 的接口 + 注册表解耦，用统一选项对象驱动 HOTP / TOTP / OTPAuthURI 三个对外能力，并按 OHPM 发布规范补齐元信息与四件套文档。**

**为什么必须用注册表而不是「公开类直接 import 实现类」**：ArkTS/ESM 的 `import` 是静态且传递的。若 `HOTP.ets` 顶层从「含 `@kit` 导入的文件」里值导入任何符号（哪怕是 `requireDefaultHmac()` 这种函数），加载 `HOTP.ets` 就会连带加载 `@kit.CryptoArchitectureKit`；而官方文档明确「本地测试当前不支持测试 C/C++ 方法及系统 API」，这将使 `Hotp.test.ets`/`Totp.test.ets`/`Secret.test.ets` 在**模块加载期**整体失败（不是少数用例失败）。因此 kit-free 层必须**不含任何 kit 导入**，且公开类只能从 kit-free 层导入。

### 架构图

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

### 文件结构（★新增 / ✎修改 / ✗删除）

```
ohos-otp/
├── .gitignore                                ✎ 补 `**/.hvigor`（当前只有根级 `/.hvigor`，模块级 .hvigor 会污染 git 洁净度验收）
├── build-profile.json5                       ✎ 仅允许一处改动：若 entry 构建因空 signingConfigs 失败，移除 products 的 "signingConfig": "default" 行
├── hvigorw / hvigorw.bat                     ★ 仅当 T02 判定 CLI 必需时补入（当前缺失）
├── library/
│   ├── oh-package.json5                      ✎ 补 description/author/repository/keywords；devDependencies 移入测试依赖
│   ├── Index.ets                             ✎ 由占位改为全量 barrel + installCryptoDefaults()
│   ├── README.md / README-cn.md              ★ 上架硬性要求（README.md 须含 ohpm install 命令）
│   ├── CHANGELOG.md                          ★ 上架硬性要求（须含当前版本号）
│   ├── LICENSE                               ★ 上架硬性要求（MIT，与 oh-package.json5 一致）
│   └── src/
│       ├── main/ets/
│       │   ├── OtpError.ets                  ★ 错误码枚举（17 个）+ OtpError
│       │   ├── OtpOptions.ets                ★ 全部对外选项/返回类型（DTO，字段表见 §3.2）
│       │   ├── Secret.ets                    ★ secret 规范化 / 校验 / 编解码 / 随机生成 / toJSON 脱敏
│       │   ├── HOTP.ets                      ★ RFC 4226 公开类
│       │   ├── TOTP.ets                      ★ RFC 6238 公开类
│       │   ├── OTPAuthURI.ets                ★ otpauth:// 解析与生成
│       │   ├── internal/
│       │   │   ├── Base32.ets                ★ RFC 4648 编解码（纯）
│       │   │   ├── Counter.ets               ★ 8 字节大端计数器（纯）
│       │   │   ├── Truncate.ets              ★ 动态截断（纯）
│       │   │   ├── Digits.ets                ★ mod 10^d + 补零（纯）
│       │   │   ├── TimeStep.ets              ★ 时间步/剩余/进度/恒定时间比较（纯）
│       │   │   ├── OtpEngine.ets             ★ 编排（纯，接收注入 provider）
│       │   │   ├── HmacProvider.ets          ★ 接口 + 注册表（**kit-free**）
│       │   │   └── CryptoSource.ets          ★ cryptoFramework 实现（**全库唯一 @kit 导入点**）
│       │   └── components/MainPage.ets       ✗ 删除（占位 UI 组件，库不该带 UI）
│       ├── test/                             （本地单测，PC 可跑）
│       │   ├── List.test.ets                 ✎ 全量注册（脚手架一次写全）
│       │   ├── vectors/RfcVectors.ets        ★ RFC 4226/6238 黄金向量（唯一来源）
│       │   ├── HmacFixture.ets               ★ 可注入 provider（黄金 digest）
│       │   ├── RandomFixture.ets             ★ 可注入随机源（供 Secret.generate 本地测）
│       │   ├── Base32.test.ets / Counter.test.ets / Truncate.test.ets
│       │   ├── Digits.test.ets / TimeStep.test.ets / Secret.test.ets
│       │   ├── CryptoSource.test.ets         ★ 真实 HMAC（分支 A 时本地跑，分支 B 时仅 smoke）
│       │   ├── OtpEngine.test.ets            ★ RFC 向量主战场
│       │   ├── Hotp.test.ets / Totp.test.ets / OtpAuthUri.test.ets / OtpError.test.ets
│       └── ohosTest/ets/test/
│           ├── List.test.ets                 ✎ 注册设备用例
│           └── CryptoAdapter.test.ets        ★ 真实 cryptoFramework vs RFC 向量（需真机/模拟器）
├── entry/
│   ├── oh-package.json5                      ✎ 增加对 @yansongda/otp 的本地依赖（消费方 smoke demo）
│   └── src/main/ets/pages/Index.ets          ✎ 替换为极简算码 demo（证明 HAR 可被消费）
└── docs/                                     ★ 本方案 + plan + evidence（本地工作产物）
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

**测试环境分支（T02 实测判定，**实现代码无分支**，分支只决定「本地测试能覆盖到哪一层」）**：

- **分支 A（Local Test 可加载并调用 kit）**：本地还能额外直连 `Index.ets`（连注册链路一起测）与 `CryptoSource.test.ets`（真实 HMAC 对 RFC 向量）→ 全链路本地可测。
- **分支 B（不可加载，或「能 import 但调用失败」的中间态，一律按 B 处理）**：本地只覆盖 kit-free 全链路（测试从深路径 import `HOTP`/`TOTP`/`Secret` 并注入 `HmacFixture`/`RandomFixture`，模块图内**不存在** `CryptoSource.ets`），默认 provider 链路由 `ohosTest` 设备用例覆盖 → **本分支下唯一接受的可测性缺口，须写入 README**。

> 判定标准：T02 的 ①②③ 三步（仅 import / 构造 generator+mac / 完成一次 HMAC 并匹配 RFC 4226 counter=1 的 digest）**全部成功**才算分支 A。

### 3.2 公共 API 契约

**选项类型字段表**（T03 按此逐字实现，字段名不得增删改）：

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
| `new TOTP(options: TotpOptions, provider?: HmacProvider)` | 构造；**同步**校验选项，非法即抛 `OtpError`；`provider` 为 `@internal` 测试 seam，缺省走 `requireHmac()` | — |
| `totp.generate(timestampMs?: number): string` | 生成当前（或指定时刻）验证码；返回 `digits` 位零填充字符串 | RFC 6238 §4.2 |
| `totp.verify(token: string, options?: VerifyOptions): number \| null` | 恒定时间比对；返回命中窗口相对当前步的**偏移 delta**（0=当前步，-1=上一步），未命中返回 `null` | RFC 6238 §5.2/§6 |
| `totp.remaining(timestampMs?: number): number` | 当前窗口剩余**整秒**，取值 `[1, period]` | — |
| `totp.progress(timestampMs?: number): number` | 当前窗口进度 `[0, 1)`，供环形进度条 | — |
| `totp.syncClockOffset(delta: number): void` | **单参数**；`clockOffsetMs -= delta * period * 1000`（符号证明见下） | RFC 6238 §6 |
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

**关键 API 决策**：

1. **同步 API（非 Promise）**。理由：① cryptoFramework 自 API 12 起提供 `convertKeySync/initSync/updateSync/doFinalSync`（已在本机 SDK `.d.ts` 实测确认存在）；② 8 字节 HMAC 是微秒级计算；③ 避免 Promise 传染与竞态——旧 `Runtime.ets` 的 `_computeSeq` 竞态修复（commit `d9ec896`）正是 async 算码带来的。
2. **`verify` 返回 delta 而非 boolean**。布尔无法支撑时钟偏移估算（scope C 的硬要求），delta 是 `boolean + 校准量` 的超集。
3. **`verify` 默认 `window = 0`（严格）**，并把 RFC 6238 §5.2 的"最多 1 步网络延迟"写进文档：客户端要复现服务端接受范围时必须显式传 `window: 1`。默认严格 = 默认安全。
4. **不缓存 `Mac`/`SymKey`**（v1）。避免实例状态与生命周期复杂度；单次调用开销可忽略，性能优化留待有 profile 证据再做。
5. **`internal/*` 与 `HmacProvider` 不进 barrel**，但测试通过深路径 `import ... from '../main/ets/internal/HmacProvider'` 直接注入 fixture。
6. **`Secret.generate()` 纳入 v1**（用户确认），随机源经 kit-free 注册表获取，`Secret.ets` 永不 import kit。
7. **`Secret.toJSON()` 返回 `'[REDACTED]'`**：ArkTS 的 `private` 只是编译期约束，`_bytes` 是可枚举自有属性，宿主 `JSON.stringify(secret)` 会泄漏密钥；实现 `toJSON` 是唯一可靠且**可单测**的堵漏手段（README 同步明示该限制）。

**`syncClockOffset` 符号证明（驳回初审的 `+=` 建议，以此表为准）**：

| 场景 | 服务端 | 设备原始时钟 | 设备产出的码 | 服务端 `verify(ts=服务端时间, window:1)` | 修正所需 offset | 公式 `-= delta*period*1000` |
|---|---|---|---|---|---|---|
| A 设备**快** 30s | 59s（counter 1） | 89s | counter 2 | delta = **+1** | **-30000**（89s 要算成 59s） | `-1*30000 = -30000` ✓ |
| B 设备**慢** 30s | 89s（counter 2） | 59s | counter 1 | delta = **-1** | **+30000**（59s 要算成 89s） | `+1*30000 = +30000` ✓ |

> 反证：若按初审建议改为 `+=`，场景 A 会得到 `offset=+30000` → `generate(89000)` 有效时间 119s → counter **3**（应为 1），反而算错。**因此 `-=` 是正确公式，v1 保留**；初审真正命中的缺陷是「计划里 T10 的测试期望值写反了」（用了 `delta=-1` 却期望 `-30000`，且断言 `generate(59000)` 恢复），已修正为「`delta=+1` → `-30000` → `generate(89000)` 命中 T=59 的码」。

### 3.3 算法设计与 RFC 对应关系

```
counter  = floor((floor(epochMs/1000) - t0) / period)   # RFC 6238 §4.2，T0 缺省 0，t0 单位秒
bytes    = uint64_be(counter)                           # 8 字节大端
digest   = HMAC(alg, secretBytes, bytes)                # RFC 4226 §5.3 Step 1
offset   = digest[last] & 0x0f                          # 动态截断
v        = (digest[offset] & 0x7f) << 24 | ...          # 31 位非负，屏蔽最高位
code     = (v mod 10^digits) 左补零至 digits 位          # §5.3 Step 3
```

| RFC 要求 | 出处 | 本库实现点 | 旧实现 |
|---|---|---|---|
| secret ≥ 128 bit，推荐 160 bit | RFC 4226 §4 R6 | `Secret.bitLength` + 可选 `minSecretBits`（**默认不强制**，见风险表） | ✗ 无 |
| 最少 6 位，可能 7/8 位 | RFC 4226 §5.3 | `digits` 允许 6/7/8，其余抛错 | ✗ 硬编码 6 |
| 动态截断屏蔽最高位 | RFC 4226 §5.3 | `Truncate.apply` `& 0x7f` | ✓ |
| **必须支持 T 超过 32 位整数** | RFC 6238 §4.2 | `Counter.toBytes` 用 high/low 拆分（**不得用 `<<` 拼 32 位**，ArkTS 位运算是 32 位有符号） | ✓ |
| 默认步长 30s | RFC 6238 §5.2 | `period` 默认 30 | ✓（来自后端） |
| 最多允许 1 个时间步网络延迟 | RFC 6238 §5.2 | `verify` 的 `window` 参数（默认 0，文档引导服务端型用法传 1） | ✗ |
| 校验侧限制漂移步数并记录 | RFC 6238 §6 | `verify` 返回 delta + `syncClockOffset` | ✗ |
| SHA256/SHA512 可选 | RFC 6238 §1.2 | `OtpAlgorithm` 三值 | ✗ 仅 SHA1 |
| Throttling（失败退避/锁定，跨会话） | RFC 4226 §7.3 | **不实现**：需要跨会话服务端状态，属校验服务职责，README 引用条款说明 | ✗ |

**恒定时间比较**：`TimeStep.constantTimeEquals(a, b)` 逐字符异或累加，不早退；`verify` 在整个 window 范围内**扫完所有窗口后再返回首个命中的 delta**，避免用提前返回泄漏"命中了第几个窗口"。

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

> **counter 上限说明**：RFC 4226 的 counter 是 64 位，ArkTS `number` 精确整数上限 2^53-1。2^53-1 步 × 30s ≈ 8.5×10⁹ 年，实践中不可触及，故**不做 BigInt 支持**，超限直接抛错（README 量化说明）。RFC 6238 §4.2 的"T 超 32 位"要求由 timestamp 路径满足（官方向量含 T=20000000000 → counter=666666666），并额外用 counter=2^32、2^32+1、2^53-1 三个边界用例覆盖（黄金 fixture 已备）。

**verify 窗口语义**：

- TOTP：`window` 单位为**时间步**；候选 counter 从 `counter - window` 扫到 `counter + window`；**counter < 0 的候选直接跳过**（epoch 之前无定义，不报错）。
- HOTP：`window` 单位为**步（=1 counter）**，语义同上。
- 返回值：命中候选的相对偏移（`candidate - base`），最负为 `-window`；未命中 `null`。

**`remaining` / `progress` 公式**（T06 必须按此实现，勿用「窗口边界即整周期」的直觉值；**`t0` 偏移与负值归一化必须有 `t0≠0` 的专项用例锁定**，否则该实现细节零覆盖）：

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

> **注意 `period` 对 counter 的影响**：`fromURI` 带 `period=60` 时，`generate(59000)` 的 counter 是 `floor(59/60)=0`，**不是** 1。写用例时务必先算 counter 再查向量表。

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

**共 17 个成员，取值必须为上述字符串字面量**（字符串枚举在本机 SDK 的 `.d.ts` 中有实际使用，编译支持已确认；T13 的 demo 里 `e.code === 'INVALID_BASE32_CHAR'` 依赖字符串比较）。

| 规则 | 说明 |
|---|---|
| 一切失败都抛 `OtpError`（`extends Error`），携带 `code` | 调用方可 `switch (e.code)` 精确分支；不再用字符串匹配 |
| **消息不含 secret、不含派生密钥** | 硬约束（旧实现 `'TOTP secret 含非法字符'` 也不含）；`CRYPTO_FAILED` 统一为固定文案，不透传原生错误对象 |
| `CRYPTO_NOT_INITIALIZED` 专用于「注册表未注册」 | 与「平台调用失败」(`CRYPTO_FAILED`) 分开，便于宿主排障（分支 B 下深路径导入者会遇到） |
| 选项校验在**构造期**完成 | 失败尽早暴露；对 `secret` 只解析一次并缓存 bytes |
| 不吞错、不打日志、不上报 | 库零 hilog 依赖，错误归属调用方 |
| `NOT_IMPLEMENTED` 仅用于脚手架占位 | 最终交付前由 F1 用 grep 验证零残留 |

### 3.6 发布形态与兼容性

| 项 | 决策 | 依据/风险 |
|---|---|---|
| 包名 | `@yansongda/otp`（已就位） | `@group/name` 合法（group 小写字母开头） |
| 版本 | `1.0.0` | 强制 semver；**同版本发布后不可覆盖/不可复用**，只能发新版本 |
| 必填字段 | 补 `description`(6–512) / `author`(对象：name + email 或 url，**必须为对象**) / `repository`(开源包必填) | OHPM《发包规则汇总》比官方字段表更严，以后者为准 |
| 推荐字段 | `keywords`（**非必填**，仅影响检索） | 初审 MINOR 9 已纠正 |
| 四件套 | `oh-package.json5` + `README.md` + `CHANGELOG.md` + `LICENSE`（均非空） | 缺任一个上架失败；README **必须包含 `ohpm install @yansongda/otp`**，CHANGELOG **必须含当前版本号** |
| README 多语言 | `README.md`（英文，必交）+ `README-cn.md`（中文，附加） | OHPM 必交项只有 `README.md`；中文版命名按官方 `readme-cn.md`/`readme_cn.md` 惯例，大小写差异不影响必交项校验 |
| LICENSE | MIT（与 `oh-package.json5` 一致） | 已有 license 字段；官方案例中 MIT/Apache-2.0 均可 |
| 依赖 | `dependencies: {}` 保持零依赖 | 三方库引用本库时**代码级不传递**依赖，零依赖最省事 |
| 测试依赖 | `@ohos/hypium 1.0.25`、`@ohos/hamock 1.0.0` 移到 `library/oh-package.json5` 的 `devDependencies` | `devDependencies` 不随 HAR 分发 |
| HAR 产物类型 | 目标：**源码 HAR**（`obfuscation.enable: false` 已就位）；若 toolchain 默认产出字节码 HAR，则须补 `types` 指向 `.d.ets` | ⚠️ **推断未实测**，T02 检视 `assembleHar` 产物内容 |
| 本地包预检 | 用 **`ohpm prepublish <产物.har>`**（实测 `ohpm` 子命令清单含 `prepublish`、**不含 `pack`**） | 初审 MAJOR 3 已纠正 |
| compatibleSdkVersion | **保持 `6.0.0(20)`**（用户确认） | 代价：API 12–19 的工程无法消费（字节码 HAR 约束：HAR 的 compatibleSdkVersion 不得大于使用方）。须在 README 顶部声明。后续如需放宽另开任务 |
| 混淆 | 不开启（v1） | 开源 HAR 更可调试；开混淆会强制要求 `types` 声明文件 |
| 发布动作 | **不在本方案范围**：只产出可发布产物（`assembleHar`）+ 物料 | 需 OHPM 账号 + RSA 密钥 + publish_id，且**版本号一次性占用** |

### 3.7 失败场景与降级

| 环节 | 失败场景 | 表现 | 降级/处置 |
|---|---|---|---|
| 构造 | secret 含非法字符/为空 | 抛 `OtpError` | 调用方决定是否回落服务端（旧 `Runtime.freshCode()` 的 `/totp/detail` 兜底模式在宿主持有） |
| 生成 | cryptoFramework 调用失败 | 抛 `OtpError(CRYPTO_FAILED)`，固定文案 | 同上；库内不重试（失败是平台级的） |
| 生成 | 注册表未注册（深路径导入且未注入） | 抛 `OtpError(CRYPTO_NOT_INITIALIZED)` | 消费者经 barrel 导入即自动注册；深路径导入者须显式注入 provider |
| 校验 | token 非法格式 | 抛 `INVALID_TOKEN` | 调用方按输入校验处理（提示用户重新输入） |
| 校验 | 未命中任何窗口 | 返回 `null` | 调用方可放大 `window` 或判定失败 |
| 解析 | URI 非法/类型不支持 | 抛 `OtpError` | 调用方提示"二维码格式不支持" |
| 本地测试 | 分支 B 下 kit 不可加载 | 仅影响默认 provider 路径 | kit-free 全链路用例仍全绿；真实 crypto 由 `ohosTest` 设备用例覆盖 |

---

## 4. 推进策略

| 阶段 | 内容 | 验证点 | 回滚 |
|---|---|---|---|
| **P-1 工程基线（串行，最先）** | ① `.gitignore` 补 `**/.hvigor` 与 `**/oh_modules`（防止模块目录产物污染 git 洁净度验收）；② 提交**基线 commit**（当前仓库零 commit，全文件 untracked，没有基线就无法 revert 被删除的文件、也无法用 `git status` 判定越界） | `git log --oneline` ≥1 条；`git status --short` 为空 | 无（这是回滚能力的来源） |
| **P0 可行性 spike（串行）** | ① 判定 CLI 构建/测试命令（必要时补 `hvigorw` 包装器）；② 实测 `hvigorw test -p module=library -p testType=local`；③ 实测 Local Test 能否加载并**调用** kit（三步），定分支 A/B；④ 实测 `*Sync` 接口可编译可用；⑤ 检视 `assembleHar` 产物类型；⑥ ArkTS 语言特性探针（`class extends Error` 的 `instanceof`、字符串枚举、class getter、`JSON.stringify` 是否走 `toJSON`、type-only import 是否被视作依赖） | 6 项结论写入 `docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`（逐字命令 + 原始输出）；分支判定标准 = ①②③ 全成功 | 临时文件 `git clean` 即回滚（基线已存在） |
| **P1 脚手架（串行）** | 目录/占位文件/全量 barrel/全量测试注册/`oh-package.json5` 元信息/四件套骨架/删 `MainPage.ets`；跑一次构建与本地单测 | `assembleHar` 与本地单测命令双绿 | `git revert` 单个 commit |
| **P2 kit-free 纯逻辑层（并行 4 路）** | Base32；Counter+Truncate+Digits；TimeStep；`CryptoSource` 适配器实现（kit-free 注册表已由 T03 完成） | 各自单测绿 | 逐 todo revert |
| **P3 解析层 + 编排层（并行 2 路）** | Secret+OTPAuthURI；RfcVectors+HmacFixture+OtpEngine（RFC 全量向量） | RFC 4226 10/10 + RFC 6238 18/18 全绿 | 逐 todo revert |
| **P4 公开类** | HOTP/TOTP + 时钟偏移 | 公开类用例绿 | 逐 todo revert |
| **P5 物料/设备/消费方（并行 3 路）** | README/CHANGELOG/License；`ohosTest` 真实 crypto 向量；`entry` 消费方 demo | 四件套齐全；设备用例通过；entry 编译通过 | 逐 todo revert |
| **P6 交付** | 覆盖率 + `ohpm prepublish` + `assembleHar` 产物检视 + README 发布前检查清单 | 覆盖率报告产出；`prepublish` 通过 | 无外部副作用（未发布） |

**回滚要点**：P-1 的基线 commit 是所有回滚的前提；此后每个 todo 独立 commit，回滚即 `git revert <sha>`。本方案**不触碰**旧 MFA 仓库、不动线上服务，无生产影响。发布环节是人工闸门。

---

## 5. 风险与对策

| 风险 | 严重度 | 对策 |
|---|---|---|
| **静态导入传递性**使「公开类 PC 可测」失效（kit 被连带加载，测试套件在模块加载期整体失败） | 高 | 已按初审 BLOCKER 1 重构：kit-free 接口层 + 注册表 + kit-only 实现层分离；公开类与 `Secret` 只值导入 kit-free 层；验收 grep 断言全库仅 `internal/CryptoSource.ets` 一处 `@kit` |
| **Local Test 不支持系统 API**（官方原文），真实 crypto 路径无法在 PC 测 | 中 | 分支 A/B 只影响「本地覆盖到哪一层」，实现代码无分支；真实适配器由 `ohosTest` 设备用例兜底；T02 结论写入 README |
| 仓库零 commit、`git status` 基线混乱、模块级 `.hvigor` 污染 | 中 | P-1 先打基线 commit + `.gitignore` 补 `**/.hvigor`；验收措辞改为「相较基线无新增未跟踪项」 |
| 仓库缺 `hvigorw`，CLI 构建/测试命令不存在 | 中 | T02 判定调用方式；必要时从 `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/` 补标准包装器 |
| **RFC 6238 向量 seed 长度按算法不同**（SHA1=20B / SHA256=32B / SHA512=64B），写错必挂 | 中 | 已用 node 全量复核 18/18 通过，且经 plan-reviewer 独立复算零错误；黄金向量表以 plan 附录 A 为唯一来源 |
| 计划正文中的**派生期望值**（非附录表值）易算错 | 中 | 初审已命中 4 处并修正；规则强化：凡涉及 `period`/`t0`/`clockOffset` 的用例，**必须先在 evidence 里写出 counter 推导过程再落断言** |
| 真实后端 secret 仅 80 bit（`JBSWY3DPEHPK3PXP`），若强制 RFC 4226 §4 R6 的 128 bit 会误伤存量账户 | 中 | `minSecretBits` **默认 0（不强制）**，只暴露 `Secret.bitLength` 让调用方自决策；README 解释取舍 |
| `Secret` 被 `JSON.stringify` 时泄漏密钥（`private` 仅编译期） | 高 | 实现 `toJSON()` 返回 `'[REDACTED]'` + 单测断言 `JSON.stringify({s: secret})` 不含密钥；README 明示限制；T02 探针验证 `toJSON` 生效（若不生效则降级为 README 显式警告 + Must NOT 条款） |
| 字节码 HAR 默认产出导致需补 `.d.ets` 声明 | 中 | T02 检视产物；若为字节码则补 `types` + 声明文件，或显式关闭 `byteCodeHar` 走源码 HAR（机械性修正，须在 evidence 注明） |
| 并行 worker 同时跑 `hvigorw` 触发工程级锁/缓存冲突造成假失败 | 中 | 编排规则：Wave 内**代码编写可并行**；进入 Acceptance 阶段前 worker 向编排方申请「构建令牌」，编排方**串行放行**（同一时刻仅一个 worker 执行 hvigor）；worker 遇锁/daemon 报错须等待并串行重试一次并记录 |
| `class OtpError extends Error` 的 `instanceof` 在 ArkTS 下异常 | 中 | 已从「T08 才发现」前移到 T02 语言探针；若失效则改普通类 + `isOtpError()` 判定函数（设计性偏差，须回对话确认） |
| `compatibleSdkVersion` 保持 (20) 使 API 12–19 工程无法消费 | 中 | 用户已决策；README 顶部显式声明；放宽兼容性另开任务 |
| `encodeURIComponent` / type-only import 擦除行为未实测 | 中 | T02 语言探针覆盖；URI 模块有专项用例 |
| secret 泄漏（异常消息/toString） | 高 | 硬约束：库内零 hilog、异常消息固定文案不含 secret、`toJSON` 脱敏；最终验证用 grep 机械检查 |
| 与后端/微信端语义漂移（后端硬编码 SHA1+6） | 中 | 默认值对齐三方共识（SHA1/6/30）；README 明示默认值；同一 RFC 向量跨端一致性用例固定 |
| `@security/no-unsafe-mac` lint 告警（HMAC-SHA1 命中） | 低 | 与旧仓库立场一致：**接受告警、不放宽规则、不加 disable 注释**；README 引用 RFC 6238 §1.2 说明 SHA1 的互操作依据 |
| 发布后发现问题无法覆盖同版本 | 中 | 发布前检查清单（P6）+ 同版本不可覆盖规则写进 CHANGELOG 流程；首次发布前 `ohpm prepublish` 预检 |
| `entry` 消费方 demo 引入 UI 代码，可能污染库范围 | 低 | demo 仅 1 个文件、只依赖 barrel 导出、不参与 HAR 打包；Must NOT 清单禁止其被 `library` 反向依赖 |

---

## 6. 监控与可观测性

**本库的设计立场：库内零日志、零上报、零埋点**（避免 secret 泄漏面、避免与宿主日志策略冲突、避免成为三方库的隐私风险点）。可观测性通过「可分类的错误码 + README 故障排查表」交付给宿主。

- **错误分类**（宿主可据此打点）：`OtpError.code` 共 17 个枚举值（见 §3.5；其中 `NOT_IMPLEMENTED` 为内部脚手架占位、不对外，README 故障排查表只需覆盖其余 16 个），宿主若需上报，只需上报 `code` 字符串，**禁止上报 secret/token**。
- **强度自省**：`Secret.bitLength` / `byteLength` 供宿主在账户导入时做一次性合规检查（例如提示"该密钥低于 RFC 4226 建议的 128 bit"）。
- **漂移可观测**：`verify()` 返回的 delta 是宿主的可观测信号——持续非 0 说明设备时钟漂移，宿主可据此提示或调用 `syncClockOffset`。建议宿主指标：`otpVerifyDeltaHistogram`（按绝对值分布）、`otpVerifyFailureRate`（null 占比）。
- **README 故障排查表**：`错误码 → 现象 → 根因 → 处置`（16 条对外码；例：`CRYPTO_NOT_INITIALIZED` → 深路径导入后调用报错 → 未经 barrel 导入或未注入 provider → 改从 `@yansongda/otp` 导入）。
- **不设计的部分**：不做内置埋点、不做 hilog、不写入任何持久化存储。

---

## 7. 审查闭环（plan-reviewer 三轮意见处置）

> 任务编号已统一为执行计划的 T01–T14。第 1 轮结论为「拒绝执行」，第 2 轮为「修改后执行」；**两轮累计 BLOCKER 已清零，MAJOR 本轮全部处置**。

### 7.1 第 1 轮（初审）：2 BLOCKER / 6 MAJOR / 11 MINOR

| # | 发现 | 等级 | 我的独立复核结论（含证据） | 处置 |
|---|---|---|---|---|
| 1 | 分支 B 的 provider 注册链路被静态导入传递性击穿，「公开类 PC 可测」不成立；T07 的 Must NOT 与原 T01 布局自相矛盾 | BLOCKER | **成立**：值与类型的静态导入都会连带加载 kit；一旦 kit 加载失败，`Hotp.test`/`Totp.test`/`Secret.test` 在**模块加载期**整体失败 | 重构为 kit-free 注册表（`internal/HmacProvider.ets`）+ kit-only 实现（`internal/CryptoSource.ets`）；**取消 A/B 两套实现**，分支只决定本地覆盖到哪一层 |
| 2 | `syncClockOffset` 公式应为 `+=` | BLOCKER | **部分成立 / 修正建议驳回**：`-=` 双向自洽（§3.2 场景表 + 反证：改 `+=` 时场景 A 得 counter 3 而非 1）。真正错的是计划里 T10 的测试期望值 | 保留公式；T10 用例改为自洽双场景（`delta=+1`→`-30000`→`generate(89000)==='287082'`） |
| 3 | `remainingSec` 期望值与公式矛盾（应为 29/44） | BLOCKER | **成立**：实测 `(1000,0,30)=29`、`(1000,0,45)=44` | 修期望值；§3.3 加参照点表；第 2 轮又补出 `t0≠0` 覆盖缺口（见 7.2-3） |
| 4 | `fromURI` 用例把 `period=60` 的 counter 算成 1 | BLOCKER | **成立**：实测 `floor(59/60)=0`，SHA256 c0 八位码 `18920136`（`46119246` 是 c1） | 修用例；§3.4 加警示；A.6 收录该值 |
| 5 | `t0` 用例把毫秒当秒（step=-33，会抛 `INVALID_COUNTER`） | BLOCKER | **成立**：实测 `t0=1000 → step=-33`；`t0=1 → step=1` | 改为 `t0: 1` |
| 6 | `Secret.generate` 的 kit 导入与该任务自身验收矛盾 | MAJOR | **成立** | `Secret.ets` 改为经 `requireRandom()`，永不 import kit |
| 7 | 零 commit 基线下 git 洁净度验收不可满足；模块级 `.hvigor` 会污染 | MAJOR | **成立**：实测零 commit + 11 个未跟踪条目 + `.gitignore` 仅根级 `/.hvigor` | 新增 T01（`.gitignore` 补 `**/.hvigor`、`**/oh_modules` + 基线 commit）；验收改为「相较基线无新增未跟踪项」 |
| 8 | `ohpm pack` 不存在 | MAJOR | **成立**：实测子命令清单含 `prepublish`、无 `pack` | 全部改为 `ohpm prepublish <har>` |
| 9 | 设计称 T02 覆盖语言特性但计划未列 | MAJOR | **成立** | T02 增加「ArkTS 语言特性探针」6 条；References 首项换成本地 SDK `.d.ts` 绝对路径 |
| 10 | Secret/URI 任务实际依赖 Base32 却被标为可并行 | MAJOR | **成立** | Base32 独立成 T04；T08 blocked by T04 |
| 11 | 发布物料与公开类并行，与其「API 冻结后方可定稿」矛盾 | MAJOR | **成立** | T12 改为 blocked by T10 |
| 12 | 11 项 MINOR（`hdc` 不在 PATH、越权改共享文件、DTO 字段未枚举、双重取模、build-profile 表述、枚举值表述、README-cn 条件、**`JSON.stringify` 泄漏密钥**、keywords 必填性、References 可达性、并行 hvigor 无序列化） | MINOR | 全部成立 | 逐条修入两份文档 |

**第 1 轮唯一驳回项**：#2 的「改 `+=`」建议（证据见 §3.2）。

### 7.2 第 2 轮（复审）：0 BLOCKER / 4 MAJOR / 12 MINOR

| # | 发现 | 等级 | 我的独立复核结论（含证据） | 处置 |
|---|---|---|---|---|
| 1 | `RandomFixture.ets` 实现权在 T08/T09 双归属，破坏 W4「文件互斥」声明 | MAJOR | **成立**：T08 References 写「本任务补实现」，T09 步骤 3 与并行说明又把它划给 T09；而唯一消费者是 T08 的 `Secret.test` | 所有权收归 **T08**；从 T09 文件集与步骤中移除 |
| 2 | T12 的「README 示例临时测试」三种执行方式全不可行，且变通方式会经 barrel 拉入 kit | MAJOR | **成立**：① 库模块 `dependencies` 必须为 `{}`，无法自解析 `@yansongda/otp`；② 相对路径导入 barrel 会拉入 `CryptoSource`（分支 B 下本地必失败）；③ 临时改 `List.test.ets` 不在授权清单内 | 改为**分支条件化**：分支 A 用「深路径导入 + 显式注册」跑示例并在授权后临时注册；分支 B 跳过该 happy 场景（包名导入形态由 T11 的 barrel 用例覆盖），改做静态签名一致性校验；授权清单补 T12 |
| 3 | 3 处 QA 破坏性验证的红点经复算不成立（T04/T06/T07） | MAJOR | **成立**：实测 —— T04 破坏字母表索引 31 时 `'AB1'` 与 seed 串均不变红（红点是 `'ab0'`）；T06 的破坏实现与正确实现在**全部 `t0=0` 用例**上结果相同（0/5 变红）→ 连带暴露 `t0` 路径零覆盖；T07① 在两个分支下都无法观察 | T04 红点改 `'ab0'`；T06 补 `t0≠0` 用例（`(31000,1,30)=30`、`(1000,5,30)=4`）并把红点改到后者、§3.3 补参照点；T07① 改为函数体 grep 静态断言 |
| 4 | T05 的 Truncate 期望值指示「由 digest 自行推导」，与「禁止自证」规则直接冲突 | MAJOR | **成立**：A.2 第 4 列已给出全部 10 条权威原始值，指示推导会变成同态自证 | 改为「10 条逐字照抄 A.2 第 4 列，禁止推导」 |
| 5 | 12 项 MINOR（T11 barrel 相对路径多一层、设计文档残留旧任务编号、`Ability.test.ets` 无处置、T04 引用未实现的 `fromBytes`、T01 验收与「先验收后提交」顺序冲突、HmacFixture 装表警示自相矛盾、T04 References 指向已删除文件、Executor rule 8 内部矛盾、若干阈值失真、旧仓库行号偏差、`clockOffsetMs` 混入基类、T07 与 T03 的 `HmacProvider.ets` 所有权模糊） | MINOR | 全部成立（逐条实测：4 层才是 `library/Index.ets`；旧 `Totp.ets` 为 157 行；倒计时注释在 `Runtime.ets:149`） | 逐条修入；其中 `clockOffsetMs` 移入 `TotpOptions`、`HmacProvider.ets` 所有权收归 T03（含 `resetForTest`），T07 只负责 `CryptoSource.ets` |

**第 2 轮无驳回项**。

### 7.3 第 3 轮（最终复审）：0 BLOCKER / 2 MAJOR / 12 MINOR

| # | 发现 | 等级 | 我的独立复核结论（含证据） | 处置 |
|---|---|---|---|---|
| 1 | T09 的 `RfcVectors` 常量清单未承载 SHA256 counter=0 的 digest，T10 的 fromURI 用例（period=60 → counter=0）经 `HmacFixture` 必然查表未命中抛错 | MAJOR | **成立**：grep 证实该 digest（`c79f479a…`）只存在于 A.6 表，T09 清单只落了 `SHA256_C0_8DIGIT = '18920136'`（码，无 digest） | T09 常量清单补 `SHA256_C0_DIGEST`，并注明「必须装入 fixture，否则 T10 用例必红」；T10 增加「fixture 数据依赖」条款（查表未命中时**不得自行补算**，须报告） |
| 2 | F4 的 `grep -rn "no-unsafe-mac" library/` 必空，与 T12 要求 README 明写该字面串直接冲突，最终验证必然无法 APPROVE | MAJOR | **成立**：`library/README.md` 在 grep 范围内，两个要求互斥 | F4 的 grep 范围收窄为 `library/src/ library/Index.ets`（lint 豁免只可能出现在源码里），并注明必须排除 `*.md` |
| 3 | 12 项 MINOR | MINOR | 全部成立（逐条实测：设计文档 L421 残留 `task-0b-spike.md`；旧 `Totp.ets` 的 `<<` 注释起于 **L78** 而非 L79；倒计时注释在 `Runtime.ets:149`；A.6 只有 2 条 7 位值；`BOUNDARY_COUNTERS` 单一 `code6/code8` 装不下三算法码；T03 步骤编号 11/13/12 乱序；T12 步骤 2 仍写 17 个；T10 伪代码仍用 `opts?`；T07 标题/commit/W3 波次仍声称实现注册表；`resetHmacForTest()` 命名漂移；plan 头部版本 v2 与「删除 2 文件」滞后；T02 临时注册未获授权；部分用例数阈值无 grep 校验） | 逐条修入两份文档（含 A.6 补 counter=9 的 7 位值 `5520489`） |

**第 3 轮无驳回项**。三轮累计：**BLOCKER 全部清零**；第 3 轮为流程上限（初审 1 次 + 复审 2 次），未闭环项与后续处置由用户裁决（见 §7.4）。

### 7.4 流程结束状态（待用户裁决）

三轮审查后的遗留事项（**已在文档中修正，但未经第 4 轮复审验证**）：
1. 第 3 轮的 2 项 MAJOR + 12 项 MINOR 已修入但未再送审（流程上限）；
2. 1 项**隐含假设**无法在只读条件下验证：ohosTest 文件能否以 `../../../../Index.ets` 跨 source set 导入主 source set 的 barrel —— T11 已给出**机械性回退**（改用 `installCryptoDefaults` + `requireHmac` 的等价断言并在 evidence 注明）；
3. 全部未实测项集中在 T02（6 项 spike）与 T14（`ohpm prepublish` 实际行为），均已设计为执行期一票定音。
---

## 附录 A：RFC 官方向量（已验证：node crypto 实测复核 18/18 + 10/10，并经 plan-reviewer 独立复算零错误）

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

> SHA256/SHA512 的 golden HMAC digest（RFC 未给出）、counter 边界用例（2^32、2^32+1、2^53-1）、`counterToBytes` 对照表、digits=7 抽样值 —— **完整表见执行计划附录 A**（执行者以该表为唯一来源，禁止自行推导）。

---

## 附录 B：契约证据等级

**已验证（读过源码 / 实测 / 官方文档）**
- 旧 `Totp.ets` 全文语义、唯一调用方 `models/Runtime.ets:194`、兜底链 `api/Totp.ets::detail()` → `/totp/detail`
- 后端契约：`config: {secret(大写无填充 base32), period(number)}` + `code`；后端硬编码 `SHA1 + 6`（Rust `totp-rs` 源码）
- 新仓库工程配置全字段；`git log` 零 commit + 11 个未跟踪顶层条目；`.gitignore` 仅根级 `/.hvigor`
- RFC 向量数值（node 实测 + plan-reviewer 独立复算，零错误）
- `counterToBytes` 高/低 32 位拆分算法的正确性（与 BigInt 参考实现 9 个边界值逐位一致）
- `syncClockOffset` 公式的双向自洽性（两场景 + 反证）
- 本地 SDK `.d.ts` 实测：`generateRandomSync(len)`、`SymKeyGenerator.convertKeySync(key)`、`Mac.initSync/updateSync/doFinalSync` 均存在（`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/api/@ohos.security.cryptoFramework.d.ts`）
- `ohpm` 子命令清单（含 `prepublish`、无 `pack`）；`hdc` 不在 PATH，实际位于 `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`
- 官方约束（Local Test 不支持系统 API；`createSymKeyGenerator('HMAC')` 语义与 1–4096 字节密钥范围；OHPM 上架四件套硬要求）

**推断（未实测 → T02 spike 覆盖）**
- 本仓库 Local Test 与 CLI `hvigorw test` 是否可跑；kit 能否加载**并调用**（三步判定 → 分支 A/B）
- `assembleHar` 默认产物是源码 HAR 还是字节码 HAR
- ArkTS 语言特性：`class extends Error` 的 `instanceof`、字符串枚举、class getter、`JSON.stringify` 是否调用 `toJSON`、type-only import 是否被视作依赖
- `encodeURIComponent` 在 ArkTS 下的行为

---

## 附录 C：不做清单（Must NOT）

- 不改动旧 MFA 仓库任何文件；不做旧工程切换
- 不做 UI 库：`library` 内不含任何 `@Component`/ArkUI 代码；删除占位 `MainPage.ets`
- 不做二维码渲染（只产出 `otpauth://` 字符串）；不做扫码
- 不实现 RFC 4226 §7.3 throttling（服务端职责，README 引用条款说明）
- 不支持 Steam Guard（非 RFC）、不支持 SHA224/SHA384/SM3（RFC 6238 §1.2 未列）
- 不引入任何运行时依赖；不引入 `@ohos/crypto-js` 等第三方算法库（含测试期）
- 不做 BigInt / 64 位 counter 全量支持（量化说明见 §3.3 注）
- 库内不打日志、不上报、不持久化、不缓存 secret 到磁盘
- 不执行 `ohpm publish`、不创建 git remote、不 push（人工闸门）
