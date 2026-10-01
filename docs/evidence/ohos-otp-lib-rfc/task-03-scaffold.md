# 2026-10-02 07:25:00

## 1. 任务范围与文件清单

### 新增（32 个）

| 文件 | 说明 |
|---|---|
| `library/src/main/ets/OtpError.ets` | 完整实现：17 个字符串值枚举 + `OtpError extends Error` |
| `library/src/main/ets/OtpOptions.ets` | 完整实现：`OtpAlgorithm`/`OtpType` + 5 个接口（字段照抄设计 §3.2） |
| `library/src/main/ets/internal/Base32.ets` | 骨架（decode/encode，throw NOT_IMPLEMENTED） |
| `library/src/main/ets/internal/Counter.ets` | 骨架（toBytes/isSafeCounter） |
| `library/src/main/ets/internal/Truncate.ets` | 骨架（apply） |
| `library/src/main/ets/internal/Digits.ets` | 骨架（format/isValidDigits） |
| `library/src/main/ets/internal/TimeStep.ets` | 骨架（step/remainingSec/progress/constantTimeEquals） |
| `library/src/main/ets/internal/OtpEngine.ets` | 骨架（EngineParams + generate/verify） |
| `library/src/main/ets/internal/HmacProvider.ets` | **T03 完整实现**：HmacProvider/RandomSource 接口 + 注册表 + `@internal resetForTest()`；零 kit |
| `library/src/main/ets/internal/CryptoSource.ets` | 骨架（**全库唯一 @kit 导入点**；CryptoFrameworkHmac/Random + installCryptoDefaults） |
| `library/src/main/ets/Secret.ets` | 骨架（fromBase32/fromBytes/generate/toBase32/bytes/byteLength/bitLength/toJSON） |
| `library/src/main/ets/HOTP.ets` | 骨架（构造第二参 `provider?: HmacProvider`，`@internal 仅测试注入`） |
| `library/src/main/ets/TOTP.ets` | 骨架（同上 + remaining/progress/syncClockOffset/clockOffsetMs/toURI/fromURI） |
| `library/src/main/ets/OTPAuthURI.ets` | 骨架（parse/build） |
| `library/src/test/{Base32,Counter,Truncate,Digits,TimeStep,Secret,CryptoSource,OtpAuthUri,OtpError,OtpEngine,Hotp,Totp}.test.ets` | 12 个空壳（各 1 条 importSmoke + `// TODO(T<N>)`） |
| `library/src/test/vectors/RfcVectors.ets` | 空占位（常量名与 T09 对齐，无向量数据） |
| `library/src/test/HmacFixture.ets` | 占位（HmacProvider 实现壳，T09 补） |
| `library/src/test/RandomFixture.ets` | 占位（RandomSource 实现壳，**所有权 T08**） |
| `library/src/ohosTest/ets/test/CryptoAdapter.test.ets` | 空壳（1 条 importSmoke + `// TODO(T11)`） |
| `library/README.md` / `README-cn.md` / `CHANGELOG.md`（含 `## 1.0.0`）/ `LICENSE`（MIT，Copyright (c) 2026 yansongda） | 四件套骨架 |
| `docs/evidence/ohos-otp-lib-rfc/task-03-scaffold.md` | 本文件 |

### 修改（4 个）

| 文件 | 说明 |
|---|---|
| `library/Index.ets` | 全量 barrel（13 个公开符号）+ 顶部 import + 立即调用 `installCryptoDefaults()`；不导出任何 internal 符号 |
| `library/src/test/List.test.ets` | 全量注册 12 个套件函数 |
| `library/src/ohosTest/ets/test/List.test.ets` | 注册 `cryptoAdapterTest`（替换 abilityTest） |
| `library/oh-package.json5` | description/author(对象)/repository/keywords/devDependencies(hypium 1.0.25 + hamock 1.0.0)；dependencies 保持 `{}` |

### 删除（3 个）

| 文件 | 说明 |
|---|---|
| `library/src/main/ets/components/MainPage.ets` | 占位 UI 组件（删除后库内无任何 UI 符号） |
| `library/src/test/LocalUnit.test.ets` | 模板测试（被 List.test.ets 全量注册替代） |
| `library/src/ohosTest/ets/test/Ability.test.ets` | 模板死文件（含 hilog 导入，与「库内零日志」约束相冲；T03 唯一授权处置） |

## 2. Acceptance 逐条验证（命令 + 真实输出）

