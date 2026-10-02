# 2026-10-02 08:38:25

## 任务
T05：整数原语（Counter / Truncate / Digits）。W3 并行波次（与 T04/T06/T07 并发）。

## 实现要点

- `library/src/main/ets/internal/Counter.ets`：
  - `isSafeCounter(value)` = `Number.isInteger(value) && value >= 0 && value <= Number.MAX_SAFE_INTEGER`。
  - `toBytes(counter)`：非法抛 `INVALID_COUNTER`；`high = Math.floor(counter / 4294967296)`、`low = counter % 4294967296`；8 字节大端，逐字节用 `>>>` 与 `& 0xff` 取值（继承旧 `Totp.ets:82-96` 的历史坑：不用 `<<` 拼 32 位——JS/ArkTS 位运算按 32 位有符号整数处理）。
- `library/src/main/ets/internal/Truncate.ets`：`digest.length < 20` 抛 `CRYPTO_FAILED`（固定文案，不含 digest 内容）；`offset = digest[digest.length-1] & 0x0f`；`v = ((digest[offset] & 0x7f) << 24 | digest[offset+1] << 16 | digest[offset+2] << 8 | digest[offset+3]) >>> 0`；**只做截断，不做取模**（取模只在 `Digits`）。
- `library/src/main/ets/internal/Digits.ets`：`isValidDigits(d)` = `d === 6 || d === 7 || d === 8`；`format(value, digits)` 非法抛 `INVALID_DIGITS`，否则 `String(value % Math.pow(10, digits))` 用**手写前置 '0' 循环**补零至 `digits` 位（不依赖运行时字符串补位 API，继承旧 `Totp.ets:115-121` 的零填充方式）。

## 派生量推导过程

本任务全部期望值均来自执行计划附录 A.2/A.5/A.6 的**权威表值**，逐字照抄，无自行推导量：

- **Counter 9 行**：逐字照抄附录 A.5（`counterToBytes` 对照表，与 `writeBigUInt64BE` 参考实现逐位一致）。
- **Truncate 10 行**：逐字照抄附录 A.2 第 4 列（RFC 4226 Appendix D 权威中间值）。**禁止用 digest 自行推导**——推导会与被测实现同源，变成自证。
- **Digits 7 行**：逐字照抄附录 A.2/A.6 的权威码值（`value % 10^digits` 后左补零）。
- 唯一需要说明的取模关系（不构成推导）：`84755224 = 84755224 % 10^8`、`37359152 = 137359152 % 10^8`、`4287082 = 4287082 % 10^7`——这些在 A.6 表中已给出等价关系（`137359152 % 10^8`），照抄。

## 实现正确性预检（node，非测试推导）

写测试前先用 node 按**与被测实现相同的公式**对附录表值做独立复核（仅验证实现正确性，测试期望值仍照抄附录原文）：
- Truncate 10 条 digest → 10 条全部 PASS（含 `& 0x7f` 与 `>>> 0`）。
- Counter 9 行 hex → 9 条全部 PASS。
- Digits 7 条 → 7 条全部 PASS。
- 合计 26/26 PASS。（脚本 `/tmp/check_truncate.js`）

## Acceptance 逐条验证

### AC1：`<T02 单测命令>` exit 0，`counterTest`/`truncateTest`/`digitsTest` 全绿

命令（统一四件套，持 hvigor 全局锁）：
```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
# 持锁 → cp oh-package.json5 /tmp/oh-package.json5.bak → sed 迁移 6.0.0→6.1.1
$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
# 还原 oh-package.json5 + rm BuildProfile.ets + rmdir 锁
```
真实输出（最终干净复跑 `final_clean`）：
```
> hvigor BUILD SUCCESSFUL in 2 s 243 ms
Tests run: 70, Failure: 0, Error: 0, Pass: 70, Ignore: 0
```
用例级结果（`library/.test/default/intermediates/test/coverage_data/test_result.txt`）：
- `counterTest`：14/14 `result=Success`（9 行 A.5 逐字节 + `-1`/`1.5`/`9007199254740992`→`INVALID_COUNTER` + `isSafeCounter` 正反例）。
- `truncateTest`：11/11 `result=Success`（A.2 全部 10 条 + 长度 19 → `CRYPTO_FAILED`）。
- `digitsTest`：10/10 `result=Success`（7 条 format + `format(1,5)`/`format(1,9)`→`INVALID_DIGITS` + `isValidDigits`）。

> 并发说明：首次跑（08:36:45）时 T06 worker 正在编辑 `TimeStep.test.ets`，出现 2 条 `timeStepTest` 失败（`remainingSec31000_1_30`/`remainingSec1000_5_30`，非本任务文件）。按并发约定以「无编译错误 + 自己 3 套件全绿」为准；最终复跑 T06 已修复，全 70 条通过。

