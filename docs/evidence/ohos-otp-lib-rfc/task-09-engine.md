# 2026-10-02 08:54:50

## T09 编排引擎 + 黄金向量 fixture —— 任务证据

- 任务：`docs/implementation/ohos-otp-lib-rfc.md` W4 todo 9（编排引擎 + 黄金向量 fixture）
- 分支：W4 并行波次，与 T08 并发；分支 B（本地不能跑真实加密，全部经 HmacFixture 注入）
- 改动文件（仅本任务 4 个 + evidence）：
  - `library/src/test/vectors/RfcVectors.ets`（新增黄金向量，逐字照抄附录 A）
  - `library/src/test/HmacFixture.ets`（查表 fixture，未命中抛错）
  - `library/src/main/ets/internal/OtpEngine.ets`（generate/verify 编排）
  - `library/src/test/OtpEngine.test.ets`（61 条用例，全 HmacFixture 注入）

## 1. 向量落表清单（附录 A 逐字照抄，机器比对一致）

用脚本解析 `docs/implementation/ohos-otp-lib-rfc.md` 附录 A 全部表格，与 `RfcVectors.ets` 逐值比对，**全部一致，零差异**：

| 常量 | 条目数 | 来源 | 比对结果 |
|---|---|---|---|
| `RFC4226_SHA1_6DIGIT` | 10 | A.2 | 10/10 一致 |
| `RFC6238_SHA1` | 6 | A.3 | 6/6 一致 |
| `RFC6238_SHA256` | 6 | A.3 | 6/6 一致 |
| `RFC6238_SHA512` | 6 | A.3 | 6/6 一致 |
| `BOUNDARY_COUNTERS` | 3（×3 算法 ×digest/code6/code8） | A.4 | 9 digest + 18 code 全一致 |
| `DIGITS7_SHA1` | 3（counter 0/1/9） | A.6 | 3/3 一致 |
| `COUNTER_BYTES` | 9 | A.5 | 9/9 一致 |
| `SEEDS` | 3 ASCII + 3 base32 | A.1 | 6/6 一致 |
| `SHA256_C0_8DIGIT`/`SHA256_C0_DIGEST` | 2 | A.6 第 1 行 | 一致 |

比对脚本输出（节选）：
```
A.2 rows: 10   A.3 rows: 18   A.4 rows: 9   A.4 counters found: ['4294967296','4294967297','9007199254740991']
ALL OK: RfcVectors.ets 与附录 A 逐字一致（A.2 10 + A.3 18 + A.4 18 + A.5 9 + A.1 3 + A.6 5 项）
```

- **与附录 A 逐条比对一致计数：A.2 10/10 + A.3 18/18 + A.4 18/18（code）+ 9/9（digest）+ A.5 9/9 + A.1 6/6 + A.6 5/5 = 共 75 项**。
- `BOUNDARY_COUNTERS` 结构按 todo 要求：每 counter 存 `sha1/sha256/sha512` 各一组 `{digest, code6, code8}`（ArkTS 禁止内联对象字面量作类型，声明了 `BoundaryAlg` 具名接口）。
- 派生量（非附录 A 直抄）在用例内先写推导再断言：
  - `step(timeSec*1000, 0, 30) = floor(floor(timeSec*1000/1000)/30) = floor(timeSec/30)`（RFC 6238 18 条时间点）。
  - `SHA256 counter=0 / digits=8`：`period=60 → floor(59/60)=0`，期望码 `18920136`（A.6 第 1 行，direct 断言）。

## 2. 实现要点