### AC1 `grep -rn "@kit\." library/src/main/ets/ library/Index.ets` → 只含 CryptoSource.ets

```
$ grep -rn "@kit\." library/src/main/ets/ library/Index.ets
library/src/main/ets/internal/CryptoSource.ets:4: * ⚠️ 本文件是**全库唯一允许** `import { cryptoFramework } from '@kit.CryptoArchitectureKit'`
library/src/main/ets/internal/CryptoSource.ets:10:import { cryptoFramework } from '@kit.CryptoArchitectureKit';
```
✓ 输出只含 `library/src/main/ets/internal/CryptoSource.ets`（注释行与 import 行均在该文件内）。

### AC2 `grep -rn "CryptoSource" ...公开类...` → 无输出

```
$ grep -rn "CryptoSource" library/src/main/ets/Secret.ets library/src/main/ets/HOTP.ets library/src/main/ets/TOTP.ets library/src/main/ets/OTPAuthURI.ets library/src/main/ets/internal/OtpEngine.ets
（无输出，exit 1）
```
✓ 无输出（首轮实现时文件头注释含 "CryptoSource" 字样被命中，已改写注释措辞——见 §5 偏差 4）。

### AC3 `grep -n "HmacProvider\|RandomSource\|OtpEngine" library/Index.ets` → 不在 export 里

```
$ grep -n "HmacProvider\|RandomSource\|OtpEngine" library/Index.ets
（无输出，exit 1）
```
✓ 无输出（首轮实现时文件头注释含这些字样，已删除——见 §5 偏差 4）。

### AC4 `grep -c "throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED" ...` 合计 ≥ 12

```
internal/Base32.ets:2  internal/Counter.ets:2  internal/CryptoSource.ets:3
internal/Digits.ets:2  internal/HmacProvider.ets:0  internal/OtpEngine.ets:2
internal/TimeStep.ets:4  internal/Truncate.ets:1  HOTP.ets:5  OTPAuthURI.ets:2
OtpError.ets:0  OtpOptions.ets:0  Secret.ets:8  TOTP.ets:9
TOTAL=40
```
✓ 合计 40 ≥ 12。

### AC5 `NOT_IMPLEMENTED`/`resetForTest` 于 HmacProvider.ets

```
$ grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/HmacProvider.ets
0
$ grep -c "resetForTest" library/src/main/ets/internal/HmacProvider.ets
1
```
✓ 无 NOT_IMPLEMENTED 字样（无 throw）；resetForTest ≥ 1。

### AC6 `ls library/src/ohosTest/ets/test/Ability.test.ets`

```
ls: library/src/ohosTest/ets/test/Ability.test.ets: No such file or directory
```
✓ 已删除。

### AC7 四件套非空

```
$ test -s library/README.md && test -s library/README-cn.md && test -s library/CHANGELOG.md && test -s library/LICENSE && echo PASS
PASS
```
✓（CHANGELOG 含 `## 1.0.0` 行；LICENSE 为 MIT 全文，Copyright (c) 2026 yansongda）

### AC8 `ls .../components/MainPage.ets .../LocalUnit.test.ets`

```
ls: library/src/main/ets/components/MainPage.ets: No such file or directory
ls: library/src/test/LocalUnit.test.ets: No such file or directory
```
✓ 两个均不存在（components/ 空目录已 rmdir）。

### AC9 构建命令（T02 版）exit 0 且含 BUILD SUCCESSFUL

命令：`/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --no-daemon -c modelVersion=6.1.1 assembleHar --mode module -p module=library@default -p product=default -p buildMode=release`

原始输出（`/tmp/final_build.log` 尾部，完整输出 30 行含全部 task 行）：

```
> hvigor Finished :library:default@HarCompileArkTS... after 1 s 14 ms
> hvigor Finished :library:default@ProcessHarArtifacts... after 10 ms
> hvigor WARN: If obfuscation is needed, enable obfuscation settings in this build process; failing to do so may prevent future obfuscation.
> hvigor Finished :library:default@PackageHar... after 6 ms
> hvigor WARN: Will skip sign 'har'. No signingConfigs profile is configured in current project.
> hvigor Finished :library:default@PackageSignHar... after 1 ms
> hvigor Finished :library:default@PackingCheckHar... after 1 ms
> hvigor Finished :library:default@CollectDebugSymbol... after 1 ms
> hvigor Finished :library:assembleHar... after 1 ms
> hvigor BUILD SUCCESSFUL in 2 s 39 ms
BUILD_EXIT=0
```
✓ exit 0 且含 `BUILD SUCCESSFUL`。

