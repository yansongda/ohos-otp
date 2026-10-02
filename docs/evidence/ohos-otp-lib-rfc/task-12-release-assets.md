# 2026-10-02 09:18:55

## 任务：T12 发布物料（README / CHANGELOG / LICENSE / 包元信息）

- 执行时刻：2026-10-02 09:18:55（evidence 成稿时刻）
- 任务依据：`docs/implementation/ohos-otp-lib-rfc.md` Todo 12；设计文档 §3.2 / §3.5 / §3.6 / 附录 C
- 前置：T10 已完成（API 冻结，commit `df5d524`）；当前 HEAD `6abc751`（W6 并行中 T13 已先行提交，本任务不涉及他人文件）
- 分支结论（T02 实测，`task-02-spike.md` L156/L209）：**分支 B**；`assembleHar` 产物为**字节码 HAR**（`byteCodeHar: true`，包内自动生成 `types: "Index.d.ets"`）→ 无需在 `library/oh-package.json5` 手工加 `types`

## 一、改动摘要

| 文件 | 动作 | 说明 |
|---|---|---|
| `library/README.md` | 补全（骨架 → 完整版） | 英文发布 README：兼容性声明、安装命令、快速开始（TOTP 生成/倒计时/校验/`syncClockOffset`、HOTP 生成）、API 表（含默认值列）、RFC 符合性章节、16 码故障排查表、测试与限制（分支 B）、已知限制、安全立场（无 lint 豁免）、发布前检查清单 |
| `library/README-cn.md` | 补全（骨架 → 完整版） | 中文版，内容与英文版对应 |
| `library/CHANGELOG.md` | 补全 | `## 1.0.0 - 2026-10-01` + Added/Changed 列表 |
| `library/LICENSE` | **未改动** | T03 骨架已是 MIT 全文 + `Copyright (c) 2026 yansongda`，逐字核对合规 |
| `library/oh-package.json5` | **未改动** | T03 已写入全部字段，本轮逐字段核对通过（见 §二.7） |

## 二、Acceptance 逐条验证（逐字命令 + 真实输出）

### AC1：四件套非空

```bash
$ test -s library/README.md && test -s library/README-cn.md && test -s library/CHANGELOG.md && test -s library/LICENSE && echo "PASS: 四件套均非空"
PASS: 四件套均非空
```

### AC2：安装命令

```bash
$ grep -c "ohpm install @yansongda/otp" library/README.md
2
```

（Install 一节 + 发布前检查清单各 1 处，≥1 通过）

### AC3：版本号与兼容性

```bash
$ grep -c "1.0.0" library/CHANGELOG.md
1
$ grep -c "6.0.0(20)" library/README.md
1
```

### AC4：README 中每个 API 名都能在源码 grep 到

```bash
$ for n in $(grep -oE '\b(TOTP|HOTP|Secret|OTPAuthURI|OtpError|OtpAlgorithm|OtpType|OtpErrorCode)\b' library/README.md | sort -u); do grep -rq "export .*$n" library/src/main/ets/ library/Index.ets || echo "MISSING $n"; done
# （无任何输出 = 无 MISSING）
```

逐名对应（人工复核）：
- `TOTP` → `library/src/main/ets/TOTP.ets:17 export class TOTP`（+ `Index.ets:19`）
- `HOTP` → `HOTP.ets:16 export class HOTP`
- `Secret` → `Secret.ets:13 export class Secret`
- `OTPAuthURI` → `OTPAuthURI.ets:11 export class OTPAuthURI`
- `OtpError` → `OtpError.ets:28 export class OtpError`
- `OtpAlgorithm` → `OtpOptions.ets:9 export enum OtpAlgorithm`
- `OtpType` → `OtpOptions.ets:18 export enum OtpType`
- `OtpErrorCode` → `OtpError.ets:5 export enum OtpErrorCode`

### AC5：README 标题数

```bash
$ grep -cE "^## |^### " library/README.md
13
```

（≥6 通过；实际 13 个：Features / Install / Quick start / API / RFC compliance / Error handling and troubleshooting / Testing status / Known limitations / Security notes / Pre-release checklist / License 等）

### AC6：故障排查表覆盖 16 个对外错误码

