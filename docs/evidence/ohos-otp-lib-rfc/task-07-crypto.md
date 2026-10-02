# 2026-10-02 08:39:03

## 1. 任务与分支背景

- 任务：T07 加密适配器实现（kit-only `CryptoSource`），W3 并行波次（T04/T05/T06/T07 并发）。
- 分支判定：**分支 B**（T02 实测定论：Local Test 可 import kit、可构造 `createMac`/`createSymKeyGenerator`，但 `doFinalSync()` 返回空 DataBlob `len=0`，async 交叉验证同样为空）。
- 分支 B 含义：`CryptoSource.test.ets` 本地只保留 1 条 import-smoke；真实 crypto 断言由 T11（ohosTest 设备用例）承担。
- `*Sync` 接口在本机 SDK 可编译（T02 已实测 + 本次 `HarCompileArkTS` 通过佐证），**无设计性偏差，无需上报**。

## 2. 实现要点

### 2.1 `library/src/main/ets/internal/CryptoSource.ets`（本任务唯一实现文件）

- `CryptoFrameworkHmac implements HmacProvider`：
  - `sign()` 全链路：`createSymKeyGenerator('HMAC')` → `convertKeySync({ data: key })` → `createMac(toMacAlgName(algorithm))` → `initSync(symKey)` → `updateSync({ data: message })` → `return new Uint8Array(mac.doFinalSync().data)`。
  - `toMacAlgName()`：`OtpAlgorithm` 枚举 switch 映射 `'SHA1'|'SHA256'|'SHA512'`（三个枚举成员全覆盖）。
  - **整段包在 try/catch**：`catch` 一律 `throw new OtpError(OtpErrorCode.CRYPTO_FAILED, 'CRYPTO_FAILED')`（固定文案，不透传原生错误、不打日志、不含 key/message，继承历史坑 `Totp.ets:152-154`）。
  - **密钥生成器必须用通用 `'HMAC'` 规格**：官方支持 [1, 4096] 字节任意长度密钥；严禁 `'HMAC|SHA1'` 之类组合规格（该规格要求密钥长度恰等于摘要长度，会拒绝 80 bit/10 字节真实 secret——继承历史坑 `Totp.ets:140-141`）。
- `CryptoFrameworkRandom implements RandomSource`：
  - `random(bytes)` 先校验 `Number.isInteger(bytes) && bytes >= 1 && bytes <= 4096`，不满足抛 `SECRET_TOO_WEAK`；随后 `new Uint8Array(cryptoFramework.createRandom().generateRandomSync(bytes).data)`，同样 try/catch → `CRYPTO_FAILED`。
- `installCryptoDefaults()`：只 `registerHmac(new CryptoFrameworkHmac())` + `registerRandom(new CryptoFrameworkRandom())`，**不发起任何 crypto 调用**（QA① 静态断言锁定）。

### 2.2 `library/src/test/CryptoSource.test.ets`（分支 B）

- 只保留 1 条 `importSmoke`（`expect(true).assertTrue()`），文件头注释写明「分支 B：Local Test 无法加载系统 kit（T02 实测 doFinalSync 返回空 DataBlob len=0），真实 crypto 断言见 `library/src/ohosTest/ets/test/CryptoAdapter.test.ets`（T11 设备用例）」。
- 套件名 `cryptoSourceTest` 与 `library/src/test/List.test.ets` 注册一致（T03 已注册，本次未改 List.test.ets）。

### 2.3 T03 交接项

- `installCryptoDefaults()` 由 NOT_IMPLEMENTED 占位补为「只 new + 注册」实现（本任务完成）。
- `internal/HmacProvider.ets` 核对无误（两个接口、四个注册函数、`@internal resetForTest()`、未注册抛 `CRYPTO_NOT_INITIALIZED` 全部在），**未修改**，未发现缺陷。

## 3. 构建与单测（逐字命令与真实输出）

