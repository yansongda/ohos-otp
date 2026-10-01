# 2026-10-02 01:22:04

## 1. CLI 调用方式（hvigorw 绝对路径 + 环境变量 + modelVersion 运行时覆盖）

**前置结论**：仓库根无 `hvigorw`，但**无需复制** `hvigorw`/`hvigorw.bat` 到仓库根——直接用 DevEco 自带绝对路径即可跑通全部三种用途。唯一工程级障碍是 `oh-package.json5` 的 `modelVersion: "6.0.0"` 与 `hvigor/hvigor-config.json5` 的 `"6.1.1"` 不一致（基线自带，非本任务引入），需用 `-c modelVersion=6.1.1` 做**运行时覆盖**（详见下方「写回副作用」）。

**环境前缀（每次 CLI 调用前必须设置）**：

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
```

> `DEVECO_SDK_HOME` 必须指向 `.../Contents/sdk`（含 `default/sdk-pkg.json` 的**父层**），指向 `.../sdk/default` 或 `.../sdk/default/openharmony` 均报 `00303312 Cannot find the corresponding SDK version`。已用 hos-sdkmanager-common 的 API 直接验证三个候选路径（`Contents/sdk` 扫描到 OPENHARMONY 组件 `ets,js,native,previewer,toolchains`，另两个返回空）。

**构建 HAR（debug 与 release 均验证）**：

```bash
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --no-daemon -c modelVersion=6.1.1 assembleHar --mode module -p module=library@default -p product=default -p buildMode=release
```

原始输出（release）：

```
> hvigor WARN: If obfuscation is needed, enable obfuscation settings in this build process; failing to do so may prevent future obfuscation.
> hvigor WARN: Will skip sign 'har'. No signingConfigs profile is configured in current project.
> hvigor BUILD SUCCESSFUL in 2 s 144 ms
```

**本地单测**：

```bash
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
```

原始输出（尾部）：

```
> hvigor Finished :library:default@GenerateUnitTestResult... after 1 s 143 ms
> hvigor Finished :library:test... after 1 ms
> hvigor BUILD SUCCESSFUL in 3 s 180 ms
```

**覆盖率**（test 任务默认即产出覆盖率报告；显式 `-p coverage=true` 亦可用）：

```bash
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local -p coverage=true
```

原始输出：`> hvigor BUILD SUCCESSFUL in 2 s 188 ms`；报告路径 `library/.test/default/outputs/test/reports/`（`index.html` + `coverageReport.json`）。

**`-c modelVersion=6.1.1` 的写回副作用（重要坑，已实测）**：
- `hvigorw -c modelVersion=6.1.1 tasks`（只读任务）不写盘（`hvigor-config.json5` md5 前后均为 `a1c1947d6f77c7e0eacaf7d35c78ff78`）。
- 但带 `-c` 跑**实际构建任务**（`assembleHar`/`test`）时，hvigor 会把 `oh-package.json5` 的 `modelVersion` 从 `6.0.0` 迁移写回为 `6.1.1`（DevEco IDE Migrate Assistant 的同一迁移），并删除 `hvigor/hvigor-config.json5` 末尾换行；同时 release 构建会在 `library/` 根生成 `BuildProfile.ets`（不被 `.gitignore` 覆盖）。
- 不带 `-c` 直接跑：`00303027 Configuration Error`，exit 255，**不会**自动迁移、不写任何文件。
- 本任务已用 `git checkout -- hvigor/hvigor-config.json5 oh-package.json5` + `rm library/BuildProfile.ets` 还原（见第 7 节）。
- **建议**：后续任务命令模板统一带 `-c modelVersion=6.1.1`，并在构建后还原这三个文件；是否将 modelVersion 迁移作为工程配置改动一次性提交，请编排方裁决（属机械性修正而非设计变更）。

## 2. Local Test 能否在 PC 跑

临时文件 `library/src/test/Task02Spike.test.ets`（1 条 `expect(1).assertEqual(1)`）+ 临时注册进 `library/src/test/List.test.ets` 后，跑：

```bash
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
```

原始输出（尾部）：

```
> hvigor Finished :library:default@UnitTestArkTS... after 1 s 148 ms
> hvigor Darwin
[2026-10-02T00:08:59.577] [INFO] default - Finished write html report
> hvigor Finished :library:default@GenerateUnitTestResult... after 1 s 143 ms
> hvigor Finished :library:test... after 1 ms
> hvigor BUILD SUCCESSFUL in 3 s 180 ms
```

exit code = **0**。用例级结果文件 `library/.test/default/intermediates/test/coverage_data/test_result.txt` 原文：

```
class=localUnitTest
test=assertContain
result=Success
class=task02SpikeTest
test=basicAssert
result=Success
Tests run: 2, Failure: 0, Error: 0, Pass: 2, Ignore: 0
```

**结论：Local Test 在 PC 上可跑、用例真实执行、exit 0**。本仓库 entry 用 `$profile:main_pages`（`library/.test/.../main_pages.json` 实测生成），未出现旧工程 `pages: $profile:pages` 导致的 `00304022` exit 255。测试进程为 PC 本地 Simulator（`RichPreviewer`），`coverage.log` 中的 `connect socket failed`/`command pipe connect failed` 为预览器调试管道噪音，不影响测试执行与结果。

## 3. Local Test 能否加载并调用系统 kit（分支判定）

临时文件三步逐一实测，每步单独跑一次单测命令（同第 2 节命令）。

**步骤①：仅顶层 import**

```ets
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
```

`test_result.txt` 原文：

```
class=task02SpikeTest
test=step1_importKitOnly
result=Success
Tests run: 2, Failure: 0, Error: 0, Pass: 2, Ignore: 0
```

exit 0，BUILD SUCCESSFUL。**import 成功**。

**步骤②：构造对象**

```ets
let mac = cryptoFramework.createMac('SHA1');
let keyGen = cryptoFramework.createSymKeyGenerator('HMAC');
```

`test_result.txt` 原文：

```
class=task02SpikeTest
test=step2_createMacAndKeyGen
result=Success
Tests run: 2, Failure: 0, Error: 0, Pass: 2, Ignore: 0
```

exit 0，BUILD SUCCESSFUL。**构造成功、不抛异常**。

**步骤③：完整 HMAC-SHA1 并对 RFC 4226 向量**

key = ASCII `12345678901234567890`，message = 8 字节大端 counter=1，期望 digest `75a48a19d4cbe100644e8ac1397eea747a2d33ab`（附录 A，另经 node `crypto.createHmac('sha1')` 独立验证一致）。用 `*Sync` 链路：`convertKeySync({data}) → initSync(key) → updateSync({data}) → doFinalSync()`，hex 比对：

```
> hvigor ERROR: Error in step3_fullHmacSha1, expect  equals 75a48a19d4cbe100644e8ac1397eea747a2d33ab
result=Failure
Tests run: 2, Failure: 1, Error: 0, Pass: 1, Ignore: 0
```

覆盖率日志中的实际 digest（`coverage.log`）：

```
10-02 00:10:55.926 85926 2988188 I A03d00/JSAPP: T02_SPIKE step3 hex=[] len=0
```

**doFinalSync() 调用不抛异常，但返回空 DataBlob（len=0）**。为排除 `*Sync` 特例，用 async（Promise）API 交叉验证同一计算（`convertKey → init → update → doFinal`）：

```
10-02 00:11:47.681 86219 2990531 I A03d00/JSAPP: T02_SPIKE step3b async hex=[] len=0
result=Failure
```

**async API 同样返回空 digest**。即：kit 可 import、可构造、调用链不抛异常，但 crypto 计算在 Local Test 环境**不真正执行**（返回空数据），属判定标准中的「能 import 但调用失败」中间态。

**结论：分支 B**

## 4. `*Sync` 接口可用性

**编译**：步骤③的 `convertKeySync`/`initSync`/`updateSync`/`doFinalSync` 全链路代码编译通过（`UnitTestArkTS` 零 ERROR），即 ArkTS 编译器接受这些签名。

**运行**：分支 B 下调用不抛异常但返回空数据（见第 3 节，`hex=[] len=0`，`*Sync` 与 async 两形态一致）——本地测试环境 crypto 计算不可用，运行期正确性须由 `ohosTest` 设备用例覆盖。

**SDK 声明文件权威行号**（`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/api/@ohos.security.cryptoFramework.d.ts`，`grep -n` 实测）：

```
1332:        generateRandomSync(len: number): DataBlob;
2006:        convertKeySync(key: DataBlob): SymKey;
2304:        initSync(key: SymKey): void;
2398:        updateSync(input: DataBlob): void;
2475:        doFinalSync(): DataBlob;
```

## 5. `assembleHar` 产物类型与路径

**产物绝对路径**（debug 与 release 共用，后者覆盖前者）：

```
/Users/yansongda/000-Coding/ohos-otp/library/build/default/outputs/default/library.har
```

**大小**：release 构建后 `ls -la` → `3863` 字节（首次 debug 构建为 5159 字节，被 release 覆盖）。

**格式**：`file` 实测为 `gzip compressed data, original size modulo 2^32 19456`——HAR 是 **gzip(tar)** 结构（非 zip），需 `gunzip -c | tar -tf` 检视。

**解包内容清单（共 18 条目，全部列出）**：

```
package/Index.d.ets
package/ResourceTable.txt
package/ets/
package/libs/
package/obfuscation.txt
package/oh-package.json5
package/src/
package/ets/modules.abc
package/src/main/
package/src/main/ets/
package/src/main/module.json
package/src/main/resources/
package/src/main/ets/components/
package/src/main/resources/base/
package/src/main/ets/components/MainPage.d.ets
package/src/main/resources/base/element/
package/src/main/resources/base/element/float.json
package/src/main/resources/base/element/string.json
```

**类型判定：字节码 HAR**。包内无源码 `.ets`（`MainPage.ets` 只以声明形态 `MainPage.d.ets` 存在），核心是 `package/ets/modules.abc`（ArkTS 编译字节码）。包内 `oh-package.json5` 原文（关键字段）：

```json
{"name":"@yansongda/otp","version":"1.0.0","description":"Please describe the basic information.","author":"","license":"MIT","dependencies":{},"types":"Index.d.ets","artifactType":"obfuscation","metadata":{"byteCodeHar":true,"sourceRoots":["./src/main"],"debug":false,"dependencyPkgVersion":{},"declarationEntry":[],"useNormalizedOHMUrl":true},"compatibleSdkVersion":20,"compatibleSdkType":"HarmonyOS","obfuscated":false}
```

**对后续任务的含义**：`byteCodeHar: true`、`types: "Index.d.ets"` 由构建自动生成并写入包内，无需手工补 `types`；工程侧 `library/oh-package.json5` 是否需要显式 `types` 字段由 T12 按本结论决策（设计文档 §3.6 的「推断未实测」项已闭环为字节码 HAR）。

## 6. ArkTS 语言特性探针（6 条逐条结论）

临时测试文件内分用例实测，全部通过时 `Tests run: 6, Failure: 0, Error: 0, Pass: 6`；type-only import 单独一轮 + 值导入对照轮。逐条：

1. **`class E extends Error {}` 的 instanceof**：**可用**。`new ProbeError('x') instanceof ProbeError` → true；`instanceof Error` → true（`probe1_extendError` Success）。
2. **字符串值枚举**：**可用**。`enum ProbeEnum { A = 'A' }` 编译通过，`String(ProbeEnum.A) === 'A'` 断言通过（`probe2_stringEnum` Success）。
3. **class getter**：**可用**。`class ProbeGetter { private _v = 1; get v(): number { return this._v; } }` 编译通过，`g.v === 1`（`probe3_getter` Success）。
4. **`JSON.stringify` 是否调用 `toJSON`**：**会调用**。带 `toJSON(): string { return 'REDACTED'; }` 的对象，`JSON.stringify({ s: obj })` 原始输出（coverage.log）：
   ```
   10-02 00:12:22.147 86431 2992307 I A03d00/JSAPP: T02_SPIKE probe4 json=[{"s":"REDACTED"}]
   ```
   `Secret.toJSON()` 脱敏方案在本地测试可验证（`probe4_toJSON` Success）。
5. **type-only import 是否导致模块加载**：**不加载**（被擦除）。负例模块 `TopLevelThrow.ets` 顶层 `throw new Error('T02_SPIKE_TOP_LEVEL_THROW_LOADED')`：
   - `import type { TopLevelThrowMarker } from './TopLevelThrow'`（仅类型标注）→ 套件正常通过（`probe5_typeOnlyImport` Success），异常未触发；
   - **对照**：改值导入 `import { TOP_LEVEL_MARKER } from './TopLevelThrow'` → `coverage.log` 出现 `Throw error: T02_SPIKE_TOP_LEVEL_THROW_LOADED` / `uncaught exception`，测试进程挂起（命令超时，已 kill）——**值导入会加载模块并触发顶层异常**，证实「静态且传递」的导入语义与分支判定一致。
6. **`encodeURIComponent`/`decodeURIComponent`**：**可用**。`encodeURIComponent('issuer:account') === 'issuer%3Aaccount'`、`encodeURIComponent('a b') === 'a%20b'`、双向 decode 还原均断言通过（`probe6_encodeURIComponent` Success）。

## 7. 清理与基线核对

- 删除临时文件：`rm -f library/src/test/Task02Spike.test.ets library/src/test/TopLevelThrow.ets`。
- 还原 `library/src/test/List.test.ets` 为基线内容（`git checkout -- library/src/test/List.test.ets`，内容与基线一致：仅注册 `localUnitTest`）。
- 还原 hvigor 写回：`git checkout -- hvigor/hvigor-config.json5 oh-package.json5`；删除构建生成物 `rm -f library/BuildProfile.ets`。
- 构建产物目录（`library/build`、`library/.test`、`library/.hvigor`）已被 `.gitignore` 覆盖，不出现于 git status。

`git status --short` 最终输出：

```
 M docs/implementation/ohos-otp-lib-rfc.md
 M docs/learning/ohos-otp-lib-rfc.md
