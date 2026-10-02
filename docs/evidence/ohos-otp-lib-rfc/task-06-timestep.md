# 2026-10-02 08:38:02

## T06 时间步与恒定时间比较（TimeStep）— 实现与验收

任务：`docs/implementation/ohos-otp-lib-rfc.md` W3 todo 6。基线 commit `0a5d04c`，当前 HEAD `e20db38`（T03 脚手架 + bookkeeping）。

### 实现要点

- `library/src/main/ets/internal/TimeStep.ets`（kit-free 纯函数，无 `Date`）：
  - 公共校验 `assertValidInputs(epochMs, t0, period)`：`epochMs` 非有限数或 ≤0 → `INVALID_TIMESTAMP`；`t0` 非整数或 <0 → `INVALID_T0`；`period` 非整数或 ≤0 → `INVALID_PERIOD`。
  - `step = Math.floor((Math.floor(epochMs/1000) - t0) / period)`（RFC 6238 §4.2，t0 单位秒）。
  - `remainingSec`：`const s = Math.floor(epochMs/1000); return period - ((((s - t0) % period) + period) % period);`（按 epoch 秒取模 + t0 偏移 + 负值归一化，落 `[1, period]`）。
  - `progress`：`(((s - t0) % period) + period) % period / period`（落 `[0, 1)`）。
  - `constantTimeEquals`：长度不等立即 `return false`；否则逐字符 `diff |= a.charCodeAt(i) ^ b.charCodeAt(i)`，返回 `diff === 0`；无 `===` 提前返回、无提前 `return true`。
- `library/src/test/TimeStep.test.ets`：27 条 `it(`（≥15），套件名 `timeStepTest`（与 `List.test.ets` 注册一致），非法输入用 hypium `assertThrowError('INVALID_xxx')` 断言固定错误文案。

### 每条断言的 `s = floor(epochMs/1000)` 推导

| 断言 | s | 推导 |
|---|---|---|
| `step(59000,0,30)===1` | 59 | `floor((59-0)/30)=floor(59/30)=1` |
| `step(30000,0,30)===1` | 30 | `floor(30/30)=1` |
| `step(29999,0,30)===0` | 29 | `floor(29/30)=0` |
| `step(20000000000000,0,30)===666666666` | 20000000000 | RFC 6238 最大向量：`floor(20000000000/30)=666666666.66…→666666666` |
| `step(1000,0,30)===0` | 1 | `floor(1/30)=0` |
| `step(31000,1,30)===1` | 31 | `floor((31-1)/30)=floor(30/30)=1` |
| `step(1000,5,30)===-1` | 1 | `floor((1-5)/30)=floor(-0.133…)=-1`（t0>当前秒，负 step，供上层抛 `INVALID_COUNTER`） |
| `remainingSec(59000,0,30)===1` | 59 | `((59%30)+30)%30=29` → `30-29=1`（参照点 s=59,p=30→1） |
| `remainingSec(60000,0,30)===30` | 60 | `((60%30)+30)%30=0` → `30-0=30`（参照点 s=60,p=30→30） |
| `remainingSec(1000,0,30)===29` | 1 | `((1%30)+30)%30=1` → `30-1=29`（参照点 s=1,p=30→29；⚠️ 初审错值 30，正确 29） |
| `remainingSec(1000,0,45)===44` | 1 | `((1%45)+45)%45=1` → `45-1=44`（⚠️ 初审错值 45，正确 44） |
| `remainingSec(45000,0,45)===45` | 45 | `((45%45)+45)%45=0` → `45-0=45`（参照点 s=45,p=45→45） |
| `remainingSec(31000,1,30)===30`（t0≠0） | 31 | `((31-1)%30+30)%30=(0+30)%30=0` → `30-0=30`（参照点 t0≠0） |
| `remainingSec(1000,5,30)===4`（t0≠0） | 1 | `((1-5)%30+30)%30=((-4)+30)%30=26` → `30-26=4`（负值归一化参照点） |
| `progress(15000,0,30)===0.5` | 15 | `((15%30)+30)%30=15` → `15/30=0.5` |
| `progress(1000,0,30)≈1/30` | 1 | `((1%30)+30)%30=1` → `1/30≈0.0333`；相对误差断言 `assertClose(1/30, 1e-6)`（容差理由：1/30 的 JS 浮点除法结果与期望值同源，diff=0，用相对误差 1e-6 覆盖） |
| `progress(45000,0,45)===0` | 45 | `((45%45)+45)%45=0` → `0/45=0` |
| `progress(31000,1,30)===0`（t0≠0） | 31 | `((31-1)%30+30)%30=0` → `0/30=0` |
| `constantTimeEquals` ×5 | — | 同值 true；末位异 true→false；长度不等 false；空串 true；多字节 `'你'` 按 UTF-16 码元异或 true |
| 非法输入 ×4 | — | `step(0,0,30)`→`INVALID_TIMESTAMP`（epochMs=0 不满足 >0）；`step(1,-1,30)`→`INVALID_T0`；`step(1,0,0)`/`step(1,0,1.5)`→`INVALID_PERIOD`（period 非正整数） |

