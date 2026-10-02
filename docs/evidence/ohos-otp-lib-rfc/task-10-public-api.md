# 2026-10-02 09:11:16

## T10 公开类（HOTP / TOTP，含时钟偏移）——W5 串行波次

### 实现要点

- `library/src/main/ets/HOTP.ets`：`class HOTP` 完整实现。
  - 构造期同步校验并缓存：`secret` 经 `Secret.fromBase32`；`algorithm` 默认 `SHA1`；`digits` 默认 `6`（`Digits.isValidDigits` 否则 `INVALID_DIGITS`）；`counter` 默认 `0`（`Counter.isSafeCounter` 否则 `INVALID_COUNTER`）；`minSecretBits > 0 && bitLength < minSecretBits` → `SECRET_TOO_WEAK`。
  - `generate(counter?)` 缺省用构造值；`verify(token, options?)` counter 缺省用构造值、window 缺省 0。
  - `toURI()` → `OTPAuthURI.build({type: HOTP, ...})`；`fromURI(uri)` → `OTPAuthURI.parse` → 构造；URI 类型非 hotp 抛 `UNSUPPORTED_OTPAUTH_TYPE`。
  - `provider` 缺省走 `requireHmac()`；第二参注释 `/** @internal 仅供测试注入 */`。
- `library/src/main/ets/TOTP.ets`：`class TOTP` 完整实现。
  - 构造期同 HOTP，另：`period` 默认 30（正整数否则 `INVALID_PERIOD`）、`t0` 默认 0（≥0 整数否则 `INVALID_T0`）、`clockOffsetMs` 默认 0（`Number.isFinite` 否则 `INVALID_TIMESTAMP`）。
  - 所有时间入口统一 `effectiveTs()`：`(timestampMs === undefined ? Date.now() : timestampMs) + this._clockOffsetMs`（显式传入时**也**叠加偏移）。`generate`/`verify`/`remaining`/`progress` 全部走该入口。
  - `syncClockOffset(delta)` 单参数：`delta` 非整数 → `INVALID_WINDOW`；`this._clockOffsetMs -= delta * this._period * 1000;`（**`-=`**，符号依据设计 §3.2 双场景证明表）。
- 两个文件顶层**零 kit / 零 `CryptoSource`** 导入；默认 provider 一律经 `internal/HmacProvider` 的 `requireHmac()`。
- 测试：`Hotp.test.ets`（22 条 `it(`）与 `Totp.test.ets`（44 条 `it(`），均深路径 import 并注入 `HmacFixture`。

### 关键断言推导（每条先推导再落断言）

通用公式：`counter = floor((floor(effectiveMs/1000) - t0) / period)`（RFC 6238 §4.2）。

1. **RFC 4226 10 条 6 位码**：`new HOTP({secret, counter:n}).generate()` → counter=n → A.2 第 n 条 code。
2. **digits=8 / counter=1 → `94287082`**：counter=1 → A.3 SHA1 c1 8 位码。**digits=7 / counter=1 → `4287082`**：A.2 c1 动态截断值的 7 位形态（A.6）。
3. **TOTP RFC 6238 18 条 8 位码**：`generate(timeSec*1000)`，offset=0、t0=0 → `counter = floor(timeSec/30)` = 表内 counter → 对应 code8（SHA256/SHA512 用例必须显式传 `algorithm`，见偏差）。
4. **`generate(59000) === '287082'`（digits=6, period=30）**：`counter = floor(59/30) = 1` → A.2 c1 6 位码。
5. **`remaining(59000) === 1`**：`s=59, period - ((59%30)+30)%30 = 30-29 = 1`（T06 参照点）。
6. **`progress(15000) === 0.5`**：`s=15, ((15%30)+30)%30/30 = 0.5`。
7. **`t0:1, period:30, timestampMs:31000` → counter = floor((floor(31000/1000)-1)/30) = floor((31-1)/30) = 1` → SHA1 c1 8 位码 `94287082`**（A.6；初审坑：曾把毫秒当秒写成 t0=1000）。
8. **`fromURI` period=60（algorithm=SHA256&digits=8&period=60）→ `generate(59000)`：counter = floor(floor(59000/1000)/60) = floor(59/60) = 0` → SHA256 / c0 / 8 位码 `18920136`**（A.6；**不是** `46119246`，那是 counter=1 的值）。
9. **`syncClockOffset` 场景 A（设备快 30s）**：`syncClockOffset(1)` → `clockOffsetMs = 0 - 1*30*1000 = -30000`；`generate(89000)` 有效时间 = `89000 + (-30000) = 59000ms` → `counter = floor(59/30) = 1` → 6 位码 `287082`。断言：`clockOffsetMs === -30000`、`generate(89000) === '287082'`。
10. **`syncClockOffset` 场景 B（设备慢 30s，新建实例）**：`syncClockOffset(-1)` → `clockOffsetMs = 0 - (-1)*30*1000 = +30000`；`generate(59000)` 有效时间 = `59000 + 30000 = 89000ms` → `counter = floor(89/30) = 2` → 6 位码 `359152`（A.2 c2）。断言：`clockOffsetMs === 30000`、`generate(59000) === '359152'`。
    - 反证（设计 §3.2）：若用 `+=`，场景 A 得 offset=+30000 → `generate(89000)` 有效时间 119s → counter 3，必然算错——QA① 实测 3 条红。
