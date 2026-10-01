# ohos-otp-lib-rfc - Work Plan

> **版本**：v3（已按 plan-reviewer **两轮**复审意见逐条独立复核后修订；完整审查闭环见设计文档 §7）
> **执行者必读**：本文件与 `../ohos-otp-lib-rfc.md`（技术设计，下称「设计文档」）配套；两者冲突时以**本文件**为准，但本文件的任何改动不得违反设计文档 §3 的 API 契约。

## TL;DR (For humans)

**What you'll get:** `library` 模块从「Hello World 占位 HAR」变成可对外发布的通用 OTP 库 `@yansongda/otp`：RFC 4226 HOTP + RFC 6238 TOTP（SHA1/SHA256/SHA512、6/7/8 位、可配 period/T0）、`verify` 漂移窗口与时钟偏移校准、`Secret` 规范化/校验/随机生成/序列化脱敏、`otpauth://` URI 解析与生成；两个 RFC 的官方向量 100% 通过；`entry` 变成 1 页消费方 demo 证明 HAR 可被消费；四件套发布物料齐备。
**Why this approach:** 旧实现把算法与 `@kit.CryptoArchitectureKit` 揉在一个文件里，导致 PC 侧本地单测只能覆盖纯函数子集（官方文档明确「Local Test 不支持系统 API」）。而 ArkTS 的 `import` 是**静态且传递**的——只要公开类从「含 kit 导入的文件」里值导入任何符号，测试加载公开类就会连带加载 kit，套件会在模块加载期整体失败。因此必须用「kit-free 接口层 + 注册表 + kit-only 实现层」把 kit 收敛到全库唯一一个文件，公开类只依赖 kit-free 层。
**What it will NOT do:** 不改旧 MFA 仓库、不做 UI 库、不做二维码渲染/扫码、不实现 RFC 4226 §7.3 throttling、不支持 Steam Guard/SHA224/384/SM3、不引入任何第三方依赖（含测试期）、不做 BigInt、库内不打日志不上报、不下调 `compatibleSdkVersion`、不执行 `ohpm publish`/不 push。
**Effort:** Medium-Large
**Risk:** Medium - 最大风险是 T02 spike 的 6 项未实测结论；其中「kit 可否本地调用」只决定**本地测试覆盖到哪一层**（实现代码无分支差异），而「静态导入传递性」这一结构性风险已在设计阶段消除。
**Decisions to sanity-check:** ① 同步 API（非 Promise）；② `verify` 返回 delta 而非 boolean、默认 `window=0`；③ `minSecretBits` 默认 0（不强制 RFC 的 128 bit，避免误伤存量 80 bit 密钥）；④ `entry` 加消费方 demo（会引入 UI 代码）；⑤ 公共类构造函数带 `@internal` 第二参数 `provider`；⑥ `Secret.toJSON()` 返回 `'[REDACTED]'`；⑦ 先打工程基线 commit 再动代码。

Your next move: 执行计划。Full execution detail follows below.

---

> TL;DR (machine): Medium-Large | Medium | 6 契约验证项（T02）+ 13 实现任务 + 4 最终验证任务 | 新增 ~24 文件、修改 ~8 文件、删除 3 文件 | 结果：可发布的 RFC 4226/6238 通用 OTP HAR + 全量官方向量单测 + 消费方 demo

## Scope

### Must have

**T01（工程基线）**
- `.gitignore`（修改：补 `**/.hvigor`）
- 一个基线 commit（仓库当前零 commit，全文件 untracked —— **没有基线就无法 revert 被删除的文件，也无法用 `git status` 判定越界**）

**T02**
- `docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`（6 项结论 + 逐字命令 + 原始输出）
- 仅当判定 CLI 必需时：`hvigorw`、`hvigorw.bat`（从 DevEco 工具目录复制）

**library 源码（`library/src/main/ets/`）**
- `OtpError.ets`（新增）：`OtpErrorCode` 枚举（**17 个成员，字符串值**）+ `OtpError extends Error`
- `OtpOptions.ets`（新增）：`OtpAlgorithm`/`OtpType` 枚举 + `HmacOptions`/`TotpOptions`/`HotpOptions`/`VerifyOptions`/`OtpAuthParams` 接口（**字段表见设计 §3.2**）
- `Secret.ets`（新增）：`fromBase32`/`fromBytes`/`generate`/`toBase32`/`bytes`/`byteLength`/`bitLength`/`toJSON`
- `HOTP.ets` / `TOTP.ets`（新增）：设计 §3.2 全部公开方法
- `OTPAuthURI.ets`（新增）：`parse`/`build`
- `internal/Base32.ets`（新增）：`decode`/`encode`
- `internal/Counter.ets`（新增）：`toBytes`/`isSafeCounter`
- `internal/Truncate.ets`（新增）：`apply`
- `internal/Digits.ets`（新增）：`format`/`isValidDigits`
- `internal/TimeStep.ets`（新增）：`step`/`remainingSec`/`progress`/`constantTimeEquals`
- `internal/OtpEngine.ets`（新增）：`EngineParams` + `generate`/`verify`
- `internal/HmacProvider.ets`（新增，**kit-free**）：`HmacProvider`/`RandomSource` 接口 + `registerHmac`/`requireHmac`/`registerRandom`/`requireRandom`
- `internal/CryptoSource.ets`（新增，**全库唯一 `@kit` 导入点**）：`CryptoFrameworkHmac`/`CryptoFrameworkRandom`/`installCryptoDefaults`
- 删除 `library/src/main/ets/components/MainPage.ets`

**library 测试**
- `library/src/test/List.test.ets`（改写，全量注册）、删除 `library/src/test/LocalUnit.test.ets`
- `library/src/test/vectors/RfcVectors.ets`（新增，附录 A 唯一来源）
- `library/src/test/HmacFixture.ets`、`library/src/test/RandomFixture.ets`（新增）
- `library/src/test/{Base32,Counter,Truncate,Digits,TimeStep,Secret,CryptoSource,OtpAuthUri,OtpError,OtpEngine,Hotp,Totp}.test.ets`（新增，12 个）
- `library/src/ohosTest/ets/test/List.test.ets`（改写）+ `CryptoAdapter.test.ets`（新增）

**发布物料**
- `library/Index.ets`（改写为全量 barrel + `installCryptoDefaults()`）
- `library/oh-package.json5`（补 description/author/repository/keywords + devDependencies）
- `library/README.md`、`library/README-cn.md`、`library/CHANGELOG.md`、`library/LICENSE`（新增）

**消费方**
- `entry/oh-package.json5`（加 `"@yansongda/otp": "file:../library"`）
- `entry/src/main/ets/pages/Index.ets`（改写为算码 demo）

**文档**
- `docs/ohos-otp-lib-rfc.md`（已完成，技术设计）
- `docs/implementation/ohos-otp-lib-rfc.md`（本文件）
- `docs/evidence/ohos-otp-lib-rfc/task-*.md`（每任务一份）

### Must NOT have (guardrails, anti-slop, scope boundaries)

- **不改动旧 MFA 仓库** `/Users/yansongda/000-Coding/application/**` 任何文件
- **不引入任何第三方依赖**：`library/oh-package.json5` 的 `dependencies` 必须保持 `{}`；不得引入 `@ohos/crypto-js`/`otpauth`/`jsbn` 等；测试期也不得引入
- **全库唯一 `@kit` 导入点 = `library/src/main/ets/internal/CryptoSource.ets`**（`Index.ets` 也只能 import `CryptoSource`，不得直接 import kit）；禁止 `@kit.PerformanceAnalysisKit`(hilog)/`@kit.ArkUI`/`@kit.AbilityKit` 等任何其他 kit
- **不打日志**：禁止任何 `hilog`/`console.*` 调用；**不写文件、不持久化**
- **异常消息不含 secret/密钥/token**：禁止把用户输入拼进错误消息（固定文案 + `code`）
- **不加 lint 豁免**：禁止 `@security/no-unsafe-mac` 的 disable 注释、禁止修改 `code-linter.json5`
- **不做 UI 库**：`library/src/main/ets/` 内禁止出现 `@Component`/`@Entry`/`build()`/任何 ArkUI 符号
- **不做非 RFC 能力**：Steam Guard、SHA224/SHA384/SM3、BigInt、64 位 counter、throttling、二维码图片渲染、扫码
- **不改工程级配置**：`compatibleSdkVersion` 保持 `6.0.0(20)`；`targetSdkVersion`/`runtimeOS`/`strictMode` 不变；`hvigor/hvigor-config.json5`/`code-linter.json5` 不改；`build-profile.json5` 唯一允许的改动是 T13 授权的 `signingConfig` 行移除
- **不越界文件**：`internal/*`、`HmacProvider`、`RandomSource`、`CryptoSource`、`OtpEngine`、`EngineParams` **不得**出现在 `library/Index.ets` 的导出里
- **不做 git 远端操作**：不 `git remote add`、不 push、不 `ohpm publish`
- **代码风格红线**：2 空格缩进、语句末尾分号、单引号、中文注释；禁止 `any`；禁止 `catch` 空块（必须 `throw` 或转 `OtpError`）；禁止用测试私有 API 绕过公开接口

## Executor rules（执行者必读，写入派发 prompt）

1. **偏差分级处理**：
   - 机械性修正（可直接改，commit message 与 evidence 注明）：hvigor/ohpm CLI 子命令或参数与 T02 记录不符、官方示例文件名不同、明显笔误、T13 授权的 `signingConfig` 行移除。
   - 设计性偏差（**停止当前 todo，输出差异与修正建议，等确认**）：API 签名形态不同、`*Sync` 加密接口不可用需改 async、`class extends Error`/字符串枚举/getter/`toJSON` 在本工程不可用需改错误模型或脱敏方案、RFC 向量与实现不符且无法解释、`compatibleSdkVersion` 需变更。**不得静默修改设计决策。**