### Acceptance 逐字命令与真实输出

**AC1：单测命令 exit 0，`timeStepTest` 全绿，用例数 ≥ 15**

```bash
$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
```
（前置：`export PATH=...v24.20.0...`、`export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk`、hvigor 全局锁、临时 `sed` 迁移 oh-package.json5 modelVersion 6.0.0→6.1.1）

真实输出（末尾）：
```
> hvigor BUILD SUCCESSFUL in 2 s 338 ms
EXIT_CODE=0
Tests run: 70, Failure: 0, Error: 0, Pass: 70, Ignore: 0
```
用例级结果（`library/.test/default/intermediates/test/coverage_data/test_result.txt`，awk 提取 timeStepTest 27 条）：
```
step59000_0_30 -> result=Success        step30000_0_30 -> result=Success
step29999_0_30 -> result=Success        step20000000000000_0_30 -> result=Success
step1000_0_30 -> result=Success         step31000_1_30 -> result=Success
step1000_5_30_negative -> result=Success
remainingSec59000_0_30 -> result=Success
remainingSec60000_0_30 -> result=Success
remainingSec1000_0_30 -> result=Success
remainingSec1000_0_45 -> result=Success
remainingSec45000_0_45 -> result=Success
remainingSec31000_1_30 -> result=Success
remainingSec1000_5_30 -> result=Success
progress15000_0_30 -> result=Success   progress1000_0_30_close_1over30 -> result=Success
progress45000_0_45 -> result=Success   progress31000_1_30 -> result=Success
constantTimeEquals_same -> result=Success
constantTimeEquals_diff_last_char -> result=Success
constantTimeEquals_diff_length -> result=Success
constantTimeEquals_empty -> result=Success
constantTimeEquals_multibyte -> result=Success
stepInvalidTimestamp -> result=Success  stepInvalidT0 -> result=Success
stepInvalidPeriodZero -> result=Success stepInvalidPeriodFraction -> result=Success
timeStepTest 失败数 = 0
```
> 注：`Tests run: 70` 含 W3 并行其他 worker（T05/T07）当时已写入的真实用例，全部 Pass，无编译错误（并发验收规则：以「无编译错误 + 自己的 timeStepTest 全绿」为准）。

**AC2：`grep -c "it("` ≥ 15**

```bash
$ grep -c "it(" library/src/test/TimeStep.test.ets
27
```

**AC3：无 `Date`**

```bash
$ grep -rn "new Date\|Date.now" library/src/main/ets/internal/TimeStep.ets
（无输出，exit=1）
```

**AC4：无 NOT_IMPLEMENTED**

```bash
$ grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/TimeStep.ets
0
```

### QA failure 场景实测

破坏实现：临时把 `remainingSec` 改成 `return period - (s % period);`（丢掉 `t0` 与负值归一化）。

真实输出（红点，`test_result.txt`）：
```
test=remainingSec31000_1_30
Error in remainingSec31000_1_30, expect 29 equals 30
test=remainingSec1000_5_30
Error in remainingSec1000_5_30, expect 29 equals 4
Tests run: 70, Failure: 2, Error: 0, Pass: 68
```
- todo 指定的红点 `remainingSec(1000,5,30)` 变红：正确 `4` / 破坏实现 `29` ✓。
- 附加红点 `remainingSec(31000,1,30)` 同样变红（`30`/`29`）——两者都是 `t0≠0` 用例；**全部 `t0=0` 用例保持绿**（两种实现在 `t0=0` 时完全等价），与 todo 预判完全一致，证明 `t0≠0` 专项用例的必要性。
- 还原：`cp /tmp/TimeStep.ets.bak library/src/main/ets/internal/TimeStep.ets` 后重跑，`Tests run: 70, Failure: 0, Pass: 70`，全绿。

### 偏差与并发注意

- 无设计性偏差。
- 并发注意（已在 learning 追加）：W3 并发下 4 个 worker 共用 `/tmp/oh-package.json5.bak`，任一 worker 的还原步骤会把 oh-package.json5 覆写回 6.0.0，导致持锁方下一次构建报 00303027。本任务改用唯一备份名 `/tmp/oh-package-t06.bak` 规避；修复轮（QA 后重跑）即因此失败过一次，重做迁移后恢复。
- 其他 worker 的 in-progress 文件（`Counter/Digits/Truncate/CryptoSource` + 各自 test）在 `git status` 中出现，属 W3 并行正常状态，本任务保留不动、不纳入提交。
- `library/.test/.../test_result.txt` 为构建产物且跨运行累积，最终验收前已 `rm -f` 清零以获得权威结果。