```

仅剩编排方维护的两个已跟踪文件改动，相较基线 `0a5d04c` **无新增未跟踪项**（本 evidence 文件提交前不计）。

**遗留注意点（供后续任务）**：① 每次 CLI 构建须带 `-c modelVersion=6.1.1`，构建后如 git status 出现 `oh-package.json5`/`hvigor-config.json5` 改动与 `library/BuildProfile.ets`，按第 1 节建议处理；② `library/BuildProfile.ets` 未被 `.gitignore` 覆盖，release 构建必生成，建议编排方裁决是否纳入忽略或提交迁移。

# 2026-10-02 01:50:12

## 编排方（main agent）亲自验证

逐条实跑 T02 Acceptance（不采信 worker 报告）：

```bash
test -f docs/evidence/ohos-otp-lib-rfc/task-02-spike.md && wc -l ...   # → 250 行            （AC1 ✓ ≥60）
grep -c '^## ' docs/evidence/ohos-otp-lib-rfc/task-02-spike.md        # → 7                 （AC2 ✓ ≥6）
grep -cE '结论：分支 [AB]' ...                                          # → 1（第 156 行 分支 B）（AC3 ✓）
grep -n '结论：分支' docs/evidence/.../task-02-spike.md                 # → 156:结论：分支 B
ls library/src/test/Task02Spike.test.ets                               # → No such file      （AC5 ✓）
git status --short                                                     # → 仅编排方维护的两处 M（AC6 ✓）
git log --oneline                                                      # → 428a585 / 0a5d04c
git show --stat --oneline 428a585                                      # → evidence 250 + learning 29，未夹带临时文件
cat library/src/test/List.test.ets                                     # → 与基线一致（仅注册 localUnitTest）✓ 已还原
cat library/oh-package.json5                                           # → modelVersion 6.0.0 原样，未提交 hvigor 迁移 ✓
ls library/BuildProfile.ets                                            # → No such file（构建生成物已删除）✓
cat library/.test/default/intermediates/test/coverage_data/test_result.txt  # → Tests run: 2 … Pass: 2
```

- **分支结论复核**：worker 判定 **分支 B**，证据链完整（① import ✓ → ② createMac/createSymKeyGenerator ✓ → ③ `doFinalSync()` 不抛异常但返回空 DataBlob `len=0`，async 交叉验证同样 `hex=[] len=0`，并附 node 独立复核的期望 digest）→ 命中计划的判定标准「能 import 但调用失败 = 分支 B」。**采纳**。
- **AC4 复核**：产物绝对路径 `library/build/default/outputs/default/library.har`（release 3863 B，gzip/tar），包内清单 18 条、含 `package/ets/modules.abc` 与自动生成的 `types: "Index.d.ets"`（字节码 HAR）；6 项语言探针逐条结论齐备（全可用，含 `JSON.stringify` 调 `toJSON`、type-only import 不加载模块的负例对照）。
- **编排方裁决（工程配置写回）**：hvigor 的 `-c modelVersion=6.1.1` 会自动把 `oh-package.json5` 迁移写回 6.1.1 并删 `hvigor/hvigor-config.json5` 末尾换行、生成 `library/BuildProfile.ets`。计划 Must NOT 明确「`hvigor/hvigor-config.json5` 不改」，故**不提交该迁移**；统一采用「构建后清理」机械流程（`git checkout -- oh-package.json5 hvigor/hvigor-config.json5; rm -f library/BuildProfile.ets`），后续所有构建任务照此执行。该裁决已同步进 learning 文件。
- **越界检查**：本次 commit 未夹带临时 spike 文件、未改工程配置、未 push（仓库有 origin 远端，全程只读）。
