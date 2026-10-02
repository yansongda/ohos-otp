# 最终验证（F1–F4，编排方亲自执行） —— 2026-10-02 10:28:45

> 全部由 main agent 亲自只读执行；不采信任何 worker 自述。命令与原始输出如下。

## F1. Plan compliance audit ✅ APPROVE

| 检查 | 命令 | 结果 |
|---|---|---|
| 逐 todo 文件清单对照 | 见下「Must have 文件清单」 | 14 个库源文件 + 15 个测试文件 + 四件套 + barrel + 元信息 **全部存在**；3 个模板文件 **已删除**（MainPage/LocalUnit.test/Ability.test）✓ |
| `git status --short` 相较 T01 基线无新增未跟踪项 | `git status --porcelain \| grep '^??'` | **无未跟踪项** ✓（`docs/evidence`、`docs/learning`、`docs/implementation` 按计划随各自 todo 入库；构建产物由 `.gitignore` 覆盖） |
| `NOT_IMPLEMENTED` 仅余枚举定义 | `grep -rn "NOT_IMPLEMENTED" library/src/main/ets/` | 仅 `OtpError.ets:22  NOT_IMPLEMENTED = 'NOT_IMPLEMENTED'` ✓ |
| 错误抛出统一为 `OtpError` | `grep -rn "new Error(" library/src/main/ets/ \| grep -v OtpError.ets` | 无输出 ✓（`OtpError.ets` 内的 `extends Error` 除外） |
| 17 个错误码逐字一致 | python 逐一比对 `NAME = 'NAME'` | **17/17 ALL OK** ✓ |
| T02 的 CLI 命令与 git 越界判定实际可执行 | F3 实跑 | 全部可执行（构建/单测/覆盖率/prepublish 均 exit 0）✓ |

## F2. Code quality review ✅ APPROVE

| 检查 | 命令 | 结果 |
|---|---|---|
| 无日志/禁用 API | `grep -rn "hilog\|console\.\|padStart\|HMAC\|" library/src/main/ets/` | **全空** ✓ |
| `@kit` 唯一导入点 | `grep -rn "@kit\." library/src/main/ets/ library/Index.ets` | 仅 `internal/CryptoSource.ets`（注释行 4 + import 行 8）✓ |
| 无 TODO/FIXME/XXX | `grep -rn "TODO\|FIXME\|XXX" library/src/main/ets/` | **全空** ✓ |
| `Secret` 无返回明文的 `toString` | `grep -n "toString" Secret.ets` | 仅注释（「刻意不实现 toString()」）✓ |
| `verify` 无提前 return | 人工读 `OtpEngine.ets:46-59` | `firstMatch` 记录首个命中后**继续扫完窗口**，循环结束才 `return firstMatch` ✓ |
| 公开类不引用 kit-only 层 | `grep -rn "CryptoSource" Secret/HOTP/TOTP/OTPAuthURI/OtpEngine` | 无输出 ✓（**F1/F2 首轮曾命中 `Secret.ets:45` 注释，已派发 worker 修复 → commit `150a856`，复查清零**） |
| barrel 导出清单 | `grep -n "^export" library/Index.ets` | 13 个公开符号；`internal/*`/`HmacProvider`/`RandomSource`/`CryptoSource`/`OtpEngine`/`EngineParams` **零导出** ✓ |
| 风格（2 空格/Tab/单引号；中文注释） | `grep -c "	" library/src/main/ets/**` + 人工抽查 | 无 Tab 缩进；与设计 §3.2 字段表逐条抽查签名/默认值一致 ✓ |
| 设计 §3.2 签名与默认值抽查 | 人工对照 `OtpOptions.ets`/`TOTP.ets`/`HOTP.ets`/`Secret.ets` | `algorithm=SHA1`/`digits=6`/`minSecretBits=0`/`period=30`/`t0=0`/`clockOffsetMs=0`/`counter=0`/`window=0` 全部一致 ✓ |

## F3. Real manual QA ✅ APPROVE（设备相关项按计划条件标注为待人工）