```bash
$ for c in EMPTY_SECRET INVALID_BASE32_CHAR SECRET_TOO_SHORT SECRET_TOO_WEAK INVALID_ALGORITHM INVALID_DIGITS INVALID_PERIOD INVALID_T0 INVALID_COUNTER INVALID_TIMESTAMP INVALID_WINDOW INVALID_TOKEN CRYPTO_FAILED CRYPTO_NOT_INITIALIZED INVALID_OTPAUTH_URI UNSUPPORTED_OTPAUTH_TYPE; do grep -q "$c" library/README.md || echo "MISSING $c"; done
# （无任何输出 = 无 MISSING，16/16 全覆盖）
```

补充：`NOT_IMPLEMENTED` 按 todo 要求**不列入**故障排查表（内部脚手架占位、交付前已清零、不对外），仅在英文 README 表前说明中提及其已被移除。中文版同样 16/16 全覆盖（实测无 MISSING）。

### 附：oh-package.json5 逐字段核对（T03 已写入，本轮定稿确认）

用 python 解析 `library/oh-package.json5` 后逐项断言，输出：

```
PASS name            (@yansongda/otp)
PASS version         (1.0.0)
PASS description 6-512
PASS main            (Index.ets)
PASS author is object({name: yansongda})
PASS license MIT
PASS repository      (https://github.com/yansongda/ohos-otp)
PASS keywords        (≥5)
PASS dependencies empty ({})
PASS devDeps         (@ohos/hypium 1.0.25 / @ohos/hamock 1.0.0)
PASS no types field
PASS no obfuscated
PASS no sourceType
ALL PASS
```

**不添加 `types`/`obfuscated`/`sourceType`**：T02 实测产物为字节码 HAR（包内自动生成 `types: "Index.d.ets"`，`task-02-spike.md` L209-215），工程侧无需也不应手工补。

## 三、静态签名一致性校验（分支 B 下替代动态场景的 QA happy）

分支 B 下按 todo 规定**跳过**「把 README 示例改写为临时测试并跑单测」的动态场景，改做下述**逐条静态核对**（README 中每个 API 签名/默认值 ↔ 冻结源码 `library/src/main/ets/*.ets`）。

### 3.1 跳过动态场景的理由与承担方

- 理由：库模块 `dependencies` 必须为 `{}`，无法自解析 `@yansongda/otp` 包名做「包名导入」验证；若用相对路径导入 barrel（`Index.ets`），会连带加载 `internal/CryptoSource.ets`（分支 B 下本地加载真实 kit 调用返回空数据），本地套件在模块加载期整体失败（T02 实测值导入的传递性）。
- 承担方：**「包名导入 + barrel 注册链路可用」的验证责任归 T11**（`ohosTest` 设备用例 `CryptoAdapter.test.ets` 的 barrel 用例）；当前无设备（`hdc list targets` → Empty），T11 按「未执行 + 人工步骤」记录。
- 本任务只做静态一致性核对 + 机械 grep 佐证，不创建任何临时测试文件。

### 3.2 方法与对照明细

方法：通读冻结源码全部 7 个公开文件（`TOTP.ets` / `HOTP.ets` / `Secret.ets` / `OTPAuthURI.ets` / `OtpError.ets` / `OtpOptions.ets`）与 `Index.ets` barrel，逐条对照 README（英/中）中出现的每个 API 与默认值；关键签名再用 grep 行号佐证。