11. **verify 系列**（T09 同语义走公开类）：
    - `verify('287082', {timestamp:59000})` → base counter 1、window 0 → delta 0。
    - `verify('755224', {timestamp:59000})` → 只查 c1，c0 码不命中 → null。
    - `verify('287082', {timestamp:89000, window:1})` → base counter 2、候选 1/2/3 → c1 命中 → delta -1。
    - `verify('287082', {timestamp:1000, window:1})` → base counter 0、候选 -1(跳过)/0/1 → c1 命中 → delta +1。
    - `verify_appliesClockOffset`：`syncClockOffset(1)` 后 `verify('287082', {timestamp:89000})` → 有效时间 59000 → base counter 1 → delta 0（证明显式传 timestamp 也叠加偏移）。

### fixture 查表缺口核对

本任务用到的全部 (algorithm, counter) 组合：SHA1 {0..9, 1, 37037036, 37037037, 41152263, 66666666, 666666666}、SHA256 {0(A.6), 1, 37037036, 37037037, 41152263, 66666666, 666666666}、SHA512 {1, 37037036, 37037037, 41152263, 66666666, 666666666}——全部在 `RfcVectors` 内，`HmacFixture` 查表**零未命中**（若未命中 fixture 会主动抛错，用例必红；未出现）。

### Acceptance 逐字命令与真实输出

```bash
$ HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local   # HB_EXIT=0
$ grep -E "^Tests run" library/.test/default/intermediates/test/coverage_data/test_result.txt
Tests run: 240, Failure: 0, Error: 0, Pass: 240, Ignore: 0
# 两套件用例级（class=/test=/result= 明细）：
hotpTest: cases=22 failures=0
totpTest: cases=44 failures=0

$ grep -c "it(" library/src/test/Hotp.test.ets   # → 22（≥ 15 ✓）
$ grep -c "it(" library/src/test/Totp.test.ets   # → 44（≥ 30 ✓）
$ grep -rn "@kit\.\|CryptoSource" library/src/main/ets/HOTP.ets library/src/main/ets/TOTP.ets   # → 无输出（exit 1）✓
$ grep -c "NOT_IMPLEMENTED" library/src/main/ets/HOTP.ets library/src/main/ets/TOTP.ets
library/src/main/ets/HOTP.ets:0
library/src/main/ets/TOTP.ets:0
$ grep -c "syncClockOffset" library/src/test/Totp.test.ets   # → 10（≥ 2 ✓）
```

QA happy 全链路（公开 API）：`new TOTP({secret:'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', digits:8}, fixture).generate(59000) === '94287082'` —— 对应 `totpTest.public_api_full_chain` 用例，Pass。

### QA failure 红点实测与还原

**QA①（符号错误灵敏度）**：临时把 `syncClockOffset` 的 `-=` 改为 `+=`：

```text
Tests run: 240, Failure: 3, Error: 0, Pass: 237
test=verify_appliesClockOffset        result=Failure
test=syncClockOffset_scenarioA_fastClock  result=Failure
test=syncClockOffset_scenarioB_slowClock  result=Failure
```

3 条红点命中（正是抓符号错误的用例），随后还原为 `-=`。

**QA②（构造期校验灵敏度）**：临时把 HOTP/TOTP 构造器里的 `isValidDigits(digits)` 校验改为恒假（惰性化）：

```text
Tests run: 240, Failure: 2, Error: 0, Pass: 238
test=ctor_digits5_throws        result=Failure   # hotpTest
test=ctor_digits5_throws        result=Failure   # totpTest
```

2 条红点命中（两套件各 1），随后还原。还原后全量复跑 `Tests run: 240, Failure: 0, Pass: 240`，`git diff` 无 QA 残留标记。

### 偏差

