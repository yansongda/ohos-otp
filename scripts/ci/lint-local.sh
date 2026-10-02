#!/usr/bin/env bash
# 本地跑 CodeLinter —— 与 CI（.github/workflows/ci.yml 的 CodeLinter step）同一引擎、同一组参数。
#
# 优先用华为 command-line-tools 里的官方 codelinter（与 CI 完全一致）；
# 本机只装了 DevEco Studio 时，回落到 IDE 内置的同一引擎（参数相同，实测可用）。
#
# 用法：
#   bash scripts/ci/lint-local.sh            # 发现 error 时退出码 4
#   bash scripts/ci/lint-local.sh --fix      # 自动修复（会改源码，先 git diff 确认）
#   CODELINTER_EXIT_ON=error,warn bash scripts/ci/lint-local.sh   # 让 warn 也失败
#
# 两个必须知道的点：
#   1. 不带 -e 时 CodeLinter 永远返回 0（IDE 里看到红点、CLI 却是绿的），所以这里默认 -e error。
#   2. lint 路径必须在工程目录内，且工程根需要有 hvigorfile.ts，否则报
#      "The entered inspection path is incorrect"。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

EXIT_ON="${CODELINTER_EXIT_ON:-error}"
TMP_BASE="${TMPDIR:-/tmp}"; TMP_BASE="${TMP_BASE%/}"
REPORT="${CODELINTER_REPORT:-$TMP_BASE/codelinter.json}"
DEVECO_HOME="${DEVECO_STUDIO_HOME:-/Applications/DevEco-Studio.app}"

NODE_BIN=""
if [ -x "$DEVECO_HOME/Contents/tools/node/bin/node" ]; then
  NODE_BIN="$DEVECO_HOME/Contents/tools/node/bin/node"
elif command -v node >/dev/null 2>&1; then
  NODE_BIN="$(command -v node)"
fi

if command -v codelinter >/dev/null 2>&1; then
  RUNNER=("$(command -v codelinter)")
elif [ -f "$DEVECO_HOME/Contents/plugins/codelinter/run/index.js" ] && [ -n "$NODE_BIN" ]; then
  RUNNER=("$NODE_BIN" "$DEVECO_HOME/Contents/plugins/codelinter/run/index.js")
else
  echo "找不到 CodeLinter：既没有 codelinter 命令，也没有 $DEVECO_HOME/Contents/plugins/codelinter/run/index.js" >&2
  echo "可用 DEVECO_STUDIO_HOME=/path/to/DevEco-Studio.app 指定安装目录。" >&2
  exit 1
fi

EXTRA=()
if [ "${1:-}" = '--fix' ]; then
  EXTRA+=(--fix)
fi

echo "CodeLinter：${RUNNER[*]} -e $EXIT_ON${EXTRA[*]+ ${EXTRA[*]}}"

set +e
"${RUNNER[@]}" -c ./code-linter.json5 -o "$REPORT" -f json -e "$EXIT_ON" "${EXTRA[@]+"${EXTRA[@]}"}" .
STATUS=$?
set -e

if [ -n "$NODE_BIN" ] && [ -f "$REPORT" ]; then
  REPORT="$REPORT" "$NODE_BIN" -e '
    const fs = require("node:fs");
    const files = JSON.parse(fs.readFileSync(process.env.REPORT, "utf8"));
    const flat = files.flatMap((f) => (f.messages || []).map((m) => ({ file: f.filePath, ...m })));
    for (const m of flat) {
      console.log(`${m.file}:${m.line}:${m.column}  ${m.severity}  ${m.rule}  ${m.message}`);
    }
    const count = (s) => flat.filter((m) => m.severity === s).length;
    console.log(`\nerrors ${count("error")} / warns ${count("warn")} / suggestions ${count("suggestion")}  →  ${
      flat.length === 0 ? "通过" : "见上方明细"
    }`);
  '
fi

echo "报告：$REPORT"
echo "退出码：${STATUS}（4 = 命中 -e 指定级别的缺陷，0 = 无该级别缺陷）"
exit "$STATUS"