2. **文件边界**：只创建/修改自己 todo 列出的文件。共享注册文件已由 T03 全量就位，**除明确授权的 task 外禁止改动**；授权清单：`library/Index.ets` → T03（T07 仅在分支 A 注册方式确有差异时，且须报告）；`library/src/test/List.test.ets` → T03/**T12/T02（仅临时注册 + 用后立即还原）**；`library/src/ohosTest/ets/test/List.test.ets` → T03/T11；`library/oh-package.json5` → T03/T12；`library/src/main/ets/internal/HmacProvider.ets` → **仅 T03**（含注册表与 `@internal resetForTest()` 的完整实现；T07 不得修改，如发现缺陷向编排方报告）；T03 有权删除 `library/src/ohosTest/ets/test/Ability.test.ets`（模板死文件，见 T03 步骤 13）。
3. **顺序约束**：Wave 间严格串行，Wave 内可并行。开工前核对依赖矩阵。
4. **完成即验证即提交**：Acceptance 全部通过后才 commit。
5. **不猜 API**：系统 crypto 接口以 **本地 SDK 声明文件** 为准 —— `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/api/@ohos.security.cryptoFramework.d.ts`（已实测含 `generateRandomSync` L1332、`SymKeyGenerator.convertKeySync(key)` L2006、`Mac.initSync(key)` L2304、`Mac.updateSync(input)` L2398、`Mac.doFinalSync()` L2475）＋ T02 实测结论；在线文档仅作补充。冲突按第 1 条分级处理。
6. **向量不可自行推导**：附录 A 的表值只能照抄，禁止用「自己算一遍」的方式生成期望值（那会变成自证）。**但**：附录 A 之外的**派生量**（如某 URI 的 `period=60` 对应的 counter）**必须**先在 evidence 里写出推导过程（如 `floor(59/60)=0`）再落断言 —— 初审已因跳过这一步命中 4 处错误。另：禁止在注释里写 `it(`（会让 `grep -c "it("` 的验收计数失真，属于自欺）。
7. **分支执行**：T02 判定「分支 A / 分支 B」后，T11 按该分支执行；**实现代码无分支**，分支只决定本地/设备测试的分工。
8. **编排与并行规则（防止 hvigor 假失败）**：Wave 内的**代码编写**可并行；进入 Acceptance 阶段前，worker 必须向编排方申请「构建令牌」，编排方**串行放行**（同一时刻仅一个 worker 执行 hvigor 命令）；worker 遇 hvigor daemon/lock 类报错，必须等待并串行重试一次，并在 evidence 注明「并发重试」。验收所需的 hvigor 命令由持有令牌的 worker 自行执行，输出直接贴入 evidence。
9. **不伪报**：无设备时设备测试必须标注「未执行 + 人工步骤」，不得用 `expect(true)` 占位冒充通过。

## Verification strategy

- **Test decision**: 分层 TDD-ish —— 每个实现 todo 自带单测（Implementation + Test = ONE todo）；纯逻辑走「先写附录 A 向量用例断言 fail → 实现 → 断言 pass」；`internal/CryptoSource.ets` 与 barrel 注册链路走设备端 `ohosTest`（PC 无系统能力）。
- **Evidence**: `docs/evidence/ohos-otp-lib-rfc/task-<NN>-<slug>.md`（每任务一份，含逐字命令、原始输出、结论、发现的偏差、**派生量的推导过程**）。**T02 是所有后续 todo 的契约快照来源。**
- **Contract-first**: 是。T02 的 6 项实测结论必须先于 Wave 2 完成，并成为后续 todo 的 References 第一项。
- **占位策略**：T03 用 `throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED')` 占位，保证脚手架阶段构建与单测双绿（每个测试文件先只放一条 import-smoke 用例）；后续每个 todo 用真实实现与真实用例替换自己那部分。`NOT_IMPLEMENTED` 必须在 T14 前清零。
- **基线对照**：T01 的基线 commit 是所有「越界检查」的参照系；`git status` 类验收一律表述为「相较基线无新增未跟踪项」。

## Execution strategy

### Parallel execution waves

- **W0（串行，最先）**: T01（工程基线：`.gitignore` 修正 + 基线 commit）
- **W1（串行）**: T02（可行性 spike：6 项）
- **W2（串行）**: T03（脚手架：全部源文件占位 + 全量注册文件 + 元信息 + 四件套骨架 + 删除占位文件；构建与单测双绿）
- **W3（并行 4 路）**: T04（Base32）、T05（Counter+Truncate+Digits）、T06（TimeStep）、T07（CryptoSource 适配器实现；注册表已由 T03 完成）
- **W4（并行 2 路）**: T08（Secret + OTPAuthURI）、T09（vectors + fixtures + OtpEngine）
- **W5（串行）**: T10（HOTP / TOTP + 时钟偏移）
- **W6（并行 3 路）**: T11（ohosTest 设备验证）、T12（发布物料）、T13（entry 消费方 demo）
- **W7（串行）**: T14（覆盖率 + 产物检视 + prepublish + 检查清单）
- **Final**: F1–F4（并行，只读审查）

> 并行安全说明：
> - W3 的 4 个任务文件集**完全不重叠**：T04={internal/Base32 + test}，T05={internal/Counter,Truncate,Digits + 3 test}，T06={internal/TimeStep + test}，T07={internal/CryptoSource + cryptoSourceTest}（`internal/HmacProvider.ets` 已由 T03 完成，不属任何 W3 任务）。共享依赖（`OtpError.ets`/`OtpOptions.ets`/`HmacProvider.ets`/`Index.ets`/`List.test.ets`）全部在 W2 由 T03 一次性写全，W3 只读不改。
> - W4 的 2 个任务不重叠：T08={Secret,OTPAuthURI,RandomFixture + 3 test}，T09={vectors/RfcVectors,HmacFixture,internal/OtpEngine + OtpEngine.test}。**`RandomFixture.ets` 的唯一所有者是 T08**（唯一消费者是 `Secret.test` 的 `generate` 用例），T09 不得创建或修改它。
> - W6 的 3 个任务不重叠：T11={ohosTest 2 文件}，T12={README×2,CHANGELOG,LICENSE,oh-package.json5}，T13={entry 2 文件}。
> - 构建产物（`library/build`、`.hvigor`、`.test`）已在 `.gitignore`（T01 修正后含 `**/.hvigor`），并行任务不产生 git 冲突；**hvigor 命令必须串行**（见 Executor rule 8）。
> - 本工程无需 worktree 隔离（文件集互斥）；如执行者选择 worktree 需注意 `.hvigor`/`oh_modules` 不会被复制，需重新 sync。

### Dependency matrix

| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| T01 | — | T02 | — |
| T02 | T01 | T03（提供 CLI 与分支结论） | — |
| T03 | T02 | T04, T05, T06, T07 | — |
| T04 | T03 | T08, T09 | T05, T06, T07 |
| T05 | T03 | T09 | T04, T06, T07 |
| T06 | T03 | T09 | T04, T05, T07 |
| T07 | T03, T02（分支结论） | T09, T11 | T04, T05, T06 |
| T08 | T03, **T04**（Secret/URI 依赖 Base32） | T10 | T09 |
| T09 | T04, T05, T06, T07 | T10 | T08 |
| T10 | T08, T09 | T11, T12, T13 | — |
| T11 | T07, T10 | T14 | T12, T13 |
| T12 | T10（API 冻结后方可定稿） | T14 | T11, T13 |
| T13 | T10 | T14 | T11, T12 |
| T14 | T11, T12, T13 | F1–F4 | — |

## Todos

> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE - never rewrite the headers above. -->

### W0

- [x] 1. 工程基线（`.gitignore` + 基线 commit）
  **What to do**：
  1. 修改 `.gitignore`：在现有基础上补 `**/.hvigor` 与 `**/oh_modules` 两行（hvigor 构建会在**模块目录**下生成 `library/.hvigor/`、`entry/.hvigor/`，而 ohpm 可能在各模块目录下生成 `oh_modules/`；现有规则只有根级 `/.hvigor`、`/oh_modules` 匹配不到，会污染后续所有 git 洁净度验收）。同时确认 `**/build`、`**/.test` 已在（它们已在）。
  2. 检查 `git status --short`，确认除 `.gitignore` 外无需忽略的产物；若有意外产物（如 `.hvigor`、`build`、`.test`）先确认忽略规则覆盖。
  3. **按下列顺序**执行（先写 evidence、再入库、最后验证，避免与「先验收后提交」冲突）：① 写 `docs/evidence/ohos-otp-lib-rfc/task-01-baseline.md`；② `git add -A`；③ `git commit -m "chore: 初始化 ohos-otp 工程基线"`（**本仓库第一个 commit，本地 commit，不涉及 push**，evidence 随本次 commit 入库）；④ 跑下述 Acceptance。
  **Must NOT do**: 不得修改任何源码/配置（除 `.gitignore` 那一行）；不得 push、不得 `git remote add`；不得删除工程现有文件；不得在此任务里开始实现 OTP 库。
  **Parallelization**: W0 | Blocked by: — | Blocks: T02
  **References**:
  - 设计文档 §4 的 P-1 阶段：`docs/ohos-otp-lib-rfc.md`
  - 现状实测事实：`git log --oneline` → `fatal: your current branch 'main' does not have any commits yet`；`git status --short` → 11 个未跟踪顶层条目；当前 `.gitignore` 内容为 `/node_modules`、`/oh_modules`、`/local.properties`、`/.idea`、`**/build`、`/.hvigor`、`.cxx`、`/.clangd`、`/.clang-format`、`/.clang-tidy`、`**/.test`、`/.appanalyzer`
  - 旧工程实证（只读参考，**禁止修改该仓库**）：`/Users/yansongda/000-Coding/application/docs/learning/huawei-totp-local-compute.md` 记录了 hvigor 在模块目录下生成 `.hvigor/` 需手工清理
  **Acceptance criteria**:
  - `grep -cE '\*\*/\.hvigor|\*\*/oh_modules' .gitignore` ≥ 2
  - `git log --oneline | wc -l` → 1
  - `git status --short` → 空输出（洁净，evidence 已随 commit 入库）
  - `git show --stat --oneline HEAD | head -20` → 输出含全部工程文件
  **QA scenarios**:
  - happy: `git status --short` 输出为空
  - failure: 临时 `mkdir -p library/.hvigor && touch library/.hvigor/x && mkdir -p library/oh_modules && touch library/oh_modules/y`，确认 `git status --short` **不出现**这两个路径（证明新忽略规则生效），随后 `rm -rf library/.hvigor library/oh_modules`
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-01-baseline.md`
  **Commit**: Y | `chore: 初始化 ohos-otp 工程基线`

### W1