| # | README 中的写法 | 源码（行号=grep 佐证） | 结论 |
|---|---|---|---|
| 1 | `new TOTP(options: TotpOptions)`（示例不展示 `provider` 第二参） | `TOTP.ets` 构造 `constructor(options: TotpOptions, provider?: HmacProvider)`，`provider` 注释 `@internal 仅供测试注入` | ✓ 一致 |
| 2 | `totp.generate(timestampMs?: number): string` | `TOTP.ets:79 generate(timestampMs?: number): string` | ✓ |
| 3 | `totp.verify(token: string, options?: VerifyOptions): number \| null`，返回漂移 delta、未命中 `null` | `TOTP.ets:88 verify(token: string, options?: VerifyOptions): number \| null`（引擎语义：扫完全部候选返回首个命中 delta / null，T09 实测） | ✓ |
| 4 | `totp.remaining(timestampMs?): number` 取值 `[1, period]` | `TOTP.ets:99 remaining(timestampMs?: number): number`（`remainingSec` 语义 `[1, period]`，T06 实测） | ✓ |
| 5 | `totp.progress(timestampMs?): number` 取值 `[0, 1)` | `TOTP.ets:106 progress(timestampMs?: number): number` | ✓ |
| 6 | `totp.syncClockOffset(delta: number): void` **单参数**，单位=时间步 | `TOTP.ets:116 syncClockOffset(delta: number): void`（`clockOffsetMs -= delta * period * 1000`，T10 实测双场景） | ✓ |
| 7 | `totp.clockOffsetMs: number` getter | `TOTP.ets:126 get clockOffsetMs(): number` | ✓ |
| 8 | `totp.toURI(): string` / `TOTP.fromURI(uri: string): TOTP` | `TOTP.ets:148 static fromURI(uri: string): TOTP` + `toURI()`；`fromURI` **无 provider 参数**（README 未写，一致） | ✓ |
| 9 | `new HOTP(options: HotpOptions)`、`hotp.generate(counter?)`、`verify`、`toURI`/`fromURI` | `HOTP.ets:61 generate(counter?: number): string`、`:70 verify(token, options?)`、`:94 static fromURI(uri): HOTP` | ✓ |
| 10 | `Secret.fromBase32(s)` / `fromBytes(bytes)` / `generate(bytes = 20)` / `toBase32()` / `bytes` / `byteLength` / `bitLength` / `toJSON()` 返回 `'[REDACTED]'` | `Secret.ets` 全部成员逐一核对：`static generate(bytes: number = 20)`（T08 已把形参名改回 `bytes`）、`toJSON(): string { return '[REDACTED]'; }`、无返回明文的 `toString()` | ✓ |
| 11 | `OTPAuthURI.parse(uri): OtpAuthParams` / `OTPAuthURI.build(params): string` | `OTPAuthURI.ets:11 export class OTPAuthURI`，`static parse(uri: string): OtpAuthParams`、`static build(params: OtpAuthParams): string` | ✓ |
| 12 | 默认值 `algorithm=SHA1` / `digits=6` / `minSecretBits=0` / `period=30` / `t0=0` / `clockOffsetMs=0` / `counter=0` / `VerifyOptions.window=0` | `TOTP.ets:33-38,92`、`HOTP.ets:30-33,72`（grep 行号如上，全部 `=== undefined ? <默认值>` 形态） | ✓ 逐项一致 |
| 13 | `enum OtpAlgorithm { SHA1, SHA256, SHA512 }` 字符串值 | `OtpOptions.ets:9-15`（`'SHA1'/'SHA256'/'SHA512'`） | ✓ |
| 14 | `enum OtpType { TOTP = 'totp', HOTP = 'hotp' }` | `OtpOptions.ets:18-20` | ✓ |
| 15 | `class OtpError extends Error { readonly code: OtpErrorCode }` | `OtpError.ets:28-35` | ✓ |
| 16 | 17 个错误码（README 故障排查表列 16 个对外码） | `OtpError.ets:5-24` 枚举 17 成员逐一比对，README 表 16 个与枚举前 16 个逐字一致 | ✓ |
| 17 | 快速开始示例：`verify(code, { window: 1 })` 显式窗口（复现服务端） | `VerifyOptions.window` 默认 0（严格），示例显式传 1 与「默认严格、显式放宽」的文档立场一致 | ✓ |
| 18 | 快速开始示例：`Secret.generate()` 无参 = 20 字节、`secret.bitLength` 对 `JBSWY3DPEHPK3PXP` 为 80 | `Secret.generate(bytes: number = 20)`；`bitLength = bytes*8`，10 字节 → 80（T08 实测 `byteLength === 10` / `bitLength === 80`） | ✓ |

### 3.3 机械佐证输出（grep 行号）

