# 2026-10-02 09:16:46

## 1. 任务概述

T13：消费方 smoke demo（entry 依赖 library）。`entry` 从 DevEco 模板页改为 1 页算码 demo，证明 HAR `@yansongda/otp`（`file:../library`）可被 entry 消费。前置：T10 已完成（API 冻结，HEAD=`df5d524`）。

## 2. 依赖同步（todo 步骤 1）

### 2.1 修改 `entry/oh-package.json5`

```json5
  "dependencies": {
    "@yansongda/otp": "file:../library"
  }
```

### 2.2 同步命令（持 /tmp/ohos-otp-hvigor.lock 执行）

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install --all
```

真实输出：

```
install completed in 0s 23ms
OHPM_EXIT=0
```

### 2.3 同步结果确认

- `entry/oh_modules/@yansongda/otp` 出现，为符号链接：

```
$ ls -la entry/oh_modules/@yansongda/
lrwxr-xr-x  otp -> ../../../library
```

（`entry/oh_modules` 已被基线 `.gitignore` 的 `**/oh_modules` 覆盖，不入库。）
- 新增 `entry/oh-package-lock.json5`（lockfileVersion 3），含：

```
"@yansongda/otp@../library": {
  "name": "@yansongda/otp",
  "version": "1.0.0",
  "resolved": "../library",
  "registryType": "local"
}
```

- 根 `oh-package-lock.json5` **未变化**（git status 无该文件）。
- 副产物 `library/oh-package-lock.json5`（ohpm 扫描 library 模块的 devDependencies 生成）：**非本任务文件，不纳入 T13 提交**，留在工作区由编排方 bookkeeping 处理。

## 3. entry 构建（todo 步骤 2 + Acceptance 4）

### 3.1 逐字命令（四件套：备份 → sed 迁移 → 持锁构建 → 还原）

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
# 持 /tmp/ohos-otp-hvigor.lock
cp oh-package.json5 /tmp/oh-package-t13.bak
sed -i '' 's/"modelVersion": "6.0.0"/"modelVersion": "6.1.1"/' oh-package.json5
$HB --no-daemon -c modelVersion=6.1.1 assembleHap --mode module -p module=entry@default -p product=default
# 还原
cp /tmp/oh-package-t13.bak oh-package.json5 && rm -f /tmp/oh-package-t13.bak library/BuildProfile.ets entry/BuildProfile.ets
rmdir /tmp/ohos-otp-hvigor.lock
```

### 3.2 真实输出（关键行）

```
> hvigor WARN: Missing module info for local modules '@yansongda/otp'. Check project-level build-profile.json5.
> hvigor Finished :entry:default@CompileArkTS... after 1 s 241 ms
> hvigor WARN: Warning: 'page_text_font_size' conflict, first declared.
        at /Users/yansongda/000-Coding/ohos-otp/entry/src/main/resources/base/element/float.json
        but declared again.
        at /Users/yansongda/000-Coding/ohos-otp/library/src/main/resources/base/element/float.json
> hvigor WARN: Will skip sign 'hos_hap'. No signingConfigs profile is configured in current project.
             If needed, configure the signingConfigs in /Users/yansongda/000-Coding/ohos-otp/build-profile.json5.
> hvigor Finished :entry:assembleHap... after 1 ms
> hvigor BUILD SUCCESSFUL in 2 s 562 ms
BUILD_EXIT=0
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`（221367 B，unsigned——无签名配置时 hvigor 仅 WARN 跳过签名，**未报错**）。

### 3.3 签名结论（重要）

products 里的 `"signingConfig": "default"` 指向**空数组** `app.signingConfigs` 时，`SignHap` 任务行为为 **WARN 跳过 + 继续**（`Will skip sign 'hos_hap'`），**并非报错**。因此 **T13 授权的 `build-profile.json5` 机械性修改未触发，未改动该文件**（git status 无 build-profile.json5）。两条 WARN（`Missing module info for local modules`、`page_text_font_size conflict`）均为无害提示：前者是本地 file: 依赖无远程元信息，后者是 library 模板资源与 entry 同名 float（library 资源归属 T03/T12，不在本任务边界）。

## 4. Acceptance 逐条真实输出

