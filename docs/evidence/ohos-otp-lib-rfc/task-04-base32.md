# 2026-10-02 08:45:02

## 任务 T04：RFC 4648 Base32 编解码（W3 并行波次）

### 实现要点

`library/src/main/ets/internal/Base32.ets`（kit-free 纯函数）：

- 字母表常量 `BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'`（RFC 4648 §6，索引 26-31 对应 `2`-`7`）。
- `decode(input: string): Uint8Array`：
  - 归一化：`replace(/\s/g,'')` → `replace(/=+$/,'')`（只去**尾部** `=`）→ `toUpperCase()`。
  - 空串 → `OtpError(EMPTY_SECRET)`；逐字符查字母表，非法字符 → `OtpError(INVALID_BASE32_CHAR)`；`Math.floor(len*5/8) === 0` → `OtpError(SECRET_TOO_SHORT)`。
  - 按 8 字符一组解码，缺位补 0，位拼接公式沿用旧实现 `Totp.ets:15-76`（`buf[0]<<3|buf[1]>>2`、`buf[1]<<6|buf[2]<<1|buf[3]>>4`、`buf[3]<<4|buf[4]>>1`、`buf[4]<<7|buf[5]<<2|buf[6]>>3`、`buf[6]<<5|buf[7]`），每字节 `& 0xff`；末组按 `floor(groupLen*5/8)` 截断。
  - 错误消息 = 错误码字符串本身（与 `TimeStep.ets` 既有风格一致），不携带任何 secret 内容。
- `encode(bytes: Uint8Array): string`：
  - 位缓冲实现（8 位进 / 5 位出，`buffer >>> (bitsLeft-5) & 31` 取组、末尾 `buffer << (5-bitsLeft) & 31` 补零），**不用**逐字符拼二进制字符串、**不用** `padStart`（规避 ArkTS 兼容性不确定性，旧 `Totp.ets:114` 同款历史坑）。
  - 输出大写、无填充；空数组返回 `''`（不抛错）。

`library/src/test/Base32.test.ets`：`export default function base32Test()` + `describe('base32Test', ...)`，16 个用例（验收要求 ≥12），含模块级辅助函数 `expectThrowsCode`（try/catch 捕获后断言 `err.code` 精确匹配，比 hypium `assertThrowError` 的消息包含匹配更严格）、`asciiBytes`、`bytesEqual`。

### 派生量推导过程（先推导后落断言）

1. **`decode` 输出字节数 = `floor(len*5/8)`**：每个 base32 字符携带 5 bit，总位数 `len*5`，每 8 bit 一个字节；末组不足 8 bit 的余量按 RFC 4648 截断丢弃 → `floor(len*5/8)`。`'A'`（1 字符）：`floor(5/8)=0` → `SECRET_TOO_SHORT`。
2. **`encode` 输出字符数 = `ceil(len*8/5)`**：`len` 字节共 `len*8` bit，每个字符带走 5 bit，末组不足 5 bit 以 0 补齐（无填充）→ `ceil(len*8/5)`。用例断言：20 字节 → `ceil(160/5)=32`；32 字节 → `ceil(256/5)=52`；64 字节 → `ceil(512/5)=103`。
3. **`'MY'` → 1 字节 `0x66`**：`M`=索引 12、`Y`=索引 24；组内 `floor(2*5/8)=1` 字节；`(12<<3 | 24>>2) & 0xff = (96|6) = 102 = 0x66`。
4. **round-trip 长度 1..8 精确还原**：`n` 字节 → `ceil(8n/5)` 字符 → 再解码 `floor(ceil(8n/5)*5/8)`，对 n=1..8 逐一为 n（1→2→1、2→4→2、3→5→3、4→7→4、5→8→5、6→10→6、7→12→7、8→13→8）；encode 的末组补零位与 decode 的截断语义互逆，故逐字节还原。
5. **A.1 各 base32 规范形字符数**：SHA1=16 字符（20 字节）；SHA256 规范形 52 字符（`16*3+4`）；SHA512 规范形 103 字符（`16*6+7`）——与公式 2 一致。

### Acceptance 逐条验证

**AC1：`<T02 单测命令>` exit 0，`base32Test` 全绿，用例数 ≥ 12**

