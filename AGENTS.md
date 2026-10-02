# AGENTS.md —— ohos-otp 工程上下文

> 面向所有在该仓库工作的编码 agent / 协作者。**动手前先读本文件**；设计结论见 `docs/ohos-otp-lib-rfc.md`（与源码冲突时以源码为准）。

## 1. 项目定位

- `library/` = HAR 库 **`@yansongda/otp` v1.0.0**：RFC 4226 HOTP + RFC 6238 TOTP（SHA1/SHA256/SHA512，6/7/8 位，otpauth URI，漂移窗口，时钟偏移校准）。零运行时依赖。
- `entry/` = 消费方 smoke demo（仅依赖 barrel，**不参与** HAR 打包）。
- 兼容性：`compatibleSdkVersion 6.0.0(20)`（API 12–19 工程无法消费，README 已声明）。
- 现状：本地单测 240 全绿 / 覆盖率 90.11%；设备端 `ohosTest` 37/37；RFC 向量 10/10 + 18/18；`ohpm prepublish` 通过。未发布。

## 2. 分层与不变量（**改动必须遵守**）

| 层 | 文件 | 允许依赖 |
|---|---|---|
| 纯算法核心 | `internal/{Base32,Counter,Truncate,Digits,TimeStep,OtpEngine}.ets` | `OtpError`、`OtpOptions`、`HmacProvider`（仅类型） |
| 解析/规范化 | `OTPAuthURI.ets`、`Secret.ets` | 纯核心 + `OtpError` + `HmacProvider`（RandomSource 接口） |
| kit-free 解耦层 | `internal/HmacProvider.ets` | 仅 `OtpError`/`OtpOptions` |
| kit-only 实现层 | `internal/CryptoSource.ets` | `@kit.CryptoArchitectureKit` + kit-free 层 |
| 公开封装 | `HOTP.ets`、`TOTP.ets` | 以上，**不得引用 kit-only 层** |
| 出口 | `Index.ets` | 公开符号 + `CryptoSource`（仅注册用） |

1. **`internal/CryptoSource.ets` 是全库唯一 `@kit` 导入点**：新增任何系统 API 调用都必须落在该文件；验证 `grep -rn "@kit\." library/src/main/ets/ library/Index.ets` 只应命中它。
2. **`internal/HmacProvider.ets` 必须 kit-free**：ArkTS 的 `import` 静态且传递，公开类一旦经它间接引入 kit，本地单测会在**模块加载期**整体失败（不是少数用例失败）。
3. **`internal/*` 不进 barrel**：`Index.ets` 只导出 `OtpError`/`OtpErrorCode`/DTO/`Secret`/`HOTP`/`TOTP`/`OTPAuthURI`；测试经深路径 import。
4. **取模只在 `Digits.format` 发生一次**；`Truncate` 只截断（`& 0x7f`，31 位非负）。
5. **secret 绝不外泄**：库内零 `console.*`/`hilog`；`OtpError` 消息为固定文案；`Secret` 刻意不实现 `toString()`，脱敏靠 `toJSON()` → `'[REDACTED]'`。
6. **`verify` 恒定时间**：窗口内**扫完所有候选**后才返回首个命中 delta，禁止加早退优化。

其他冻结契约：`OtpOptions` 字段名/可选性冻结（v1 起仅允许**新增可选字段**）；`OtpErrorCode` 固定 17 个字符串码；全同步 API（`*Sync` 链路）；零运行时依赖。

## 3. 命令（实测可跑）

```bash
# 先设环境：hvigor 需要 DEVECO_SDK_HOME 与可用的 node
PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"   # 必须指向 Contents/sdk（父层），不是 sdk/default
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
OHPM=/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
# 仓库根无 hvigorw；-c modelVersion=6.1.1 为兜底（须与 oh-package.json5 / hvigor/hvigor-config.json5 一致）

# 本地单测 + 覆盖率（PC；改算法逻辑后必跑）
$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local -p coverage=true
#   → Tests run: 240, Pass: 240；覆盖率 lines ≈ 90%

# 库产物（release）
$HB --no-daemon -c modelVersion=6.1.1 assembleHar --mode module -p module=library@default -p product=default -p buildMode=release
#   → library/build/default/outputs/default/library.har

# 消费方 HAP（验证 barrel 可被 entry 消费）
$HB --no-daemon -c modelVersion=6.1.1 assembleHap --mode module -p module=entry@default -p product=default

# 发布预检（必做；不执行 publish）
$OHPM prepublish library/build/default/outputs/default/library.har

# 设备端真实 crypto 用例（需模拟器/真机；ohosTest 的 hvigor 包装命令需 signingConfigs 非空）
$HB --no-daemon -c modelVersion=6.1.1 onDeviceTest --mode module -p module=library@default -p testType=ohosTest
#  备选：DevEco Studio → 右键 library/src/ohosTest → Run；或 hdc install 后
#  $HDC shell "aa test -b cn.yansongda.otp -m library_test -s unittest OpenHarmonyTestRunner -s timeout 120000"
```

