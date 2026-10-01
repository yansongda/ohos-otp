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