编排方在仓库内实跑（持 hvigor 锁；构建后还原 `oh-package.json5`，`git status` 复检为空）：

```
############ 单测 + 覆盖率 ############
$ hvigorw --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local -p coverage=true
TEST_EXIT=0 ; BUILD SUCCESSFUL in 28 s 62 ms
Tests run: 240, Failure: 0, Error: 0, Pass: 240, Ignore: 0
覆盖率: lines 419/465 = 90.11% ; functions 48/55 = 87.27% ; branches 183/207 = 88.41%

############ lib release HAR ############
$ hvigorw … assembleHar --mode module -p module=library@default -p product=default -p buildMode=release
HAR_EXIT=0 ; BUILD SUCCESSFUL in 2 s 138 ms
library/build/default/outputs/default/library.har = 30 651 字节
包内 src/test|ohosTest 计数 = 0

############ entry HAP ############
$ hvigorw … assembleHap --mode module -p module=entry@default -p product=default
HAP_EXIT=0 ; BUILD SUCCESSFUL in 2 s 491 ms

############ ohpm prepublish ############
$ ohpm prepublish library/build/default/outputs/default/library.har
ohpm WARN: … the har file "library.har" contains source code, which may cause code asset leakage.
prepublish @yansongda/otp 1.0.0 succeed.
PREPUBLISH_EXIT=0

############ 设备探测 ############
$ hdc list targets
[Empty]    （HDC_EXIT=0；无设备/模拟器）
```

| F3 子项 | 状态 |
|---|---|
| 构建 / 单测 / 覆盖率 / `prepublish` 全跑通 | ✅ 全部 exit 0（见上） |
| entry demo 人工运行（码 30s 翻转/倒计时/进度条） | ⏳ **待人工**（无设备）：DevEco 打开工程 → 启动模拟器/真机 → Run `entry` |
| 设备端 `cryptoAdapterTest`（真实 crypto + barrel 链路，37 用例） | ⏳ **待人工**：右键 `library/src/ohosTest/ets/test/CryptoAdapter.test.ets` → Run；且本环境 **ohosTest 源码连编译都无法自动验证**（无 `ohosTest@CompileArkTS` 任务；`genOnDeviceTestHap` 在 `PackageHap` 因工程级 `--resources-path is invalid` 失败） |
| DevEco Code Linter | ⏳ **待人工**：DevEco → 右键 `library` → Code Linter；期望 `@security/no-unsafe-mac` 仅 warn、其余 `@security/*` 零命中 |
| 需要用户提供的真实环境项 | ① 模拟器/真机（设备端两套验证）；② OHPM 账号 + 发布密钥（`ohpm publish` 发布动作，**本次未执行**） |

## F4. Scope fidelity ✅ APPROVE