**hvigor 并发**：同一时刻只跑一个 hvigor 任务（工程级锁），并行 agent 需串行放行。

## 4. 测试策略（**禁止用 mock 冒充真实验证**）

| 目录 | 环境 | 覆盖 |
|---|---|---|
| `src/test/` | PC Local Test（kit-free 可跑） | 纯算法核心全链路 + 公开类（注入 `HmacFixture`/`RandomFixture`）+ RFC 黄金向量 |
| `src/ohosTest/` | 设备/模拟器 | 真实 `CryptoFrameworkHmac`、barrel 注册链路、默认 provider（**不注入 fixture**） |

- 新算法逻辑必须先在 `src/test` 覆盖（PC 可跑）；涉及真实 crypto 的断言只能放 `src/ohosTest`。
- 向量唯一来源：`src/test/vectors/RfcVectors.ets`——**逐字照抄，禁止自行推导或补算**；期望值不得由被测实现反推（自证）。
- Local Test 环境下 cryptoFramework 返回空数据（`doFinalSync()` 的 DataBlob `len=0`），是环境限制而非缺陷；不要在 PC 用例里断言真实 digest。
- 测试文件禁止 `expect(true)` 占位；`it(` 计数不得下降。

## 5. 代码约定

- 缩进 2 空格、单引号、无 Tab；注释用中文，只写「为什么 / 约束 / RFC 依据 / ArkTS 陷阱」，不逐行复述代码。
- 不引入运行时依赖（含测试期第三方算法库）；`dependencies` 必须保持 `{}`。
- 错误一律 `throw new OtpError(code, FIXED_MESSAGE)`；不得新增错误码，也不得改已有码的字符串值。
- ArkTS 注意：位运算是 32 位有符号（大整数须 high/low 拆分）；不用 `padStart`；不假设 `URLSearchParams` 可用；`JSON.stringify` 会调用 `toJSON()`。
- lint：`@security/no-unsafe-mac` 对 HMAC-SHA1 报警为 **warn 且有意接受**（RFC 6238 §1.2 互操作依据）；不放宽规则、不加 disable 注释。

## 6. 文档职责

| 路径 | 用途 | 是否入库 |
|---|---|---|
| `docs/ohos-otp-lib-rfc.md` | **设计结论唯一入库文档**（背景/架构/契约/向量/验证结果/不做清单） | ✅ |
| `docs/implementation/`、`docs/evidence/`、`docs/learning/` | 执行计划、验证证据、共享知识（过程产物） | ❌ 已 gitignore，本地保留 |
| `library/README.md`（英文，必交）/ `README-cn.md` | 使用说明、错误码故障排查表、覆盖边界声明 | ✅ |
| `library/CHANGELOG.md` | **必须含当前版本号** | ✅ |

## 7. 发布流程（人工闸门）

1. 改 `library/oh-package.json5` 的 `version`（semver；**同版本发布后不可覆盖**）。
2. 更新 `library/CHANGELOG.md`（含新版本号）；README 保持含 `ohpm install @yansongda/otp`。
3. 跑单测 + `assembleHar` + `ohpm prepublish`；确认 HAR 内 `src/test`/`ohosTest` 计数为 0。
4. **`ohpm publish` / `git push` / 创建 remote 一律需人工授权**，agent 不得自行执行。

## 8. 已知环境坑

- 未设 `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk` 会报 `00303217 Configuration Error`；指向 `sdk/default` 或更深层会报 `00303312 Cannot find the corresponding SDK version`。
- 仓库根无 `hvigorw`，用 DevEco 绝对路径；`hvigor` 与 `oh-package.json5` 的 `modelVersion` 必须一致（当前均 6.1.1）。
- 构建会写 `hvigor/` 缓存、`local.properties` 与模块根 `BuildProfile.ets`（均已 gitignore）；不要把构建产物提交进来。
- HAR 模块的 ohosTest 打包可能报 `--resources-path is invalid`（工程级限制）；设备用例优先走 DevEco IDE。
- `hdc` 不在 PATH，用上面的绝对路径。