- `HmacFixture`：构造接收 `Map<string,string>`（键 `<algorithm>:<message hex>`）；`sign()` 查表命中 hex→Uint8Array，**未命中 `throw new Error('HmacFixture 未命中: ...')`**，绝不返回零值数组；`buildRfcFixture()` 把 RfcVectors 全部 digest 装表（SHA1 counter=1 在 A.2 与 A.3 T=59 重复，Map.set 幂等无害，无多余合并逻辑）。message hex 用与引擎同源的 `toBytes` 生成，保证键一致。
- `OtpEngine.generate`：`formatDigits(truncateApply(provider.sign(algorithm, key, toBytes(counter))), digits)`，**取模只在 `Digits.format` 内做一次**。
- `OtpEngine.verify`：① token 纯数字且 `length===digits` 否则 `INVALID_TOKEN`；② window ≥0 整数否则 `INVALID_WINDOW`；③ 候选 `counter+delta`（delta −window..+window），`<0` 或非 safe 跳过；④ `constantTimeEquals` 比对；⑤ **扫完全部候选后才返回首个命中 delta**（不提前 return）；⑥ 未命中 `null`。无 import kit、无日志。

## 3. 验收结果（逐条）

### AC1 单测 exit 0 + otpEngineTest 全绿 + 用例数 ≥ 45

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cp oh-package.json5 /tmp/oh-package-t09.bak && sed -i '' 's/"modelVersion": "6.0.0"/"modelVersion": "6.1.1"/' oh-package.json5
rm -f library/.test/default/intermediates/test/coverage_data/test_result.txt
$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
grep -E "^Tests run" library/.test/default/intermediates/test/coverage_data/test_result.txt
cp /tmp/oh-package-t09.bak oh-package.json5 && rm -f /tmp/oh-package-t09.bak library/BuildProfile.ets
```

真实输出：
```
> hvigor BUILD SUCCESSFUL in 2 s 293 ms
Tests run: 176, Failure: 0, Error: 0, Pass: 176, Ignore: 0
otpEngineTest 失败数: 0
otpEngineTest 用例数: 61
otpEngineTest Success 数: 61
```
（`Tests run` 总数含 T08 并行推进的其它套件，判定以「无编译错误 + otpEngineTest Failure: 0」为准。）

### AC2 `grep -c "it("` ≥ 45

```
$ grep -c "it(" library/src/test/OtpEngine.test.ets
61
```

### AC3 反自证：无 `@kit` / `cryptoFramework`

```
$ grep -rn "@kit\|cryptoFramework" library/src/test/OtpEngine.test.ets library/src/test/HmacFixture.ets library/src/test/vectors/RfcVectors.ets
（无输出，exit=1）
```

### AC4 `grep -c "NOT_IMPLEMENTED"` = 0

```
$ grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/OtpEngine.ets
0
```

### AC5 `grep -c "%"` 无取模（取模只在 Digits.format 内）

```
$ grep -c "%" library/src/main/ets/internal/OtpEngine.ets
0
```
人工确认：OtpEngine.ets 无任何 `%`，取模唯一发生在 `Digits.format` 内部（该文件不属于本任务改动）。

### 逐条向量比对计数（测试内断言）

| 分组 | 用例数 | 断言内容 |
|---|---|---|
| RFC 4226（A.2，SHA1/6 位） | 10 | `generate(...) === 附录 A 6 位码`（10/10） |
| RFC 6238（A.3，三算法 × 6 时间点） | 18 | 每条含 `step(timeSec*1000,0,30)===counter` + `generate(...)===8 位码`（18/18） |
| 边界（A.4，3 × 三算法 × {6,8 位}） | 18 | 覆盖 2^32 / 2^32+1 / 2^53-1（18/18） |
| 7 位（A.6，counter 0/1/9） | 3 | 3/3 |
| SHA256 counter=0 / 8 位（A.6 第 1 行） | 1 | 1/1（同时证明 SHA256_C0_DIGEST 已装入 fixture） |
| verify 正例 | 3 | delta0 / −1 / +1 |
| verify 负例 | 2 | window0 上一步码 → null；错误码 → null |
| verify 边界 | 1 | counter0 码、window=2 → 0（负候选跳过不崩溃） |
| verify 入参校验 | 4 | '12345'/'12a456'→INVALID_TOKEN；window −1/1.5→INVALID_WINDOW |
| fixture 未命中 | 1 | counter=42 → 抛错 |
| **合计** | **61** | 全绿 |

## 4. QA failure 三个红点实测（均记录输出后还原）

### ① Truncate offset 掩码 `0x0f` → `0x0e`（临时）

```bash
cp library/src/main/ets/internal/Truncate.ets /tmp/truncate-t09.bak
sed -i '' 's/0x0f/0x0e/' library/src/main/ets/internal/Truncate.ets
# 构建 + 单测
```
真实输出：`Tests run: 176, Failure: 26, Error: 0, Pass: 150`
失败归属：`23 otpEngineTest + 3 truncateTest`，RFC 向量大面积变红（rfc4226_counter_1/8/9、rfc6238_* 大量、boundary_*、digits7_*、verify_positive_* 等 23 条）。
还原：`cp /tmp/truncate-t09.bak library/src/main/ets/internal/Truncate.ets`，`git diff --stat` 与 HEAD 无差异。

### ② TimeStep.step 外层 `Math.floor` → `Math.round`（临时）

```bash
cp library/src/main/ets/internal/TimeStep.ets /tmp/timestep-t09.bak
sed -i '' 's/return Math.floor((Math.floor(epochMs \/ 1000) - t0) \/ period);/return Math.round((Math.floor(epochMs \/ 1000) - t0) \/ period);/' library/src/main/ets/internal/TimeStep.ets
```
真实输出：`Tests run: 176, Failure: 16, Error: 0, Pass: 160`
失败归属：`12 otpEngineTest（RFC 6238 时间点用例，如 rfc6238_sha1_t59 / t1111111109 / t2000000000 / t20000000000 等）+ 4 timeStepTest`。
还原：`cp /tmp/timestep-t09.bak library/src/main/ets/internal/TimeStep.ets`，与 HEAD 无差异。

### ③ fixture 未命中返回零值数组（临时）

```bash
cp library/src/test/HmacFixture.ets /tmp/hmacfixture-t09.bak
# 将 throw new Error('HmacFixture 未命中...') 临时替换为 return new Uint8Array(0);
```
真实输出：`Tests run: 176, Failure: 1, Error: 0, Pass: 175`，唯一失败 `test=fixture_miss_throws`（其余全绿，证明零值数组会让该用例假绿→真实红）。
还原：`cp /tmp/hmacfixture-t09.bak library/src/test/HmacFixture.ets`，恢复 `throw`。

## 5. 偏差与注意点

- **无设计性偏差**：附录 A 全部值照抄、机器比对一致；未补算任何值；未改 `RfcVectors.ets` 数值；未动 `RandomFixture.ets`（T08 所有权）。
- **实现层面的机械性修正（已在 evidence 注明）**：
  - ArkTS 禁止内联对象字面量类型（`arkts-no-obj-literals-as-types`）与未类型化对象字面量（`arkts-no-untyped-obj-literals`）→ `BOUNDARY_COUNTERS` 补 `BoundaryAlg` 具名接口、`SEEDS` 补 `Seeds` 接口、测试参数对象显式标注 `EngineParams`。
  - `Counter/Truncate/Digits/TimeStep` 是**具名函数导出**（非命名空间对象），import 改为按名导入（`toBytes`/`truncateApply`/`formatDigits`/`constantTimeEquals`）。
- **用例展开而非循环注册**：初版用 for 循环注册 `it()`，`grep -c "it("` 只数出 23（运行时 61 条），不满足 AC2 的字面量 ≥45 → 改为逐条显式 `it(`，共 61 行。无注释含 `it(`，计数不虚高。
- **QA ① 首次执行时的 sed 事故**：`s/& 0x0f/& 0x0e/` 中 `&` 被 sed 展开为匹配文本，把行改写为 `& 0x0f 0x0e` 导致编译错误而非测试红点；已用备份还原并用 `s/0x0f/0x0e/` 重做，得到真实红点（Failure 26）。属自证过程，非实现缺陷。
- **T08 并发**：构建/单测期间 git status 出现 T08 的 in-progress 文件（Secret/OTPAuthURI/RandomFixture 等），未触碰、未提交；以「无编译错误 + otpEngineTest Failure: 0」为准。
- **构建三件套**：按共享流程备份→迁移 modelVersion→持 hvigor 锁→还原；`oh-package.json5` 还原后 git 洁净；未改动任何工程配置。

# 2026-10-02 09:15:40

## 编排方（main agent）亲自验证（隔离副本 + node 独立复算全量向量）

**① 隔离副本单测**（`git archive fbd7e84` + `oh_modules` → `/tmp/v-t09`，持 hvigor 锁冷缓存实跑）：
```
EXIT=0
Tests run: 145, Failure: 0, Error: 0, Pass: 145, Ignore: 0
（otpEngineTest 失败项：无）
```
| Acceptance | 命令 | 实测 |
|---|---|---|
| 1. `otpEngineTest` 全绿、用例 ≥45 | `test … -p testType=local` | 61 条全 Success，`Failure: 0` ✓ |
| 2. 用例数 | `grep -c "it(" library/src/test/OtpEngine.test.ets` | **61** ≥45 ✓（含 RFC4226 10 / RFC6238 18 / 边界 18 / 7 位 3 / verify 11 / fixture 未命中 1） |
| 3. 反自证 | `grep -rn "@kit\|cryptoFramework" OtpEngine.test.ets HmacFixture.ets vectors/RfcVectors.ets` | 无输出 ✓ |
| 4. 无占位 | `grep -c "NOT_IMPLEMENTED" internal/OtpEngine.ets` | `0` ✓ |
| 5. 无重复取模 | `grep -n "%" internal/OtpEngine.ets` | **无任何 `%`**（取模仅存在于 `Digits.format` 内）✓ |

**② 编排方独立复算（最强验证，非采信 worker 脚本）**：用 `node` 的 `crypto.createHmac` + 手写动态截断，对 `RfcVectors.ets` 里**每一个数值**重新计算并逐项比对 → **112 项检查，0 项真实不一致**：
- A.2 10 条（digest + code6，2×10=20 项）
- A.3 三算法 ×6 时间点（counter 推导、counterHex、digest、code8，4×18=72 项）
- A.4 3 counter ×3 算法（counterHex、digest、code6、code8，4×9=36 项）
- A.6 digits7 3 条（digest + code7）、A.5 9 条 hex、A.6 SHA256 counter=0（digest + code8）
- 另有 2 项「不一致」经复核是**我自己的检查脚本假设错误**（误以为 base32 位数=字节×8，实际无填充 base32 为 `ceil(bits/5)` 位）→ 已用真实 base32 解码器复核：SHA1/SHA256/SHA512 三算法 **A.1 base32 规范形解码后与 ASCII seed 逐字节相等**（20B/32B/64B，3/3 通过）。
> 结论：向量表既与**计划附录 A**一致（worker 机器比对），也与 **node 独立复算**一致（编排方），且 SHA256 counter=0 的 A.6 digest 已落表并装入 fixture（T10 的 `period=60` 用例不会因查表未命中而误红）。

**③ 内容级审查**：`OtpEngine.generate` = `formatDigits(truncateApply(provider.sign(alg, key, toBytes(counter))), digits)`，**取模只在 `Digits.format` 内一次**；`verify` 用 `firstMatch` 记录首个命中并**继续扫完全部候选**（无提前 return），`candidate < 0 || !isSafeCounter(candidate)` 才 `continue`；token 校验用逐字符 `charCodeAt` 判断（不依赖正则）；`HmacFixture.sign` 查表未命中 `throw new Error('HmacFixture 未命中: …')`（**未返回零值数组**），并有专门用例 `fixture_miss_throws` 锁定该行为；`buildRfcFixture` 覆盖 A.2/A.3/三算法 A.4/A.6 counter=0。