### AC10 本地单测（T02 版）exit 0、12 套件名全出现、失败数 0

命令：`/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local`

`library/.test/default/intermediates/test/coverage_data/test_result.txt` 原文（全文）：

```
class=base32Test
test=importSmoke
result=Success
class=counterTest
result=Success
class=truncateTest
result=Success
class=digitsTest
result=Success
class=timeStepTest
result=Success
class=secretTest
result=Success
class=cryptoSourceTest
result=Success
class=otpAuthUriTest
result=Success
class=otpErrorTest
result=Success
class=otpEngineTest
result=Success
class=hotpTest
result=Success
class=totpTest
result=Success
Tests run: 12, Failure: 0, Error: 0, Pass: 12, Ignore: 0
```
✓ 12 个套件名（base32Test/counterTest/truncateTest/digitsTest/timeStepTest/secretTest/cryptoSourceTest/otpAuthUriTest/otpErrorTest/otpEngineTest/hotpTest/totpTest）全部出现；`Tests run: 12, Failure: 0`；TEST_EXIT=0（`/tmp/final_test.log` 尾部：`BUILD SUCCESSFUL in 2 s 742 ms`）。

## 3. QA failure 场景实测

### 场景 1：临时移除 `Index.ets` 的 `installCryptoDefaults()` 调用 → 本地单测仍全绿

操作：`sed -i '' 's/^installCryptoDefaults();$/\/\/ QA场景1: 临时移除 installCryptoDefaults() 调用/' library/Index.ets`（import 保留，仅删调用）。

结果（`/tmp/qa1.log` 尾部 + test_result.txt）：

```
TEST_EXIT=0
Tests run: 12, Failure: 0, Error: 0, Pass: 12, Ignore: 0
```
✓ 分支 B 下测试走深路径、模块图内无 barrel，移除调用不影响本地单测（与 T02 分支 B 结论一致）。随后 `cp /tmp/Index.ets.bak library/Index.ets` 还原，并确认 `grep -n "installCryptoDefaults();" library/Index.ets` → `13:installCryptoDefaults();`。

### 场景 2：临时给 `HmacProvider.ets` 加 kit import → 验收 grep 失败（证明 grep 有效）

操作：`sed -i '' '2i\ import ...'` 在 `library/src/main/ets/internal/HmacProvider.ets` 第 2 行插入 `import { cryptoFramework } from '@kit.CryptoArchitectureKit';`。

结果：验收 grep 命中（**证明 AC1 的 grep 真实有效**）：

```
$ grep -rn "@kit\." library/src/main/ets/ library/Index.ets
library/src/main/ets/internal/CryptoSource.ets:4: ...
library/src/main/ets/internal/CryptoSource.ets:10:import { cryptoFramework } from '@kit.CryptoArchitectureKit';
library/src/main/ets/internal/HmacProvider.ets:2:import { cryptoFramework } from '@kit.CryptoArchitectureKit';
```
✓ HmacProvider.ets 被命中 → AC1 必失败。同时本地单测仍 `Tests run: 12, Failure: 0, Pass: 12`（exit 0）——与 T02 探针「import kit 本身在本地不失败，值导入只是真实加载」一致。随后 `cp /tmp/HmacProvider.ets.bak ...` 还原，并重跑单测+构建至双绿（见 §2 AC9/AC10 的最终输出）。

## 4. 构建/单测原始输出存档

- 构建：`/tmp/final_build.log`（BUILD SUCCESSFUL in 2 s 39 ms，BUILD_EXIT=0）
- 单测：`/tmp/final_test.log`（BUILD SUCCESSFUL in 2 s 742 ms，TEST_EXIT=0）
- 用例级结果：`library/.test/default/intermediates/test/coverage_data/test_result.txt`（见 AC10 全文）
- QA1：`/tmp/qa1.log`；QA2：`/tmp/qa2.log`

## 5. 发现的偏差与处置（全部为机械性修正，无设计性偏差）

