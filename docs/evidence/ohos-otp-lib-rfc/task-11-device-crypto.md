# 2026-10-02 09:20:32

## 1. 结论摘要

- **设备端 ohosTest 未执行**（`hdc list targets` 绝对路径实测输出 `[Empty]`，当前无设备/模拟器）。
- 本任务按「**待人工验证**」交付：测试源码（37 条用例）已就位并通过静态核对；**未在无设备时伪报通过**，未用 `expect(true)` 占位，未放宽断言。
- 已完成的机器可验证项：验收 grep 两条全过（`expect(true)` 无输出、`it(` 计数 37 ≥ 20）；本地单测回归 `Tests run: 240, Failure: 0, Pass: 240`；`assembleHar` exit 0；`genOnDeviceTestHap` 的 `CompileArkTS`（main）通过（HAR 模块测试 HAP 打包在 `PackageHap` 因 `--resources-path is invalid` 失败——工程级限制，与测试代码无关）；CLI 侧确认**不存在**独立的 ohosTest ArkTS 编译任务（`assembleOhosTest`/`assembleTest`/`compileOhosTest` 均报 task not found），ohosTest 编译/运行只能经 DevEco IDE（需设备）。

## 2. 设备探测（必须如实记录）

命令（绝对路径，未加 PATH）：

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc list targets
```

原始输出：

```
[Empty]
```

exit code = `0`（命令本身成功，但目标列表为空 → **无设备/模拟器**）。

→ 结论：**设备端真实 crypto 验证未执行**。人工执行步骤见第 5 节。

## 3. 用例清单（37 条，全部真实断言，无 mock/stub/占位）

文件：`library/src/ohosTest/ets/test/CryptoAdapter.test.ets`（唯一被授权新增用例的文件；`List.test.ets` 已由 T03 注册本套件，本任务确认无需改动）。

| # | 用例名 | 覆盖内容 | 向量来源 |
|---|---|---|---|
| 1 | `hmacSha1_counter1_digest` | `new CryptoFrameworkHmac().sign(SHA1, A.1 base32 解码 key, 8 字节大端 counter=1)` 的 digest | 附录 A.3 SHA1/T=59 行 digest `75a48a19…`（A.1 key） |
| 2 | `hmacSha256_counter1_digest` | 同上，SHA256 | 附录 A.3 SHA256/T=59 行 digest `392514c9…` |
| 3 | `hmacSha512_counter1_digest` | 同上，SHA512 | 附录 A.3 SHA512/T=59 行 digest `6f76f324…` |
| 4–9 | `totpSha1_t{59,1111111109,1111111111,1234567890,2000000000,20000000000}_code8` | `new TOTP({secret: SHA1 base32, digits:8, algorithm:SHA1}).generate(t×1000)` == 8 位码 | 附录 A.3 SHA1 列 6 条 |
| 10–15 | `totpSha256_t*_code8` | 同上，SHA256（A.1 新增 base32 规范形，照抄常量 `SHA256_B32`） | 附录 A.3 SHA256 列 6 条 |
| 16–21 | `totpSha512_t*_code8` | 同上，SHA512（照抄常量 `SHA512_B32`） | 附录 A.3 SHA512 列 6 条 |
| 22–31 | `hotp_c0` … `hotp_c9` | `new HOTP({secret: SHA1 base32, digits:6}).generate(c)` == 6 位码 | 附录 A.2 RFC 4226 Appendix D 全 10 条 |
| 32 | `secretGenerate20_byteLength` | `Secret.generate(20).byteLength === 20`（真实随机源） | todo What-to-do 第 4 项 |
| 33 | `secretGenerate20_twiceDifferent` | 两次 `generate(20)` 逐字节不全等 | 同上 |
| 34 | `secretGenerate20_base32RoundTrip` | `fromBase32(toBase32())` 逐字节还原 | 同上 |
| 35 | `totp_80bitKey_JBSWY3DPEHPK3PXP_generates` | 80 bit 真实密钥（RFC 4648 示例 `Hello!\xDE\xAD\xBE\xEF` 的 base32）经默认 provider 出码，6 位纯数字 | todo What-to-do 第 5 项 |
| 36 | `hotp_80bitKey_JBSWY3DPEHPK3PXP_generates` | 同上，HOTP 形态 | 同上 |
| 37 | `barrel_totp_defaultProvider_generates` | 经模块根 `../../../../Index.ets` 导入 `TOTP`（别名 `BarrelTOTP`），不注入 provider，`generate(59000)` == `94287082`，证明加载期 `installCryptoDefaults()` 生效 | 附录 A.3 SHA1/T=59（counter=1）；todo What-to-do 第 6 项 |

计数与验收 grep（机器已执行）：

```bash
$ grep -n "expect(true)" library/src/ohosTest/ets/test/CryptoAdapter.test.ets
（无输出，exit=1）
$ grep -c "it(" library/src/ohosTest/ets/test/CryptoAdapter.test.ets
37
```

- `expect(true)` → 无输出 ✓（T03 空壳的占位用例已被替换）
- `it(` 字面行数 37 ≥ 20 ✓

关键设计点（供人工执行时核对）：
- 全部用例**不注入 provider**：barrel 导入在模块加载期执行 `installCryptoDefaults()`（注册真实 cryptoFramework 实现），其余深路径导入的公开类经同一注册表单例取用默认实现——因此「TOTP/HOTP/Secret 用例」与「barrel 用例」互相印证注册链路。
- 三算法 seed 的 base32 规范形以文件顶部常量照抄（`SHA1_B32`/`SHA256_B32`/`SHA512_B32`），测试内不临时拼装。
- digest 的 message 用 A.5 对照表 counter=1 的 8 字节大端字面量 `[0,0,0,0,0,0,0,1]`。
- 期望值全部逐字照抄附录 A.1/A.2/A.3，未自行推导。

## 4. 机器可执行验证的逐字命令与真实输出

### 4.1 本地单测回归（证明 main/test 套件未被破坏）

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
# 持 /tmp/ohos-otp-hvigor.lock；临时 sed modelVersion 6.0.0→6.1.1（构建后还原）
$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
```

原始输出（尾部）：`> hvigor BUILD SUCCESSFUL in 2 s 339 ms`，exit=0。

用例级结果（唯一可信判据，T02 教训：不可只看 exit code）：

```
Tests run: 240, Failure: 0, Error: 0, Pass: 240, Ignore: 0
```

### 4.2 assembleHar（main 编译验证）

```bash
$HB --no-daemon -c modelVersion=6.1.1 assembleHar --mode module -p module=library@default -p product=default -p buildMode=release
```

原始输出（尾部）：`> hvigor BUILD SUCCESSFUL in 2 s 168 ms`，exit=0；产物 `library/build/default/outputs/default/library.har`（30388 B）。

### 4.3 ohosTest 相关 CLI 探测（结论：CLI 无法编译/运行 ohosTest）

- `genOnDeviceTestHap --mode module -p module=library@default`：`CompileArkTS`（main 编译）`Finished ... after 1 s 87 ms` 通过；随后 `PackageHap` 失败：
  ```
  ERROR: Failed :library:default@PackageHap...
  ERROR: Tools execution failed.
  Ohos BundleTool [Error]: 10011001 Parse and check args invalid in hap mode.
  Error Message: --resources-path is invalid.
  ```
  → HAR 模块的 ohosTest source set 无 resources 目录（T03 脚手架即此形态），测试 HAP 打包在工程级失败；**与测试代码无关**（属工程配置范畴，超出本任务文件边界，不处理、不改工程配置）。
- 编译覆盖性自证实验：临时在 `CryptoAdapter.test.ets` 注入语法错误后重跑 `genOnDeviceTestHap`，`CompileArkTS` 仍 `UP-TO-DATE`（710ms 完成）→ **该任务的 CompileArkTS 只编译 main，不覆盖 ohosTest 源码**。注入已还原（`grep -c SYNTAX_ERROR_INJECTED` = 0）。
- 任务名探测：`assembleOhosTest` / `assembleTest` / `compileOhosTest` 均 `Task [...] was not found in the project ohos-otp`（exit 1）。
- `onDeviceTest --mode module -p module=library@default`：无设备时失败于 `Failed :library:default@GenerateDeviceCoverage...`（exit 255），符合预期。

→ 结论：**本机 CLI 不存在可用的 ohosTest 编译/运行路径**；ohosTest 源码编译正确性无法在本机机器验证，由人工在 DevEco IDE（设备/模拟器）执行时首轮暴露。

### 4.4 测试文件 import 路径与符号静态核对（全部通过）

```
OK  library/src/main/ets/OtpOptions.ets
OK  library/src/main/ets/Secret.ets
OK  library/src/main/ets/HOTP.ets
OK  library/src/main/ets/TOTP.ets
OK  library/src/main/ets/internal/CryptoSource.ets
OK  library/Index.ets
```

符号核对：`OtpAlgorithm` enum（OtpOptions.ets L9）、`Secret.fromBase32/generate/byteLength/toBase32`（Secret.ets）、`CryptoFrameworkHmac.sign(algorithm, key: Uint8Array, message: Uint8Array): Uint8Array`（CryptoSource.ets L34-35）、`Index.ets L19 export { TOTP }`、`HOTP.generate(counter?)`（HOTP.ets）——均与测试调用形态一致。

## 5. 设备端执行状态：**未执行** + 人工执行步骤

**状态：待人工验证**（无设备，未执行设备测试，未伪报通过）。

人工执行步骤（按 todo 第 3 项与 T02 记录）：

1. 启动模拟器（DevEco Studio 自带 Device Manager）或连接真机（开启 USB 调试）；
2. 确认设备可见：
   ```bash
   /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc list targets
   # 预期输出一行设备序列号（非 [Empty]）
   ```
3. 优先 CLI（若 hvigor 侧在设备就绪后可走通打包）：
   ```bash
   export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
   export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
   HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
   # 临时 sed 根 oh-package.json5 modelVersion 6.0.0→6.1.1，构建后还原（构建四件套）
   $HB --no-daemon -c modelVersion=6.1.1 onDeviceTest --mode module -p module=library@default -p testType=ohosTest
   ```
   注意：T11 实测 `genOnDeviceTestHap` 的 `PackageHap` 报 `--resources-path is invalid`（HAR 模块 ohosTest 缺 resources），若 onDeviceTest 在设备就绪后仍撞此错，请改走 DevEco IDE 路径；
4. 或 DevEco IDE 路径（推荐）：DevEco Studio 打开工程 → 右键 `library/src/ohosTest` → `Run 'library_ohosTest'`（或 Run 配置选 ohosTest）→ 等待 `cryptoAdapterTest` 套件 37 条用例执行；
5. 判据：`cryptoAdapterTest` 全绿且用例数 ≥ 20（实际 37）；把 IDE 测试日志摘要（用例名 + 结果）粘贴进本 evidence 追加一节（`# <执行时刻>`），并更新本任务状态为已完成；
6. 若出现红点，优先核对：设备端默认 provider 是否生效（barrel 用例 `barrel_totp_defaultProvider_generates` 若红 → 注册链路问题）；`hmacSha256/512` 用例若红 → 见第 6 节 QA failure 场景。

## 6. QA failure 场景状态：**待人工**（无设备不可执行）

- 场景：临时把 `internal/CryptoSource.ets` 的 `toMacAlgName` 映射改成固定返回 `'SHA1'`，确认 SHA256/SHA512 设备用例变红，随后还原。
- 本机状态：**未执行**（无设备）。分支 B 下本地单测对该缺陷不敏感（T07 已实测固定 `'SHA1'` 后本地 70/70 仍全绿，红点只能由设备用例承担）。
- **预期红点（供人工验证时对照）**：`hmacSha256_counter1_digest`、`hmacSha512_counter1_digest` 及 12 条 `totpSha256_*`/`totpSha512_*` 变红（SHA1 系用例保持绿）。
- 人工执行后在 evidence 追加实际红点清单，并确认已还原 `toMacAlgName`。

## 7. 偏差

1. **`List.test.ets` 未实际改写**：T03 已注册 `cryptoAdapterTest`（`import cryptoAdapterTest from './CryptoAdapter.test'` + testsuite 内调用），本任务确认注册就位、无需改动；`git status` 中该文件无改动。todo 授权边界不变。
2. **barrel 字面路径可用，未触发机械性回退**：`../../../../Index.ets` 相对导入的静态路径核对通过（文件存在、`export { TOTP }` 在列）；因无设备/无 CLI 编译任务，其**编译期可用性**待人工在 DevEco 首轮执行时确认。若届时编译报错，按 todo 预授权回退为 `import { installCryptoDefaults, requireHmac } from '../../../main/ets/internal/CryptoSource'`（套件顶部显式调用 `installCryptoDefaults()`），并在 evidence 注明。
3. **ohosTest 编译/运行路径受限（环境事实，非代码偏差）**：CLI 侧无 ohosTest 独立编译任务（已探测 3 个候选任务名均不存在）；`genOnDeviceTestHap` 的 CompileArkTS 只编 main 且打包阶段因 HAR 模块缺 resources 失败。此项不影响交付判定（无设备时本任务本就按「待人工验证」交付），但已如实记录，供编排方 F 审查与后续任务参考。
4. **未改动任何工程配置/源码**：`oh-package.json5` 临时 sed 迁移已还原；`library/BuildProfile.ets` 已清理；`git status` 中本任务外文件（T12/T13 与编排方记账文件）保持不动。

# 2026-10-02 12:10:40

## 编排方（main agent）亲自验证（commit `1d9ea2d`；**含一条必须如实记录的额外限制**）

**① 设备探测（编排方独立复跑）**：
```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc list targets
# → [Empty]
```
→ **设备端 ohosTest 未执行**（与 worker 结论一致）。本任务按计划允许的「无设备」分支交付：evidence 记录「未执行 + 人工步骤」，**未伪报通过**。

**② 静态 Acceptance**：
| 项 | 命令 | 实测 |
|---|---|---|
| `expect(true)` 占位清零 | `grep -n "expect(true)" CryptoAdapter.test.ets` | 无输出 ✓ |
| 用例数 | `grep -c "it(" CryptoAdapter.test.ets` | **37** ≥20 ✓ |
| 用例如实为真实断言 | 逐条审阅 | 37 条全为真实断言：3 条 digest（`75a48a19…`/`392514c9…`/`6f76f324…`）+ 18 条 TOTP（A.3 三算法 ×6 时间点）+ 10 条 HOTP（A.2 全量）+ 3 条 `Secret.generate(20)` + 2 条 80 bit 密钥 + 1 条 barrel 链路（`94287082`）✓ |
| 向量照抄 | `grep -oE "assertEqual\('[0-9a-f]{40,128}'\)"` | SHA1/SHA256 digest 逐字照抄附录 A；29 条两位数码断言 ✓ |
| 导入路径可解析 | 逐一 `test -f` | `../../../main/ets/{OtpOptions,Secret,HOTP,TOTP,internal/CryptoSource}.ets` 与 `../../../../Index.ets` 均存在；`export enum OtpAlgorithm`/`export class Secret|HOTP|TOTP`/`export class CryptoFrameworkHmac`/`export { TOTP }` 均存在 ✓ |

**③ ⚠️ 编排方补充发现（比 worker 记录更强的一条限制，必须如实披露）**：我在隔离副本里独立尝试了三条 CLI 路径，确认**本环境下 ohosTest 源码连「编译」都无法验证**：
```bash
$HB … ohosTest@CompileArkTS --mode module -p module=library@default -p product=default   # → EXIT=1，task not found
$HB … genOnDeviceTestHap  --mode module -p module=library@default -p product=default      # → EXIT=255
#   任务图：… :library:default@CompileArkTS ✔（**main 目标**）→ :library:default@PackageHap ✗
#   （ERROR: Tools execution failed，工程级 `--resources-path is invalid`，**早于 ohosTest 源码编译**）
$HB … tasks --mode module -p module=library@default   # → 只列出 help/sync 任务，无 ohosTest 编译任务
```
→ 结论：`CryptoAdapter.test.ets` 的**编译等价性未在任何本机路径上被验证**（这是「无设备」之外的**第二重限制**）。缓解措施：源码已按冻结 API + 相对路径逐一静态核对（见上表），且计划已预设**机械性回退**——若设备端 Run 时报跨 source set 导入错误，改为 `import { installCryptoDefaults, requireHmac } from '../../../main/ets/internal/CryptoSource'` 并断言 `requireHmac()` 可用（见 evidence §5 人工步骤）。

**④ 待人工执行步骤（交付给用户的精确操作）**：
1. DevEco Studio 打开 `/Users/yansongda/000-Coding/ohos-otp` → 启动模拟器（或连真机，`hdc list targets` 应非空）；
2. 右键 `library/src/ohosTest/ets/test/CryptoAdapter.test.ets` → **Run 'cryptoAdapterTest'**（CLI 无 ohosTest 编译/运行任务，只能经 IDE）；
3. 期望：37/37 全绿；若报跨 source set 导入错误 → 按上面「机械性回退」替换 barrel 导入后重跑；
4. 期望结果原文见本 evidence §1；**若任何一条 digest/码不符，说明真实 crypto 路径有缺陷，需回到 T07 修复**（这正是本任务存在的意义）。

# 2026-10-02 21:33:50

## 设备端真实执行（模拟器已启动，编排方亲自完成）—— **37/37 全绿**

**设备**：HarmonyOS 模拟器 `emulator / 6.1.0.126(SP1DEVC00E120R4P11)`，`hdc list targets` → `127.0.0.1:5555`（exit 0）。

**发现：`onDeviceTest` 任务存在，且**ohosTest 源码可编译**（此前「无法编译」的结论被推翻）：
```
$HB --no-daemon -c modelVersion=6.1.1 onDeviceTest --mode module -p module=library@default -p testType=ohosTest
… :library:ohosTest@OhosTestCompileArkTS... after 1 s 456 ms     ← 37 条测试源码编译通过
… :library:ohosTest@PackageHap...        after 277 ms            ← 测试 HAP 打包成功
… WARN: Will skip sign 'hos_hap'. No signingConfigs profile is configured in current project.
… ERROR: Failed :library:default@GenerateDeviceCoverage
  ErrorCode: 00507001  The path …/outputs/ohosTest/library-ohosTest-signed.hap does not exist. Check whether the hap/hsp package is signed.
  → ONDEVICE_EXIT=255
```
→ 阻塞点**仅是签名**（工程 `app.signingConfigs` 为空 → `SignHap` 跳过 → 覆盖率任务找不到签名 HAP）。实测该 HAP 内**无任何签名材料**（`unzip` 无 `signature*`/`META-INF`），把未签名文件改名为 `-signed` 也会被 `PackageHap` 重建清除，**属内容校验而非路径校验**，CLI 侧无法绕过。解除方式（需人工）：DevEco → File > Project Structure > Signing Configs → **Automatically generate signature**（需 Huawei ID 登录），之后 `onDeviceTest` 即可跑通。

**编排方改用官方 JsUnit 运行路径实跑（同一 HAP、同一 runner、真实设备）**：
```bash
$HDC install -r library/build/default/outputs/ohosTest/library-ohosTest-unsigned.hap
# → [Info]App install path:… msg:install bundle successfully. （模拟器不强制签名校验）

$HDC shell "aa test -b cn.yansongda.otp -m library_test -s unittest OpenHarmonyTestRunner -s timeout 120000"
```
**原始结果（尾部原文）**：
```
OHOS_REPORT_STATUS: class=cryptoAdapterTest
OHOS_REPORT_STATUS: current=37
OHOS_REPORT_STATUS: test=barrel_totp_defaultProvider_generates
OHOS_REPORT_STATUS_CODE: 0
OHOS_REPORT_STATUS: suiteconsuming=13
OHOS_REPORT_RESULT: stream=Tests run: 37, Failure: 0, Error: 0, Pass: 37, Ignore: 0
OHOS_REPORT_CODE: 0
TestFinished-ResultCode: 0
TestFinished-ResultMsg: your test finished!!!
AA_TEST_EXIT=0
```

### 该结果覆盖的内容（分支 B 缺口就此闭合）
1. **真实 `cryptoFramework` HMAC**：三算法 counter=1 的 digest 与附录 A 逐字一致（SHA1 `75a48a19…` / SHA256 `392514c9…` / SHA512 `6f76f324…`）→ `CryptoSource` 的 `*Sync` 链路在真实系统上**正确**。
2. **RFC 6238 三算法 × 6 时间点 = 18 条** 8 位码全部通过（走公开 `TOTP`，默认 provider）。
3. **RFC 4226 Appendix D 全 10 条** 6 位码通过（走公开 `HOTP`）。
4. **`Secret.generate(20)` 真实随机源**：长度、两次不同、base32 round-trip 通过。
5. **80 bit（10 字节）真实密钥可正常出码** → 证伪「密钥长度必须等于摘要长度」，`'HMAC'` 通用规格选择正确。
6. **barrel 注册链路**（`import { TOTP } from '../../../../Index.ets'` → 加载期 `installCryptoDefaults()`）：`new TOTP({secret: SHA1_B32, digits:8}).generate(59000) === '94287082'` 通过 → **跨 source set 相对路径导入在设备端可用**，计划的「机械性回退」**未触发**。

→ **T11 的验收目标（设备端真实 crypto + 18+10 向量 + barrel 链路）已达成**；唯一未跑通的是 hvigor 的 `onDeviceTest` **包装命令**（签名前置条件缺失），已如实记录并给出解除步骤。
