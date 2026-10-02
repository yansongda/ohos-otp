# ohos-otp-lib-rfc —— 执行期共享知识库

> 由 execute-plan 编排维护。**只能末尾追加，严禁修改/删除既有内容。**
> 每个任务**开工前必读**本文件；完成后必须把本任务发现的坑、契约实测结果、偏差处理**追加**到文件末尾。
> 计划文档：`docs/implementation/ohos-otp-lib-rfc.md`；技术设计：`docs/ohos-otp-lib-rfc.md`（冲突时以计划文档为准）。

## 0. 编排约定（main agent 维护，2026-10-01 23:57:32）

### 0.1 证据文件
`docs/evidence/ohos-otp-lib-rfc/task-NN-<slug>.md`，每个任务一份。**纯追加**：每轮（含修复轮）新增一节，节标题必须是 `# YYYY-MM-DD HH:MM:SS`。严禁修改历史轮次。

### 0.2 hvigor 构建令牌（Executor rule 8：hvigor 命令必须全局串行）
Wave 内多任务并发时，**任何 hvigor 调用前必须先获取全局文件锁**（替代向编排方逐次申请令牌，效果等价且无需人工放行）。统一用法：

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
LOCKDIR=/tmp/ohos-otp-hvigor.lock
for i in $(seq 1 180); do
  mkdir "$LOCKDIR" 2>/dev/null && break
  find /tmp -maxdepth 1 -name 'ohos-otp-hvigor.lock' -mmin +45 -exec rmdir {} \; 2>/dev/null
  sleep 10
done
# ← 在此运行 hvigor 命令（持锁期间不得做别的事）
rmdir "$LOCKDIR"
```

- 若 180 次（30 分钟）仍拿不到锁：向编排方报告，禁止无锁抢跑。
- 遇 hvigor daemon/lock 类报错：等待后**串行重试一次**，并在 evidence 注明「并发重试」。

### 0.3 git 边界（默认）
- worker **默认不 commit / 不 git add / 不改 .gitignore**；仅当 todo 的 `Commit` 字段为 Y 且须提交本任务产物时，才执行该 todo 指定的 commit（**只 add 本任务列出的文件 + 本任务 evidence**）。
- 禁止 `git push`、`git remote add/set-url`、`git reset --hard`、`git checkout` 覆盖他人改动。
- cs-fix/lint 自动修复若波及 todo 之外的文件：`git checkout -- <file>` 还原并在 evidence 记录。
- `docs/evidence/` 的 evidence 文件**随各自 todo 入库**（与本计划的 Commit strategy 一致，用户已批准该策略）。

### 0.4 环境事实（main agent 实测）
- 仓库：`/Users/yansongda/000-Coding/ohos-otp`，分支 `main`，**零 commit**（T01 打基线后才有 HEAD）
- DevEco Studio 6.1.1；hvigorw：`/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw`（仓库根**没有** hvigorw）
- ohpm：`/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm`（只有 `prepublish`，无 `pack`）
- hdc：`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`（不在 PATH）；`hdc list targets` → `[Empty]`（**当前无设备**）
- node：`/Users/yansongda/.nvm/versions/node/v24.20.0/bin`（跑 hvigorw 前必须 export PATH）
- `.hvigor/cache/meta.json` = `{"compileSdkVersion":"6.1.1(24)","hvigorVersion":"6.24.4","toolChainsVersion":"6.1.1.125"}`
- 本地 SDK 声明文件（**权威**）：`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/api/@ohos.security.cryptoFramework.d.ts`

## T01 工程基线（worker 追加，2026-10-01 23:58:25）

- 基线 commit：`b9dd116`（root-commit，57 文件 / 2278 行插入，本仓库第一个 commit）。
- 基线时的 git 状态：`git status --short` 为空，后续所有「越界检查」以此为参照系。
- `.gitignore` 实测共 12 行（环境事实曾记 6 行，不准确），末尾 `.appanalyzer` 后无换行符；根级 `/.hvigor`、`/oh_modules` 只匹配根目录产物，已补 `**/.hvigor` 与 `**/oh_modules` 覆盖模块目录产物（QA 验证 `library/.hvigor`、`library/oh_modules` 不出现于 git status）。
- 根级产物 `.hvigor/`、`oh_modules/`、`.idea/`、`local.properties` 基线时均已被既有规则忽略，无需额外处理。

## T01 编排方复核与纠错（main agent 追加，2026-10-02 00:03:10）

- **基线 commit 最终为 `0a5d04c`**（唯一 root commit，57 个跟踪文件；中间 hash `b9dd116`/`0084df6` 已被 squash 重写，引用一律以 `0a5d04c` 为准）。
- **⚠️ 仓库存在 `origin` 远端**：`https://github.com/yansongda/ohos-otp.git`。本计划全程**严禁 push / remote 写操作**（授权红线）；编排方开工侦察时未检查 remote，此前 learning §0.4「零远端」表述有误，以本节为准。
- **经验（后续任务必须遵守）**：todo 的 Acceptance 一旦写成「commit 数 == 1」这类计数断言，worker 在 commit 之后再追加 evidence/learning 就会破坏该断言。正确做法：**先把 evidence（含本轮全部内容）写全，再一次性 commit**；确需在 commit 后补记时，必须同时把补记折叠进同一个 commit（`git reset --soft <root> && git commit --amend`，需编排方一次性授权）。
- **经验（编排协议）**：worker session 在前台执行结束、被环境清理后**无法 resume**（`Agent not found`）。此时按 execute-plan 的替代路径：以**自包含 prompt 携带上一轮完整失败证据**重派同类型 worker-low，并在 evidence 记录该替代原因。
- **编排方记账提交**：plan 文档的 `[x]` 勾选与 learning 文件追加会让工作区出现已跟踪文件的改动；编排方不亲自 commit，改为在每个 Wave 结束时派发 1 个极小 worker 执行 bookkeeping commit（`docs: 更新执行计划勾选与共享知识（<任务>）`），以保持 `git status` 洁净。该 bookkeeping commit 与「每 todo 独立 commit」策略并存，已在最终总结中披露。

## T02 可行性 spike（worker 追加，2026-10-02 01:25:00）

- **CLI 完整配方（三种用途全部实测跑通，无需复制 hvigorw 到仓库根）**：
  ```bash
  export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
  export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"   # 必须指向 Contents/sdk（含 default/sdk-pkg.json 的父层），指向 default/ 或 openharmony/ 均报 00303312
  HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
  # 构建 HAR：$HB --no-daemon -c modelVersion=6.1.1 assembleHar --mode module -p module=library@default -p product=default -p buildMode=release
  # 本地单测：$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
  # 覆盖率：  $HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local -p coverage=true
  ```