1. **根 `oh-package.json5` 的 modelVersion 不再自动迁移（环境状态变化，机械性修正）**。T02 记录「带 `-c modelVersion=6.1.1` 跑实际任务会把根 oh-package.json5 从 6.0.0 迁移写回 6.1.1」；本次实测该自动迁移**不再发生**——`-c` 只覆盖 hvigor-config.json5，检查 `hvigor-config(6.1.1) vs oh-package(6.0.0)` 恒失败 00303027（exit 255），`tasks` 只读命令同样失败。佐证：`.hvigor/report/` 显示 03:31/03:52 已有两次同样的 00303027 失败（非本 worker 产生，早于本任务开始）。**处置**：每次构建/单测前临时 `sed -i '' 's/"modelVersion": "6.0.0"/"modelVersion": "6.1.1"/' oh-package.json5`，完成后 `cp /tmp/oh-package.json5.bak oh-package.json5` 还原（与编排方「不提交迁移、构建后清理」裁决一致；提交前 `git status` 已确认根 oh-package.json5 无改动）。**建议写入 learning 供后续任务继承**。
2. **`HarCompileArkTS` 增量编译缓存损坏导致构建卡死（环境问题，机械性处置）**。04:41 一次失败构建（misplaced imports）后，`library/build/default/cache/default/default@HarCompileArkTS` 缓存进入损坏状态：后续 assembleHar 卡在 `HarCompileArkTS` 任务无任何输出、不写 report、无进程残留（等待 240s+ 无果），`tasks` 却正常。**处置**：`rm -rf library/build/default/cache/default/default@HarCompileArkTS` 后构建恢复 2 s 完成（此后多次构建/单测均稳定）。**后续任务遇构建卡死先清该缓存**。
3. **ArkTS `import` 必须位于文件顶部（编译错误 10605150 arkts-no-misplaced-imports）**。首版 `Index.ets` 把 `import { installCryptoDefaults }` 放在 export 语句之后，报 `"import" statements after other statements are not allowed`。**处置**：改为 import → 调用 → export 顺序，编译通过。属 ArkTS 语法约束，非设计偏差。
4. **验收 grep 严格性：源码注释也不得含 `CryptoSource`/`HmacProvider`/`@kit.CryptoArchitectureKit` 等字样**。首版在 `Secret/HOTP/TOTP.ets` 注释写「禁止 import internal/CryptoSource」、`Index.ets` 注释写「@kit.CryptoArchitectureKit」与「HmacProvider/RandomSource/OtpEngine」，均被 AC1/AC2/AC3 的 grep 命中。**处置**：改写注释措辞（「禁止 import kit（kit-free）」「internal/* 一律不对外导出」），grep 清零。属机械性文字修正。
5. **macOS 无 GNU `timeout` 命令**。改用「后台启动 + `kill -0` 轮询 + 超时 pkill」实现软超时；hvigor 命令被 kill 后须 `pkill -9 -f hvigor` 并 `rmdir /tmp/ohos-otp-hvigor.lock`。
6. 顺带记录：`library/oh-package.json5` 新增 devDependencies 后**无需** `ohpm install`——根 `oh_modules` 已含 hypium/hamock（根 oh-package.json5 的 devDependencies 与之同版本），构建直接解析成功。

## 6. 越界检查

- 未改动：`entry/**`、`build-profile.json5`、`code-linter.json5`、`hvigor/hvigor-config.json5`（git status 无其改动）、`.gitignore`。
- 未 push / 未动 remote；未引入任何依赖（`dependencies` 保持 `{}`）。
- 构建产物（`library/build`、`library/.test`、`library/.hvigor`、`library/BuildProfile.ets`）均已清理或由 .gitignore 覆盖；提交前 `git status --short` 只剩本任务文件。

# 2026-10-02 07:28:40

## 编排方（main agent）亲自验证

逐条实跑 T03 全部 10 条 Acceptance（不采信 worker 报告）：

```bash
grep -rn "@kit\." library/src/main/ets/ library/Index.ets
# → 仅 library/src/main/ets/internal/CryptoSource.ets（注释行 4 + import 行 10）            AC1 ✓
grep -rn "CryptoSource" .../Secret.ets .../HOTP.ets .../TOTP.ets .../OTPAuthURI.ets .../OtpEngine.ets
# → 无输出                                                                                  AC2 ✓
grep -n "HmacProvider\|RandomSource\|OtpEngine" library/Index.ets
# → 无输出（比要求更严：连 import 上下文也无这些标识符）                                      AC3 ✓
grep -c "throw new OtpError(OtpErrorCode.NOT_IMPLEMENTED" library/src/main/ets/internal/*.ets library/src/main/ets/*.ets
# → 合计 40（Base32 2 / Counter 2 / CryptoSource 3 / Digits 2 / OtpEngine 2 / TimeStep 4 / Truncate 1
#     / HOTP 5 / OTPAuthURI 2 / Secret 8 / TOTP 9；HmacProvider 0 / OtpError 0 / OtpOptions 0） ≥12  AC4 ✓
grep -c "NOT_IMPLEMENTED" .../internal/HmacProvider.ets   # → 0（允许：只有枚举定义行）        AC5 ✓
grep -c "resetForTest"    .../internal/HmacProvider.ets   # → 1                              AC5 ✓
ls library/src/ohosTest/ets/test/Ability.test.ets library/src/main/ets/components/MainPage.ets library/src/test/LocalUnit.test.ets
# → 三个 No such file or directory                                                          AC6/AC8 ✓
test -s library/README.md && ... README-cn.md CHANGELOG.md LICENSE   # → 四件套非空            AC7 ✓
grep "^class=" library/.test/.../test_result.txt   # → 12 个套件名与计划步骤 6 清单逐一对应    AC10 ✓
git status --short                                 # → 空（提交后无残留）                    越界 ✓
git show --stat 4264459                            # → 43 文件，含 3 删除，无越界文件
```

**AC9/AC10 由编排方在隔离副本中独立复跑**（避免改动仓库任何文件）：`rsync -a`（排除 `.git`/`build`/`.test`/`.hvigor`）到 `/tmp/t03-verify`，`sed` 把副本的 `oh-package.json5` modelVersion 改 6.1.1 后：
- `hvigorw --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local` → `TEST_EXIT=0`、`BUILD SUCCESSFUL in 27 s 628 ms`、`Tests run: 12, Failure: 0, Error: 0, Pass: 12, Ignore: 0`（**冷缓存全新副本可复现，非增量残留**）
- `hvigorw --no-daemon -c modelVersion=6.1.1 assembleHar --mode module -p module=library@default -p product=default -p buildMode=release` → `BUILD_EXIT=0`、`BUILD SUCCESSFUL in 2 s 99 ms`、产物 `library.har`（10 770 B）
- 仓库本体 `git status --short` 全程为空，`oh-package.json5` 未被改动 ✓

### 内容级审查（code review，非仅 --stat）
- `OtpError.ets`：17 个字符串枚举成员与设计 §3.5 逐字一致；`class OtpError extends Error` + `readonly code`，无用户输入拼进消息 ✓
- `OtpOptions.ets`：`HmacOptions`/`TotpOptions`/`HotpOptions`/`VerifyOptions`/`OtpAuthParams` 字段名、可选性、顺序与设计 §3.2 字段表**逐字一致** ✓
- `internal/HmacProvider.ets`：两接口 + 四函数 + `resetForTest()`；未注册抛 `CRYPTO_NOT_INITIALIZED`；无任何 kit 导入；模块级单例 ✓
- `Index.ets`：只导出 13 个公开符号，internal 符号零导出；`import` 在最顶部（ArkTS 语法要求）→ 调用 → export ✓
- `library/oh-package.json5`：`author` 为对象、description 长度合规、keywords 10 项、`dependencies: {}` 未变 ✓
- 已删除 3 个模板文件（MainPage/LocalUnit.test/Ability.test），库内不再有 UI 符号与 hilog ✓

### 采纳的机械性偏差（worker 报告 6 条，我逐条复核后采纳）
1. **根 `oh-package.json5` 的 modelVersion 自动迁移失效**（`00303027`，与 T02 结论不同，属环境变化）：后续统一流程改为「构建前临时 sed 成 6.1.1 → 构建 → 还原」，仓库本体始终保持 6.0.0 不变。**该调整写入 learning**。
2. `HarCompileArkTS` 增量缓存损坏会卡死构建 → `rm -rf library/build/default/cache/default/default@HarCompileArkTS` 恢复。
3. ArkTS 要求 `import` 必须在文件顶部（`arkts-no-misplaced-imports`）。
4. 注释里出现 `CryptoSource`/`@kit.*` 字样会被验收 grep 命中 → 措辞改写（合理：grep 就是用来锁死导入边界的）。
5. macOS 无 GNU `timeout`，用 `kill -0` 轮询实现软超时。
6. `library/oh-package.json5` 加 devDependencies 后无需 `ohpm install`（根 `oh_modules` 已有同版本）。
7. 遗留待交接：`CryptoSource.installCryptoDefaults()` 目前是 `NOT_IMPLEMENTED` 占位（T03 允许），由 T07 补「只 new + 注册」实现——**已写入 T07 派发 prompt**；`Secret.generate(byteLength = 20)` 的形参名与设计 §3.2 的 `bytes` 不同，**已要求 T08 改回 `bytes`**。