### AC2：`grep -rn "padStart" library/src/main/ets/internal/Digits.ets` → 无输出

```
$ grep -rn "padStart" library/src/main/ets/internal/Digits.ets
（无输出，exit=1）
```
> 首版注释写了「不依赖 padStart」被字面 grep 命中（learning 已知坑：验收 grep 纯字面匹配，注释也算）。已改写注释为「不依赖运行时字符串补位 API」后清零。

### AC3：`grep -c "NOT_IMPLEMENTED"` 三个文件 → 0

```
$ grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/Counter.ets library/src/main/ets/internal/Truncate.ets library/src/main/ets/internal/Digits.ets
library/src/main/ets/internal/Counter.ets:0
library/src/main/ets/internal/Truncate.ets:0
library/src/main/ets/internal/Digits.ets:0
```

### AC4：`it(` 计数

```
$ grep -c "it(" library/src/test/Counter.test.ets   → 14（≥ 12 ✓）
$ grep -c "it(" library/src/test/Truncate.test.ets  → 11（≥ 11 ✓）
$ grep -c "it(" library/src/test/Digits.test.ets    → 10（≥ 8  ✓）
```

## QA failure 三红点实测（均已记录输出后还原）

### 红点①：`Counter.toBytes` 的 `high` 改成 `counter >> 32`
变更：`high: number = Math.floor(counter / UINT32)` → `high: number = counter >> 32`。
hvigor 原始输出（`/tmp/qa_qa1_counter_shift.log`，全量 70 条 `Failure: 9`，其中 counterTest 7 条）：
```
hvigor ERROR: Error in toBytes(1) 逐字节 == 0000000000000001, expect 1 equals 0
hvigor ERROR: Error in toBytes(9) 逐字节 == 0000000000000009, expect 9 equals 0
hvigor ERROR: Error in toBytes(666666666) 逐字节 == 0000000027bc86aa, expect 39 equals 0
hvigor ERROR: Error in toBytes(4294967295) 逐字节 == 00000000ffffffff, expect 255 equals 0
hvigor ERROR: Error in toBytes(4294967296) 逐字节 == 0000000100000000, expect 0 equals 1
hvigor ERROR: Error in toBytes(4294967391) 逐字节 == 000000010000005f, expect 95 equals 1
hvigor ERROR: Error in toBytes(9007199254740991) 逐字节 == 001fffffffffffff, expect 255 equals 0
```
（另 2 条为该时刻 T06 未完成的 `remainingSec` 失败，与本任务无关。）已还原为 `Math.floor(counter / UINT32)`。

### 红点②：去掉 `Truncate` 的 `& 0x7f`
变更：`(digest[offset] & 0x7f) << 24` → `(digest[offset]) << 24`。
hvigor 原始输出（`/tmp/qa_qa2_truncate_mask.log`，`Failure: 4`，均为 truncateTest；命中 `digest[offset] >= 0x80` 的 4 条）：
```
hvigor ERROR: Error in counter=0 digest → 1284755224, expect 3432238872 equals 1284755224
hvigor ERROR: Error in counter=1 digest → 1094287082, expect 3241770730 equals 1094287082
hvigor ERROR: Error in counter=3 digest → 1726969429, expect 3874453077 equals 1726969429
hvigor ERROR: Error in counter=9 digest → 645520489, expect 2793004137 equals 645520489
```
已还原为 `(digest[offset] & 0x7f) << 24`。

### 红点③：`Digits.format` 的取模换成 `value`
变更：`String(value % Math.pow(10, digits))` → `String(value)`。
hvigor 原始输出（`/tmp/qa_qa3_digits_modulo.log`，`Failure: 1`）：
```
hvigor ERROR: Error in format(137359152,8) === 37359152, expect 137359152 equals 37359152
```
已还原为 `String(value % Math.pow(10, digits))`。

### 还原后复跑
`final_clean`：`Tests run: 70, Failure: 0, Error: 0, Pass: 70`，三个套件全绿，确认还原彻底。

## 越界检查与偏差

- **无设计性偏差**。
- 唯一偏差为机械性修正：`Digits.ets` 注释措辞（去掉字面 `padStart` 字样）以通过 AC2 字面 grep——已在本节记录，不影响实现。
- `git status --short` 存在其他 worker 的文件（`TimeStep.ets`/`TimeStep.test.ets` 属 T06、`CryptoSource.ets`/`CryptoSource.test.ets` 属 T07），**保留不动**；本次只 add 本任务 6 个文件 + 本 evidence。
- 构建期间根 `oh-package.json5` 一度被 git 标记 modified，实为 stat-cache 陈旧（MD5 与 HEAD 完全一致），`touch` 后洁净；未做任何工程配置改动。
- 未执行任何 push / remote / reset 操作。