```bash
$ grep -n "generate(timestampMs\|verify(token\|remaining(timestampMs\|progress(timestampMs\|syncClockOffset(delta\|get clockOffsetMs\|static fromURI(uri\|generate(counter" library/src/main/ets/TOTP.ets library/src/main/ets/HOTP.ets
library/src/main/ets/TOTP.ets:79:  generate(timestampMs?: number): string {
library/src/main/ets/TOTP.ets:88:  verify(token: string, options?: VerifyOptions): number | null {
library/src/main/ets/TOTP.ets:99:  remaining(timestampMs?: number): number {
library/src/main/ets/TOTP.ets:106:  progress(timestampMs?: number): number {
library/src/main/ets/TOTP.ets:116:  syncClockOffset(delta: number): void {
library/src/main/ets/TOTP.ets:126:  get clockOffsetMs(): number {
library/src/main/ets/TOTP.ets:148:  static fromURI(uri: string): TOTP {
library/src/main/ets/HOTP.ets:61:  generate(counter?: number): string {
library/src/main/ets/HOTP.ets:70:  verify(token: string, options?: VerifyOptions): number | null {
library/src/main/ets/HOTP.ets:94:  static fromURI(uri: string): HOTP {

$ grep -n "OtpAlgorithm.SHA1 : options\|=== undefined ? 6\|=== undefined ? 0\|=== undefined ? 30" library/src/main/ets/TOTP.ets library/src/main/ets/HOTP.ets
library/src/main/ets/TOTP.ets:33:    const algorithm: OtpAlgorithm = options.algorithm === undefined ? OtpAlgorithm.SHA1 : options.algorithm;
library/src/main/ets/TOTP.ets:34:    const digits: number = options.digits === undefined ? 6 : options.digits;
library/src/main/ets/TOTP.ets:35:    const period: number = options.period === undefined ? 30 : options.period;
library/src/main/ets/TOTP.ets:36:    const t0: number = options.t0 === undefined ? 0 : options.t0;
library/src/main/ets/TOTP.ets:37:    const clockOffsetMs: number = options.clockOffsetMs === undefined ? 0 : options.clockOffsetMs;
library/src/main/ets/TOTP.ets:38:    const minSecretBits: number = options.minSecretBits === undefined ? 0 : options.minSecretBits;
library/src/main/ets/TOTP.ets:92:    const window: number = options === undefined || options.window === undefined ? 0 : options.window;
library/src/main/ets/HOTP.ets:30:    const algorithm: OtpAlgorithm = options.algorithm === undefined ? OtpAlgorithm.SHA1 : options.algorithm;
library/src/main/ets/HOTP.ets:31:    const digits: number = options.digits === undefined ? 6 : options.digits;
library/src/main/ets/HOTP.ets:32:    const counter: number = options.counter === undefined ? 0 : options.counter;
library/src/main/ets/HOTP.ets:33:    const minSecretBits: number = options.minSecretBits === undefined ? 0 : options.minSecretBits;
library/src/main/ets/HOTP.ets:72:    const window: number = options === undefined || options.window === undefined ? 0 : options.window;
```

**结论：README 全部 18 项 API/默认值核对项与冻结源码一致，无 MISSING、无与最终 API 签名不一致的示例。**

## 四、QA failure 场景实测（删除 `ohpm install` 行）

```bash
$ cp library/README.md /tmp/readme-t12.bak
$ sed -i '' '/ohpm install @yansongda\/otp/d' library/README.md
$ grep -c "ohpm install @yansongda/otp" library/README.md
0
```

→ 发布前检查清单「README 含安装命令」条目能发现该缺失（计数 0 ≠ ≥1）。随后还原：

```bash
$ cp /tmp/readme-t12.bak library/README.md && rm -f /tmp/readme-t12.bak
$ grep -c "ohpm install @yansongda/otp" library/README.md
2
$ grep -c "6.0.0(20)" library/README.md
1
```

还原后 AC2/AC3 复验通过。

## 五、Must NOT 合规自查

- 未写与最终 API 签名不一致的示例（§三 18 项逐条核对）。
- 未宣称支持 Steam Guard / SHA224 / SHA384 / SM3 / BigInt —— 反向写入「已知限制：不提供」，与设计附录 C 一致。
- 未写任何未经实测的覆盖率数字；「测试与限制说明」如实写明分支 B 缺口（真实 crypto 与 barrel 链路由 ohosTest 覆盖、当前待人工设备验证）。
- 未改任何源码（`library/src/**`、`library/Index.ets` 零改动）；未执行 `ohpm publish`。
- 未动 `entry/**`、`build-profile.json5`、`code-linter.json5`、`hvigor/**`。
- README 明写「不使用 `@security/no-unsafe-mac` 豁免」立场并引用 RFC 6238 §1.2（HMAC 为规范规定的算法）。
- 未添加 `types`/`obfuscated`/`sourceType` 字段（字节码 HAR 自动生成 types）。
- README 示例中**未**给消费者展示 `provider` 注入参数（`@internal 仅供测试注入`），与冻结 API 一致。

