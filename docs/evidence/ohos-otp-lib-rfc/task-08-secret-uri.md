# 2026-10-02 08:57:21

## T08 Secret 与 OTPAuth URI（规范化层）证据

任务：W4（与 T09 并发）。实现 `Secret.ets`、`OTPAuthURI.ets`，补实现 `RandomFixture.ets`（唯一所有者 T08），写 `Secret.test.ets`/`OtpAuthUri.test.ets`/`OtpError.test.ets`。

### 实现要点

**`Secret.ets`（kit-free，禁止 import kit 与 CryptoSource）**
- `fromBase32(input)` → `Base32.decode`（宽松：大小写/空白/填充）；解码结果长度 0 抛 `EMPTY_SECRET`（decode 对空串本身抛该码，此处兜底防御）。
- `fromBytes(bytes)` → 空数组抛 `EMPTY_SECRET`；**必须拷贝**入参 `new Uint8Array(bytes)`，杜绝外部引用共享。
- `generate(bytes = 20)` → 形参名已按交接项从 `byteLength` 改回 `bytes`（与设计 §3.2 一致，签名语义不变）；校验 `Number.isInteger(bytes) && bytes >= 1 && bytes <= 4096`，否则抛 `SECRET_TOO_WEAK`；取值经 `requireRandom().random(bytes)`（注册表取用，不 import kit）。
  - **`SECRET_TOO_WEAK` 错误码选择理由**：① `internal/CryptoSource.ets` 的 `CryptoFrameworkRandom.random`（T07 已实现）对**完全相同的边界**（`Number.isInteger && 1..4096`）使用同一错误码，本层保持一致可让调用方对「随机强度不足」统一分支；② 设计 §3.3 统一约束表把「强度不足（minSecretBits 违规）」归入 `SECRET_TOO_WEAK`，随机长度越界同属「强度不足」语义，故沿用该码而非新增或复用 `INVALID_COUNTER` 之类。
- `bytes` getter **返回拷贝**（`new Uint8Array(_bytes)`）；`byteLength`/`bitLength` 直读；`toBase32()` 用 `Base32.encode`（大写无填充）；`toJSON()` 返回固定 `'[REDACTED]'`（T02 已实测 `JSON.stringify` 会调用 `toJSON()`，且 `private` 字段运行期仍可枚举，这是唯一可单测的堵漏手段）。
- **刻意不实现 `toString()`**：`String(secret)` 将落到 `'[object Object]'`，两者都不含明文；避免模板字符串/日志把密钥暴露（文件头注释已写明「不实现」）。

**`OTPAuthURI.ets`（kit-free，纯解析层）**
- `parse`：① 大小写不敏感匹配 `otpauth://` 前缀（`uri.toLowerCase().indexOf(prefix) !== 0` 抛 `INVALID_OTPAUTH_URI`）；② type 取 `?` 前、`/` 后并 `toLowerCase()`，非 totp/hotp 抛 `UNSUPPORTED_OTPAUTH_TYPE`；③ label 取 `/` 后、`?` 前并 `decodeURIComponent`（失败回退原串），按解码后首个 `:` 切 issuer/account，解码失败回退时兼容 `%3A` 分隔（只切第一个分隔符）；④ query 手写拆分（`&` 分段、`=` 分键值、键值都 `decodeURIComponent` 失败回退，**未用 URL 查询解析 API**）；⑤ 字段按设计 §3.4 表：未知参数忽略、secret 必填经 `Base32.decode` 校验、algorithm 大小写不敏感映射（SHA1/256/512 否则 `INVALID_ALGORITHM`）、digits 默认 6（仅 6/7/8 否则 `INVALID_DIGITS`）、period 默认 30（仅 TOTP，正整数否则 `INVALID_PERIOD`）、counter 默认 0（仅 HOTP，非负整数否则 `INVALID_COUNTER`）；⑥ 返回 secret 为 `encode(decode(raw))` 规范化大写无填充 base32；⑦ query 的 issuer 与 label 前缀不一致时以 query 为准。
- `build`：输出 `otpauth://<type>/<label>?...`；label 形如 `issuer:account`（两者 `encodeURIComponent`、冒号保留，issuer/account 为空省略对应部分）；参数顺序固定 `secret, issuer, algorithm, digits, period|counter`；`algorithm` 始终显式输出。
  - **省略 digits/period 默认值的 GA 惯例依据**：Google Authenticator 生成的 otpauth URI 只在参数值与默认值不同时输出（默认 `algorithm=SHA1`/`digits=6`/`period=30` 不输出），以保持 URI 简洁与互操作；本实现采用同一惯例：`digits` 仅 `!= 6` 输出、`period` 仅 TOTP 且 `!= 30` 输出。HOTP 的 `counter` 是规范必填参数，始终输出（含默认 0）。