命令（T03 统一构建流程：临时迁移 modelVersion + 持 hvigor 全局锁 + 事后还原）：

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd /Users/yansongda/000-Coding/ohos-otp
# LOCKDIR=/tmp/ohos-otp-hvigor.lock 获取成功（LOCK-ACQUIRED）
cp oh-package.json5 /tmp/oh-package.json5.bak && sed -i '' 's/"modelVersion": "6.0.0"/"modelVersion": "6.1.1"/' oh-package.json5
$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
```

真实输出（tail）：

```
> hvigor Finished :library:default@UnitTestArkTS... after 1 s 59 ms
> hvigor Finished :library:test... after 1 ms
> hvigor BUILD SUCCESSFUL in 2 s 358 ms
EXIT=0
```

用例级结果（`library/.test/default/intermediates/test/coverage_data/test_result.txt`，base32Test 16 个用例全部 `result=Success`）：

```
class=base32Test
test=decodeRfcSecret_20Bytes          → Success（20 字节，bytes[0]===49、bytes[19]===48）
test=decodeTailGroupTruncate_MY       → Success（1 字节 0x66）
test=decodeCaseInsensitiveEquivalent  → Success
test=decodePaddingEquivalent          → Success
test=decodeWhitespaceEquivalent       → Success
test=decodeEmptyThrowsEmptySecret     → Success
test=decodeSingleCharThrowsTooShort   → Success
test=decodeIllegalChar_AB1            → Success
test=decodeIllegalChar_ab0            → Success
test=encodeDecodeRoundTrip_RfcVector  → Success（附录 A.1 SHA1 规范形 round-trip，未用 Secret.fromBytes）
test=sha256SeedRoundTrip              → Success（A.1 32 字节 ASCII ↔ 52 字符规范形）
test=sha512SeedRoundTrip              → Success（A.1 64 字节 ASCII ↔ 103 字符规范形）
test=roundTripByteArrays_1to8         → Success
test=encodeEmptyReturnsEmptyString    → Success
test=encodeUppercaseNoPadding         → Success
test=encodeOutputLengthFormula        → Success（32/52/103）
```

全量汇总：`Tests run: 85, Failure: 0, Error: 0, Pass: 85, Ignore: 0`（含其他已就位套件）。

**AC2：`grep -rn "padStart" library/src/main/ets/internal/Base32.ets` → 无输出；`grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/Base32.ets` → 0**

```bash
$ grep -rn "padStart" library/src/main/ets/internal/Base32.ets
（无输出，exit=1）
$ grep -c "NOT_IMPLEMENTED" library/src/main/ets/internal/Base32.ets
0
```

**AC3：`grep -c "it(" library/src/test/Base32.test.ets` ≥ 12**

```bash
$ grep -c "it(" library/src/test/Base32.test.ets
16
```

### QA failure 场景实测（破坏字母表 → 确认红点 → 还原）

把字母表索引 31 的 `7` 换成 `0`（`'ABCDEFGHIJKLMNOPQRSTUVWXYZ234560'`），重跑同一单测命令：

```bash
$ sed -i '' 's/ABCDEFGHIJKLMNOPQRSTUVWXYZ234567/ABCDEFGHIJKLMNOPQRSTUVWXYZ234560/' library/src/main/ets/internal/Base32.ets
$ grep -n "BASE32_ALPHABET: string" library/src/main/ets/internal/Base32.ets
7:const BASE32_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234560';
$HB --no-daemon -c modelVersion=6.1.1 test ...（LOCK-ACQUIRED，BUILD SUCCESSFUL，EXIT=0）
```

用例级结果（test_result.txt）：

```
test=decodeIllegalChar_ab0
Error in decodeIllegalChar_ab0, expect true, actualValue is false
    at expectThrowsCode (library/src/test/Base32.test.ets:15:18)
    at anonymous (library/src/test/Base32.test.ets:97:7)