## 六、偏差

无设计性偏差。机械性说明：README 快速开始示例中刻意不给 `hotpCode` 标注码值断言（`JBSWY3DPEHPK3PXP` 是 80 bit 示例密钥，counter=0 的码并非 RFC 4226 附录 D 的 `755224`——后者对应 20 字节 ASCII seed 的 base32 `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`；为避免误导，示例只展示调用形态不展示码值），已在 §五 核对中确认无错误断言。

# 2026-10-02 11:52:30

## 编排方（main agent）亲自验证（commit `0ecde3e`）

| Acceptance | 命令 | 实测 |
|---|---|---|
| 1. 四件套非空 | `test -s …` ×4 | 通过（README 180 行 / README-cn 180 行 / CHANGELOG 19 行 / LICENSE 21 行）✓ |
| 2. 安装命令 | `grep -c "ohpm install @yansongda/otp" library/README.md` | **2** ≥1 ✓ |
| 3. 版本/兼容性 | `grep -c "1.0.0" CHANGELOG.md` = 1；`grep -c "6.0.0(20)" README.md` = 1 | ✓ |
| 4. API 名可 grep 到导出 | 逐名 `grep -rq "export .*$n" library/src/main/ets/ library/Index.ets` | **无 MISSING** ✓ |
| 5. 章节数 | `grep -cE "^## \|^### " README.md` | **13** ≥6 ✓ |
| 6. 16 个对外错误码齐全 | 逐码 grep | **无 MISSING**（`NOT_IMPLEMENTED` 按计划不列入）✓ |

**内容级审查（逐条对照冻结 API 与设计文档）**：
- 示例代码与冻结签名一致：`new TOTP({secret})`、`generate()/remaining()/progress()`、`verify(code,{window:1}) → delta → syncClockOffset(delta)`、`toURI()/TOTP.fromURI(uri)`、`new HOTP({secret,counter:0})`、`hotp.verify(code,{window:5})`、`Secret.fromBase32/fromBytes/generate/toBase32/bitLength`、`try/catch` + `e instanceof OtpError` + `e.code` —— 与 `library/src/main/ets/*.ets` 逐一核对**无出入**。
- 选项默认值表与设计 §3.2 完全一致（`algorithm=SHA1`/`digits=6`/`minSecretBits=0`/`period=30`/`t0=0`/`clockOffsetMs=0`/`counter=0`/`window=0`，`window` 处明确写「strict」）。
- RFC 符合性章节覆盖 §4 R6、§5.3、§4.2、§5.2、§6、§1.2，并**明确写出「RFC 4226 §7.3 throttling 由校验服务端负责，本库不提供」**。
- **诚实性检查（关键）**：`Testing status` 章节如实写明「分支 B：PC 上 Local Test 无法执行真实系统 crypto…真实 crypto 路径与 barrel 注册链路由 `ohosTest` 覆盖，**As of this release it is pending manual verification on a device**」，并声明「No coverage figures are claimed for paths not exercised by the local suite」——**未伪报设备端通过、未宣称未经证实的覆盖率** ✓
- 已知限制齐全：counter ≤ 2^53-1（含量化）、`otpauth://` 为 GA 事实标准（IANA Provisional #13829）、未知 query 参数忽略、`toJSON()` 只是安全网而非可随意打日志、not-provided 清单（Steam/SHA224/384/SM3/BigInt/throttling/二维码）。
- 安全章节明确「**不使用 `@security/no-unsafe-mac` 豁免**」并给出 RFC 6238 §1.2 依据（F4 的 grep 范围排除 `library/*.md` 正因此处需要出现该字样）。
- 发布前检查清单 6 项可勾选，含「同版本发布后不可覆盖」。
- `library/oh-package.json5` 13 项字段核对通过（`author` 为对象、`dependencies: {}`、`devDependencies` 仅 hypium/hamock）；**未添加** `types`/`obfuscated`/`sourceType`（与 T02「字节码 HAR，类型声明由构建自动生成」结论一致）。