- `parse(build(p))` 与 `p` 语义等价（round-trip 用例覆盖 TOTP 全字段 / HOTP / 仅必填字段三类）。

**`RandomFixture.ets`（本文件唯一所有者 T08，T09 未动）**
- `random(bytes)` 返回 `bytes` 个连续字节 `0x00,0x01,…`（`i & 0xff`）；`lastRequestedBytes` 记录最近一次请求长度供断言。

### Acceptance 逐项验证

单测命令（唯一可信判据 = `test_result.txt` 的 Failure 计数，hvigor exit code 不可信）：

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
# 持 hvigor 全局锁（W4 与 T09 并发，等锁约 50s 后获取）
$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
```

最终全绿输出（QA 还原后复跑，08:56:57）：

```
> hvigor BUILD SUCCESSFUL in 2 s 307 ms
Tests run: 176, Failure: 0, Error: 0, Pass: 176, Ignore: 0
```

3 个套件用例级结果（`test_result.txt`，T09 的 otpEngineTest 61 条同轮全绿）：

```
secretTest:     10 用例, Failures=0
otpAuthUriTest: 20 用例, Failures=0
otpErrorTest:    4 用例, Failures=0
```

各验收 grep（最终态实测）：

| 验收 | 命令 | 结果 |
|---|---|---|
| AC-1 | `grep -rn "URLSearchParams\|@kit\." library/src/main/ets/Secret.ets library/src/main/ets/OTPAuthURI.ets` | 无输出（exit 1）✓ |
| AC-2 | `grep -n "toString" library/src/main/ets/Secret.ets` | 仅第 6 行注释「刻意不实现 toString()…」，无方法定义 ✓ |
| AC-3 | `grep -c "it(" OtpAuthUri.test.ets` / `OtpError.test.ets` | 20 ≥ 18 / 4 ≥ 4 ✓ |
| AC-4 | `grep -c "random(\|lastRequestedBytes" RandomFixture.ets` | 4 ≥ 2（真实实现，非占位）✓ |
| AC-5 | `grep -c "NOT_IMPLEMENTED" Secret.ets OTPAuthURI.ets` | 0 / 0 ✓ |
| AC-6 | `<单测命令>` | exit 0 + `Failure: 0` ✓ |

### QA failure 两个红点实测与还原

**QA① 去掉 parse 的 digits 校验（允许 digits=5）**：临时把 OTPAuthURI.ets 的校验条件改成恒假 `d === -999`（digits=5 不再抛错）。复跑（08:56:07）：

```
Tests run: 176, Failure: 1, Error: 0, Pass: 175, Ignore: 0
test=parse_failInvalidDigits
Error in parse_failInvalidDigits, expect true, actualValue is false
```

红点 = `parse_failInvalidDigits`（不再抛 `INVALID_DIGITS`，`expectThrowsCode` 的 thrown 断言失败），且**仅此 1 条**变红（digits=8/默认 6 用例不受影响）。已还原校验条件并复跑全绿。

**QA② 临时删掉 `Secret.toJSON()`**：把方法体注释掉（方法不存在）。复跑（08:56:30）：

```
Tests run: 176, Failure: 1, Error: 0, Pass: 175, Ignore: 0
test=jsonStringify_redactsSecret
Error in jsonStringify_redactsSecret, -1 is not larger than 0
```

红点 = `jsonStringify_redactsSecret`（`JSON.stringify` 不再含 `[REDACTED]`，`indexOf('[REDACTED]')` = -1）；紧邻的 `stringConversion_doesNotLeakSecret` 仍绿（无 toString 时 `String(secret)`='[object Object]'，本就不含明文，符合设计预期）。已还原 `toJSON()` 并复跑全绿（176/176）。

### 偏差

- 无设计性偏差。`OtpError instanceof` 双真（Error + OtpError）实测通过，无需改错误模型。
- 说明性取舍（非偏差，已在实现要点记录）：
  1. parse 把解码后的 label 一并写入 `result.label`（接口含该可选字段，便于消费方读取完整 label）；build 只从 issuer/account 重建 label，不读 `label` 字段——round-trip 语义等价以 type/secret/algorithm/digits/period/counter/issuer/account 为准（TOTP 缺省 period=30、HOTP 缺省 counter=0 视为等价，见 `assertParamsEqual` 的缺省归一化）。
  2. query 参数键存储时统一 `toLowerCase()`（容忍 `Secret=` 之类大小写），值保留原义。
- 工程配置还原：`oh-package.json5` 已恢复 6.0.0（与 HEAD 一致），无 `library/BuildProfile.ets` 残留，hvigor/git 锁均已释放。

### Commit

`git add library/src/main/ets/Secret.ets library/src/main/ets/OTPAuthURI.ets library/src/test/RandomFixture.ets library/src/test/Secret.test.ets library/src/test/OtpAuthUri.test.ets library/src/test/OtpError.test.ets docs/evidence/ohos-otp-lib-rfc/task-08-secret-uri.md`
`git commit -m "feat(otp): 实现 Secret 规范化/校验/生成/脱敏与 OTPAuth URI 解析生成"`

# 2026-10-02 09:40:20

## 编排方（main agent）亲自验证（隔离副本 commit `72d0e92` + 两处破坏-变红）

**方法**：`git archive 72d0e92` + `oh_modules` → `/tmp/v-t08`，持 hvigor 锁冷缓存实跑（**判据用 `test_result.txt` 的 `Failure` 计数，不用 exit code**）。

| Acceptance | 命令 | 实测 |
|---|---|---|
| 1. 3 套件全绿 | `test … -p testType=local` | `Tests run: 176, Failure: 0, Error: 0, Pass: 176`（`secretTest` 10、`otpAuthUriTest` 20、`otpErrorTest` 4 全 Success）✓ |
| 2. 无 `URLSearchParams`/kit | `grep -rn "URLSearchParams\|@kit\." Secret.ets OTPAuthURI.ets` | 无输出 ✓ |
| 3. 无明文 `toString()` | `grep -n "toString" Secret.ets` | 仅第 6 行**注释**说明「刻意不实现 `toString()`」，无方法定义 ✓ |
| 4. 用例数 | `grep -c "it("` | `OtpAuthUri.test.ets` **20** ≥18 ✓；`OtpError.test.ets` **4** ≥4 ✓ |
| 5. `RandomFixture` 已真实实现 | `grep -c "random(\|lastRequestedBytes" RandomFixture.ets` | **4** ≥2 ✓（`lastRequestedBytes` 记录 + 递增字节序列，非 T03 占位） |
| 6. 无占位 | `grep -c "NOT_IMPLEMENTED" Secret.ets OTPAuthURI.ets` | `0 / 0` ✓ |

**内容级审查**：
- `Secret`：`fromBytes` 用 `new Uint8Array(bytes)` 拷贝入参、`get bytes()` 返回拷贝、`generate(bytes)` 已按设计 §3.2 把形参名从 `byteLength` 改回 **`bytes`**（T03 交接项闭环）、`toJSON()` 返回 `'[REDACTED]'`、**无 `toString()`**、错误消息全为固定文案（无密钥拼接）、随机源经 `requireRandom()`（未 import kit）。
- `OTPAuthURI.parse`：scheme 大小写不敏感；type 小写化并限定 `totp`/`hotp`；label 先 `decodeURIComponent`（`try/catch` 回退原串）再切首个冒号，回退路径兼容 `%3A`；query 手写 `&`/`=` 拆分（**未用 `URLSearchParams`**）；未知参数忽略；`secret` 经 `decode`+`encode` 规范化成大写无填充 base32；`algorithm` 大小写不敏感映射否则 `INVALID_ALGORITHM`；`period`/`counter` 按 type 分支读取并校验；**query `issuer` 优先于 label 前缀**；`type` 字段用 `OtpType` 枚举输出。
- `OTPAuthURI.build`：参数顺序固定 `secret, issuer, algorithm, digits, period|counter`；`algorithm` 始终输出；`digits != 6` 才输出；TOTP `period != 30` 才输出；HOTP 始终输出 `counter`；label 两部分各自 `encodeURIComponent` 且冒号保留；为空方省略。

**编排方独立破坏实验（两处 red 点均被抓住）**：
1. 去掉 `digits` 的 6/7/8 校验 → `Failure: 1`（`INVALID_DIGITS` 用例变红）✓
2. 删掉 `Secret.toJSON()` → `Failure: 1`（脱敏用例变红）✓
   两处均随后还原并**复跑至 `Failure: 0`**（176/176）✓