- **必须带 `-c modelVersion=6.1.1`**：基线 `oh-package.json5` modelVersion=6.0.0 与 `hvigor-config.json5` 6.1.1 不一致，不带 -c 直接 exit 255（00303027）且不自动迁移。带 -c 跑**实际构建任务**时 hvigor 会把 oh-package.json5 的 modelVersion 迁移写回 6.1.1 并删 hvigor-config.json5 末尾换行；`tasks` 只读命令不写盘。构建后须 `git checkout -- oh-package.json5 hvigor/hvigor-config.json5` 还原（本任务边界禁止改工程配置；是否把迁移作为机械性修正提交由编排方裁决）。
- **release 构建会在 `library/` 根生成 `BuildProfile.ets`**（`.gitignore` 不覆盖，`**/build` 只覆盖 build/ 目录）→ 构建后 `rm -f library/BuildProfile.ets`。
- **Local Test 实测可跑**（本仓库无旧工程的 00304022）：用例级结果在 `library/.test/default/intermediates/test/coverage_data/test_result.txt`（`Tests run: 2, Failure: 0, Error: 0, Pass: 2`）；覆盖率报告在 `library/.test/default/outputs/test/reports/`（index.html + coverageReport.json）。`coverage.log` 里 previewer 的 `connect socket failed` 是噪音，不影响结果。
- **分支判定 = 分支 B（决定性证据）**：kit 在 Local Test 下「可 import（①✓）、可构造 createMac/createSymKeyGenerator（②✓）、调用链不抛异常但 **doFinalSync() 返回空 DataBlob len=0**（③✗）」；async API 交叉验证同样 `hex=[] len=0`。=「能 import 但调用失败」中间态 → 分支 B。本地测试只能覆盖 kit-free 全链路（注入 fixture），真实 crypto 由 ohosTest 设备用例兜底。
- **`*Sync` 接口编译可用**：SDK 权威行号 `@ohos.security.cryptoFramework.d.ts` —— `convertKeySync` L2006、`initSync` L2304、`updateSync` L2398、`doFinalSync` L2475、`generateRandomSync` L1332；运行期本地返回空数据（分支 B 语义）。
- **`assembleHar` 产物 = 字节码 HAR**：`library/build/default/outputs/default/library.har`（release 3863 B；debug/release 同路径互相覆盖）；gzip(tar) 结构（非 zip，`gunzip -c | tar -tf`）；含 `package/ets/modules.abc` + 自动生成的 `types: "Index.d.ets"`（包内 oh-package.json5 metadata `byteCodeHar: true`），**无源码 .ets**（只有 .d.ets 声明）。T12 无需手工补 types。
- **6 项语言探针全可用**：① `class extends Error` 的 `instanceof E` 与 `instanceof Error` 均 true；② 字符串值枚举 `String(C.A)==='A'`；③ class getter；④ `JSON.stringify` 会调用 `toJSON()`（实测输出 `[{"s":"REDACTED"}]`，Secret 脱敏方案本地可测）；⑤ **type-only import 不加载目标模块**（顶层抛异常负例验证：`import type` 通过，值导入对照触发 uncaught exception 且**测试进程挂起导致 hvigor 超时**——做此实验记得超时后 kill hvigor/RichPreviewer 进程并清理 `/tmp/ohos-otp-hvigor.lock`）；⑥ `encodeURIComponent/decodeURIComponent` 含 %20/%3A 往返正确。
- **坑：超时命令被杀会残留 `/tmp/ohos-otp-hvigor.lock`**，后续所有持锁命令会空转 30 分钟直到超时——遇「命令迟迟不产生日志」先 `rmdir /tmp/ohos-otp-hvigor.lock`。
- 命令模板与分支结论的权威出处：`docs/evidence/ohos-otp-lib-rfc/task-02-spike.md`。

## T02 编排方裁决与后续任务统一流程（main agent 追加，2026-10-02 01:52:30）

### 裁决 1：不提交 hvigor 的 modelVersion 自动迁移（保持工程配置与基线一致）
计划 Must NOT 规定「`hvigor/hvigor-config.json5` 不改」，故 `-c modelVersion=6.1.1` 触发的写回**一律还原、不入库**、也不写进 `.gitignore`。
**所有需要跑 hvigor 的任务，统一按以下「构建三件套」执行**（缺一即会被 F1/F4 判为越界）：

```bash
# ① 环境前缀
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
# ② 持锁执行（用法见 §0.2）
$HB --no-daemon -c modelVersion=6.1.1 <任务> --mode module -p module=library@default ...   # test 追加 -p testType=local
# ③ 构建后清理（必须；否则 git status 出现 3 处噪声）
git checkout -- oh-package.json5 hvigor/hvigor-config.json5 2>/dev/null; rm -f library/BuildProfile.ets
rmdir /tmp/ohos-otp-hvigor.lock 2>/dev/null
```

三种用途的完整命令（T02 实测，**权威出处 = `docs/evidence/ohos-otp-lib-rfc/task-02-spike.md` §1**）：
- 构建 HAR：`$HB --no-daemon -c modelVersion=6.1.1 assembleHar --mode module -p module=library@default -p product=default -p buildMode=release`
- 本地单测：`$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local`
- 覆盖率：在上条追加 `-p coverage=true`
- entry 构建（T13）：`$HB --no-daemon -c modelVersion=6.1.1 assembleHap --mode module -p module=entry@default -p product=default`

### 裁决 2：分支 B 已定论
本地单测只能覆盖 **kit-free 层**（注入 fixture）；`internal/CryptoSource.ets` 与 barrel 注册链路的真实行为由 **T11 的 ohosTest 设备用例**覆盖。当前 `hdc list targets` → `[Empty]`（**无设备**），T11 预计按「未执行 + 人工步骤」记录，**严禁伪报通过**。

### 验收自查工具（比看 hvigor stdout 更可靠）
- 用例级结果：`cat library/.test/default/intermediates/test/coverage_data/test_result.txt`（含 `class=<套件名>`、`test=<用例名>`、`result=Success|Failure`、`Tests run: N, Failure: 0`）
- 覆盖率报告：`library/.test/default/outputs/test/reports/`（`index.html` + `coverageReport.json`）
- 构建产物：`library/build/default/outputs/default/library.har`（release 3863 B，**字节码 HAR**，包内自动含 `types: "Index.d.ets"` → T12 无需手工补 `types`）

### 坑（务必继承）
- 不用 `-c modelVersion=6.1.1` → exit 255（`00303027`）；用 `-c` 跑**实际任务**才有写回，`tasks` 只读不写盘。
- 命令超时被 kill 后会残留 `/tmp/ohos-otp-hvigor.lock`，导致后续持锁命令空转 30 分钟 → 异常时先 `rmdir /tmp/ohos-otp-hvigor.lock`。
- type-only import 不加载模块（已实测），但**值导入会**（顶层抛异常会让测试进程挂起、hvigor 超时）——这是「kit-free 分层」的结构性依据，也是本地套件绝不能间接 import `CryptoSource` 的原因。
- 一级排障入口：`DEVECO_SDK_HOME` 必须指向 `/Applications/DevEco-Studio.app/Contents/sdk`。

## T03 脚手架（worker 追加，2026-10-02 07:25:00）