| # | 判据 | 命令 | 输出 | 结论 |
|---|---|---|---|---|
| 1 | `grep -c "@yansongda/otp" entry/oh-package.json5` ≥ 1 | grep -c | `1` | ✅ |
| 2a | `grep -c "TOTP" entry/src/main/ets/pages/Index.ets` ≥ 1 | grep -c | `6` | ✅ |
| 2b | `grep -c "clearInterval" entry/src/main/ets/pages/Index.ets` ≥ 1 | grep -c | `1` | ✅ |
| 3 | `grep -c "syncClockOffset\|verify" entry/src/main/ets/pages/Index.ets` ≥ 1 | grep -c | `4` | ✅ |
| 4 | entry 构建 exit 0 且输出含 BUILD SUCCESSFUL | 见 §3 | `BUILD_EXIT=0` + `BUILD SUCCESSFUL` | ✅ |
| 5 | `grep -rn "entry" library/oh-package.json5` → 无输出 | grep -rn | 无输出（exit 1） | ✅ |

## 5. demo 实现说明（`entry/src/main/ets/pages/Index.ets`）

- `import { TOTP, OtpError } from '@yansongda/otp';`（barrel 导入，`installCryptoDefaults()` 自动生效，消费者零配置）。
- 固定示例 secret `JBSWY3DPEHPK3PXP`（文档公开示例值，80 bit 存量密钥形态，非真实密钥），`new TOTP({ secret, period: 30 })`。
- `aboutToAppear`：构造 TOTP + `refresh()` + `setInterval(…, 1000)`；`aboutToDisappear` 中 `clearInterval` 清理定时器。
- 展示：6 位码（`$r('app.float.page_text_font_size')` 50fp）、`remaining()` 倒计时、「校验并校准」按钮下方 `progress()` 线性进度条（`Progress({ value: this.progress, total: 1 })`，progress ∈ [0,1)）。
- 「校验并校准」：`verify(this.code, { window: 1 })` → delta 非 null 时 `syncClockOffset(delta)`（单参数，单位=时间步），null 时提示「未命中窗口」。
- 构造/算码/校验三处 try/catch，捕获后按 `(e as OtpError).code` 分支展示到 errorText（红字），不崩溃。

## 6. QA failure 场景实测

临时把 secret 改为非法值 `'AB1'` 后重新构建：

```
--- 临时修改后的构造行 ---
22:      this.totp = new TOTP({ secret: 'AB1', period: 30 });
> hvigor BUILD SUCCESSFUL in 2 s 186 ms
BUILD_EXIT=0
```

结论（**静态检查**，无设备无法跑 UI 运行时）：
- 编译期不报错（抛错发生在运行期构造时），构建仍 SUCCESSFUL，证明 try/catch 路径在编译层面成立。
- 运行期推导链路：`'1'` 不在 base32 字母表 `ABCDEFGHIJKLMNOPQRSTUVWXYZ234567` → `Base32.decode('AB1')` 抛 `OtpError(INVALID_BASE32_CHAR)`（T04 用例 `decodeIllegalChar_AB1` 已锁定该行为）→ `TOTP` 构造器经 `Secret.fromBase32` 传递该错误 → demo `aboutToAppear` 的 catch 捕获并展示 `err.code === 'INVALID_BASE32_CHAR'`，不崩溃。
- 已还原 secret 为 `JBSWY3DPEHPK3PXP`（`git diff` 确认仅本 demo 文件改动）。
- 运行时 UI 展示（红字显示 `INVALID_BASE32_CHAR`）**待人工验证**。

## 7. 设备端运行（QA happy 场景）

**未执行**：`hdc list targets` 环境事实为 `[Empty]`（无设备/模拟器）。**待人工验证**，人工步骤：
1. DevEco Studio 打开本工程，`entry` 配置签名（模拟器可用自动签名）后 Run `entry`。
2. 观察：6 位码每 30s 翻转；倒计时从 30 递减到 1（无 0）；进度条随倒计时同步回退。
3. 点击「校验并校准」：delta=0 → 显示「命中 delta=0，已校准」；或（若故意把系统时间调偏 30s 内）显示对应 delta。
4. 把 secret 临时改为 `'AB1'` 重跑：页面显示红色 `初始化失败: INVALID_BASE32_CHAR`，不崩溃。

## 8. 偏差记录