- [x] 2. 可行性 spike（6 项实测结论快照）
  **What to do**（逐项实测并把**逐字命令 + 原始输出**贴进 evidence）：
  1. **CLI 调用方式**：仓库根**没有** `hvigorw`。先直接用 DevEco 自带 `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw`（运行前确保 node 在 PATH：`export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"`）。记录能跑通的**完整命令行**，至少覆盖：构建 HAR、本地单测、覆盖率三种用途。若必须先复制 `hvigorw`/`hvigorw.bat` 到仓库根才能跑通，则复制并说明来源；否则不要落地这两个文件，写清「使用 DevEco 绝对路径即可」。
  2. **Local Test 能否在 PC 跑**：在 `library/src/test/` 建**临时**文件 `Task02Spike.test.ets`（只含 1 条 `expect(1).assertEqual(1)`）+ 临时在 `library/src/test/List.test.ets` 注册；跑本地单测命令，记录 exit code 与输出。旧工程曾因 `pages: $profile:pages` 与 hvigor 硬编码 `main_pages` 冲突 exit 255；本仓库 entry 用 `$profile:main_pages`，需实测确认。
  3. **Local Test 能否加载并调用系统 kit（决定分支）**：在临时文件里分三步，**每步单独记录**：① 仅 `import { cryptoFramework } from '@kit.CryptoArchitectureKit';`；② `cryptoFramework.createMac('SHA1')` 与 `cryptoFramework.createSymKeyGenerator('HMAC')`；③ 完整做一次 HMAC-SHA1（key = ASCII `12345678901234567890`，message = 8 字节大端 counter=1）并与附录 A 的 `75a48a19d4cbe100644e8ac1397eea747a2d33ab` 比对。**判定标准：①②③ 全部成功 = 分支 A；只要出现「能 import 但调用失败」的中间态，一律按分支 B 处理。** evidence 必须有且仅有一行 `结论：分支 A` 或 `结论：分支 B`，并附三步的原始输出。
  4. **`*Sync` 接口可用性**：调用 `createSymKeyGenerator('HMAC').convertKeySync({data})`、`mac.initSync(key)`、`mac.updateSync({data})`、`mac.doFinalSync()`，跑一次构建确认**编译通过**；分支 A 下另确认运行结果正确。同时记录本地 SDK 声明文件里的行号作为权威依据。
  5. **`assembleHar` 产物类型与路径**：跑一次 release HAR 构建，记录**产物绝对路径与大小**（该路径后续 T14 要引用），解包检视内容：是**源码 `.ets`**（→ 源码 HAR，无需 `types`）还是 **`.abc` 字节码**（→ 字节码 HAR，发布需 `types` 指向 `.d.ets`）。列出包内容清单前 30 行。
  6. **ArkTS 语言特性探针**（每条给出「可用/不可用 + 原始报错或输出」）：
     - `class E extends Error {}` 的 `new E() instanceof E` 与 `instanceof Error`
     - 字符串值枚举：`enum C { A = 'A' }` 且 `String(C.A) === 'A'`
     - class getter：`class G { private _v = 1; get v(): number { return this._v; } }`
     - `JSON.stringify({s: obj})` 是否会调用 `obj.toJSON()`（用一个带 `toJSON()` 返回 `'REDACTED'` 的对象验证）
     - type-only import（仅用于类型标注的 import）是否会导致该模块被加载（用一个「顶层抛异常」的模块做负例验证）
     - `encodeURIComponent`/`decodeURIComponent` 可用性（含 `%20`/`%3A` 往返）
  7. **清理**：删除所有临时 spike 文件（含 `List.test.ets` 里的临时注册），跑 `git status --short` 确认相较基线无新增未跟踪项（除 evidence 与可能的 `hvigorw`）。
  **Must NOT do**: 不得为此修改任何工程级配置；不得把 spike 临时文件留在仓库；不得引入依赖；不得在此任务里开始实现 OTP 库代码；不得 push。
  **Parallelization**: W1 | Blocked by: T01 | Blocks: T03
  **References (executor has NO interview context)**:
  - 设计文档 §3.1（分层与分支 A/B 定义）、§3.5（17 个错误码）、附录 A（RFC 4226 向量）、附录 B（哪些是推断项）：`docs/ohos-otp-lib-rfc.md`
  - **本地 SDK（权威）**：`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/api/@ohos.security.cryptoFramework.d.ts`（已实测：`generateRandomSync` L1332、`convertKeySync(key: DataBlob): SymKey` L2006、`initSync(key: SymKey)` L2304、`updateSync(input: DataBlob)` L2398、`doFinalSync()` L2475）
  - 官方 Local Test 文档（明确「当前不支持测试 C/C++ 方法及系统 API」）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-local-test
  - 官方 hvigorw 命令行文档：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-commandline
  - 官方构建 HAR（产物路径与内容清单）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-build-har
  - 旧工程失败先例（只读参考，**禁止修改该仓库**）：`/Users/yansongda/000-Coding/application/docs/learning/huawei-totp-local-compute.md`（CLI exit 255 根因、Plan A 后果、`.hvigor` 清理）
  - 本机环境实测事实：DevEco Studio 6.1.1；`hvigorw` 在 `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/`；`ohpm` 在 `.../tools/ohpm/bin/ohpm`；`hdc` 在 `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`（**不在 PATH**）；node v24.20.0；`.hvigor/cache/meta.json` = `{"compileSdkVersion":"6.1.1(24)","hvigorVersion":"6.24.4","toolChainsVersion":"6.1.1.125"}`
  **Acceptance criteria** (agent-executable):
  - `test -f docs/evidence/ohos-otp-lib-rfc/task-02-spike.md && wc -l docs/evidence/ohos-otp-lib-rfc/task-02-spike.md` → 文件存在且 ≥60 行
  - `grep -c '^## ' docs/evidence/ohos-otp-lib-rfc/task-02-spike.md` ≥ 6（6 个小节）
  - `grep -cE '结论：分支 [AB]' docs/evidence/ohos-otp-lib-rfc/task-02-spike.md` == 1
  - evidence 中含 ≥1 条 `assembleHar` 产物的**绝对路径**与大小，含 6 项语言探针的逐条结论
  - `ls library/src/test/Task02Spike.test.ets` → `No such file or directory`（临时文件已清理）
  - `git status --short` → 只出现 evidence 文件（及必要时 `hvigorw`/`hvigorw.bat`）
  **QA scenarios** (name the exact tool + invocation):
  - happy: 第 2 项用 T02 记录的单测命令实跑，输出含成功标记且 exit code 0
  - failure: 第 2 项若失败，把完整错误输出（含 exit code 与 `00304022` 类错误码）贴进 evidence，并给出**可替代验证路径**（DevEco IDE 内运行 Local Test 的人工步骤），不得只写「不可用」
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`
  **Commit**: Y | `chore(otp): 实测 hvigorw/本地单测/系统kit/语言特性并固化契约快照`

### W2

- [ ] 3. 脚手架（全部文件就位 + 全量注册 + 双绿基线）
  **What to do**：
  1. 建目录 `library/src/main/ets/internal/`、`library/src/test/vectors/`。
  2. **完整写出**（不是占位）`library/src/main/ets/OtpError.ets`：`export enum OtpErrorCode`（**17 个成员，字符串值**，取值与设计 §3.5 逐字一致：`EMPTY_SECRET`/`INVALID_BASE32_CHAR`/`SECRET_TOO_SHORT`/`SECRET_TOO_WEAK`/`INVALID_ALGORITHM`/`INVALID_DIGITS`/`INVALID_PERIOD`/`INVALID_T0`/`INVALID_COUNTER`/`INVALID_TIMESTAMP`/`INVALID_WINDOW`/`INVALID_TOKEN`/`CRYPTO_FAILED`/`CRYPTO_NOT_INITIALIZED`/`INVALID_OTPAUTH_URI`/`UNSUPPORTED_OTPAUTH_TYPE`/`NOT_IMPLEMENTED`）+ `export class OtpError extends Error { readonly code: OtpErrorCode; constructor(code: OtpErrorCode, message: string) { super(message); this.code = code; } }`。消息文案固定、不含用户输入。
  3. **完整写出** `library/src/main/ets/OtpOptions.ets`：`enum OtpAlgorithm { SHA1 = 'SHA1', SHA256 = 'SHA256', SHA512 = 'SHA512' }`、`enum OtpType { TOTP = 'totp', HOTP = 'hotp' }`，以及**设计 §3.2「选项类型字段表」中逐字列出的全部接口与字段**（`HmacOptions`/`TotpOptions extends HmacOptions`/`HotpOptions extends HmacOptions`/`VerifyOptions`/`OtpAuthParams`）。**字段名、可选性、顺序照抄该表，不得增删改。**
  4. **写出全部剩余源文件骨架**，签名按设计 §3.1/§3.2 逐字对齐，方法体一律 `throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED, 'NOT_IMPLEMENTED');`：
     `internal/Base32.ets`（`decode(input: string): Uint8Array`、`encode(bytes: Uint8Array): string`）、
     `internal/Counter.ets`（`toBytes(counter: number): Uint8Array`、`isSafeCounter(value: number): boolean`）、
     `internal/Truncate.ets`（`apply(digest: Uint8Array): number`）、
     `internal/Digits.ets`（`format(value: number, digits: number): string`、`isValidDigits(digits: number): boolean`）、
     `internal/TimeStep.ets`（`step(epochMs: number, t0: number, period: number): number`、`remainingSec(...)`、`progress(...)`、`constantTimeEquals(a: string, b: string): boolean`）、
     `internal/OtpEngine.ets`（`export interface EngineParams { algorithm: OtpAlgorithm; digits: number; key: Uint8Array; }`、`generate(provider: HmacProvider, params: EngineParams, counter: number): string`、`verify(provider: HmacProvider, params: EngineParams, token: string, counter: number, window: number): number | null`）、
     `internal/HmacProvider.ets`（**本文件由 T03 完整实现，T07 不得再改**：`export interface HmacProvider { sign(algorithm: OtpAlgorithm, key: Uint8Array, message: Uint8Array): Uint8Array; }`、`export interface RandomSource { random(bytes: number): Uint8Array; }`、模块级单例 + `registerHmac`/`requireHmac`/`registerRandom`/`requireRandom` + `@internal resetForTest(): void`（清空两个单例，供测试验证未注册分支）；`requireXxx()` 未注册时 `throw new OtpError(OtpErrorCode.CRYPTO_NOT_INITIALIZED, 'CRYPTO_NOT_INITIALIZED')`；**本文件禁止任何 `@kit` 导入**）、
     `internal/CryptoSource.ets`（`export class CryptoFrameworkHmac implements HmacProvider`、`export class CryptoFrameworkRandom implements RandomSource`、`export function installCryptoDefaults(): void`；**本文件是全库唯一允许 `import { cryptoFramework } from '@kit.CryptoArchitectureKit'` 的地方**；`installCryptoDefaults()` 只 `new` + 注册，**不得发起任何 crypto 调用**）、
     `Secret.ets`、`OTPAuthURI.ets`、`HOTP.ets`、`TOTP.ets`（签名严格按设计 §3.2；`HOTP`/`TOTP` 构造函数第二参 `provider?: HmacProvider`，注释标 `@internal 仅测试注入`；**这四个文件禁止 import `CryptoSource.ets`**）。
  5. **改写** `library/Index.ets` 为**全量 barrel**（脚手架规则：一次写全所有共享注册）：导出 `OtpError, OtpErrorCode, OtpAlgorithm, OtpType, HmacOptions, TotpOptions, HotpOptions, VerifyOptions, OtpAuthParams, Secret, HOTP, TOTP, OTPAuthURI`，并在模块顶层 import `installCryptoDefaults` from `./src/main/ets/internal/CryptoSource` 后**立即调用一次**（这是唯一把 kit 引入 barrel 的路径，也是消费者零配置使用的前提）。**不得**导出 `internal/*` 的任何符号、`HmacProvider`、`RandomSource`、`CryptoSource`、`OtpEngine`、`EngineParams`。
  6. **改写** `library/src/test/List.test.ets`：import 并调用下面全部 12 个套件函数 —— `base32Test, counterTest, truncateTest, digitsTest, timeStepTest, secretTest, cryptoSourceTest, otpAuthUriTest, otpErrorTest, otpEngineTest, hotpTest, totpTest`。**删除** `library/src/test/LocalUnit.test.ets`。
  7. **创建**上述 12 个测试文件 + `vectors/RfcVectors.ets` + `HmacFixture.ets` + `RandomFixture.ets`：12 个 `.test.ets` 各只含一条 `it('importSmoke', 0, () => { expect(true).assertTrue(); });`（文件头注释 `// TODO(T<N>): 由对应 todo 替换为真实用例`）；`vectors/RfcVectors.ets`/`HmacFixture.ets`/`RandomFixture.ets` 只导出类型正确的空占位结构（不写向量数据）。
  8. **改写** `library/src/ohosTest/ets/test/List.test.ets` 注册 `cryptoAdapterTest`，并创建该套件的空壳（1 条 importSmoke，`// TODO(T11)`）。
  9. `library/oh-package.json5`：`description` → `RFC 4226/6238 compliant HOTP and TOTP library for ArkTS (SHA1/SHA256/SHA512, OTPAuth URI, drift window)`（6–512 字符）；`author` → **对象** `{"name":"yansongda"}`；补 `"repository":"https://github.com/yansongda/ohos-otp"`、`"keywords":["otp","totp","hotp","2fa","mfa","authenticator","rfc6238","rfc4226","arkts","harmonyos"]`；`devDependencies` 补 `@ohos/hypium: 1.0.25`、`@ohos/hamock: 1.0.0`；`dependencies` 保持 `{}`。
  10. **创建四件套骨架**（内容可短但必须非空）：`library/README.md`、`library/README-cn.md`、`library/CHANGELOG.md`（含 `## 1.0.0` 行）、`library/LICENSE`（MIT 全文，`Copyright (c) 2026 yansongda`）。
  11. 删除 `library/src/main/ets/components/MainPage.ets`。
  12. 删除 `library/src/ohosTest/ets/test/Ability.test.ets`（模板死文件：改写 `List.test.ets` 后它不再被注册，且其 `hilog` 导入与「库内零日志」约束相冲；T03 是本文件唯一被授权处置者）。
  13. 跑构建与单测，确认**双绿**。
  **Must NOT do**: 不得写任何真实算法/解析逻辑（例外：`OtpError.ets`、`OtpOptions.ets`、`HmacProvider.ets` 三个文件要**完整实现**，因为它们全是纯声明与纯单例逻辑）；`internal/HmacProvider.ets` 禁止 import kit；`Secret.ets`/`HOTP.ets`/`TOTP.ets`/`OTPAuthURI.ets` 禁止 import `CryptoSource.ets`；不得导出 internal 符号；不得改动 `entry/**`、`build-profile.json5`、`code-linter.json5`；不得引入依赖。
  **Parallelization**: W2 | Blocked by: T02 | Blocks: T04, T05, T06, T07
  **References**:
  - T02 结论快照（**CLI 命令与分支结论以它为准**）：`docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`
  - 设计文档 §2（文件结构）、§3.1（分层与注册表契约）、**§3.2「选项类型字段表」**（T03 步骤 3 的唯一来源）、§3.5（17 个错误码全表）、§3.6（发布字段要求）：`docs/ohos-otp-lib-rfc.md`
  - 现状文件：`library/Index.ets`（当前 1 行）、`library/oh-package.json5`、`library/src/test/List.test.ets`、`library/src/test/LocalUnit.test.ets`、`library/src/ohosTest/ets/test/List.test.ets`、`library/src/ohosTest/ets/test/Ability.test.ets`、`library/src/main/ets/components/MainPage.ets`
  - 代码风格样张（2 空格 / 分号 / 单引号）：`library/src/main/ets/components/MainPage.ets`、`library/src/test/LocalUnit.test.ets`
  - 中文注释风格样张（旧实现，只读参考，**禁止修改该仓库**）：`/Users/yansongda/000-Coding/application/huawei/atomicservice/MFA/entry/src/main/ets/utils/Totp.ets`
  - OHPM 必填字段要求：https://ohpm.openharmony.cn/#/cn/help/publishrules
  **Acceptance criteria**:
  - `grep -rn "@kit\." library/src/main/ets/ library/Index.ets` → 输出**只**含 `library/src/main/ets/internal/CryptoSource.ets`
  - `grep -rn "CryptoSource" library/src/main/ets/Secret.ets library/src/main/ets/HOTP.ets library/src/main/ets/TOTP.ets library/src/main/ets/OTPAuthURI.ets library/src/main/ets/internal/OtpEngine.ets` → 无输出
  - `grep -n "HmacProvider\|RandomSource\|OtpEngine" library/Index.ets` → 只出现在 import/调用 `installCryptoDefaults` 的上下文中，**不得**出现在 `export` 语句里
  - `grep -c "throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED" library/src/main/ets/internal/*.ets library/src/main/ets/*.ets` → 合计 ≥ 12
  - `grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/HmacProvider.ets` → 只允许枚举定义行（不得有 `throw`）；`grep -c "resetForTest" library/src/main/ets/internal/HmacProvider.ets` ≥ 1
  - `ls library/src/ohosTest/ets/test/Ability.test.ets` → `No such file or directory`
  - `test -s library/README.md && test -s library/README-cn.md && test -s library/CHANGELOG.md && test -s library/LICENSE` → 通过
  - `ls library/src/main/ets/components/MainPage.ets library/src/test/LocalUnit.test.ets` → 两个 `No such file or directory`
  - 构建命令（T02 版）exit 0 且输出含 `BUILD SUCCESSFUL`；本地单测命令（T02 版）exit 0 且 12 个套件名全部出现、失败数 0
  **QA scenarios**:
  - happy: `<T02 构建命令>` → `BUILD SUCCESSFUL`；`<T02 单测命令>` → 12 套件全绿
  - failure: 临时删掉 `library/Index.ets` 里的 `installCryptoDefaults()` 调用并跑本地单测（分支 B 下应仍全绿，因为测试走深路径；分支 A 下应仍全绿），随后在 `internal/HmacProvider.ets` 里加一行 `import { cryptoFramework } from '@kit.CryptoArchitectureKit';` 并跑本地单测，确认**验收 grep 会失败**（证明 grep 有效），随后还原并重跑至绿
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-03-scaffold.md`
  **Commit**: Y | `feat(otp): 搭建 HAR 库脚手架（kit-free 分层 + 全量注册入口）`

### W3

- [ ] 4. Base32 编解码（RFC 4648）
  **What to do**：
  1. `internal/Base32.ets`：字母表常量 `'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'`。
     - `decode(input: string): Uint8Array`：`replace(/\s/g,'')` → 去尾部 `=` → `toUpperCase()`；空串抛 `EMPTY_SECRET`；逐字符校验，非法字符抛 `INVALID_BASE32_CHAR`；`Math.floor(len*5/8)` 为 0 时抛 `SECRET_TOO_SHORT`；按 8 字符一组解码（沿用旧实现 `Totp.ets:15-76` 的位拼接公式：`buf[0]<<3|buf[1]>>2`、`buf[1]<<6|buf[2]<<1|buf[3]>>4`、`buf[3]<<4|buf[4]>>1`、`buf[4]<<7|buf[5]<<2|buf[6]>>3`、`buf[6]<<5|buf[7]`，每字节 `& 0xff`；不足 8 字符的末组按剩余有效位数截断输出）。输出 `Uint8Array`。
     - `encode(bytes: Uint8Array): string`：输出**大写、无填充**；输出字符数 = `ceil(len*8/5)`；空数组返回空串（不抛错，由调用方决定语义）。
  2. `Base32.test.ets`：
     - `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ` → 20 字节，`bytes[0]===49`、`bytes[19]===48`
     - `'MY'` → 1 字节 `0x66`（末组截断）
     - 大小写等价、含 `=` 等价、含空白等价
     - `''` → `EMPTY_SECRET`；`'A'` → `SECRET_TOO_SHORT`；`'AB1'` → `INVALID_BASE32_CHAR`（`1` 不在字母表）；`'ab0'` → `INVALID_BASE32_CHAR`
     - `encode(decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'))` → `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`（附录 A.1；**不得用 `Secret.fromBytes`**，那是 T08 才实现的符号）
     - 对长度 1..8 字节的字节数组做 `decode(encode(x))` round-trip
     - appendix A.1 的 SHA256/SHA512 seed（32/64 字节 ASCII）round-trip
  **Must NOT do**: 不得用逐字符拼二进制字符串的方式解码；不得用 `padStart`；不得在错误消息里带 secret 内容；不得修改其他文件。
  **Parallelization**: W3 | Blocked by: T03 | Blocks: T08, T09 | Can parallelize with: T05, T06, T07
  **References**:
  - 设计文档 §3.3、附录 A.1
  - 旧实现（只读，**禁止修改该仓库**）：`/Users/yansongda/000-Coding/application/huawei/atomicservice/MFA/entry/src/main/ets/utils/Totp.ets` 的 `base32Decode`（L15-76）与旧用例 `/Users/yansongda/000-Coding/application/huawei/atomicservice/MFA/entry/src/test/TotpCode.test.ets`
  - RFC 4648 §6（base32 字母表与填充规则）：https://www.rfc-editor.org/rfc/rfc4648.txt
  - 历史坑：旧 `Totp.ets:114`「不依赖 padStart（规避 ArkTS 兼容性不确定性）」
  - hypium 断言 API 样张：`library/src/test/List.test.ets` 与 T03 产出的任一占位测试文件（**注意**：模板 `LocalUnit.test.ets` 已在 W2 被 T03 删除，不要去找它）
  **Acceptance criteria**:
  - `<T02 单测命令>` exit 0，`base32Test` 全绿，用例数 ≥ 12
  - `grep -rn "padStart" library/src/main/ets/internal/Base32.ets` → 无输出；`grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/Base32.ets` → 0
  - `grep -c "it(" library/src/test/Base32.test.ets` ≥ 12
  **QA scenarios**:
  - happy: `<T02 单测命令>` → `base32Test` 全绿
  - failure: 临时把字母表改成 `'ABCDEFGHIJKLMNOPQRSTUVWXYZ234560'`（把索引 31 的 `7` 换成 `0`），确认 **`'ab0'` 用例变红**（它从「非法字符」变成合法，不再抛 `INVALID_BASE32_CHAR`）；**注意 `'AB1'` 与 seed 串在此破坏下不会变红**（`1` 始终非法；seed 串只用到索引 ≤30 的字符），不要拿它们当红点。记录输出后还原
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-04-base32.md`
  **Commit**: Y | `feat(otp): 实现 RFC 4648 base32 编解码`

- [ ] 5. 整数原语（Counter / Truncate / Digits）
  **What to do**：
  1. `internal/Counter.ets`：`toBytes(counter)` —— 校验 `Number.isInteger(counter) && counter >= 0 && counter <= Number.MAX_SAFE_INTEGER`，否则抛 `INVALID_COUNTER`；`high = Math.floor(counter / 4294967296)`、`low = counter % 4294967296`；8 字节大端，**必须**用 `>>>` 与 `& 0xff` 取值（**严禁**用 `<<` 拼 32 位：ArkTS 位运算是 32 位有符号）。`isSafeCounter(value)` 返回同规则布尔。
  2. `internal/Truncate.ets`：`digest.length < 20` 抛 `CRYPTO_FAILED`（固定文案，不含 digest 内容）；`offset = digest[digest.length-1] & 0x0f`；`v = ((digest[offset] & 0x7f) << 24 | digest[offset+1] << 16 | digest[offset+2] << 8 | digest[offset+3]) >>> 0`；返回 `v`（**只做截断，不做取模**）。
  3. `internal/Digits.ets`：`isValidDigits(d)` = `d === 6 || d === 7 || d === 8`；`format(value, digits)` 非法 digits 抛 `INVALID_DIGITS`，否则 `String(value % Math.pow(10, digits))` 左补 `'0'` 至 `digits` 位（**不得用 `padStart`**，沿用旧实现的手写补零）。
  4. `Counter.test.ets`：附录 A.5 的**全部 9 行**逐字节断言（`0`/`1`/`9`/`666666666`/`4294967295`/`4294967296`/`4294967297`/`4294967391`/`9007199254740991`）；`-1`、`1.5`、`9007199254740992`（2^53）→ `INVALID_COUNTER`；`isSafeCounter` 正反例。
  5. `Truncate.test.ets`：附录 A.2 **全部 10 条**的 Truncate 原始值（第 4 列：`1284755224`/`1094287082`/`137359152`/`1726969429`/`1640338314`/`868254676`/`1918287922`/`82162583`/`673399871`/`645520489`）逐字照抄并逐条断言 `apply()` 返回值相等 —— **禁止用 digest 自行推导**（推导会与被测实现同源，变成自证）；长度 19 的 digest → `CRYPTO_FAILED`。
  6. `Digits.test.ets`：`format(287082,6)==='287082'`、`format(1234,6)==='001234'`、`format(0,6)==='000000'`、`format(755224,6)==='755224'`、`format(4287082,7)==='4287082'`、`format(84755224,8)==='84755224'`、`format(137359152,8)==='37359152'`；`format(1,5)`/`format(1,9)` → `INVALID_DIGITS`。
  **Must NOT do**: 不得用 `<<` 拼接超过 32 位的数据；不得用 `padStart`；不得在 `Truncate` 里做取模（取模只在 `Digits`）；不得在错误消息里带 secret/digest 内容；不得修改其他文件。
  **Parallelization**: W3 | Blocked by: T03 | Blocks: T09 | Can parallelize with: T04, T06, T07
  **References**:
  - 设计文档 §3.3（伪代码与约束表）、附录 A.2/A.5
  - 旧实现（只读）：旧 `Totp.ets` 的 `counterToBytes`（L82-96）、`truncate`（L99-112）、`zeroPad6`（L115-121）
  - 历史坑（必须继承）：旧 `Totp.ets:78-96`（`<<` 说明注释起于 L78）「不能用 `<<` 直接拼 32 位——JS/ArkTS 位运算按 32 位有符号整数处理」；`Totp.ets:114`「不依赖 padStart」
  - RFC 4226 §5.3（动态截断 + 屏蔽最高位的理由）：https://www.rfc-editor.org/rfc/rfc4226.txt
  **Acceptance criteria**:
  - `<T02 单测命令>` exit 0，`counterTest`/`truncateTest`/`digitsTest` 全绿
  - `grep -rn "padStart" library/src/main/ets/internal/Digits.ets` → 无输出
  - `grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/Counter.ets library/src/main/ets/internal/Truncate.ets library/src/main/ets/internal/Digits.ets` → 0
  - `grep -c "it(" library/src/test/Counter.test.ets` ≥ 12；`Truncate.test.ets` ≥ 11；`Digits.test.ets` ≥ 8
  **QA scenarios**:
  - happy: `<T02 单测命令>` → 3 套件全绿
  - failure: ① 临时把 `Counter.toBytes` 的 `high` 改成 `counter >> 32`，确认 `counterTest` 变红；② 临时去掉 `Truncate` 的 `& 0x7f`，确认 `truncateTest` 变红；③ 临时把 `Digits.format` 的取模换成 `value`，确认 `digitsTest` 变红。三处都记录输出后还原
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-05-primitives.md`
  **Commit**: Y | `feat(otp): 实现计数器打包/动态截断/位数填充原语及向量单测`

- [ ] 6. 时间步与恒定时间比较（TimeStep）
  **What to do**：
  1. `internal/TimeStep.ets`：
     - `step(epochMs, t0, period)`：校验 `epochMs` 为 >0 有限数（否则 `INVALID_TIMESTAMP`）、`t0` 为 ≥0 整数（否则 `INVALID_T0`）、`period` 为正整数（否则 `INVALID_PERIOD`）；返回 `Math.floor((Math.floor(epochMs/1000) - t0) / period)`。**`t0` 单位是秒。**
     - `remainingSec(epochMs, t0, period)`：同校验；`const s = Math.floor(epochMs/1000); return period - ((((s - t0) % period) + period) % period);` → 落在 `[1, period]`。**必须按 epoch 秒取模**，不得用本地时区/`Date` 的 date 部分。
     - `progress(epochMs, t0, period)`：同校验；返回 `((((s - t0) % period) + period) % period) / period` → `[0, 1)`。
     - `constantTimeEquals(a, b)`：长度不等立即返回 `false`；否则逐字符 `diff |= a.charCodeAt(i) ^ b.charCodeAt(i)`，返回 `diff === 0`；**禁止**用 `===` 或提前 `return true`。
  2. `TimeStep.test.ets`（**期望值来自设计 §3.3 的参照点，必须先写出推导**）：
     - `step(59000,0,30) === 1`；`step(30000,0,30) === 1`；`step(29999,0,30) === 0`；`step(20000000000000,0,30) === 666666666`（RFC 6238 最大向量）；`step(1000,0,30) === 0`；`step(31000,1,30) === 1`（t0=1 秒）
     - `remainingSec(59000,0,30) === 1`；`remainingSec(60000,0,30) === 30`；`remainingSec(1000,0,30) === 29`；`remainingSec(1000,0,45) === 44`；`remainingSec(45000,0,45) === 45`
     - **`t0≠0` 专项（锁定 `t0` 偏移与负值归一化；无此组用例时，实现丢掉 `t0` 也不会红）**：`remainingSec(31000,1,30) === 30`（`((31-1)%30+30)%30=0` → `30-0`）；`progress(31000,1,30) === 0`；`remainingSec(1000,5,30) === 4`（`((1-5)%30+30)%30=26` → `30-26`）；`step(1000,5,30) === -1`（t0 大于当前秒时的负 step，供上层抛 `INVALID_COUNTER`）
     - `progress(15000,0,30) === 0.5`；`progress(1000,0,30)` 接近 `1/30`；`progress(45000,0,45) === 0`
     - `constantTimeEquals('123456','123456') === true`；`('123456','123457') === false`；`('12345','123456') === false`；`('','') === true`；`('你','你') === true`
     - 非法输入：`step(0,0,30)` → `INVALID_TIMESTAMP`；`step(1,-1,30)` → `INVALID_T0`；`step(1,0,0)`/`step(1,0,1.5)` → `INVALID_PERIOD`
  **Must NOT do**: 不得用 `Date` 对象做时间计算（只做纯数值运算）；不得在 `constantTimeEquals` 中提前返回 true；不得依赖时区；不得修改其他文件。
  **Parallelization**: W3 | Blocked by: T03 | Blocks: T09 | Can parallelize with: T04, T05, T07
  **References**:
  - 设计文档 §3.3（含**参照点表**：`s=59,p=30 → 1`；`s=60,p=30 → 30`；`s=1,p=30 → 29`；`s=45,p=45 → 45`）、§3.3 verify 窗口语义
  - RFC 6238 §4.2（T 计算与 >32 位要求）：https://www.rfc-editor.org/rfc/rfc6238.txt
  - 历史坑（必须继承）：旧 `models/Runtime.ets:149`（`private schedule()` 在 L150）「倒计时必须与 TOTP 计数器同样按 epoch 秒取模，否则 period 非 60 约数（45s）或时区偏移非整小时（+05:30）时倒计时与验证码翻转错开」—— `/Users/yansongda/000-Coding/application/huawei/atomicservice/MFA/entry/src/main/ets/models/Runtime.ets`（只读）
  - ⚠️ 本任务曾在初审中被查出 2 处期望值错误（1000ms 处误写 30/45，正确为 29/44）；**必须先写出 `s = floor(ms/1000)` 的推导再落断言**
  **Acceptance criteria**:
  - `<T02 单测命令>` exit 0，`timeStepTest` 全绿，用例数 ≥ 15
  - `grep -c "it(" library/src/test/TimeStep.test.ets` ≥ 15
  - `grep -rn "new Date\|Date.now" library/src/main/ets/internal/TimeStep.ets` → 无输出
  - `grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/TimeStep.ets` → 0
  **QA scenarios**:
  - happy: `<T02 单测命令>` → `timeStepTest` 全绿
  - failure: 临时把 `remainingSec` 改成 `period - Math.floor(epochMs/1000) % period`（丢掉 `t0` 与负值归一化），确认 **`remainingSec(1000,5,30)` 用例变红**（正确 `4` / 破坏实现 `29`）—— 注意：仅看 `t0=0` 的用例**不会**变红（两种实现在 `t0=0` 时完全等价），这正是该红点的意义；记录输出后还原
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-06-timestep.md`
  **Commit**: Y | `feat(otp): 实现时间步/倒计时/进度与恒定时间比较`

- [ ] 7. 加密适配器实现（kit-only `CryptoSource`）
  **What to do**：
  1. **核对** T03 已完整实现的 `internal/HmacProvider.ets`：须含 `HmacProvider`/`RandomSource` 两个接口，`registerHmac`/`requireHmac`/`registerRandom`/`requireRandom` 四个函数，以及 `@internal resetForTest()`；`requireXxx()` 未注册时抛 `CRYPTO_NOT_INITIALIZED`。**本任务不得修改该文件**（所有权归 T03），如发现缺陷必须向编排方报告而不自行修正。
  2. `internal/CryptoSource.ets`（**全库唯一 `@kit` 导入点**）：
     - `export class CryptoFrameworkHmac implements HmacProvider`：`sign()` 内 `const gen = cryptoFramework.createSymKeyGenerator('HMAC'); const symKey = gen.convertKeySync({ data: key }); const mac = cryptoFramework.createMac(algName); mac.initSync(symKey); mac.updateSync({ data: message }); return new Uint8Array(mac.doFinalSync().data);`；`algName` 由 `OtpAlgorithm` 映射为 `'SHA1'|'SHA256'|'SHA512'`；**整段包在 `try/catch` 中**，`catch` 一律 `throw new OtpError(OtpErrorCode.CRYPTO_FAILED, 'CRYPTO_FAILED')`（固定文案，不透传原生错误、不含 key/message）。密钥生成器**必须**用 `'HMAC'`（通用规格，支持 1–4096 字节任意长度），**严禁** `'HMAC|SHA1'` 之类（该规格要求密钥长度恰等于摘要长度，会拒绝 80 bit 的真实 secret）。
     - `export class CryptoFrameworkRandom implements RandomSource`：`random(bytes)` 校验 `Number.isInteger(bytes) && bytes >= 1 && bytes <= 4096`（否则 `SECRET_TOO_WEAK`），返回 `new Uint8Array(cryptoFramework.createRandom().generateRandomSync(bytes).data)`；同样 try/catch → `CRYPTO_FAILED`。
     - `export function installCryptoDefaults(): void` → 只 `registerHmac(new CryptoFrameworkHmac())` + `registerRandom(new CryptoFrameworkRandom())`，**不得发起任何 crypto 调用**。
     - 若 T02 判定 `*Sync` 接口不可用：**停止**，按 Executor rule 1 作为设计性偏差上报（API 需改 async），不得自行改 async。
  3. `CryptoSource.test.ets`（本地，视 T02 分支）：
     - **分支 A**：断言 `new CryptoFrameworkHmac().sign(SHA1, <ASCII 20 字节 seed>, <8 字节大端 counter=1>)` 的 hex == `75a48a19d4cbe100644e8ac1397eea747a2d33ab`；SHA256（32 字节 seed）counter=1 == `392514c9dd4165d4709456062c78e04e16e68718515951333bdb8b26caa3053c`；SHA512（64 字节 seed）counter=1 == `6f76f324230cefda1d3f65309a0badb36efce9528ada64967d71e4e9d74c4aa37fe7650f931ab86ddccc2d38962d720ee626a20feb311b485a92e3bb0796df28`；`secret = JBSWY3DPEHPK3PXP` 解码的 10 字节密钥不抛错（证伪「密钥长度必须等于摘要长度」）；`CryptoFrameworkRandom().random(20).length === 20` 且两次不同；`installCryptoDefaults()` 后可 `requireHmac()`/`requireRandom()`；未注册时 `requireHmac()` 抛 `CRYPTO_NOT_INITIALIZED`（用 T03 已提供的 `@internal resetForTest()` 先重置再取用；**T07 不得修改 `HmacProvider.ets`**，若该函数缺失则改用「先断言未注册分支再注册」的顺序）。
     - **分支 B**：`CryptoSource.test.ets` 只保留 1 条 import-smoke，文件头注释写明「分支 B：Local Test 无法加载系统 kit，真实 crypto 断言见 `library/src/ohosTest/ets/test/CryptoAdapter.test.ets`」。
  **Must NOT do**: 不得引入第三方 HMAC 实现；不得让 `HmacProvider.ets` 依赖 kit（哪怕 type-only）；不得在 `catch` 里打日志或吞错；不得用 `'HMAC|SHA*'` 规格；不得 mock 系统 API 伪造通过；不得修改其他文件。
  **Parallelization**: W3 | Blocked by: T03, T02（分支结论） | Blocks: T09, T11 | Can parallelize with: T04, T05, T06
  **References**:
  - 设计文档 §3.1（注册表契约、kit-free/kit-only 分离理由）、§3.3、§3.5
  - **本地 SDK（权威）**：`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/api/@ohos.security.cryptoFramework.d.ts`（`generateRandomSync` L1332、`convertKeySync(key)` L2006、`initSync(key)` L2304、`updateSync(input)` L2398、`doFinalSync()` L2475）
  - 官方 HMAC 开发指导（`createSymKeyGenerator('HMAC')` + 同步 API 示例）：https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/security/CryptoArchitectureKit/crypto-compute-hmac.md
  - 官方密钥生成/转换规格（「HMAC」密钥范围 [1,4096] 字节；`HMAC|SHAxxx` 要求密钥长度=摘要长度）：https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/security/CryptoArchitectureKit/crypto-sym-key-generation-conversion-spec.md
  - 历史坑（必须继承）：旧 `utils/Totp.ets:140-141`「用通用 'HMAC' 规格导入密钥…不得用 'HMAC|SHA1'」；`Totp.ets:152-154`「失败不吞错、不打日志、不输出 secret」
  - T02 结论快照：`docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`
  **Acceptance criteria**:
  - 构建命令 exit 0（证明 `*Sync` 接口在本工程可编译）
  - `<T02 单测命令>` exit 0；分支 A 下 `cryptoSourceTest` 用例数 ≥ 8 且全绿，分支 B 下仅 1 条 smoke 且 evidence 明确标注该缺口与设备端替代验证
  - `grep -n "HMAC|" library/src/main/ets/internal/CryptoSource.ets` → 无输出
  - `grep -n "@kit\." library/src/main/ets/internal/HmacProvider.ets` → 无输出
  - `grep -c "OtpErrorCode.CRYPTO_FAILED\|OtpErrorCode.CRYPTO_NOT_INITIALIZED" library/src/main/ets/internal/CryptoSource.ets library/src/main/ets/internal/HmacProvider.ets` ≥ 2
  **QA scenarios**:
  - happy: `<T02 单测命令>` → `cryptoSourceTest` 按分支通过；分支 A 下 SHA1/SHA256/SHA512 三条 digest 与附录 A 一致
  - failure: ① **用静态断言验证，不得动态调用**：`awk '/function installCryptoDefaults/{f=1} f{print} f&&/^\}/{exit}' library/src/main/ets/internal/CryptoSource.ets | grep -c "cryptoFramework\."` → 必须为 `0`（锁定「注册期不得调用 crypto」这条约束；原因：分支 A 下调用成功不会报错，分支 B 下测试模块图内又不存在 barrel，**动态验证在两个分支下都观察不到**）；② 临时把 `algName` 映射改成固定 `'SHA1'`，**分支 A** 下确认本地 SHA256/SHA512 用例变红；**分支 B** 下 `cryptoSourceTest` 本地仅 1 条 smoke，该红点由 **T11 的设备用例**承担（在 evidence 注明）；均记录输出后还原
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-07-crypto.md`
  **Commit**: Y | `feat(otp): 实现 cryptoFramework 加密适配器（CryptoSource）`

### W4

- [ ] 8. Secret 与 OTPAuth URI（规范化层）
  **What to do**：
  1. `Secret.ets`（**禁止 import kit、禁止 import CryptoSource**）：
     - `static fromBase32(input: string): Secret` → `Base32.decode`；结果长度 0 抛 `EMPTY_SECRET`
     - `static fromBytes(bytes: Uint8Array): Secret` → 空数组抛 `EMPTY_SECRET`；**必须拷贝**入参（`new Uint8Array(bytes)`）
     - `static generate(bytes: number = 20): Secret` → 校验 `Number.isInteger(bytes) && bytes >= 1 && bytes <= 4096`，否则抛 `SECRET_TOO_WEAK`（在 evidence 注明该错误码选择理由）；取值经 `requireRandom().random(bytes)`
     - `get bytes(): Uint8Array`（**返回拷贝**）、`get byteLength()`、`get bitLength()`、`toBase32()`、`toJSON(): string` 返回 `'[REDACTED]'`
     - **不得**实现返回明文的 `toString()`；不得实现其他序列化方法
  2. `OTPAuthURI.ets`：`export class OTPAuthURI { static parse(uri: string): OtpAuthParams; static build(params: OtpAuthParams): string; }`
     - `parse`：① 大小写不敏感匹配 `otpauth://`，不匹配抛 `INVALID_OTPAUTH_URI`；② `type` 取 `?` 之前、`/` 之后部分并小写化；非 `totp`/`hotp` 抛 `UNSUPPORTED_OTPAUTH_TYPE`；③ label 取 `/` 之后、`?` 之前部分并百分号解码（解码失败回退原串）；按**解码后**与 `%3A` 两种形式切出 `issuer`/`account`（只切第一个冒号）；④ query 手写拆分（`&` 分段、`=` 分键值、键值都百分号解码；**不得**用 `URLSearchParams`）；⑤ 字段按设计 §3.4 表格处理（未知参数忽略；secret 必填且经 `Base32.decode` 校验；algorithm 大小写不敏感映射否则 `INVALID_ALGORITHM`；digits 默认 6、period 默认 30、counter 默认 0 且仅 HOTP 读取）；⑥ 返回 `secret` 为规范化大写无填充 base32；⑦ query 的 `issuer` 与 label 前缀不一致时**以 query 为准**
     - `build`：输出 `otpauth://<type>/<label>?...`（HOTP 输出 `counter` 而非 `period`；`issuer`/`account` 为空时省略对应部分）；label 形如 `issuer:account` 时两者百分号编码、冒号保留；参数顺序固定 `secret, issuer, algorithm, digits, period|counter`；`algorithm` 字段始终显式输出；`digits` 仅在 `!= 6` 时输出、`period` 仅在 TOTP 且 `!= 30` 时输出（与 GA 惯例一致，须在 evidence 注明该选择）
     - `parse(build(p))` 与 `p` 语义等价（round-trip 用例）
  3. `library/src/test/RandomFixture.ets`（**本文件唯一所有者是 T08；T09 不得创建或修改**）：`export class RandomFixture implements RandomSource`，`random(bytes)` 返回固定递增序列（`bytes` 个连续字节 `0x00,0x01,…`），并暴露 `lastRequestedBytes` 供断言。
  4. `Secret.test.ets`：`fromBase32('jbswy3dpehpk3pxp').byteLength === 10`、`.bitLength === 80`（用例名点明「低于 RFC 4226 §4 R6 的 128 bit 建议」）；大小写/填充/空白等价；`fromBytes(new Uint8Array())` → `EMPTY_SECRET`；改写入参数组不影响实例；改动 `bytes` 返回值不影响内部（再取一次校验）；`toBase32()` 等于规范化大写；`generate(20).byteLength === 20`（经 `registerRandom(new RandomFixture())` 注入固定值 → 断言值确定，**不要用真实随机源断言**）；`JSON.stringify({s: secret})` **不含**密钥内容且含 `'[REDACTED]'`；`String(secret)` 不含明文 base32（若 `toString` 未定义则等于 `'[object Object]'`，两种结果都须断言为「不含密钥」）
  5. `OtpAuthUri.test.ets`：标准 URI `otpauth://totp/ACME%20Co:john@example.com?secret=JBSWY3DPEHPK3PXP&issuer=ACME%20Co&algorithm=SHA256&digits=8&period=60` 全字段解析断言；`%3A` 分隔形式；缺省值（无 algorithm/digits/period → SHA1/6/30）；HOTP URI 带 `counter=42`；未知参数被忽略；`OTPAUTH://TOTP/` 大写 scheme 可解析；失败用例：`http://…`→`INVALID_OTPAUTH_URI`、`otpauth://steam/…`→`UNSUPPORTED_OTPAUTH_TYPE`、缺 secret→`EMPTY_SECRET`、`algorithm=MD5`→`INVALID_ALGORITHM`、`digits=5`→`INVALID_DIGITS`、`period=0`→`INVALID_PERIOD`、`counter=-1`→`INVALID_COUNTER`；`build`→`parse` round-trip（TOTP 全字段、HOTP、仅必填字段各 1 例）；`build` 输出逐字断言
  6. `OtpError.test.ets`：`new OtpError(OtpErrorCode.INVALID_DIGITS,'x') instanceof Error` 与 `instanceof OtpError` 均为 `true`、`.code === OtpErrorCode.INVALID_DIGITS`、`.message === 'x'`；**17 个成员值逐一断言**（防枚举改动）；若 `instanceof OtpError` 断言失败 → 停止，按 Executor rule 1 作为设计性偏差上报（错误模型需改普通类 + 判定函数）
  **Must NOT do**: 不得使用 `URLSearchParams`/`URL`；`Secret` 不得暴露明文于 `toString`；不得让 `Secret.bytes` 返回内部引用；不得 import kit 或 `CryptoSource`；不得在测试里使用真实生产密钥。
  **Parallelization**: W4 | Blocked by: T03, T04 | Blocks: T10 | Can parallelize with: T09
  **References**:
  - 设计文档 §3.2（`Secret`/`OTPAuthURI` 签名与 `toJSON` 决策）、§3.4（URI 字段全表）、§3.5（错误模型）、§3.1（注册表）
  - GA Key URI Format（事实标准，label ABNF、"padding should be omitted"）：https://github.com/google/google-authenticator/wiki/Key-URI-Format
  - IANA URI scheme `otpauth` 状态 Provisional #13829：https://www.iana.org/assignments/uri-schemes/uri-schemes.xhtml
  - RFC 4226 §4 R6（secret ≥128 bit、推荐 160 bit）：https://www.rfc-editor.org/rfc/rfc4226.txt
  - 已就位依赖：`internal/{Base32,HmacProvider}.ets`、`OtpError.ets`、`OtpOptions.ets`；`src/test/RandomFixture.ets`（T03 建的占位；**本任务补实现，所有权归 T08**）
  - T02 语言探针结论（`toJSON` 是否被 `JSON.stringify` 调用）：`docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`
  **Acceptance criteria**:
  - `<T02 单测命令>` exit 0，`secretTest`/`otpAuthUriTest`/`otpErrorTest` 全绿
  - `grep -rn "URLSearchParams\|@kit\." library/src/main/ets/Secret.ets library/src/main/ets/OTPAuthURI.ets` → 无输出
  - `grep -n "toString" library/src/main/ets/Secret.ets` → 只允许注释或「不实现」的说明，不得有 `toString()` 方法定义
  - `grep -c "it(" library/src/test/OtpAuthUri.test.ets` ≥ 18；`OtpError.test.ets` ≥ 4
  - `grep -c "random(\|lastRequestedBytes" library/src/test/RandomFixture.ets` ≥ 2（证明该文件已由 T08 真实实现，非 T03 占位）
  - `grep -c "NOT_IMPLEMENTED" library/src/main/ets/Secret.ets library/src/main/ets/OTPAuthURI.ets` → 0
  **QA scenarios**:
  - happy: `<T02 单测命令>` → 3 套件全绿
  - failure: 临时把 `parse` 的 digits 校验去掉（允许 `digits=5`），确认 `INVALID_DIGITS` 用例变红；临时删掉 `toJSON()`，确认脱敏用例变红；均记录输出后还原
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-08-secret-uri.md`
  **Commit**: Y | `feat(otp): 实现 Secret 规范化/校验/生成/脱敏与 OTPAuth URI 解析生成`

- [ ] 9. 编排引擎 + 黄金向量 fixture（RFC 全量向量主战场）
  **What to do**：
  1. `library/src/test/vectors/RfcVectors.ets`：把**附录 A 的全部表格**落为 ArkTS 常量：`RFC4226_SHA1_6DIGIT`（10 条 `{counter, digestHex, code}`）、`RFC6238_SHA1/SHA256/SHA512`（各 6 条 `{timeSec, counter, counterHex, digestHex, code8}`）、`BOUNDARY_COUNTERS`（3 条；每条**按算法各存一组**：`{counter, counterHex, sha1: {digest, code6, code8}, sha256: {digest, code6, code8}, sha512: {digest, code6, code8}}` —— A.4 每个 counter 有三算法各一组 6/8 位码，单一 `code6/code8` 字段装不下）、`DIGITS7_SHA1`（**3 条：counter 0/1/9，值见 A.6**）、`COUNTER_BYTES`（9 条 `{counter, hex}`）、`SEEDS`（三算法 ASCII 字节串 **+ A.1 的 base32 规范形**，供 T11 走公开 API 测 SHA256/512 用）、`SHA256_C0_8DIGIT = '18920136'`、**`SHA256_C0_DIGEST = 'c79f479abc3c567224e3f8c8e46b2631d5b3f319a06a1e472cbdbee3aa479848'`**（A.6 第 1 行的 digest；**必须落表并装入 fixture**：T10 的 fromURI 用例走 `period=60` → counter=0，若缺此条则 fixture 查表未命中、按自身规格必抛错，用例必红）。**逐字照抄附录 A，禁止改值、禁止补算**。
  2. `library/src/test/HmacFixture.ets`：`export class HmacFixture implements HmacProvider`，构造接收 `Map<string,string>`（键 `<algorithm>:<message hex>`，值 digest hex）；`sign()` 查表命中则 hex→`Uint8Array` 返回，**未命中必须抛错**（绝不允许返回零值数组，那会让用例假绿）；`export function buildRfcFixture(): HmacFixture` 把 `RfcVectors` 的 digest 全部装表（**注意 SHA1 counter=1 在 A.2 与 A.3 的 T=59 行各出现一次，digest 相同，`Map.set` 重复写入幂等无害** —— 不要为它写多余的合并逻辑）。
  3. `internal/OtpEngine.ets`：
     - `generate(provider, params, counter)`：`Digits.format(Truncate.apply(provider.sign(params.algorithm, params.key, Counter.toBytes(counter))), params.digits)` —— **取模只在 `Digits.format` 内做一次**，不得在此处再取模。
     - `verify(provider, params, token, counter, window)`：① 校验 `token` 为纯数字且 `token.length === params.digits`，否则 `INVALID_TOKEN`；② 校验 `window` 为 ≥0 整数，否则 `INVALID_WINDOW`；③ 对每个候选 `candidate = counter + delta`（`delta` 从 `-window` 到 `+window`），`candidate < 0` 或 `!Counter.isSafeCounter(candidate)` 的**跳过**；④ 生成候选码并 `constantTimeEquals` 比对；⑤ **扫完全部候选后才返回**第一个命中的 `delta`（不得提前 return）；⑥ 未命中 `null`。
     - 不得 import kit，不得打日志。
  4. `OtpEngine.test.ets`（**全部用 `HmacFixture` 注入，不碰系统 kit**）：
     - RFC 4226：counter 0..9 逐条 == 附录 A 的 6 位码（10 条）
     - RFC 6238：三算法 × 6 时间点 = 18 条（用 `counter` 直接喂；**另用 `TimeStep.step(timeSec*1000, 0, 30)` 断言等于附录 A 的 counter 列**）
     - 边界：`BOUNDARY_COUNTERS` 3 条 × 三算法 × {6 位, 8 位}（覆盖 >2^32 与 2^53-1）
     - 7 位：`DIGITS7_SHA1` 3 条
     - `verify` 正例：`verify(fixture, {SHA1,6,key20}, '287082', 1, 0) === 0`；`verify(..., '287082', 2, 1) === -1`；`verify(..., '287082', 0, 1) === 1`
     - `verify` 负例：`window:0` 时上一步的码 → `null`；错误码 → `null`
     - `verify` 边界：`verify(..., <counter0 的码>, 0, 2) === 0`（负候选被跳过且不崩溃）
     - `verify` 入参校验：`'12345'`、`'12a456'` → `INVALID_TOKEN`；`window: -1`、`window: 1.5` → `INVALID_WINDOW`
     - fixture 未命中必须报错：用不在表里的 counter 调 `generate`，断言抛错
  **Must NOT do**: 不得改 `RfcVectors.ets` 任何数值；不得在 fixture 未命中时静默返回 0 值；不得让 `verify` 提前 return；不得 import 系统 kit 或 `CryptoSource`；不得在 `OtpEngine` 内重复取模；**不得创建或修改 `library/src/test/RandomFixture.ets`（所有权归 T08）**。
  **Parallelization**: W4 | Blocked by: T04, T05, T06, T07 | Blocks: T10 | Can parallelize with: T08
  **References**:
  - 设计文档 §3.3（伪代码、verify 窗口语义、恒定时间比较要求）、**附录 A（唯一向量来源，逐字照抄）**
  - RFC 4226 Appendix D：https://www.rfc-editor.org/rfc/rfc4226.txt
  - RFC 6238 Appendix B / §5.2 / §6：https://www.rfc-editor.org/rfc/rfc6238.txt
  - 已就位依赖：`internal/{Base32,Counter,Truncate,Digits,TimeStep,HmacProvider,OtpEngine}.ets`、`OtpError.ets`、`OtpOptions.ets`
  - 旧测试参考（只读）：`/Users/yansongda/000-Coding/application/huawei/atomicservice/MFA/entry/src/test/TotpCode.test.ets`
  **Acceptance criteria**:
  - `<T02 单测命令>` exit 0，`otpEngineTest` 全绿，用例数 ≥ 45
  - `grep -c "it(" library/src/test/OtpEngine.test.ets` ≥ 45
  - 反自证检查：`grep -rn "@kit\|cryptoFramework" library/src/test/OtpEngine.test.ets library/src/test/HmacFixture.ets library/src/test/vectors/RfcVectors.ets` → 无输出
  - `grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/OtpEngine.ets` → 0
  - `grep -c "%" library/src/main/ets/internal/OtpEngine.ets` → 只出现在 `Digits.format` 调用处之外应无取模（人工确认无重复取模）
  **QA scenarios**:
  - happy: `<T02 单测命令>` → `otpEngineTest` 全绿（RFC 4226 10 + RFC 6238 18 + 边界 18 + 7 位 3 + verify ≥ 8）
  - failure: ① 临时把 `Truncate` 的 offset 高位掩码 `0x0f` 改成 `0x0e`，确认 RFC 向量大面积变红；② 临时把 `TimeStep.step` 的 `Math.floor` 改成 `Math.round`，确认 RFC 6238 时间点用例变红；③ 临时让 fixture 未命中返回零值数组，确认「未命中必报错」用例变红；均记录输出后还原
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-09-engine.md`（必须含「与附录 A 逐条比对一致」的断言计数）
  **Commit**: Y | `feat(otp): 实现 HOTP/TOTP 编排引擎并通过 RFC 4226/6238 全量官方向量`

### W5

- [ ] 10. 公开类（HOTP / TOTP，含时钟偏移）
  **What to do**：
  1. `HOTP.ets`（**禁止 import kit / CryptoSource**）：`class HOTP { constructor(options: HotpOptions, provider?: HmacProvider); generate(counter?: number): string; verify(token: string, options?: VerifyOptions): number | null; toURI(): string; static fromURI(uri: string): HOTP; }`
     - 构造期校验并缓存：`secret` 经 `Secret.fromBase32`；`algorithm` 默认 `SHA1`；`digits` 默认 `6`（`Digits.isValidDigits` 否则 `INVALID_DIGITS`）；`counter` 默认 `0`（`Counter.isSafeCounter` 否则 `INVALID_COUNTER`）；`minSecretBits > 0` 且 `bitLength < minSecretBits` → `SECRET_TOO_WEAK`
     - `generate(counter?)` 缺省用构造值；`verify(token, options?)` counter 缺省用构造值、window 缺省 0
     - `toURI()` → `OTPAuthURI.build({type: OtpType.HOTP, secret: secret.toBase32(), algorithm, digits, counter, issuer, account})`；`fromURI(uri)` → `OTPAuthURI.parse` → 构造；URI 为 totp 时抛 `UNSUPPORTED_OTPAUTH_TYPE`
     - `provider` 缺省走 `requireHmac()`；第二参注释 `/** @internal 仅供测试注入 */`
  2. `TOTP.ets`（同上禁令）：`class TOTP { constructor(options: TotpOptions, provider?: HmacProvider); generate(timestampMs?: number): string; verify(token: string, options?: VerifyOptions): number | null; remaining(timestampMs?: number): number; progress(timestampMs?: number): number; syncClockOffset(delta: number): void; get clockOffsetMs(): number; toURI(): string; static fromURI(uri: string): TOTP; }`
     - 构造期同 HOTP，另：`period` 默认 30（正整数否则 `INVALID_PERIOD`）、`t0` 默认 0（≥0 整数否则 `INVALID_T0`）、`clockOffsetMs` 默认 0（有限数否则 `INVALID_TIMESTAMP`）
     - 所有时间入口统一 `const ts = (timestampMs ?? Date.now()) + this._clockOffsetMs;`（显式传入时**也**叠加偏移）
     - `generate(ts?)` → `OtpEngine.generate(provider, params, TimeStep.step(effectiveTs, t0, period))`；`verify(token, options?)` → `OtpEngine.verify(provider, params, token, TimeStep.step((options?.timestamp ?? Date.now()) + offset, t0, period), options?.window ?? 0)`；`remaining`/`progress` 直接转 `TimeStep`
     - `syncClockOffset(delta)`：**单参数**；`delta` 非整数 → `INVALID_WINDOW`（并写进 evidence）；`this._clockOffsetMs -= delta * period * 1000;` —— **符号依据见设计 §3.2 的双场景表**：delta=+1（码来自**下一步**，说明设备时钟**快**）⇒ offset 变负 ⇒ `89000 + (-30000) = 59000` 命中 T=59 的码。**不得改成 `+=`。**
  3. `Hotp.test.ets`（**一律从深路径 import 并注入 `HmacFixture`**：`import { HOTP } from '../main/ets/HOTP'`）：
     - 用 `secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'` 跑 RFC 4226 全部 10 条 6 位码
     - `digits:8` 时 counter=1 → `94287082`；`digits:7` 时 counter=1 → `4287082`
     - `toURI()` 逐字断言；`fromURI(toURI())` 后 `generate()` 结果一致
     - 构造期即抛错：`digits:5` → `INVALID_DIGITS`；`counter:-1` → `INVALID_COUNTER`；`minSecretBits:128` 且 80 bit secret → `SECRET_TOO_WEAK`；`minSecretBits:128` 且 160 bit secret → 不抛错
  4. `Totp.test.ets`（同样注 `HmacFixture`）：
     - 三算法 × 6 时间点（`timeSec*1000` 毫秒传入）共 18 条 8 位码断言
     - `digits:6` 且 `period:30`：`generate(59000) === '287082'`
     - `remaining(59000) === 1`；`progress(15000) === 0.5`
     - `verify` 正例/负例/窗口（与 T09 同语义，但走公开类）
     - **fixture 数据依赖（重要）**：本任务所有用例都经 `HmacFixture` 注入，**凡是用到的 (算法, counter) 组合必须在 `RfcVectors` 里有对应 digest 条目**；若发现查表未命中（fixture 会主动抛错），说明 T09 的常量清单有缺口，**不得自行补算**，须停下来向编排方报告（因为 `RfcVectors.ets` 不是本任务的文件）
     - **`syncClockOffset` 双场景（按设计 §3.2 表，先写推导再落断言）**：
       - 场景 A：`syncClockOffset(1)` → `clockOffsetMs === -30000`；`generate(89000) === '287082'`（T=59 的 6 位码）
       - 场景 B：新建实例 `syncClockOffset(-1)` → `clockOffsetMs === 30000`；`generate(59000) === '359152'`（counter 2 的 6 位码）
     - `t0` 用例：`t0: 1, period: 30, timestampMs: 31000` → counter = `floor((31-1)/30)` = 1 → `digits:8` 时 === `'94287082'`
     - `fromURI` 用例：URI 带 `algorithm=SHA256&digits=8&period=60` → `generate(59000)` 的 counter = `floor(59/60)` = **0** → === **`'18920136'`**（SHA256 counter=0 的 8 位码；**不要写 `46119246`，那是 counter=1 的值**）
     - 覆盖「构造期即抛错」
  **Must NOT do**: 不得在 `HOTP.ets`/`TOTP.ets` 顶层 import kit 或 `CryptoSource`；不得把 `provider` 参数类型导出到 barrel；不得缓存 provider 结果或码；不得改 `Index.ets`。
  **Parallelization**: W5 | Blocked by: T08, T09 | Blocks: T11, T12, T13
  **References**:
  - 设计文档 §3.2（API 全表、`syncClockOffset` 双场景证明、`period=60` 警示）、§3.3（窗口语义）、§3.7（失败场景）
  - 已就位依赖：`internal/{OtpEngine,TimeStep,HmacProvider,Counter,Digits,Truncate,Base32}.ets`、`Secret.ets`、`OTPAuthURI.ets`、`OtpOptions.ets`、`OtpError.ets`、`src/test/HmacFixture.ets`、`src/test/vectors/RfcVectors.ets`
  - RFC 6238 §6（resync/漂移）：https://www.rfc-editor.org/rfc/rfc6238.txt
  - 旧调用方语义参考（只读）：`/Users/yansongda/000-Coding/application/huawei/atomicservice/MFA/entry/src/main/ets/models/Runtime.ets:188-217`、`.../types/Item.ets:9-14`
  - 历史坑（必须继承）：旧 `Runtime.ets:332-334`「端内算码是权威来源，避免用旧窗口的服务端码覆盖本地新码」
  - ⚠️ 本任务曾在初审中被查出 3 处期望值/符号错误（syncClockOffset、fromURI、t0）；**每条断言前必须先在 evidence 写出 counter 推导**
  **Acceptance criteria**:
  - `<T02 单测命令>` exit 0，`hotpTest`/`totpTest` 全绿，用例数分别 ≥ 15 / ≥ 30
  - `grep -c "it(" library/src/test/Hotp.test.ets` ≥ 15；`grep -c "it(" library/src/test/Totp.test.ets` ≥ 30
  - `grep -rn "@kit\.\|CryptoSource" library/src/main/ets/HOTP.ets library/src/main/ets/TOTP.ets` → 无输出
  - `grep -c "NOT_IMPLEMENTED" library/src/main/ets/HOTP.ets library/src/main/ets/TOTP.ets` → 0
  - `grep -c "syncClockOffset" library/src/test/Totp.test.ets` ≥ 2（双场景各 1 次调用；另有 `clockOffsetMs` 断言，若用例名也含该词计数会更高，阈值取下限）
  **QA scenarios**:
  - happy: `<T02 单测命令>` → 两套件全绿；另加一条**公开 API 全链路**用例：`new TOTP({secret:'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', digits:8}, fixture).generate(59000) === '94287082'`
  - failure: ① 临时把 `syncClockOffset` 改成 `+=`，确认场景 A 用例变红（同时证明该用例能抓住这个符号错误）；② 临时去掉「构造期校验」改为惰性校验，确认构造期抛错用例变红；均记录输出后还原
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-10-public-api.md`
  **Commit**: Y | `feat(otp): 实现 HOTP/TOTP 公开类与时钟偏移校准`

### W6

- [ ] 11. 设备端真实 crypto 验证（ohosTest）
  **What to do**：
  1. `library/src/ohosTest/ets/test/CryptoAdapter.test.ets`：**用默认 provider（不注入 fixture）** 跑：
     - `new CryptoFrameworkHmac().sign` 三算法 counter=1 的 digest 与附录 A 一致（SHA1 `75a48a19…`、SHA256 `392514c9…`、SHA512 `6f76f324…`）
     - `new TOTP({secret: <A.1 对应算法的 base32>, digits:8})`：**三算法 × 6 时间点 = 18 条**，均 == 附录 A.3 的 8 位码（SHA1 用 A.1 的 base32；SHA256/512 用 A.1 新增的 base32 规范形，**照抄，不得在测试里临时拼**）
     - `new HOTP({secret:'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', digits:6})` counter 0..9 == RFC 4226 全量
     - `Secret.generate(20)`：`byteLength === 20`、两次不相等、`toBase32()` 可被 `fromBase32` 还原
     - 80 bit 真实密钥（`JBSWY3DPEHPK3PXP`）可正常出码
     - **barrel 注册链路（本任务是分支 B 下该链路的唯一覆盖点）**：从 `../../../../Index.ets` 导入 `TOTP` 并直接 `new TOTP({...}).generate()`（不注入 provider），证明 `installCryptoDefaults()` 生效。**机械性回退**：若相对路径跨 source set 导入报错，改用 `import { installCryptoDefaults, requireHmac } from '../../../main/ets/internal/CryptoSource'`，调用后断言 `requireHmac()` 可用，并在 evidence 注明「barrel 字面路径不可用，已用等价断言替代」
  2. 改写 `library/src/ohosTest/ets/test/List.test.ets` 注册该套件（T03 已建空壳，此处补真实用例；**本文件在本任务被授权修改**）。
  3. 执行方式：`export PATH="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains:$PATH"` 后 `hdc list targets` 确认设备；优先 CLI（按 T02 记录的设备测试命令），否则在 DevEco 内右键 Run ohosTest。**无设备时**：evidence 必须明确记录「未执行」+ 人工执行步骤，并把本任务标记为**待人工验证**，不得伪报通过。
  **Must NOT do**: 不得用 mock/stub 冒充真实 crypto；不得放宽断言；不得用 `expect(true)` 占位；不得为了迁就环境改源码；不得在无设备时谎报通过。
  **Parallelization**: W6 | Blocked by: T07, T10 | Blocks: T14 | Can parallelize with: T12, T13
  **References**:
  - 设计文档 §3.1（分支 A/B 的可测性缺口）、§3.7
  - 官方 Local Test 限制（「不支持系统 API」→ 必须走设备端）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-local-test
  - 官方 JsUnit/ohosTest 指南：https://gitee.com/openharmony/docs/blob/master/en/application-dev/application-test/unittest-guidelines.md
  - 官方 hvigorw 任务（`onDeviceTest`）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-task-process
  - 向量：本 plan 附录 A；fixture 参考：`library/src/test/vectors/RfcVectors.ets`
  - T02 结论快照（CLI 命令、设备工具路径）：`docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`
  **Acceptance criteria**:
  - `hdc list targets`（使用**绝对路径** `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`）的输出被记录进 evidence；为空则明确写「未执行 + 人工步骤」
  - 有设备时：设备测试命令 exit 0，`cryptoAdapterTest` 全绿且用例数 ≥ 20
  - `grep -n "expect(true)" library/src/ohosTest/ets/test/CryptoAdapter.test.ets` → 无输出
  - `grep -c "it(" library/src/ohosTest/ets/test/CryptoAdapter.test.ets` ≥ 20
  **QA scenarios**:
  - happy: 启动模拟器 → `<T02 设备测试命令>` → 全绿；或 DevEco 内 Run `CryptoAdapter` 套件 → 全绿（把日志摘要粘进 evidence）
  - failure: 临时把 `CryptoFrameworkHmac` 的 `algName` 映射改成固定 `'SHA1'`，确认 SHA256/512 设备用例变红，还原
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-11-device-crypto.md`
  **Commit**: Y | `test(otp): 增加设备端真实 cryptoFramework 的 RFC 向量验证`