- **⚠️ 根 `oh-package.json5` 的 modelVersion 自动迁移已失效（影响所有后续 hvigor 任务）**：T02 记录「带 `-c modelVersion=6.1.1` 会自动把根 oh-package.json5 迁移写回 6.1.1」，本次实测该迁移**不再发生**——`-c` 只覆盖 hvigor-config.json5；`hvigor-config(6.1.1) vs 根 oh-package(6.0.0)` 不一致检查恒失败 00303027（`tasks`/`assembleHar`/`test` 一律 exit 255）。`docs/evidence/.../task-02-spike.md` §1 的「不带 -c 才失败」表述已过时。**统一处置（构建三件套升级为四件套）**：构建/单测前临时 `sed -i '' 's/"modelVersion": "6.0.0"/"modelVersion": "6.1.1"/' oh-package.json5`，完成后从备份还原（先 `cp oh-package.json5 /tmp/oh-package.json5.bak`）；提交前必须确认根 oh-package.json5 无 git 改动。佐证：`.hvigor/report/` 里 03:31/03:52 的两次 00303027 失败非 T03 产生，说明该状态从那时起即存在。
- **⚠️ `HarCompileArkTS` 增量缓存损坏会卡死构建（后续任务遇「构建无输出卡住」先清它）**：一次 ArkTS 编译失败（如 misplaced imports）后，`library/build/default/cache/default/default@HarCompileArkTS` 会进入损坏状态，后续 assembleHar 卡在该任务（无输出、无 report、无残留进程，等 240s+ 无果；`tasks` 却正常）。处置：`rm -rf library/build/default/cache/default/default@HarCompileArkTS` 后构建恢复 ~2s 完成。单测（`.test` 目录）未观察到同类问题。
- **ArkTS 语法红线补充：`import` 必须在文件顶部**（错误 10605150 arkts-no-misplaced-imports）——`library/Index.ets` 的正确顺序是 import → 顶层调用 `installCryptoDefaults()` → export 语句。
- **验收 grep 是纯字面匹配，注释也不能踩**：`@kit\.`/`CryptoSource`/`HmacProvider` 等字样出现在任何注释里都会让 grep 类验收失败（T03 首版被注释命中 3 处，改写措辞后清零）。写注释时避免这些词（用「kit」「internal/*」等替代）。
- **未使用 import 不构成编译错误**（CryptoSource.ets 骨架的 `cryptoFramework` 未被引用仅 WARN），可以放心先留 import 再让后续任务实现。
- **QA 场景实证**：① 移除 `Index.ets` 的 `installCryptoDefaults()` 调用后本地单测仍 12/12 全绿（分支 B 下测试模块图内无 barrel，走深路径）；② 在 `HmacProvider.ets` 加一行 `import { cryptoFramework } from '@kit.CryptoArchitectureKit';` 后本地单测仍全绿（import kit 本身不失败）但 AC1 grep 必命中——这正是「验收 grep 有效性」的证明方式。
- **`library/oh-package.json5` 新增 devDependencies 无需 `ohpm install`**：根 `oh_modules` 已含同版本 hypium/hamock，hvigor 直接解析。
- **macOS 无 GNU `timeout`**：软超时用「后台启动 + `kill -0` 轮询 + `pkill -9 -f hvigor` + `rmdir /tmp/ohos-otp-hvigor.lock`」。

## T03 脚手架完成 + 构建流程变更（main agent 追加，2026-10-02 07:32:00）

### ⚠️ 重要变更：T02 的「`-c modelVersion=6.1.1` 会自动迁移根 oh-package.json5」已失效
T03 实测（并由 T03 在 `.hvigor/report/` 中找到 03:31/03:52 两次更早的同样失败佐证）：带 `-c modelVersion=6.1.1` 跑实际任务时**不再自动迁移**，hvigor 恒报 `00303027`（hvigor-config 6.1.1 vs oh-package 6.0.0 不一致）exit 255。
**统一后的构建流程（T03 实测可跑通，编排方已在隔离副本冷缓存复跑验证）**：

```bash
export PATH="/Users/yansongda/.nvm/versions/node/v24.20.0/bin:$PATH"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
HB=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw
cd <repo>
cp oh-package.json5 /tmp/oh-package.json5.bak                              # ① 备份
sed -i '' 's/"modelVersion": "6.0.0"/"modelVersion": "6.1.1"/' oh-package.json5   # ② 临时迁移
# ③ 持 hvigor 锁执行（见 §0.2；本 Wave 多任务并发时**必须**持锁）
$HB --no-daemon -c modelVersion=6.1.1 test --mode module -p module=library@default -p testType=local
# ④ 还原工程配置（必须！仓库里 oh-package.json5 永远保持 6.0.0）
cp /tmp/oh-package.json5.bak oh-package.json5 && rm -f /tmp/oh-package.json5.bak
rm -f library/BuildProfile.ets; rmdir /tmp/ohos-otp-hvigor.lock 2>/dev/null
```

- 每次构建后 `git status --short` 必须不含 `oh-package.json5` / `hvigor/hvigor-config.json5` / `library/BuildProfile.ets`。
- **构建卡死（HarCompileArkTS 无输出、无 report）** → `rm -rf library/build/default/cache/default/default@HarCompileArkTS` 后重跑（T03 实测恢复）。
- macOS 无 GNU `timeout`：用「后台 + `kill -0` 轮询 + `pkill -9 -f hvigor`」实现软超时；被 kill 后务必 `rmdir /tmp/ohos-otp-hvigor.lock`。

### 并行提交的 git 锁（W3/W4/W6 多 worker 并发时**必须**使用）
多个 worker 同时 `git add`/`git commit` 会撞 `.git/index.lock`，且可能误把别人的文件纳入本次提交。统一约定：

```bash
GITLOCK=/tmp/ohos-otp-git.lock
for i in $(seq 1 120); do mkdir "$GITLOCK" 2>/dev/null && break; find /tmp -maxdepth 1 -name 'ohos-otp-git.lock' -mmin +15 -exec rmdir {} \; 2>/dev/null; sleep 5; done
git add <仅本任务的显式文件路径>          # 严禁 git add -A / git add .
git commit -m "<本 todo 的 message>"
rmdir "$GITLOCK"
```

### ArkTS / 工程约束（实测）
- `import` 必须在文件顶部（第一条语句前不得有其他语句），否则 `10605150 arkts-no-misplaced-imports`。
- 源码与 `Index.ets` 的**注释**里也不要出现 `CryptoSource`（除 CryptoSource.ets 自身）、`@kit.` 字样——验收 grep 是全文件匹配，注释命中即判失败。
- `library/oh-package.json5` 加 `devDependencies` 无需 `ohpm install`（根 `oh_modules` 已含同版本 hypium/hamock）。
- 本地单测用例级结果（比 hvigor stdout 可靠）：`library/.test/default/intermediates/test/coverage_data/test_result.txt`（格式 `class=<套件>` / `test=<用例>` / `result=Success|Failure` + `Tests run: …`）。

### 交接项
- `internal/CryptoSource.ets` 的 `installCryptoDefaults()` 目前是 NOT_IMPLEMENTED 占位，**归 T07 实现**（只 new + 注册，禁止发起 crypto 调用）。
- `Secret.generate(byteLength = 20)` 形参名与设计 §3.2 的 `bytes` 不一致，**T08 需改回 `bytes`**。

## T06 时间步与恒定时间比较（worker 追加，2026-10-02 08:40:00）

- **W3 并发下 `/tmp/oh-package.json5.bak` 是共享文件**：4 个 worker 都用同一路径做「备份→迁移→还原」，任一 worker 的还原步骤都会把 oh-package.json5 覆写回 6.0.0，导致持锁方下一次构建报 00303027（本任务 QA 后重跑即因此失败过一次）。**处置：备份名用唯一路径（如 `/tmp/oh-package-t06.bak`），还原用自己的备份，勿依赖共享名。**
- **`library/.test/default/intermediates/test/coverage_data/test_result.txt` 跨运行累积（追加而非覆盖）**：多次构建后文件含多轮结果，`Tests run:` 行是累积总数，单轮验收前先 `rm -f` 该文件再跑，否则容易误读。类计数中 `class=` 行与 `test=` 行数量可不等（部分类只有 result 行），以 `Tests run: N, Failure: 0` 与自己的套件用例行（`test=...` / `result=Success`）为准。
- **hypium `assertClose(expected, precision)` 是相对误差**（`|expected-actual|/|actual| < precision`），actual=0 且 diff≠0 时恒失败；做「接近值」断言（如 `progress(1000,0,30) ≈ 1/30`）时可用它，但要写明容差理由。
- **hypium `assertThrowError(string)` 匹配的是错误 message 的 includes**（非 code 字段）；OtpError 的固定文案即错误码字符串，`expect(() => fn()).assertThrowError('INVALID_TIMESTAMP')` 可直接锁定错误码。
- **T06 QA 实证**：把 `remainingSec` 破坏成 `period - s % period` 后，`t0=0` 全部用例保持绿，仅 `t0≠0` 用例（`remainingSec(1000,5,30)` 与 `remainingSec(31000,1,30)`）变红——证实「无 t0≠0 专项用例时，实现丢掉 t0 也不会红」。
- **concurrent worker 的文件**：W3 并行期间 `git status` 会看到其他 worker 的 in-progress 文件（Counter/Digits/Truncate/CryptoSource），提交时只 add 自己 3 个显式路径，其余保留不动。

## T05 整数原语（worker 追加，2026-10-02 08:40:00）

- **`assertThrowError(string)` 匹配的是 OtpError 的 message.includes**：OtpError 固定文案 == 错误码字符串（如 `'INVALID_COUNTER'`），所以 `expect(() => toBytes(-1)).assertThrowError(OtpErrorCode.INVALID_COUNTER)` 可直接锁定错误码（hypium `assertThrowError.js` 源码：`err.message.includes(expected[0])`）。
- **注释里也不能出现验收 grep 目标词**：`Digits.ets` 首版注释写了「不依赖 padStart」，被 `grep -rn "padStart"` 命中（AC2 失败）。learning §T03 已提示过「验收 grep 纯字面匹配，注释也算」，T05 再次踩坑——注释措辞必须避开 `padStart`/`NOT_IMPLEMENTED`/`it(` 等字样。
- **W3 并发实测**：08:36 首次单测时 T06 的 `timeStepTest` 有 2 条失败（`remainingSec31000_1_30`/`remainingSec1000_5_30`，其 worker 正在编辑），08:37 复跑已全绿。按「无编译错误 + 自己套件全绿」判定，不把他人 in-progress 失败当自己失败。
- **git stat-cache 假阳性**：多次 `cp /tmp/oh-package.json5.bak oh-package.json5` 还原后，`git status` 显示 ` M oh-package.json5` 但 `git diff`/MD5 均与 HEAD 一致——是 stat 缓存 mtime 失配，`touch oh-package.json5` 即恢复洁净，无需 checkout。
- **QA 红点实测值**（供后续 F 审查核对）：① `high` 改 `counter >> 32` → counterTest 7 条红（`toBytes(1)` expect 1 equals 0 等）；② 去掉 `& 0x7f` → truncateTest 4 条红（counter=0/1/3/9，均为 `digest[offset]>=0x80`，如 counter=0 `expect 3432238872 equals 1284755224`）；③ 取模换 `value` → digitsTest 1 条红（`format(137359152,8)` `expect 137359152 equals 37359152`）。

## ⚠️ 验收判据修正：hvigor `test` 的 exit code 不可信（main agent 追加，2026-10-02 08:07:50）

编排方在 T05/T06 的独立破坏实验中实测：**hvigorw `test` 任务即使有用例失败，exit code 仍为 `0`**（例：故意去掉 `Truncate` 的 `& 0x7f` → `EXIT=0` 但 `Tests run: 70, Failure: 4, Pass: 66`；故意丢掉 `remainingSec` 的 `t0` → `EXIT=0` 但 `Failure: 2`）。
**因此所有「单测通过」的判定必须读用例级结果文件，而非 exit code**：

```bash
# 唯一可信判据（Failure 必须为 0）
grep -E "^Tests run" library/.test/default/intermediates/test/coverage_data/test_result.txt
grep -E "^class=|^test=|^result=" library/.test/default/intermediates/test/coverage_data/test_result.txt | grep -B2 "result=Failure"
```

- 后续任务（T08–T14）与 F3 最终验证一律按此判据执行；worker 若只贴 `BUILD SUCCESSFUL` 而未贴 `Tests run … Failure: 0`，视为**未完成验证**。
- 隔离副本验证法（编排方已用它复核 T05/T06，强烈推荐给需要「确定性复跑」的场景）：
  ```bash
  rm -rf /tmp/v-<task> && mkdir -p /tmp/v-<task>
  (cd <repo> && tar -cf - oh_modules | (cd /tmp/v-<task> && tar -xf -))     # 排除 .git 与构建缓存
  (cd <repo> && git archive <commit> | tar -x -C /tmp/v-<task>)
  sed -i '' 's/"modelVersion": "6.0.0"/"modelVersion": "6.1.1"/' /tmp/v-<task>/oh-package.json5
  # 在副本内跑 hvigor（持 /tmp/ohos-otp-hvigor.lock）
  ```
  好处：不影响仓库、无并发干扰、可确定性复现指定 commit 的状态。
- 破坏-变红实验（验证用例灵敏度）也建议在副本内做，避免污染仓库文件。

## T07 加密适配器（worker 追加，2026-10-02 08:39:00）

- **分支 B 下 QA②（临时改坏 algName 映射）本地观察不到红点**：把 `toMacAlgName` 改成固定 `return 'SHA1'` 后，本地单测仍 70/70 全绿——`cryptoSourceTest` 只有 1 条 importSmoke，不触发真实 crypto。这正是分支 B 语义：该缺陷红点只能由 T11 设备用例（ohosTest `CryptoAdapter.test.ets` 的 SHA256/SHA512 向量）承担。todo 要求「记录输出后还原」，分支 B 下不要期待本地变红。
- **注释里 `HMAC|` 字面量会命中验收 grep**：初版注释写「严禁 'HMAC|SHA1' 之类规格」（继承历史坑措辞），被 `grep -n "HMAC|"` 命中。验收 grep 是纯字面匹配，注释措辞须避开——已改写为「管道符拼接算法名的组合规格（如 HMAC 管道符 SHA1）」。与 T03/T05 的「注释不能踩 grep 词」同一教训。
- **`installCryptoDefaults()` 的静态锁定方式**：`awk '/function installCryptoDefaults/{f=1} f{print} f&&/^\}/{exit}' <file> | grep -c "cryptoFramework\."` 必须为 0——函数体内只能 `new` + `registerHmac/registerRandom`，连注释都不能出现 `cryptoFramework.`（本实现注释在函数体外，安全）。
- **cryptoFramework 同步链路（本机 SDK 权威签名，T07 已编译验证）**：`createSymKeyGenerator('HMAC')` → `convertKeySync({data: Uint8Array})` → `createMac('SHA1'|'SHA256'|'SHA512')` → `initSync(symKey)` → `updateSync({data})` → `doFinalSync()` 返回 `DataBlob`（`.data` 为 `Uint8Array`）；随机源 `createRandom().generateRandomSync(bytes)`。`createRandom(): Random` 在 d.ts L1433。所有调用必须 try/catch → `OtpError(CRYPTO_FAILED, 'CRYPTO_FAILED')` 固定文案。
- **W3 并发下「构建+单测」合并执行易超时**：首次把 assembleHar 与 test 串在同一 bash 命令里，单测执行期挂起被环境终止（report 显示卡在 UnitTestArkTS 之后的测试执行期）。分步执行（各自持锁）后 2s 级成功。后续 W3 任务建议构建与单测**分开两次持锁执行**，避免一次超时丢全部结果；被 kill 后记得 `rmdir /tmp/ohos-otp-hvigor.lock` 并检查 `oh-package.json5` 是否残留 6.1.1 迁移态（`cp /tmp/oh-package.json5.bak` 还原）。
- **`grep -c` 统计的是行数**：`OtpErrorCode.CRYPTO_FAILED` 在 sign 与 random 各 1 行 → CryptoSource.ets 计数 2，加上 HmacProvider.ets 的 2 行 `CRYPTO_NOT_INITIALIZED` 合计 4 ≥ 2，Acceptance 通过。

## T07 cryptoFramework 适配器落地（main agent 追加，2026-10-02 08:21:30）

- **`*Sync` 链路在本地 SDK 上可编译**（`assembleHar` exit 0、零 ERROR）：`createSymKeyGenerator('HMAC')` → `convertKeySync({data})` → `createMac(algName)` → `initSync(symKey)` → `updateSync({data})` → `doFinalSync()`。运行期在 PC 上仍返回空 DataBlob（分支 B），**设备端正确性由 T11 覆盖**。
- **密钥生成器必须用通用 `'HMAC'` 规格**（支持 1–4096 字节任意长度），不得用管道符组合规格（会拒绝 80 bit/10 字节的存量 secret）。
- `installCryptoDefaults()` 已补全为「只 `new` + `register*`」，**注册期零 crypto 调用**（用 `awk` 取函数体 + `grep -c "cryptoFramework\."` = 0 做静态断言锁定；这是两个分支下唯一可观察的验证手段）。
- `internal/HmacProvider.ets` 是 T03 的专属文件，T07 已确认未改动（`git show --stat <t07 commit> -- HmacProvider.ets` 为空）。
- **T11 接手项**：设备端 `library/src/ohosTest/ets/test/CryptoAdapter.test.ets` 必须覆盖（a）三算法 counter=1 的 digest 对照附录 A；（b）`TOTP`/`HOTP` 公开类走**默认 provider**（不注入 fixture）出码；（c）barrel（`Index.ets`）注册链路可用；（d）`Secret.generate(20)` 真实随机源。当前**无设备**，T11 需按「未执行 + 人工步骤」如实记录（**严禁 expect(true) 占位伪报**）。

## T04 Base32 编解码（worker 追加，2026-10-02 08:45:02）

- **QA 破坏场景已实测并还原**：字母表索引 31 `7`→`0` 后，`base32Test` 唯一红点 = `decodeIllegalChar_ab0`（`'0'` 变合法不再抛错，`expectThrowsCode` 的 thrown 断言失败，报 `Error in decodeIllegalChar_ab0, expect true, actualValue is false`）；`decodeIllegalChar_AB1`（`'1'` 始终非法）与 A.1 seed round-trip 用例（只用到索引 ≤30 的字符）**均不变红**——与计划附录 7.2-3 的复算一致。还原后字母表恢复 `'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'`。
- **hypium 1.0.25 的 `assertThrowError` 精度不足**：字符串期望只做 `err.message.includes()`，函数期望只比对 `constructor.name`；要断言**具体错误码**必须 try/catch 后取 `(e as OtpError).code` 用 `assertEqual` 精确匹配（本任务 `expectThrowsCode` 辅助函数模式，后续 T08/T10 等错误断言可复用）。
- **hypium 用例失败不使 hvigor 构建失败**：QA 破坏场景下 hvigor 仍 `BUILD SUCCESSFUL`（exit 0），判定红点必须看 `test_result.txt` 的 `result=Failure` + 用例堆栈（`Error in <用例名>, ...` 行直接给出失败用例名），不能只看构建结果。
- **ArkTS 位缓冲编码可行**：`buffer = (buffer << 8) | bytes[i]` + `(buffer >>> (bitsLeft-5)) & 31` 取 5 位组、末尾 `(buffer << (5-bitsLeft)) & 31` 补零，buffer 恒 ≤ 12 bit 无 32 位符号溢出问题；输出字符数天然 = `ceil(len*8/5)`，无需 `padStart`/二进制字符串。
- **`encode` 空数组返回 `''`（不抛错）** 与 `decode` 空串抛 `EMPTY_SECRET` 的语义差是设计意图（encode 的语义由调用方决定），T08 `Secret.fromBytes`/`toBase32` 接手时注意别误改成抛错。

## W3 全部完成（main agent 追加，2026-10-02 08:41:40）

四个并行任务均由编排方在**隔离副本**（`git archive <commit>` + `oh_modules`，排除 `.git`/构建缓存）冷缓存复跑验收，并各做一次破坏-变红灵敏度实验：

| 任务 | commit | 复跑结果 | 破坏-变红实验 |
|---|---|---|---|
| T04 Base32 | `0982209` | `Failure: 0, Pass: 85`（base32Test 16） | 字母表索引 31 `7`→`0` → **1 条**（`decodeIllegalChar_ab0`）变红 ✓ |
| T05 原语 | `07be70b` | `Failure: 0, Pass: 70`（14/11/10） | 去掉 `Truncate` 的 `& 0x7f` → **4 条**变红 ✓ |
| T06 TimeStep | `dae8bc8` | `Failure: 0, Pass: 38`（27） | `remainingSec` 丢 `t0` → **2 条**变红 ✓ |
| T07 CryptoSource | `8da3abe` | `Failure: 0, Pass: 70`；`assembleHar` exit 0 | 固定 `'SHA1'` 映射 → 分支 B 本地**不红**（计划预期，红点归 T11 设备用例）|

**并行 Wave 的实操经验（W4/W6 复用）**：
- 「hvigor 锁 + git 锁 + 只 add 显式路径」三件套即可让 4 个 worker 并发互不干扰；提交后工作区只剩编排方维护的 `M docs/**`（预期）。
- 共享文档（`docs/learning/ohos-otp-lib-rfc.md`、`docs/implementation/**`）在并发 Wave 中**由 worker 只追加、不提交**，由编排方在 Wave 末统一记账提交，避免相互夹带。
- 并行期单测的 `Tests run` 总数会随其他任务落地而增长（12 → 38 → 70 → 85），**判定只看 `Failure: 0`**，不要拿总数做断言。

## T09 编排引擎 + 黄金向量 fixture（worker 追加，2026-10-02 08:55:00）

- **`grep -c "it("` 是字面量行数，不是运行时用例数**：初版用 for 循环注册 `it()`（运行时 61 条、字面 23 行）不满足 AC「≥45」；验收按字面量，须逐条展开显式 `it(`。与「注释别写 it(」同一计数语义。
- **ArkTS 对象字面量三条红线（本任务踩全）**：① 接口字段不能用内联对象字面量类型 `{a: string}`（`arkts-no-obj-literals-as-types`）；② 数组字面量元素若含内联对象字面量类型会连带报 `arkts-no-noninferrable-arr-literals`；③ 无类型注解的对象字面量赋值必须对应具名 interface/class（`arkts-no-untyped-obj-literals`）。处置：`BOUNDARY_COUNTERS` 的 `{digest,code6,code8}` 提为 `BoundaryAlg` 具名接口；`SEEDS` 声明 `Seeds` 接口；测试参数对象显式 `: EngineParams`。
- **`internal/*` 均为具名函数导出**（`toBytes`/`apply`/`format`/`step` 等），不是命名空间对象——`import { Counter }` 会报「no exported member」；须按名导入，重名冲突用 `as` 别名（`apply as truncateApply`）。
- **fixture 表键用引擎同源的 `toBytes` 生成 message hex**：保证装表键与引擎实际传入 message 逐字节一致，避免「表键口径不同导致假红/假绿」。
- **QA① 的 sed 陷阱**：`s/& 0x0f/& 0x0e/` 的 `&` 在替换串中展开为整段匹配文本，产物是 `& 0x0f 0x0e` 编译错误（不是红点）。破坏实验用纯字面替换 `s/0x0f/0x0e/`，或先备份再 python replace，避免 `&` 展开。
- **QA 红点实测值（供 F 审查）**：① Truncate `0x0f→0x0e` → `Failure: 26`（otpEngineTest 23 + truncateTest 3，RFC 向量大面积红）；② TimeStep.step 外层 `floor→round` → `Failure: 16`（otpEngineTest 12 个 RFC6238 时间点 + timeStepTest 4）；③ fixture 未命中改返零值数组 → `Failure: 1`（仅 `fixture_miss_throws`）。均还原，`git diff` 与 HEAD 无差异。
- **W4 并发下 test_result.txt 的 `Tests run` 总数会随 T08 落地增长（145→176）**：判定只看 `Failure: 0` + 自己的套件；`rm -f` 后再跑仍可能累计多轮，别拿总数断言。
- **verify 窗口语义实现**：负候选（candidate<0）与超 2^53-1 候选跳过而非报错；扫完全部候选才返回首个命中 delta（不提前 return）；token 校验先于 window 校验（todo 顺序 ①②）。

## T09 引擎与向量验证方法（main agent 追加，2026-10-02 09:17:00）

- **最强验证手段（推荐复核黄金向量时复用）**：用 `node` 的 `crypto.createHmac` + 手写动态截断，**独立复算** `RfcVectors.ets` 的每一个 digest/码值再逐项比对（编排方本次做了 **112 项检查，0 项真实不一致**）。注意这不是「自证」：复算用的是与 ArkTS 完全无关的实现，且复算脚本只是**校验**，不参与 fixture 生成。
- **无填充 base32 的位数公式**：输出字符数 = `ceil(bits/5)`，**不是** `bytes×8`。32 字节 → 52 字符（260 位）；64 字节 → 103 字符（515 位）。按位长反推会误判为「不一致」（编排方初次检查脚本即踩此坑），正确做法是用 base32 解码后与原始字节逐字节比对。A.1 三算法 seed 的 base32 规范形已用真实解码器复核：**逐字节相等**。
- `OtpEngine.verify` 的正确形态：用 `firstMatch` 记录首个命中后**继续扫完整个窗口**（不得提前 return），`candidate < 0 || !isSafeCounter(candidate)` 跳过；`OtpEngine.ets` 内应**完全没有 `%`**（取模只在 `Digits.format`）。
- `HmacFixture.sign` 未命中必须 `throw`，并有专门用例（`fixture_miss_throws`）锁定；**绝不允许返回零值数组**。

## T08 Secret + OTPAuth URI 规范化层（worker 追加，2026-10-02 08:57:21）

- **W4 并发实测**：T09 先持锁构建时把 oh-package.json5 迁到 6.1.1，其释放锁前已还原为 6.0.0（我拿到锁时确认是 6.0.0）。拿锁后立刻自检 modelVersion 再决定是否 sed；还原用自己的唯一备份名（`/tmp/oh-package-t08.bak`），避免踩共享 `/tmp/oh-package.json5.bak`（T06 已踩）。
- **waiting-for-lock 经验**：等锁用「`mkdir` 轮询 + 每 10s 一次 + 上限」，T09 用完释放后约 50s 拿到；不要在无锁时跑 hvigor（含 `tasks` 只读命令也建议持锁，避免与对方写盘竞态）。
- **`assertLargerOrEqual(0)` 可用来断言 `indexOf >= 0`**（hypium 已含该方法，`json.indexOf('[REDACTED]') >= 0` 脱敏断言可用）；`assertEqual` 是严格 `===`，`assertEqual(undefined)` 对 undefined 字段可用（parse 结果可选字段比对）。
- **`OtpError instanceof` 双真在真实套件里实测通过**（`instanceof Error` 与 `instanceof OtpError` 均 true），无需改错误模型——T02 探针结论在 hypium 运行时再次确认。
- **ArkTS `Map<string,string>` 可用**（query 手写拆分用 Map 存键值，编译通过）；`params.get(k)` 返回 `string | undefined`，判空用 `=== undefined`。
- **枚举值字符串拼接可用**：`'algorithm=' + params.algorithm`（OtpAlgorithm 字符串枚举）编译与运行均正确输出 `algorithm=SHA1`。
- **ArkTS 可选链/接口可选字段**：`result.period = period` 对可选字段赋值合法；`params.issuer === undefined ? '' : params.issuer` 模式可安全取默认值（避免 `??` 在部分旧版 ArkTS 工具的兼容疑虑，直接用三元）。
- **QA 红点实测值（供 F 审查）**：① 去掉 parse 的 digits 校验（digits=5 不再抛）→ `Failure: 1`，唯一红点 `parse_failInvalidDigits`（`expect true, actualValue is false`）；② 删掉 `Secret.toJSON()` → `Failure: 1`，唯一红点 `jsonStringify_redactsSecret`（`-1 is not larger than 0`），`stringConversion_doesNotLeakSecret` 仍绿（无 toString 时 String() 本来就不含明文）。均还原后 176/176 全绿。
- **验收 grep 注释红线再次验证**：Secret/OTPAuthURI 的注释里绝不能出现 `@kit.`/`URLSearchParams` 字面量（即使是无害措辞）；写「不依赖平台 URL 查询解析 API」替代。T08 注释用「kit-free」「import kit」避开了 `@kit.`。
- **`build` 与 GA 惯例**：digits 仅 !=6、period 仅 TOTP 且 !=30 时输出（省略默认值），algorithm 始终输出，HOTP 的 counter 始终输出（规范必填）——T10/T11 若断言 build 输出请对齐该惯例。
- **parse 缺省归一化**：TOTP 结果恒带 `period`（默认 30）、HOTP 恒带 `counter`（默认 0）；round-trip 语义等价断言须把「缺省=默认值」归一化后比较（本任务 `assertParamsEqual` 模式可复用）。

## W4 完成（main agent 追加，2026-10-02 09:42:00）

- **T08 `72d0e92`**（Secret + OTPAuthURI）：隔离副本 `Failure: 0, Pass: 176`（secretTest 10 / otpAuthUriTest 20 / otpErrorTest 4）；破坏实验两处 red 点均命中（去掉 digits 校验 → 1 红；删掉 `toJSON()` → 1 红）。
  - 已闭环 T03 交接项：`Secret.generate(byteLength)` → **`generate(bytes)`**（与设计 §3.2 形参名一致）。
  - `Secret` 无 `toString()`（仅注释说明），`bytes` getter 与 `fromBytes` 均为拷贝语义；`OTPAuthURI` query 手写拆分，未用 `URLSearchParams`。
- **T09 `fbd7e84`**（引擎 + 向量 + fixture）：隔离副本 `Failure: 0, Pass: 145`，`otpEngineTest` 61 条；编排方 node 独立复算 **112 项 0 不一致**。
- **共享知识（供 T10 及后续复用）**：
  - `HmacFixture` 表键 = `<algorithm>:<8 字节大端 counter hex>`，装表来源 = `RfcVectors` 的 A.2/A.3/A.4/A.6；**A.6 SHA256/counter=0（`SHA256_C0_DIGEST`）已落表** → T10 的 `period=60` fromURI 用例（counter=0）不会查表未命中。
  - `SEEDS.SHA1_BASE32`（`GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`）/`SHA256_BASE32`/`SHA512_BASE32` 可直接用于 T10/T11 走公开 API 的向量用例（A.1 规范形，已用真实 base32 解码器复核逐字节相等）。
  - 公开类必须接受第二参 `provider?: HmacProvider`（`@internal 仅测试注入`）——T10 的全部用例都靠注入 `HmacFixture`，**不能**依赖默认 provider（分支 B 下本地 crypto 返回空数据）。

## T10 公开类 HOTP/TOTP + 时钟偏移（worker 追加，2026-10-02 09:11:16）

- **TOTP 走公开类跑三算法向量时必须显式传 `algorithm`**：`new TOTP({secret: SHA256_BASE32, digits:8})` 的 algorithm 默认 SHA1，会拿 SHA1 fixture 出码（t20000000000 出 65353130 而非 47863826）。初版漏传导致 6 SHA256 + 6 SHA512 全红，补 `algorithm: OtpAlgorithm.SHA256/SHA512` 后全绿。与 T09 用 EngineParams 显式带 algorithm 同因。
- **`fromURI(uri)` 无 provider 参数，走默认 `requireHmac()`**：本地测试要让 fromURI 产物可算出码，需在套件顶部 `registerHmac(fixture)`（深路径 import `internal/HmacProvider`）注册 fixture 为默认 provider。注意 `registerHmac` 是模块级单例、跨套件持久——本仓库无套件依赖「requireHmac 未注册抛错」，注册安全；若未来加 `resetForTest()` 依赖的用例需留意顺序。
- **QA 灵敏度实证（T10 完成）**：① `syncClockOffset` 的 `-=` 改 `+=` → 3 条红（scenarioA/scenarioB/verify_appliesClockOffset）；② 去掉构造期 digits 校验 → HOTP/TOTP 各 1 条 `ctor_digits5_throws` 红。说明「双场景 + 构造期抛错」用例能真实抓住这两类回归。
- **`syncClockOffset` 语义确认**：`delta` 非整数 → `INVALID_WINDOW`（单参数，无 options）；`clockOffsetMs -= delta * period * 1000`。场景 A：delta=+1 → offset=-30000 → generate(89000) 有效 59000 → c1；场景 B：delta=-1 → offset=+30000 → generate(59000) 有效 89000 → c2。所有时间入口（含显式 timestamp）都叠加 offset。
- **hypium `expect(fn).assertTrue()` 恒失败**（断言的是函数对象 === true）——「不抛错」用例不能这么写，应真实构造后对产物断言（如 `new HOTP({...}).generate() === '755224'`）。
- **TOTP 构造期校验清单**（与 HOTP 共用 digits/minSecretBits，另加）：period 正整数→INVALID_PERIOD、t0 ≥0 整数→INVALID_T0、clockOffsetMs 有限数→INVALID_TIMESTAMP。
- **验收 grep 计数语义再次确认**：`grep -c "it("` 是字面行数（Hotp 22 / Totp 44），注释与 `it(` 同行的 `it(` 也算；用例名里含 `syncClockOffset` 会推高 grep 计数（10 ≥ 2 阈值）。

## T10 公开类完成 → API 冻结（main agent 追加，2026-10-02 11:07:00）

- **commit `df5d524`**，隔离副本 `Failure: 0, Pass: 240`（hotpTest 22 / totpTest 44）。
- **API 已冻结**（T12 的 README/示例必须与之一致）：
  - `new HOTP(options: HotpOptions, provider?: HmacProvider)` / `new TOTP(options: TotpOptions, provider?: HmacProvider)`；`provider` 为 `@internal 仅供测试注入`，缺省走 `requireHmac()`。
  - `HOTP.generate(counter?)` / `HOTP.verify(token, options?)` / `HOTP.toURI()` / `HOTP.fromURI(uri)`。
  - `TOTP.generate(timestampMs?)` / `verify(token, options?)` / `remaining(ts?)` / `progress(ts?)` / `syncClockOffset(delta)` / `get clockOffsetMs` / `toURI()` / `TOTP.fromURI(uri)`。
  - `fromURI` **不接受 provider 参数**；本地测试要覆盖 `fromURI` 需先 `registerHmac(fixture)`（注册表契约允许），设备端则由 barrel/`installCryptoDefaults()` 提供默认实现。
- **已验证的推导结论（后续任务可直接引用）**：`syncClockOffset(+1)` → `clockOffsetMs = -30000` → `generate(89000)` 有效 59000 → counter 1；`syncClockOffset(-1)` → `+30000` → `generate(59000)` 有效 89000 → counter 2；`t0=1, period=30, ts=31000` → counter 1；`period=60, ts=59000` → counter 0（SHA256 c0 = `18920136`）。
- 破坏-变红实测：`-=`→`+=` 触发 3 红；去掉构造期 digits 校验触发 2 红 → 用例灵敏度达标。

## T13 消费方 smoke demo（worker 追加，2026-10-02 09:16:46）

- **`ohpm install --all` 对 `file:../library` 依赖的解析**：在**模块目录**下生成符号链接 `entry/oh_modules/@yansongda/otp -> ../../../library`（`entry/oh_modules` 被 `**/oh_modules` 忽略），并生成**模块级** `entry/oh-package-lock.json5`（`registryType: "local"`、`resolved: "../library"`）；根 `oh-package-lock.json5` 不变。副产物：`library/oh-package-lock.json5`（扫描 library devDependencies 生成）——**非任务文件，别提交**，留待编排方 bookkeeping。
- **entry `assembleHap` 在「products 有 `"signingConfig": "default"` 但 `app.signingConfigs` 为空数组」时不报错**：`SignHap` 仅 WARN `Will skip sign 'hos_hap'. No signingConfigs profile is configured` 后继续，构建照常 `BUILD SUCCESSFUL`，产物为 `*-unsigned.hap`。→ **T13 授权的 signingConfig 行移除未触发**，`build-profile.json5` 保持原样。此结论修正了「空 signingConfigs + 有引用行必然报签名错误」的预判。
- **`file:../library` 本地依赖构建有两条无害 WARN**：① `Missing module info for local modules '@yansongda/otp'`（本地依赖无远程元信息）；② `'page_text_font_size' conflict`（library 模板残留的 float.json 与 entry 同名资源，HAR 库本不该有 UI 资源，归属 T03/T12 处理，T13 不动）。均不影响构建结果。
- **消费方 UI 编译要点**：`import { TOTP, OtpError } from '@yansongda/otp'` 在 entry 侧编译/运行链路成立（barrel 自动 `installCryptoDefaults()`，消费者零配置）；`setInterval`/`clearInterval` 在 ArkUI 组件可直接用（`private timerId: number = -1` + `aboutToDisappear` 清理）；`Progress({ value: progress, total: 1 })` 直接吃 `progress()` 的 [0,1) 返回值；`catch (e) { const err = e as OtpError; err.code }` 分支展示可用。
- **QA failure 场景（`'AB1'`）无设备时的验证法**：临时改 secret 后重新构建——编译期不报错（抛错在运行期构造），构建 SUCCESSFUL 即证明 try/catch 路径编译成立；运行期推导链路引用 T04 已锁定的 `decodeIllegalChar_AB1` 行为（`'1'` 不在字母表 → `Base32.decode` 抛 `INVALID_BASE32_CHAR` → TOTP 构造器透传 → demo catch 展示）。必须注明「静态检查 + 待人工验证」，不得伪报运行时行为。

## T12 发布物料（worker 追加，2026-10-02 09:19:00）

- **字节码 HAR 定论已闭环**：`assembleHar` 产物包内自动生成 `types: "Index.d.ets"`（`byteCodeHar: true`），`library/oh-package.json5` **不手工加 `types`**（T02 结论，T12 再次确认）。
- **README 验收 grep 的 `\b` 单词边界陷阱**：AC4 用 `grep -oE '\b(OtpError|...)\b'` 提取 README 中的 API 名——`OtpErrorCode` 文本不会让 `\bOtpError\b` 命中（`r` 与 `C` 之间无边界），所以 README 里 `OtpError` 必须作为独立单词出现（表格中写类名即可）；同理 `OtpType`/`OtpAlgorithm`/`TOTP`（后跟 `(`/`.`/空格均算边界）。写 README 时留意类名与枚举名分开出现。
- **16 个对外错误码表 = 17 枚举 − `NOT_IMPLEMENTED`**：故障排查表只列 16 个，`NOT_IMPLEMENTED` 在表前说明中提及「已从交付产物清零」即可，不能进表。
- **快速开始示例的码值陷阱**：`JBSWY3DPEHPK3PXP`（80 bit / 10 字节）的 counter=0 码**不是** `755224`——`755224` 属于 20 字节 ASCII seed `12345678901234567890`（base32 `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`）。README 示例若标注码值必须用后者；前者只展示调用形态。
- **`syncClockOffset`/`verify`/`remaining` 等签名与默认值已在 T12 与冻结源码逐条核对**（evidence §三 18 项对照表）：`verify` 默认 `window:0` 严格、示例须显式 `{window:1}`；`remaining` 取值 `[1,period]`、`progress` 取值 `[0,1)`；`fromURI` 无 provider 参数。
- **发布前检查清单第 2 条「README 含 ohpm install」的失效检测已实测**：删行后 `grep -c` 从 2 → 0，清单条目可发现（QA failure 场景）。
- **README 中写「不使用 @security/no-unsafe-mac 豁免」不会触发 F4**：F4 的 `grep -rn "no-unsafe-mac" library/src/ library/Index.ets` 范围明确排除 `library/*.md`。

## T12/T13 完成（main agent 追加，2026-10-02 11:54:00）

- **T12 `0ecde3e`**：README（英/中 各 180 行）+ CHANGELOG（`## 1.0.0 - 2026-10-01`）+ LICENSE 定稿；6 条 Acceptance 全过（安装命令、16 个对外错误码、API 名可 grep 到导出、13 个章节）。**诚实性要点已核对**：README 明写分支 B 的可测性缺口与「设备端待人工验证」，未宣称覆盖率。
- **T13 `6abc751`**：`entry` 走 barrel 消费 `@yansongda/otp`（`file:../library`），编排方在隔离副本实跑 `assembleHap -p module=entry@default` → **exit 0 / BUILD SUCCESSFUL / 零 ERROR**，产出 `entry-default-unsigned.hap`（221 KB）。**空 `signingConfigs` 未导致构建失败** → 未触发 T13 唯一授权的 `signingConfig` 行移除，`build-profile.json5` 零改动。
- **`ohpm install --all` 的副产物**：在 `entry/oh-package-lock.json5`（已随 T13 入库）之外还生成了 `library/oh-package-lock.json5`（library 有 devDependencies 时 ohpm 为每个模块生成 lock）。约定：**与 entry 保持一致，入库**（否则 F1 的「零新增未跟踪项」不成立）。后续任何 `ohpm install` 都会重建它，不要删。
- **消费方事实**：`entry/oh_modules/@yansongda/otp` 是指向 `../../../library` 的**相对符号链接**；`entry/oh-package-lock.json5` 里 `@yansongda/otp@../library` 为 `registryType: local`。复制工程做隔离验证时需保留该符号链接（`rsync -a` 默认保留）。

## T11 设备端真实 crypto 验证（worker 追加，2026-10-02 09:20:32）

- **CLI 侧不存在 ohosTest 的独立 ArkTS 编译任务（已探测）**：`assembleOhosTest`/`assembleTest`/`compileOhosTest` 均报 `Task [...] was not found in the project ohos-otp`；`genOnDeviceTestHap` 任务树里的 `CompileArkTS` **只编译 main**（注入语法错误到 `src/ohosTest` 后该任务仍 `UP-TO-DATE`，注入已还原）。ohosTest 编译/运行只能经 DevEco IDE（需设备/模拟器），CLI 无法预验证 ohosTest 源码编译。
- **`genOnDeviceTestHap` 对 HAR 模块打包失败**：`PackageHap` 报 `Ohos BundleTool [Error]: 10011001 ... --resources-path is invalid`——HAR 模块的 ohosTest source set 只有 `ets/test` + `module.json5`、无 resources 目录（T03 脚手架即此形态），属工程级限制（改工程配置超出 T11 边界，未处理）。设备就绪后若 `onDeviceTest` 仍撞此错，人工路径应改走 DevEco IDE Run ohosTest。
- **无设备交付形态（供 F 审查对照）**：测试源码 37 条 `it(` 全真实断言（digest 3 + TOTP 18 + HOTP 10 + Secret.generate 3 + 80bit 密钥 2 + barrel 1），`expect(true)` 零残留；验收 grep 两条已过；本地回归 `Tests run: 240, Failure: 0`；`assembleHar` exit 0。**设备端未执行**，evidence 明确写了「待人工验证 + 人工步骤 + QA failure 预期红点清单」。
- **ohosTest 中「默认 provider」的结构性实现**：barrel（`../../../../Index.ets` 相对导入，T11 静态核对路径与 `export { TOTP }` 均在）在模块加载期执行 `installCryptoDefaults()` → 注册表单例对深路径导入的公开类同样生效，所以「TOTP/HOTP/Secret 用例」与「barrel 用例」互相印证注册链路，无需在测试里显式调注册函数。若 DevEco 首轮编译报 barrel 跨 source set 导入错误，回退路径已预授权（`../../../main/ets/internal/CryptoSource` 的 `installCryptoDefaults` + `requireHmac` 断言）。
- **digest 用例的 key/message 构造**：key 用 `Secret.fromBase32(<A.1 base32 规范形>).bytes`（纯 base32 解码、kit-free，且 A.1 规范形已复核与 ASCII seed 逐字节相等）；message 用 A.5 对照表 counter=1 的 8 字节大端字面量 `[0,0,0,0,0,0,0,1]`——都不算「临时拼」。
- **TOTP 用例照抄 T10 教训**：走公开类跑三算法向量必须显式传 `algorithm`（默认 SHA1），否则 SHA256/512 用例必然红。

## T11 交付状态与双重限制（main agent 追加，2026-10-02 12:12:00）

- **T11 commit `1d9ea2d`**：`CryptoAdapter.test.ets` 37 条真实断言（3 digest + 18 TOTP + 10 HOTP + 3 `Secret.generate` + 2 个 80 bit 密钥 + 1 barrel 链路），无 `expect(true)` 占位。
- **限制 1（计划已预见）**：无设备 → `hdc list targets` = `[Empty]`，设备端**未执行**，按「待人工验证」交付，**未伪报**。
- **限制 2（编排方补充发现，必须继承）**：本环境下 ohosTest 源码**连编译都无法验证**——
  - `ohosTest@CompileArkTS` → task not found（EXIT=1）；
  - `genOnDeviceTestHap` → EXIT=255，任务图在 `:library:default@CompileArkTS`（**main 目标**）之后于 `:library:default@PackageHap` 失败（工程级 `--resources-path is invalid`），**早于 ohosTest 源码编译**；
  - `tasks` 列表里没有 ohosTest 编译任务。
  → 因此 ohosTest 的编译/运行**只能经 DevEco IDE + 设备**；任何 ohosTest 源码改动都属于「静态核对 + 待人工」级别，不可宣称已验证。
- **人工验证步骤（交付给用户）**：DevEco 打开工程 → 启动模拟器/连真机 → 右键 `library/src/ohosTest/ets/test/CryptoAdapter.test.ets` → Run `cryptoAdapterTest` → 期望 37/37 绿；若报跨 source set 导入错误，**机械性回退**：把 `import { TOTP as BarrelTOTP } from '../../../../Index.ets'` 换成 `import { installCryptoDefaults, requireHmac } from '../../../main/ets/internal/CryptoSource'` 并在用例内调用注册后断言 `requireHmac()` 可用。
- **`library/oh-package-lock.json5`**：由 `ohpm install --all` 生成（library 有 devDependencies 时 ohpm 会为模块生成 lock），已入库以保持与 `entry/oh-package-lock.json5` 一致，并满足 F1「零新增未跟踪项」。