1. **测试 bug 首轮自修（不属设计性偏差）**：初版 TOTP 的 SHA256/SHA512 用例漏传 `algorithm`（默认 SHA1），与 S256/S512 secret 不匹配，6+6 条失败；已补 `algorithm: OtpAlgorithm.SHA256/SHA512` 后全绿。
2. **`fromURI` 的 provider 来源**：按 todo 的 API 签名 `static fromURI(uri: string)` 不含 provider 参数，`fromURI` 构造实例走默认 `requireHmac()`。本地测试通过 `registerHmac(fixture)`（深路径 import `internal/HmacProvider`）注册默认 provider 兜底（对 `fromURI` 产物生效；直接 `new TOTP({...}, fixture)` 仍走显式注入）。这是测试侧的 seam 使用，不改公开 API 形态。已确认无其他套件依赖 `requireHmac()` 未注册抛错（仅 OtpError.test 校验枚举值）。
3. **`syncClockOffset` 非整数 → `INVALID_WINDOW`**：todo 要求写进 evidence——已实现并有用例 `syncClockOffset_nonInteger_throws`（delta=1.5 → INVALID_WINDOW）。
4. **toURI 逐字断言**：HOTP `otpauth://hotp/?secret=…&algorithm=SHA1&counter=0`（digits 默认 6 省略、HOTP 恒输出 counter）；TOTP `otpauth://totp/?secret=…&algorithm=SHA1&digits=8`（period 默认 30 省略）——与 T08 build 惯例一致。
5. **QA ② 的演示口径**：构造期校验有 5 类（digits/period/t0/clockOffset/minSecretBits），本次演示移除 digits 校验即让两套件的 `ctor_digits5_throws` 红（足以证明「构造期抛错用例」的灵敏度）；其余校验类用例同构，未逐一破坏。

# 2026-10-02 11:05:30

## 编排方（main agent）亲自验证（隔离副本 commit `df5d524` + 两处破坏-变红）

**方法**：`git archive df5d524` + `oh_modules` → `/tmp/v-t10`，持 hvigor 锁冷缓存实跑（判据 = `test_result.txt` 的 `Failure` 计数）。

| Acceptance | 命令 | 实测 |
|---|---|---|
| 1. 两套件全绿 | `test … -p testType=local` | `Tests run: 240, Failure: 0, Error: 0, Pass: 240`（`hotpTest` 22、`totpTest` 44 全 Success）✓ |
| 2. 用例数 | `grep -c "it("` | Hotp **22** ≥15 ✓；Totp **44** ≥30 ✓ |
| 3. 无 kit/CryptoSource | `grep -rn "@kit\.\|CryptoSource" HOTP.ets TOTP.ets` | 无输出 ✓ |
| 4. 无占位 | `grep -c "NOT_IMPLEMENTED"` | `0 / 0` ✓ |
| 5. `syncClockOffset` 双场景 | `grep -c "syncClockOffset" Totp.test.ets` | **10** ≥2 ✓ |

**内容级审查（逐条对照设计 §3.2）**：
- `TOTP`：构造期同步校验 `digits`（`isValidDigits`→`INVALID_DIGITS`）、`period` 正整数（→`INVALID_PERIOD`）、`t0` ≥0 整数（→`INVALID_T0`）、`clockOffsetMs` 有限数（→`INVALID_TIMESTAMP`）、`minSecretBits>0 && bitLength<minSecretBits`（→`SECRET_TOO_WEAK`）；字段全部 `readonly`，`_clockOffsetMs` 可变；`effectiveTs()` 统一 `(timestampMs ?? Date.now()) + _clockOffsetMs` —— **`generate`/`remaining`/`progress`/`verify` 四条时间入口全部叠加偏移**（`verify` 内显式写了 `baseTs + _clockOffsetMs`）✓。
- **`syncClockOffset(delta)` 符号正确**：`this._clockOffsetMs -= delta * period * 1000`（与设计 §3.2 双场景表一致：delta=+1 → −30000）。非整数 → `INVALID_WINDOW` ✓。
- `HOTP`：`counter` 经 `Counter.isSafeCounter` 校验（→`INVALID_COUNTER`）；`generate/verify` 缺省用构造 counter；`window` 缺省 0 ✓。
- `toURI()` 均走 `OTPAuthURI.build`（TOTP 带 period、HOTP 带 counter）；`fromURI` 类型不匹配抛 `UNSUPPORTED_OTPAUTH_TYPE` ✓；两文件零 kit 依赖、无缓存 provider 结果/码、未改 `Index.ets`。

**编排方独立破坏实验**：
1. `syncClockOffset` 的 `-=` 改 `+=` → `Failure: 3`（双场景 + verify 偏移用例变红）✓ —— 证明该用例能抓住历史上的符号错误。
2. 去掉 `HOTP`/`TOTP` 构造期 `digits` 校验 → `Failure: 2`（`ctor_digits5_throws` 类用例变红）✓ —— 证明「构造期即抛错」被真实锁定。
   两处均随后还原并复跑至 `Failure: 0`（240/240）✓

**接受 worker 的偏差处理**：`fromURI(uri)` 签名不含 `provider`（设计 §3.2 即如此），本地用例通过 `registerHmac(fixture)` 走注册表兜底——**符合注册表契约**；分支 B 下默认 provider 的真实 crypto 链路由 T11 设备用例覆盖（本任务不伪报）。