环境前缀（每次执行前）：

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
```

### 3.1 构建 HAR（③a，持 hvigor 锁）

```bash
cd /Users/yansongda/000-Coding/ohos-otp
cp oh-package.json5 /tmp/oh-package.json5.bak && sed -i '' 's/"modelVersion": "6.0.0"/"modelVersion": "6.1.1"/' oh-package.json5
$HB --no-daemon -c modelVersion=6.1.1 assembleHar --mode module -p module=library@default -p product=default -p buildMode=release
```

真实输出（尾部，关键行）：

```
> hvigor Finished :library:default@HarCompileArkTS... after 1 s 79 ms
> hvigor Finished :library:default@ProcessHarArtifacts... after 12 ms
> hvigor WARN: If obfuscation is needed, enable obfuscation settings in this build process; ...
> hvigor Finished :library:default@PackageHar... after 7 ms
> hvigor WARN: Will skip sign 'har'. No signingConfigs profile is configured in current project.
> hvigor Finished :library:assembleHar... after 1 ms
> hvigor BUILD SUCCESSFUL in 2 s 195 ms
```

exit code = **0**。`HarCompileArkTS` 通过 ⇒ `convertKeySync/initSync/updateSync/doFinalSync/generateRandomSync` 全链路 `*Sync` 在本工程可编译（Acceptance 1 ✓）。

### 3.2 本地单测（③b，持 hvigor 锁）

```bash
$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
```

真实输出（尾部）：

```
> hvigor Finished :library:default@UnitTestArkTS... after 975 ms
> hvigor Darwin
[2026-10-02T08:37:59.482] [INFO] default - Finished write html report
> hvigor Finished :library:default@GenerateUnitTestResult... after 366 ms
> hvigor Finished :library:test... after 1 ms
> hvigor BUILD SUCCESSFUL in 2 s 232 ms
```

exit code = **0**。用例级结果（`library/.test/default/intermediates/test/coverage_data/test_result.txt`）：

```
class=cryptoSourceTest
result=Success
Tests run: 70, Failure: 0, Error: 0, Pass: 70, Ignore: 0
```

`cryptoSourceTest` 仅 1 条 importSmoke 且 Success（分支 B 预期，Acceptance 2 ✓）；12 个套件全绿（并发中 T04/T05/T06 的用例也在本结果内通过，无他人文件干扰）。

### 3.3 构建后还原

每次构建/单测后执行：`cp /tmp/oh-package.json5.bak oh-package.json5 && rm -f /tmp/oh-package.json5.bak library/BuildProfile.ets; rmdir /tmp/ohos-otp-hvigor.lock`。提交前 `git status` 确认根 `oh-package.json5` 无改动（见第 6 节）。

## 4. Acceptance 逐条验证（真实输出）

| # | 断言 | 结果 |
|---|---|---|
| 1 | 构建命令 exit 0 | `BUILD SUCCESSFUL in 2 s 195 ms`，exit 0 ✓ |
| 2 | 单测命令 exit 0；分支 B 仅 1 条 smoke | `BUILD SUCCESSFUL in 2 s 232 ms`，exit 0；`cryptoSourceTest` 1 条 importSmoke Success；`Tests run: 70, Failure: 0, Error: 0, Pass: 70, Ignore: 0` ✓ |
| 3 | `grep -n "HMAC|" library/src/main/ets/internal/CryptoSource.ets` 无输出 | exit=1（无匹配）✓ |
| 4 | `grep -n "@kit\." library/src/main/ets/internal/HmacProvider.ets` 无输出 | exit=1（无匹配）✓ |
| 5 | `grep -c "OtpErrorCode.CRYPTO_FAILED\|OtpErrorCode.CRYPTO_NOT_INITIALIZED" ...` ≥ 2 | CryptoSource.ets: 2（sign/random 两个 catch），HmacProvider.ets: 2（requireHmac/requireRandom），合计 4 ≥ 2 ✓ |

补充：全库唯一 `@kit` 导入点检查 `grep -rln "@kit\." library/src/main/ets/ library/Index.ets` → 仅 `library/src/main/ets/internal/CryptoSource.ets` ✓；`CryptoSource.ets` 内 `NOT_IMPLEMENTED` 残留 = 0 ✓。

## 5. QA failure 场景

### 5.1 场景①：锁定「注册期不得调用 crypto」（静态断言，不动态调用）

```bash
awk '/function installCryptoDefaults/{f=1} f{print} f&&/^\}/{exit}' library/src/main/ets/internal/CryptoSource.ets | grep -c "cryptoFramework\."
```

真实输出：`0` ✓（`installCryptoDefaults` 函数体内只有 `registerHmac(new CryptoFrameworkHmac())` + `registerRandom(new CryptoFrameworkRandom())`，无任何 `cryptoFramework.` 调用。理由：分支 A 下调用成功不会报错、分支 B 下测试模块图内无 barrel，动态验证在两个分支下都观察不到，故用静态断言锁定。）

### 5.2 场景②：临时把 `algName` 映射改成固定 `'SHA1'`（分支 B）

临时修改：`toMacAlgName` 的 switch 整体替换为 `return 'SHA1';`（`grep -n "return 'SHA1'"` → L18 命中，patch 成功），跑本地单测：

真实输出：

```
> hvigor BUILD SUCCESSFUL in 2 s 276 ms
test exit=0
class=cryptoSourceTest
result=Success
Tests run: 70, Failure: 0, Error: 0, Pass: 70, Ignore: 0
```

**分支 B 语义确认**：破坏 SHA256/SHA512 映射后本地单测仍 70/70 全绿——`cryptoSourceTest` 本地仅 1 条 importSmoke，不触发真实 crypto 计算，**本地观察不到该红点**。该红点由 **T11 的设备用例**承担（ohosTest `CryptoAdapter.test.ets` 对 RFC 6238 附录 B 的 SHA256/SHA512 向量断言，设备端若 `sign(SHA256)` 实际返回 SHA1 摘要必红）。随后还原映射（`cp /tmp/CryptoSource.ets.bak` 恢复），重跑单测确认恢复绿：`BUILD SUCCESSFUL in 2 s 268 ms`，`Tests run: 70, Failure: 0, Error: 0, Pass: 70, Ignore: 0` ✓。记录后已还原，交付文件与第 2 节一致。

## 6. 分支 B 缺口说明与设备端替代验证

- **缺口**：Local Test 环境下 kit crypto 计算不真正执行（T02 实测 `doFinalSync()` 返回空 DataBlob `len=0`，async 同样），因此本任务无法在本地验证：① `sign()` 三种算法对 RFC 4226/6238 附录 A 向量的 digest 正确性；② 10 字节短密钥（80 bit，如 `JBSWY3DPEHPK3PXP`）能被通用 `'HMAC'` 规格接受（证伪「密钥长度必须等于摘要长度」）；③ `random()` 返回真实随机数据；④ 注册链路（`installCryptoDefaults` → `requireHmac`/`requireRandom`）在真实环境可用。
- **设备端替代验证（T11）**：`library/src/ohosTest/ets/test/CryptoAdapter.test.ets`（T03 已建空壳，套件 `cryptoAdapterTest`）承担：RFC 4226 附录 D（SHA1 counter=1 → `75a48a19d4cbe100644e8ac1397eea747a2d33ab`）、RFC 6238 附录 B（SHA256/SHA512 向量）、10 字节 secret 不抛错、`random(20)` 长度与两次不同、`requireXxx()` 未注册抛 `CRYPTO_NOT_INITIALIZED`。当前无设备（`hdc list targets` → `[Empty]`），T11 按「未执行 + 人工步骤」记录，本任务不伪报。
- 分支 B 下可测性缺口为设计文档 §3.1 明确接受的唯一缺口（写入 README 由 T12 负责）。

## 7. 偏差

- **无设计性偏差**：`*Sync` 接口编译可用（SDK 声明 `convertKeySync` L2006 / `initSync` L2304 / `updateSync` L2398 / `doFinalSync` L2475 / `generateRandomSync` L1332 与 T02 结论一致），无需改 async。
- **机械性修正**：初版注释含字面 `HMAC|SHA1`（历史坑引用），命中验收 grep `grep -n "HMAC|"`（T03 已警告「验收 grep 是纯字面匹配，注释也不能踩」）→ 改写措辞为「管道符拼接算法名的组合规格（如 HMAC 管道符 SHA1）」后无匹配，已在 evidence 记录。
- **一次构建超时**：首次「构建+单测」合并执行时单测阶段挂起（约 1 分钟后被环境终止，`.hvigor/report` 显示流程卡在 `UnitTestArkTS` 之后的测试执行期），清理残留锁与进程、删除 `library/build/default/cache/default/default@HarCompileArkTS` 缓存后，构建与单测**分步**重跑均 2s 级成功。疑似并发波次内多 worker 交替持锁/编译所致，重试后无复现。

## 8. 文件边界与并发说明

- 本任务只改 2 个文件：`library/src/main/ets/internal/CryptoSource.ets`、`library/src/test/CryptoSource.test.ets`（+ 本 evidence）。
- 未触碰：`internal/HmacProvider.ets`（归 T03）、`List.test.ets`、`Index.ets`、`oh-package.json5` 等。
- 提交前 `git status --short`（见下）：除本任务 2 个文件外，另有并发 worker（T05 Counter/Digits/Truncate 及其测试、T05 evidence）与编排方维护文件（learning）的改动，**保留不动**，只 add 本任务文件。

```
 M docs/learning/ohos-otp-lib-rfc.md        ← 编排方/并发 worker 维护，不提交
 M library/src/main/ets/internal/Counter.ets  ← T05，不动
 M library/src/main/ets/internal/CryptoSource.ets  ← 本任务
 M library/src/main/ets/internal/Digits.ets    ← T05，不动
 M library/src/main/ets/internal/Truncate.ets  ← T05，不动
 M library/src/test/Counter.test.ets           ← T05，不动
 M library/src/test/CryptoSource.test.ets      ← 本任务
 M library/src/test/Digits.test.ets            ← T05，不动
 M library/src/test/Truncate.test.ets          ← T05，不动
?? docs/evidence/ohos-otp-lib-rfc/task-05-primitives.md  ← T05，不动
```