result=Failure
...
Tests run: 85, Failure: 1, Error: 0, Pass: 84, Ignore: 0
```

- **唯一红点 = `decodeIllegalChar_ab0`**：`'0'` 进入字母表后 `'ab0'` 变为合法输入、不再抛 `INVALID_BASE32_CHAR` → `expectThrowsCode` 的 thrown 断言失败，符合计划预期。
- **`decodeIllegalChar_AB1` 与全部 seed round-trip 用例保持 Success（不变红）**：`'1'` 不在破坏后字母表（`2`-`6`,`0`），始终非法；seed 串只使用索引 ≤30 的字符（A-Z 与 `2`-`6`），不触及索引 31——与 plan-reviewer 复算结论一致。

**还原过程**：

```bash
sed -i '' 's/ABCDEFGHIJKLMNOPQRSTUVWXYZ234560/ABCDEFGHIJKLMNOPQRSTUVWXYZ234567/' library/src/main/ets/internal/Base32.ets
grep -n "BASE32_ALPHABET: string" library/src/main/ets/internal/Base32.ets
7:const BASE32_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';   # 已还原
cp /tmp/oh-package.json5.bak oh-package.json5 && rm -f /tmp/oh-package.json5.bak library/BuildProfile.ets
rmdir /tmp/ohos-otp-hvigor.lock
```

### 验证辅助

- 开工前先用 node 复刻同一公式做了算法冒烟（16 项全过：RFC 向量 20 字节 / `MY`→0x66 / 三种等价 / 四个错误 / SHA1/256/512 round-trip / 1..8 长度 round-trip / 长度公式 / 空数组）——仅验证算法实现自身，未推导任何新向量；附录 A 的表值一律逐字照抄。

### 偏差

无设计性偏差。执行细节（均在 todo 授权范围内）：

1. 错误用例断言采用 try/catch + `err.code` 精确匹配（hypium `assertThrowError` 仅支持消息包含/构造函数名匹配，精度不足）。
2. QA 破坏场景下 hvigor 仍 BUILD SUCCESSFUL（hypium 用例失败不使构建失败），以 `test_result.txt` 的 `Failure: 1` 与失败用例堆栈为判定依据。
3. 构建产物清理：`library/BuildProfile.ets` 在两次构建后均删除；根 `oh-package.json5` 已从备份还原（`git status` 无该文件改动）。

# 2026-10-02 08:40:30

## 编排方（main agent）亲自验证（隔离副本 commit `0982209` + 破坏-变红）

**方法**：`git archive 0982209` + `oh_modules` → `/tmp/v-t04`（排除 `.git`/构建缓存），持 hvigor 锁冷缓存实跑。

| Acceptance | 命令 | 实测 |
|---|---|---|
| 1. 单测 exit 0、`base32Test` 全绿、用例 ≥12 | `test ... -p testType=local` | `TEST_EXIT=0`、`Tests run: 85, Failure: 0, Error: 0, Pass: 85`（`base32Test` 16 条全 Success）✓ |
| 2. 无 `padStart`；无占位 | `grep -rn "padStart" .../Base32.ets`、`grep -c "NOT_IMPLEMENTED" .../Base32.ets` | 无输出；`0` ✓ |
| 3. 用例数 | `grep -c "it(" library/src/test/Base32.test.ets` | **16** ≥12 ✓ |

**内容级审查**：`decode` 顺序为 去空白 → 去尾部 `=` → 大写 → 空串 `EMPTY_SECRET` → 逐字符 `indexOf` 校验（非法 `INVALID_BASE32_CHAR`）→ `floor(len*5/8)===0` 抛 `SECRET_TOO_SHORT` → 8 字符一组位拼接（`<<3|>>2`…`<<5|`）每字节 `& 0xff`，末组按 `floor(groupLength*5/8)` 截断；`encode` 用 8 位进/5 位出的位缓冲（**非**逐字符二进制字符串），大写无填充，空数组返回空串。16 条用例覆盖：A.1 三 seed round-trip（SHA1/SHA256/SHA512）、`'MY'` 末组截断、大小写/填充/空白等价、四种错误路径（`''`/`'A'`/`'AB1'`/`'ab0'`）、1..8 字节 round-trip、编码长度公式。

**编排方独立破坏实验（按计划点名的 red 点）**：把字母表索引 31 的 `7` 换成 `0`（`…234560`）→ `Tests run: 85, Failure: 1, Pass: 84`，**正好是 `decodeIllegalChar_ab0` 变红**（`'ab0'` 由「非法字符」变成合法，不再抛 `INVALID_BASE32_CHAR`），而 `'AB1'` 与 seed 串用例按计划预期不变红 ✓；随后还原。
