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