- [ ] 12. 发布物料（README / CHANGELOG / LICENSE / 包元信息）
  **What to do**：
  1. `library/oh-package.json5`：核对并最终定稿（T03 已写入）：`name`/`version`/`description`(6–512)/`main`/`author`(**对象**)/`license`(MIT)/`repository`/`keywords`/`dependencies`(空)/`devDependencies`。**不得**添加 `types`/`obfuscated`/`sourceType` 等，除非 T02 判定为字节码 HAR。
  2. `library/README.md`（英文）+ `library/README-cn.md`（中文）必备内容：
     - 顶部**兼容性声明**：`Requires compatibleSdkVersion >= 6.0.0(20)`
     - **必须包含安装命令**（上架硬性要求）：`ohpm install @yansongda/otp`
     - 快速开始代码块（TOTP 生成 + 倒计时 + 校验 + `syncClockOffset`；HOTP 生成）
     - API 表格（对齐设计 §3.2，含默认值列）
     - **RFC 符合性章节**：RFC 4226 §4 R6（secret 长度建议 + `minSecretBits` 默认 0 的原因：存量后端密钥仅 80 bit）、§5.3（6/7/8 位）、RFC 6238 §4.2（>32 位 T）、§5.2/§6（漂移窗口）、§1.2（SHA1 为互操作默认，SHA256/512 可选）；**明确写出「RFC 4226 §7.3 throttling 由校验服务端实现，本库不提供」**
     - **故障排查表**：**16 个对外** `OtpErrorCode` → 现象 → 根因 → 处置（含 `CRYPTO_NOT_INITIALIZED` 专条；`NOT_IMPLEMENTED` 为内部脚手架占位、交付前已清零，不列入）
     - **测试与限制说明**：写清 T02 的分支结论（本地单测覆盖范围；分支 B 下真实 crypto 与 barrel 注册链路由 `ohosTest` 覆盖）
     - **已知限制**：counter ≤ 2^53-1（量化说明）；`otpauth://` 非 RFC 而是 GA 事实标准（IANA Provisional #13829）；未知 query 参数被忽略；**`Secret` 虽实现 `toJSON()` 脱敏，仍不得主动把 secret 交给日志/上报**
     - **不使用 `@security/no-unsafe-mac` 豁免的立场**：引用 RFC 6238 §1.2
  3. `library/CHANGELOG.md`：`## 1.0.0` + 日期 `2026-10-01` + Added/Changed 列表。**必须含 `1.0.0`**。
  4. `library/LICENSE`：MIT 全文，`Copyright (c) 2026 yansongda`。
  5. README 中的「发布前检查清单」（可勾选）：四件套非空、README 含 `ohpm install`、CHANGELOG 含当前版本号、`dependencies` 为空、`ohpm prepublish <har>` 通过、**同版本发布后不可覆盖**。
  **Must NOT do**: 不得写与最终 API 签名不一致的示例（逐条核对）；不得宣称支持 Steam/SHA224/384/SM3/BigInt；不得写未经证实的覆盖率声明；不得改源码；不得执行 `ohpm publish`。
  **Parallelization**: W6 | Blocked by: **T10**（API 冻结后方可定稿） | Blocks: T14 | Can parallelize with: T11, T13
  **References**:
  - 设计文档 §3.2（API 表）、§3.5（17 个错误码）、§3.6（发布字段表）、附录 C（不做清单）
  - OHPM 发布必要文件：https://ohpm.openharmony.cn/#/cn/help/publishrequirefile
  - OHPM 发包规则汇总：https://ohpm.openharmony.cn/#/cn/help/publishrules
  - 同类库 README 结构参照（非内容）：https://gitee.com/lengyf/otplibrary
  - 官方 oh-package.json5 字段说明：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-oh-package-json5
  - T02 分支与产物结论：`docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`
  **Acceptance criteria**:
  - `test -s library/README.md && test -s library/README-cn.md && test -s library/CHANGELOG.md && test -s library/LICENSE` → 通过
  - `grep -c "ohpm install @yansongda/otp" library/README.md` ≥ 1
  - `grep -c "1.0.0" library/CHANGELOG.md` ≥ 1；`grep -c "6.0.0(20)" library/README.md` ≥ 1
  - README 中每个 API 名都能在源码 grep 到：`for n in $(grep -oE '\b(TOTP|HOTP|Secret|OTPAuthURI|OtpError|OtpAlgorithm|OtpType|OtpErrorCode)\b' library/README.md | sort -u); do grep -rq "export .*$n" library/src/main/ets/ library/Index.ets || echo "MISSING $n"; done` → 无 MISSING
  - `grep -cE "^## |^### " library/README.md` ≥ 6
  - README 故障排查表覆盖 16 个**对外**错误码（机器可校验；`NOT_IMPLEMENTED` 为内部脚手架占位，不对外，不要求列入）：`for c in EMPTY_SECRET INVALID_BASE32_CHAR SECRET_TOO_SHORT SECRET_TOO_WEAK INVALID_ALGORITHM INVALID_DIGITS INVALID_PERIOD INVALID_T0 INVALID_COUNTER INVALID_TIMESTAMP INVALID_WINDOW INVALID_TOKEN CRYPTO_FAILED CRYPTO_NOT_INITIALIZED INVALID_OTPAUTH_URI UNSUPPORTED_OTPAUTH_TYPE; do grep -q "$c" library/README.md || echo "MISSING $c"; done` → 无 MISSING
  **QA scenarios**:
  - happy（**分支条件化，按 T02 结论选用**）：**分支 A** —— 把 README 示例改写为「深路径 import 公开类 + 显式 `registerHmac(new CryptoFrameworkHmac())` + `registerRandom(new CryptoFrameworkRandom())`」，落到临时 `library/src/test/Readme.example.test.ets`，临时在 `library/src/test/List.test.ets` 注册（**T12 已被授权**），跑单测确认示例逻辑可跑通，随后删除临时文件与注册并重跑确认无残留；**分支 B** —— **跳过**该动态场景（原因：库模块 `dependencies` 必须为 `{}`，无法自解析 `@yansongda/otp` 包名；而相对路径导入 barrel 会拉入 `CryptoSource` 导致本地套件在模块加载期整体失败），改做下述**静态签名一致性校验**，并将「包名导入可用」的验证责任交给 T11 的 barrel 用例
  - failure: 从 README 删掉 `ohpm install` 一行，确认发布前检查清单第 1 条能发现，随后补回
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-12-release-assets.md`
  **Commit**: Y | `docs(otp): 补齐 README/CHANGELOG/LICENSE 与 HAR 包元信息`

- [ ] 13. 消费方 smoke demo（entry 依赖 library）
  **What to do**：
  1. `entry/oh-package.json5`：`dependencies` 加 `"@yansongda/otp": "file:../library"`；跑一次依赖安装/同步（按 T02 记录的 CLI 或 DevEco sync），确认 `oh_modules/@yansongda/otp` 出现或 `oh-package-lock.json5` 更新。
  2. `entry/src/main/ets/pages/Index.ets`：替换模板为**极简算码 demo**（单文件、无额外组件）：
     - 固定示例 secret `JBSWY3DPEHPK3PXP`（文档公开示例值，非真实密钥），`new TOTP({ secret, period: 30 })`
     - 展示：当前 6 位码、`remaining()` 倒计时（`setInterval` 1s，`aboutToDisappear` 中清理）、`progress()` 进度条
     - try/catch 展示 `OtpError.code` 分支
     - 一个「校验并校准」按钮：对当前码调 `verify(token, {window:1})` 并展示返回的 delta，非 null 时调 `syncClockOffset(delta)`
     - 用 `@State` 驱动，样式沿用模板 `$r('app.float.page_text_font_size')` 风格
  3. 不新增测试文件（UI 不进单测）；不改 `entry/src/test/**`、`entry/src/ohosTest/**`。
  **Must NOT do**: 不得让 `library` 反向依赖 `entry`；不得做成多页面工程；不得引入扫码/相机/网络权限；不得改动 `entry/src/main/module.json5` 的权限；不得使用真实生产密钥；不得掩盖 `entry` 构建的签名报错（只能按授权改 `signingConfig` 行）。
  **Parallelization**: W6 | Blocked by: T10 | Blocks: T14 | Can parallelize with: T11, T12
  **References**:
  - 设计文档 §3.7（失败场景表）
  - 现有 entry 文件：`entry/src/main/ets/pages/Index.ets`、`entry/oh-package.json5`、`entry/src/main/resources/base/element/string.json`、`entry/src/main/resources/base/profile/main_pages.json`
  - `library/Index.ets`（barrel 导出清单）、`library/README.md`（快速开始示例，demo 应与之一致）
  - 依赖写法（本地源码目录 `file:../library`）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-oh-package-json5
  - 旧 UI 的倒计时/竞态坑（只读参考）：`/Users/yansongda/000-Coding/application/huawei/atomicservice/MFA/entry/src/main/ets/models/Runtime.ets:150-166`
  - T02 记录的构建命令与产物路径：`docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`
  **Acceptance criteria**:
  - `grep -c "@yansongda/otp" entry/oh-package.json5` ≥ 1
  - `grep -c "TOTP" entry/src/main/ets/pages/Index.ets` ≥ 1；`grep -c "clearInterval" entry/src/main/ets/pages/Index.ets` ≥ 1（定时器清理）
  - `grep -c "syncClockOffset\|verify" entry/src/main/ets/pages/Index.ets` ≥ 1
  - entry 构建命令 exit 0（T02 记录的 `module=entry@default` + `assembleHap`）；若失败**仅**因空 `signingConfigs` 引起的签名报错，按 Executor rule 1 移除 `build-profile.json5` products 里的 `"signingConfig": "default"` 行后重试并在 evidence 注明（唯一允许的工程级机械性修改）
  - `grep -rn "entry" library/oh-package.json5` → 无输出（无反向依赖）
  **QA scenarios**:
  - happy: entry 构建 exit 0 且输出含 `BUILD SUCCESSFUL`；随后在 DevEco/模拟器手动运行（若可用）确认码每 30s 翻转、倒计时从 30 递减到 1、进度条同步；把观察结果写入 evidence（无设备则写明「待人工验证」）
  - failure: 临时把 `secret` 改成非法值 `'AB1'`，确认 demo 走到 `OtpError.code === 'INVALID_BASE32_CHAR'` 分支而非崩溃，还原
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-13-entry-demo.md`
  **Commit**: Y | `feat(entry): 增加消费 @yansongda/otp 的算码 smoke demo`

### W7

- [ ] 14. 覆盖率、产物检视与交付收尾
  **What to do**：
  1. 跑覆盖率：`<T02 覆盖率命令>`（形如 `hvigorw test -p module=library -p coverage=true`），确认报告生成（用 T02 记录的**实际报告路径**，不要硬编码）；把总覆盖率数值（行/分支）与未覆盖文件清单写进 evidence。目标：`internal/**` + `OtpError`/`OtpOptions`/`Secret`/`OTPAuthURI`/`HOTP`/`TOTP` 覆盖率尽量高；`internal/CryptoSource.ets` 与 `Index.ets`（分支 B）允许低覆盖，但必须列出并说明原因（PC 无系统能力）。
  2. 清零占位：`grep -rn "NOT_IMPLEMENTED" library/src/main/ets/` 必须只剩 `OtpError.ets` 里的**枚举定义**，不得有 `throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED`。
  3. 构建可发布产物：`<T02 构建命令>`（release HAR），记录**产物绝对路径与大小**（用 T02 记录的真实路径）；解包检视内容（对照 T02 的产物类型结论），确认：无 `src/test`、无 `ohosTest`、README/CHANGELOG/LICENSE 在包内。
  4. **本地包结构预检**：`/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm prepublish <产物.har>`（**实测 `ohpm` 无 `pack` 子命令，只有 `prepublish`**），记录输出。**不得 publish**。
  5. 把 T14 的实际结论（覆盖率、产物路径/大小、`prepublish` 结果）填进 evidence，并补齐 `library/README.md` 的「发布前检查清单」为可勾选列表。
  6. 运行 DevEco Code Linter（`code-linter.json5` 只在 IDE 生效）：记录**人工执行步骤**与结果；无法自动执行则标注「待人工」并列出期望结果（`@security/no-unsafe-mac` 仅 warn，其余 `@security/*` 为 error 且应无命中）。
  **Must NOT do**: 不得执行 `ohpm publish`、不得 `git push`/`git remote add`；不得为提升覆盖率写无意义断言；不得删除或放宽任何断言；不得新增 `code-linter.json5` 的 ignore 项。
  **Parallelization**: W7 | Blocked by: T11, T12, T13 | Blocks: F1–F4
  **References**:
  - 设计文档 §3.6（产物与 `prepublish` 要求）、§4 P6、附录 C
  - 官方覆盖率（Local Test coverage 报告）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-local-test
  - 官方 HAR 产物内容清单：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-hvigor-build-har
  - 官方 ohpm publish 校验规则（仅本地自查，**不执行发布**）：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-ohpm-publish
  - T02 结论快照（产物路径、CLI 命令）：`docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`
  **Acceptance criteria**:
  - `grep -rn "throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED" library/src/main/ets/` → 无输出
  - T02 记录的产物路径下存在 `*.har`，且 evidence 记录了绝对路径与大小
  - 解包清单中 `grep -c "src/test\|ohosTest"` → 0
  - `ohpm prepublish <har>` exit 0；evidence 含其原始输出
  - evidence 含覆盖率数值、产物路径/大小、lint 执行状态
  **QA scenarios**:
  - happy: 覆盖率命令 exit 0 且报告存在；`ohpm prepublish` exit 0
  - failure: 从 `library/` 临时删掉 `CHANGELOG.md` 再跑 `ohpm prepublish`，确认**确实报错**（证明校验有效），随后恢复文件并重跑至通过
  - Evidence: `docs/evidence/ohos-otp-lib-rfc/task-14-delivery.md`
  **Commit**: Y | `chore(otp): 完成覆盖率/产物检视/prepublish 与发布前检查清单`

## Final verification wave

> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.

- [ ] F1. Plan compliance audit：逐 todo 对照文件路径/导出符号/错误码默认值；`git status --short` 相较 T01 基线**无新增未跟踪项**（除 evidence/`hvigorw`）；`grep -rn "NOT_IMPLEMENTED" library/src/main/ets/` 只余枚举定义；`grep -rn "throw new Error(" library/src/main/ets/` 一律为 `OtpError`（`OtpError.ets` 内的 `extends Error` 除外）；确认 T02 evidence 中的 CLI 命令与 `git status` 越界判定的实际执行一致。
- [ ] F2. Code quality review：对照设计 §3.2 字段表与 API 表逐条抽查签名与默认值；核对风格（2 空格/分号/单引号/中文注释）；`grep -rn "hilog\|console\.\|padStart\|HMAC|" library/src/main/ets/` 必须全空；`grep -rn "@kit\." library/src/main/ets/ library/Index.ets` **只允许** `internal/CryptoSource.ets`；`grep -rn "TODO\|FIXME\|XXX" library/src/main/ets/` 为空；确认 `Secret` 无返回明文的 `toString`；确认 `verify` 无提前 return（人工读 `OtpEngine.ets`）；确认 `HOTP.ets`/`TOTP.ets`/`Secret.ets`/`OTPAuthURI.ets` 不引用 `CryptoSource`。
- [ ] F3. Real manual QA：完整跑通 `<T02 构建命令>` + `<T02 单测命令>` + `<T02 覆盖率命令>` + `ohpm prepublish`；执行 T13 的 entry demo 人工运行步骤（若设备可用）；执行 DevEco Code Linter 并贴结果；列出所有需要用户提供的真实环境项（模拟器/真机、OHPM 账号与发布密钥 —— 后者仅列出不执行）。
- [ ] F4. Scope fidelity：`git diff --stat` 逐条验证 Must NOT：零第三方依赖（`library/oh-package.json5` 的 `dependencies` 为空对象）、无 UI 符号（`grep -rn "@Component\|@Entry\|build()" library/src/main/ets/` 无输出）、  - `grep -rn "no-unsafe-mac" library/src/ library/Index.ets` → 无输出（**范围必须排除 `library/*.md`**：T12 要求 README 明写「不使用 `@security/no-unsafe-mac` 豁免的立场」，原文含该字面串；lint 豁免只可能出现在源码里）、无非 RFC 能力（`grep -rni "steam\|qrcode\|sm3\|sha224\|sha384\|bigint" library/src/main/ets/` 无输出）、`compatibleSdkVersion` 仍为 `6.0.0(20)`、旧 MFA 仓库 `git -C /Users/yansongda/000-Coding/application status --short` 无本任务产生的改动。

## Commit strategy

每个 todo 独立 commit，conventional commits，中文描述（scope 统一 `otp`/`entry`/`docs`/`chore`）。Wave 内并行任务各自 commit（文件集互斥，无冲突）。

每个 todo 的 commit **包含其 evidence 文件**（`docs/evidence/ohos-otp-lib-rfc/task-NN-*.md`）——证据不入库则 `git status` 的洁净度验收失去意义，也无法从 git 历史回溯判据。

**默认逐 todo commit；执行期用户可随时推翻（如改为全部不 commit、由用户统一审核后提交），以 execute-plan 收到的最新用户指令为准。**

## Success criteria

1. **构建/测试/lint 全绿**：`<T02 构建命令>`、`<T02 单测命令>`、`<T02 覆盖率命令>` 均 exit 0 且失败数 0；`ohpm prepublish` exit 0；DevEco Code Linter 无 error（`@security/no-unsafe-mac` 的 warn 为预期）。
2. **端到端验收**：RFC 4226 Appendix D 的 10 条 + RFC 6238 Appendix B 的 18 条向量，在 `OtpEngine`（注入 fixture）与 `HOTP`/`TOTP`（注入 fixture）全部通过；设备端 `cryptoAdapterTest`（T11）用**真实 cryptoFramework** 覆盖同一批 10+18 向量（无设备时明确标注待人工，**不得伪报**）；`entry` demo 可构建、可运行、码按 30s 翻转。
3. **范围与风格的机械验证**：F1–F4 四项全部 APPROVE；`library` 零第三方依赖、唯一 kit 导入点（`internal/CryptoSource.ets`）、无 UI 符号、无日志、无 `NOT_IMPLEMENTED` 残留。

---

## 附录 A：黄金向量（唯一来源，逐字照抄，禁止自行推导）

> 生成方式：`node v24.20.0` 的 `crypto.createHmac` + 手写动态截断。**RFC 6238 Appendix B 的 18/18 与 RFC 4226 Appendix D 的 10/10 已由本人与 plan-reviewer 各独立复算一次，零错误**。SHA256/SHA512 的 digest 是 RFC 未给出的中间值，由同一脚本产出。

### A.1 seed（RFC 6238 Appendix B 规定：三算法 seed 长度不同）

| 算法 | seed（ASCII 字节串） | 字节数 | bit 数 | 等价 base32 |
|---|---|---|---|---|
| SHA1 | `12345678901234567890` | 20 | 160 | `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ` |
| SHA256 | `12345678901234567890123456789012` | 32 | 256 | `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA` |
| SHA512 | `1234567890123456789012345678901234567890123456789012345678901234` | 64 | 512 | `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA` |

### A.2 RFC 4226 Appendix D（SHA1 / seed 20B / digits=6）

| counter | digest hex | 期望码（6 位） | Truncate 原始值 |
|---|---|---|---|
| 0 | `cc93cf18508d94934c64b65d8ba7667fb7cde4b0` | `755224` | `1284755224` |
| 1 | `75a48a19d4cbe100644e8ac1397eea747a2d33ab` | `287082` | `1094287082` |
| 2 | `0bacb7fa082fef30782211938bc1c5e70416ff44` | `359152` | `137359152` |
| 3 | `66c28227d03a2d5529262ff016a1e6ef76557ece` | `969429` | `1726969429` |
| 4 | `a904c900a64b35909874b33e61c5938a8e15ed1c` | `338314` | `1640338314` |
| 5 | `a37e783d7b7233c083d4f62926c7a25f238d0316` | `254676` | `868254676` |
| 6 | `bc9cd28561042c83f219324d3c607256c03272ae` | `287922` | `1918287922` |
| 7 | `a4fb960c0bc06e1eabb804e5b397cdc4b45596fa` | `162583` | `82162583` |
| 8 | `1b3c89f65e6c9e883012052823443f048b4332db` | `399871` | `673399871` |
| 9 | `1637409809a679dc698207310c8c7fc07290d9e5` | `520489` | `645520489` |

### A.3 RFC 6238 Appendix B（X=30 / T0=0 / **digits=8**）

| T (s) | counter | counterHex | 算法 | digest hex | 期望码（8 位） |
|---|---|---|---|---|---|
| 59 | 1 | `0000000000000001` | SHA1 | `75a48a19d4cbe100644e8ac1397eea747a2d33ab` | `94287082` |
| 59 | 1 | `0000000000000001` | SHA256 | `392514c9dd4165d4709456062c78e04e16e68718515951333bdb8b26caa3053c` | `46119246` |
| 59 | 1 | `0000000000000001` | SHA512 | `6f76f324230cefda1d3f65309a0badb36efce9528ada64967d71e4e9d74c4aa37fe7650f931ab86ddccc2d38962d720ee626a20feb311b485a92e3bb0796df28` | `90693936` |
| 1111111109 | 37037036 | `00000000023523ec` | SHA1 | `278c02e53610f84c40bd9135acd4101012410a14` | `07081804` |
| 1111111109 | 37037036 | `00000000023523ec` | SHA256 | `4eed729864525d771326c6049bc885629fb8813ebb417e5704df02358793f056` | `68084774` |
| 1111111109 | 37037036 | `00000000023523ec` | SHA512 | `b3381250260d6a9e811ae58dfa406705e38c804c97528d5a7ed8ee533331f8c43cc3454911ad1d2761f9380170c0b180a657e3a944c796e05d09f2d1630b7505` | `25091201` |
| 1111111111 | 37037037 | `00000000023523ed` | SHA1 | `b0092b21d048af209da0a1ddd498ade8a79487ed` | `14050471` |
| 1111111111 | 37037037 | `00000000023523ed` | SHA256 | `cb48f7ef5cd98f6d7bfcb31ae7458ff692a015776205de7e1abfff29d6d48a9d` | `67062674` |
| 1111111111 | 37037037 | `00000000023523ed` | SHA512 | `01713ed59e49948a4f0fffb7466baebac66362d90764a5a23df761636e1535c44b635339ec00a789b8ca45cd3d727acd6b995047547f6f68adc6f16a7436c331` | `99943326` |
| 1234567890 | 41152263 | `000000000273ef07` | SHA1 | `907cd1a9116564ecb9d5d1780325f246173fe703` | `89005924` |
| 1234567890 | 41152263 | `000000000273ef07` | SHA256 | `3befb8821caef9df4e05790da0966163f4e38feee7f71fcd289c3de48d3486d9` | `91819424` |
| 1234567890 | 41152263 | `000000000273ef07` | SHA512 | `87d0cfb5d4e968d7d9041a5cf21dd7d460705784004f0244edb98004e6cf9942ace539d621c97dc0fb75f6f10d64af1f09ecae83ea7f1213c7fa187dfaf6b938` | `93441116` |
| 2000000000 | 66666666 | `0000000003f940aa` | SHA1 | `25a326d31fc366244cad054976020c7b56b13d5f` | `69279037` |
| 2000000000 | 66666666 | `0000000003f940aa` | SHA256 | `a4e8eabbe549adfa65408945a9282cb93f394f06c0d4f122260963641bc3abe2` | `90698825` |
| 2000000000 | 66666666 | `0000000003f940aa` | SHA512 | `129baa738cfa1565a24297237bce282671ff6e261754eb7011e1e75bd2555b326313142a1f9fe2f31d9ce6cc95d3b16a0dee56f2492f2f76885702d98bfadc93` | `38618901` |
| 20000000000 | 666666666 | `0000000027bc86aa` | SHA1 | `ab07e97e2c1278769dbcd75783aabde75ed8550a` | `65353130` |
| 20000000000 | 666666666 | `0000000027bc86aa` | SHA256 | `1363cc0ee3557f092e5b55ea3ddb06bcd20f063ce393ccf670059e3ca44941f8` | `77737706` |
| 20000000000 | 666666666 | `0000000027bc86aa` | SHA512 | `562298a02af13e7522127adee3dc6678d53669ca2b7016186968f9a9c14f51d1e7098ba91293a01b5f3bab4207a2af5ce332a45f2c2ff2b9885aa42ff61cb426` | `47863826` |

### A.4 边界 counter（RFC 6238 §4.2「T 必须支持超过 32 位」）

| counter | counterHex | 算法 | digest hex | 6 位码 | 8 位码 |
|---|---|---|---|---|---|
| 4294967296 (2^32) | `0000000100000000` | SHA1 | `7c9fd37f3b71aad82c508f423de075df9a15fbea` | `999456` | `55999456` |
| 4294967296 | `0000000100000000` | SHA256 | `e2a1668e5766bf539f1e796308d494ee098d463aa95d6fd078987d5c9cc89874` | `351443` | `66351443` |
| 4294967296 | `0000000100000000` | SHA512 | `06d77e29a50045fa79fdefc7b53a6daeaa06563a8607332dd9bbe7292bb4d898c9675a3d85f115293c81179bb57d435b010fcb26a7207308a026a9b57768ce5f` | `894678` | `82894678` |
| 4294967297 (2^32+1) | `0000000100000001` | SHA1 | `3203c942196668bb1ec3c6c8610c9ad02f191010` | `108930` | `39108930` |
| 4294967297 | `0000000100000001` | SHA256 | `8d7f17cf14053f1f8b2dd5ce012f3332899627ace62e1e990e068a9e08f2b112` | `447045` | `99447045` |
| 4294967297 | `0000000100000001` | SHA512 | `674f239496a045b341265c7a5be6fd6e3d3d4fbf3a3227600ed3c19e8f04bf14f382d486f9b7dda1e7dfb4e837bdbecd6afb4ed08f5528792b2c603652b90a96` | `375526` | `69375526` |
| 9007199254740991 (2^53-1) | `001fffffffffffff` | SHA1 | `7d8d6dc907ebca15280ec364c9ca7c567c7a3cf2` | `891307` | `41891307` |
| 9007199254740991 | `001fffffffffffff` | SHA256 | `bf01b7ccf0341510011a732a5ad7ad4ab4f23361d88fe285f3df6bff6ab1bcf1` | `822768` | `28822768` |
| 9007199254740991 | `001fffffffffffff` | SHA512 | `8c799dd186a120528c62d2d604c466fe4d9491824234abd9e6cbd8a483639a99b7ca033365a0f8635fee6bdada51da1bf3ed2742983c384b7a6b636a06093d65` | `766412` | `55766412` |

### A.5 counterToBytes 对照表（与 `writeBigUInt64BE` 参考实现逐位一致，已实测）

| counter | 8 字节大端 hex |
|---|---|
| 0 | `0000000000000000` |
| 1 | `0000000000000001` |
| 9 | `0000000000000009` |
| 666666666 | `0000000027bc86aa` |
| 4294967295 (2^32-1) | `00000000ffffffff` |
| 4294967296 (2^32) | `0000000100000000` |
| 4294967297 (2^32+1) | `0000000100000001` |
| 4294967391 | `000000010000005f` |
| 9007199254740991 (2^53-1) | `001fffffffffffff` |

### A.6 其他派生参考值（供 T08/T10 用例使用）

| 场景 | counter 推导 | 期望值 |
|---|---|---|
| SHA256 / digits=8 / counter=0 | `period=60` 时 `floor(59000ms→59s / 60) = 0` | 8 位码 `18920136`（digest `c79f479abc3c567224e3f8c8e46b2631d5b3f319a06a1e472cbdbee3aa479848`） |
| SHA1 / digits=8 / counter=1 | T=59s、period=30 | `94287082` |
| SHA1 / digits=6 / counter=1 | 同上 | `287082` |
| SHA1 / digits=7 / counter=1 | 同上 | `4287082` |
| SHA1 / digits=8 / counter=0 | T<30s | `84755224` |
| SHA1 / digits=7 / counter=0 | 同上 | `4755224` |
| SHA1 / digits=7 / counter=9 | T<300s（counter 9 属早期窗口） | `5520489`（= `645520489 % 10^7`，A.2 counter=9；**供 `DIGITS7_SHA1` 第 3 条用**） |
| SHA1 / digits=6 / counter=2 | 设备时钟慢 30s 场景（`t0=0, period=30, 有效时间 89000ms`） | `359152` |
| SHA1 / digits=6 / counter=0 | `offset=-30000` 且 `generate(59000)` | `755224` |
| SHA1 / digits=8 / counter=1（t0=1s） | `t0=1, period=30, timestampMs=31000` → `floor((31-1)/30)=1` | `94287082` |
| SHA1 / digits=8 / counter=2 | 有效时间 89000ms（t0=0, period=30）→ `floor(89/30)=2` | `37359152`（= `137359152 % 10^8`） |

> ⚠️ T10 的每条断言必须**在同一行内完成推导**（`counter = floor((effectiveMs/1000 - t0)/period)`），并写进 evidence。A.4 表里的 8 位码属于边界 counter（2^32 级），**与 A.6 的小 counter 不要互抄**。