- **无设计性偏差**；HAR 可被 entry 正常消费（`import '@yansongda/otp'` 编译通过、构建 exit 0），barrel 导入路径成立。
- **`build-profile.json5` 未改动**：预期中的「空 signingConfigs + `"signingConfig": "default"`」在 `assembleHap` 下仅为 WARN 跳过签名（`Will skip sign 'hos_hap'`），不报错，故 T13 授权的工程级修改**未触发**（§3.3）。
- **`entry/oh-package-lock.json5` 随本任务提交**：ohpm 依赖同步的机械性产物（todo 授权「lock 若变化则一并提交并注明」；实际变化发生在 entry/ 而非根，按同一精神处理）。
- `library/oh-package-lock.json5`（ohpm 扫描副产物）与 `docs/**`（T10 evidence / T11-T12 在改的计划与 learning）**未纳入**本任务提交。
- 无设备，UI 运行时行为与 failure 分支 UI 展示均为「静态验证 + 待人工验证」，未伪报。

# 2026-10-02 11:40:10

## 编排方（main agent）亲自验证（隔离副本 commit `6abc751` 实跑 entry 构建）

**方法**：`rsync` 工作树到 `/tmp/v-t13`（保留 `oh_modules` 与 `entry/oh_modules/@yansongda/otp → ../../../library` 符号链接，排除 `.git`/各模块 `build`/`.hvigor`）+ `git archive 6abc751` 覆盖为 T13 提交状态，持 hvigor 锁实跑 entry 构建。

| Acceptance | 命令 | 实测 |
|---|---|---|
| 1. 依赖声明 | `grep -c "@yansongda/otp" entry/oh-package.json5` | `1` ✓（`"file:../library"`） |
| 2. demo 使用 API | `grep -c "TOTP" …/Index.ets` = `6`；`grep -c "clearInterval" …` = `1`；`grep -c "syncClockOffset\|verify" …` = `4` | ✓（定时器在 `aboutToDisappear` 中清理；按钮走 `verify(code,{window:1})` → 命中则 `syncClockOffset(delta)`） |
| 3. entry 构建 exit 0 | `assembleHap --mode module -p module=entry@default -p product=default` | `ENTRY_BUILD_EXIT=0`、`BUILD SUCCESSFUL in 2 s 225 ms`、日志 `ERROR` 计数 **0**、产物 `entry-default-unsigned.hap`（221 367 B）✓ |
| 4. 无反向依赖 | `grep -rn "entry" library/oh-package.json5` | 无输出 ✓ |

**内容级审查**：`Index.ets` 单文件、无额外组件；`import { TOTP, OtpError } from '@yansongda/otp'` 走 barrel（零配置，自动 `installCryptoDefaults()`）；固定示例 secret `JBSWY3DPEHPK3PXP`（文档公开值）；`@State` 驱动 code/remaining/progress/deltaText/errorText；`setInterval` 1s + `aboutToDisappear` 中 `clearInterval`；两处 `try/catch` 均按 `OtpError.code` 分支展示，不崩溃；样式沿用 `$r('app.float.page_text_font_size')`。

**依赖同步结果（worker 报告 + 编排方核对）**：`ohpm install --all` exit 0 → `entry/oh_modules/@yansongda/otp` 符号链接出现（指向 `../../../library`，已核对相对路径正确）；新增并已提交 `entry/oh-package-lock.json5`（`@yansongda/otp@../library` `registryType: local`，35 行）。

**构建签名**：根 `build-profile.json5` 的 `app.signingConfigs` 为空但 `products[].signingConfig: "default"` → 实测**未导致失败**（hvigor 产出 unsigned HAP，`SignHap` 任务 1 ms 通过），**因此未触发 T13 唯一授权的 `signingConfig` 行移除**，该行保持原样（`git diff build-profile.json5` 为空）。

**待人工验证（如实记录，未伪报）**：设备/模拟器端运行（码每 30s 翻转、倒计时 30→1、进度条同步、按钮校准 delta）**未执行**（`hdc list targets` → `[Empty]`）。人工步骤：DevEco Studio 打开工程 → 启动模拟器/连接真机 → Run `entry` → 观察上述行为；或 CLI `hdc` 安装 `entry/build/default/outputs/default/entry-default-unsigned.hap`（需签名后安装）。