| Must NOT 条目 | 命令 | 结果 |
|---|---|---|
| 零第三方依赖 | \`awk '/"dependencies": \{/,/\}/' library/oh-package.json5\` | \`"dependencies": {},\` ✓（仅 \`devDependencies\`: hypium/hamock，测试期官方库） |
| 不做 UI 库 | \`grep -rn "@Component\|@Entry\|build()" library/src/main/ets/\` | 无输出 ✓ |
| 不加 lint 豁免 | \`grep -rn "no-unsafe-mac" library/src/ library/Index.ets\` | 无输出 ✓（范围按计划排除 \`library/*.md\`：README 需明写「不使用该豁免」的立场） |
| 不做非 RFC 能力 | \`grep -rni "steam\|qrcode\|sm3\|sha224\|sha384\|bigint" library/src/main/ets/\` | 无输出 ✓ |
| 不改工程级配置 | \`grep -n compatibleSdkVersion build-profile.json5\`；\`git diff 0a5d04c..HEAD --stat -- build-profile.json5 code-linter.json5 hvigor/\` | \`compatibleSdkVersion = "6.0.0(20)"\` 未变；\`diff\` 为空 → \`build-profile.json5\`/\`code-linter.json5\`/\`hvigor/**\` **零改动** ✓（T13 授权的 \`signingConfig\` 行移除**未触发**） |
| 不越界旧 MFA 仓库 | \`git -C /Users/yansongda/000-Coding/application status --short\` | 无输出 ✓ |
| 反自证（测试不依赖系统 kit） | \`grep -rn "@kit\|cryptoFramework" library/src/test/{OtpEngine.test,HmacFixture,vectors/RfcVectors}.ets\` | 无输出 ✓（本地向量用例全部经 \`HmacFixture\` 查表注入） |
| 不执行远端/发布动作 | \`git log --oneline\`；\`git remote -v\` | 全程**零 push、零 remote 写操作**；\`ohpm publish\` **未执行**（只跑 \`prepublish\`）✓ |

---

## 交付物清单（基线 \`0a5d04c\` → HEAD）

**代码规模**：60 个文件变更，**+6 837 / −123** 行；提交历史 **22 个 commit**（1 基线 + 14 任务 + 6 文档记账 + 1 最终修复）。

**library 源码（14 个）**：\`OtpError.ets\`（17 错误码 + \`class OtpError extends Error\`）、\`OtpOptions.ets\`（2 枚举 + 5 接口）、\`Secret.ets\`、\`HOTP.ets\`、\`TOTP.ets\`、\`OTPAuthURI.ets\`、\`internal/{Base32,Counter,Truncate,Digits,TimeStep,OtpEngine}.ets\`、\`internal/HmacProvider.ets\`（kit-free 注册表）、\`internal/CryptoSource.ets\`（**全库唯一 \`@kit\` 导入点**）

**library 测试（15 个）**：12 个本地套件 + \`vectors/RfcVectors.ets\`（附录 A 全量向量）+ \`HmacFixture.ets\` + \`RandomFixture.ets\`；设备端 \`ohosTest/…/CryptoAdapter.test.ets\`（37 用例）

**发布物料**：\`library/Index.ets\`（barrel + 自动 \`installCryptoDefaults()\`）、\`library/oh-package.json5\`、\`README.md\`/\`README-cn.md\`（各 180 行）、\`CHANGELOG.md\`、\`LICENSE\`（MIT）、\`library/oh-package-lock.json5\`

**消费方**：\`entry/oh-package.json5\`（\`file:../library\`）、\`entry/src/main/ets/pages/Index.ets\`（算码 demo）、\`entry/oh-package-lock.json5\`

**执行期经确认的计划修正（已在 learning/evidence 记录）**：① T02 的「\`-c modelVersion\` 会自动迁移根 \`oh-package.json5\`」失效 → 改为「构建前临时 sed + 构建后还原」；② \`ohpm prepublish\` 不校验四件套是否存在（只校验归档格式与 \`oh-package.json5\` 元数据）→ 四件套齐备列为人工检查项；③ 并发 Wave 采用「hvigor 锁 + git 锁 + 只 add 显式路径 + 共享文档由编排方记账提交」；④ 目录证据按计划随各 todo 入库（与 skill 默认「docs 目录 gitignore」不同，用户已批准的 Commit strategy 明确要求入库）；⑤ \`library/oh-package-lock.json5\` 为 \`ohpm install --all\` 副产物，已入库以保持 git 洁净。

**验收判据修正（重要）**：hvigor \`test\` 任务**即使有用例失败 exit code 仍为 0** → 所有「单测通过」判定以 \`test_result.txt\` 的 \`Failure\` 计数为准（已写入 learning §F3 与各任务 evidence）。

## 证据索引（\`docs/evidence/ohos-otp-lib-rfc/\`）

\`task-01-baseline.md\`、\`task-02-spike.md\`（契约快照：分支 B / CLI 配方 / 字节码 HAR）、\`task-03-scaffold.md\`、\`task-04-base32.md\`、\`task-05-primitives.md\`、\`task-06-timestep.md\`、\`task-07-crypto.md\`、\`task-08-secret-uri.md\`、\`task-09-engine.md\`、\`task-10-public-api.md\`、\`task-11-device-crypto.md\`、\`task-12-release-assets.md\`、\`task-13-entry-demo.md\`、\`task-14-delivery.md\`、\`final-verification.md\`（本文件）

## 独立验证强度（编排方不采信 worker 自述）

- 每个任务均在**隔离副本**（\`git archive <commit>\` + \`oh_modules\`，排除 \`.git\`/构建缓存）**冷缓存复跑**验收命令；
- 6 次**破坏-变红**灵敏度实验（Base32 字母表 / Truncate 掩码 / TimeStep t0 / CryptoSource algName / TOTP 偏移符号 / 构造期校验）确认用例能抓住对应缺陷；
- 向量表用 **node \`crypto.createHmac\` 独立复算 112 项**（含 counter 推导、digest、6/7/8 位码、counterToBytes）比对，零真实不一致；A.1 base32 seed 用独立解码器逐字节复核；
- 最终验证又发现并修复了 1 处真实违规（\`Secret.ets\` 注释字面引用 \`CryptoSource\` 导致越界 grep 失效）→ commit \`150a856\`。

---

# F3 设备端补充验证（模拟器启动后由编排方补做）—— 2026-10-02 21:34:00

原 F3 中「设备相关待人工」的 3 项，其中 2 项已完成，1 项仍待人工：

| 原待人工项 | 现状 | 证据 |
|---|---|---|
| 设备端 `cryptoAdapterTest`（37 用例，真实 crypto + barrel 链路） | ✅ **已完成，37/37 全绿** | `task-11-device-crypto.md` 末尾「设备端真实执行」节：`hdc install` + `aa test -b cn.yansongda.otp -m library_test -s unittest OpenHarmonyTestRunner` → `Tests run: 37, Failure: 0, Error: 0, Pass: 37`（`AA_TEST_EXIT=0`） |
| `entry` demo 设备端运行（码 30s 翻转/倒计时/进度条） | ✅ **已完成，界面级验证通过** | `task-13-entry-demo.md` 末尾节：`uitest dumpLayout` 5 次采样（码 `836277`→`279557` 跨窗口翻转、倒计时 6→22→10→3→2、进度 0.800/0.2667 与倒计时自洽），并用 **node 独立计算 TOTP 与界面码逐次比对 MATCH** |
| DevEco Code Linter | ⏳ 仍待人工（CLI 无入口） | 人工步骤见 F3 正文 |

**新增环境限制（如实记录）**：计划的官方 CLI 包装命令 `hvigorw onDeviceTest` 在本机**无法 exit 0**——它在 `:library:ohosTest@PackageHap`/`SignHap` 之后卡在 `:library:default@GenerateDeviceCoverage`（`ErrorCode: 00507001`：找不到 `library-ohosTest-signed.hap`），根因是工程 `app.signingConfigs` 为空导致 `SignHap` 被跳过（实测 HAP 内无任何签名材料，改名绕过会被 `PackageHap` 重建清除 → 属**内容校验**）。
- **不影响 T11 的验收实质**：同一测试 HAP 已由官方 JsUnit runner（`OpenHarmonyTestRunner`）在**真实设备**上跑完 37/37。
- **解除方式（用户项）**：DevEco → File > Project Structure > Signing Configs → *Automatically generate signature*（需 Huawei ID 登录）；配置后 `hvigorw onDeviceTest` 即可完整跑通（含设备端覆盖率采集）。**该操作会写入 `build-profile.json5` 的 `signingConfigs`，属需用户授权的工程配置变更，编排方未擅自添加。**

**同时纠正一条早前结论**：T11 evidence 首轮曾记录「本环境下 ohosTest 源码连编译都无法验证」。设备端推进时实测 **`onDeviceTest` 任务存在**，其任务图包含 `:library:ohosTest@OhosTestCompileArkTS`（编译通过）与 `:library:ohosTest@PackageHap`（打包通过）→ **ohosTest 源码可编译**这一结论成立；此前失败的是 `genOnDeviceTestHap`（在 `:library:default@PackageHap` 因 `--resources-path is invalid` 更早失败），两条路径不同。该纠正已同步至 learning。
