---
name: releasing-ohos-otp
description: 用于发布 @yansongda/otp 新版本到 OHPM 时——bump 版本号、落版 CHANGELOG、开 release PR、打 tag、执行 ohpm publish；或 ohpm publish 卡住/刷屏/OOM/反复报 "The content of private key in the key_path error" 时使用
---

# 发布 @yansongda/otp 到 OHPM

## Overview

**已发布版本不可覆盖、不可删除**——发错只能占用下一个版本号，所以产物自检是最后一道防线。

职责分工：`AGENTS.md` §7 定义流程与人工闸门、§3 定义命令；本 skill 只补**执行顺序、判定标准、实测坑**。

## 五步流程

| # | 步骤 | 判定 / 约束 |
|---|---|---|
| 1 | 落版 | 版本唯一来源是 `library/oh-package.json5`；`CHANGELOG.md` 写出 `## <ver> - <YYYY-MM-DD>`；`README.md` 预发布清单里的版本号同步 |
| 2 | 本地预检 | 不变量守卫 9/9 → CodeLinter 0 缺陷 → local test 全绿 → `assembleHar` → 产物自检 → `prepublish succeed` |
| 3 | 分支 + PR | 本仓库是 **squash** 合并；PR 由人工合并，agent 不合并 |
| 4 | tag | `git tag -a v<ver> -m "v<ver>" <merge-commit>`；推送需人工授权 |
| 5 | publish | **由人在真实终端执行**；agent 只交付命令与核验结论 |

## 产物自检（`AGENTS.md` §3 命令之外的必做项）

```bash
HAR=library/build/default/outputs/default/library.har
tar xOf "$HAR" package/oh-package.json5 | grep '"version"'       # 必须等于待发版本
tar tzf "$HAR" | grep -c 'src/test\|ohosTest'                    # 必须为 0
# 陈旧性检查：HAR 内打包了 README/README-cn/CHANGELOG/LICENSE，必须与工作区逐字一致
tar xOf "$HAR" package/README.md    | diff - library/README.md
tar xOf "$HAR" package/CHANGELOG.md | diff - library/CHANGELOG.md
```

任一条出现差异 = 产物已陈旧 → `assembleHar` → 重跑本节自检 → 重跑 `prepublish`，再交付发布。

## publish：必须在交互式终端

```bash
# 人在自己终端里执行；提示 what is your passphrase of the private key: 时手输口令
PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH" \
  /Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm publish \
  library/build/default/outputs/default/library.har
```

## 发布结果判定：以 registry 为准

```bash
ohpm info @yansongda/otp@<ver>   # exit 0 = 已发布；exit 1 + NOTFOUND = 未发布，可安全重试（此退出码可信）
```

唯一**不能**作为判定依据的是 `ohpm publish` 自己的刷屏输出与退出码——无 TTY 崩溃时的 exit 134 只说明本地失败。

`curl -s -o /dev/null -w "%{http_code}\n" https://ohpm.openharmony.cn/ohpm/@yansongda/otp/<ver>` 与 `.../-/otp-<ver>.har` 亦可交叉核验（200 = 已发布）。

## 实测坑（每一条都真踩过）

| 现象 | 真因与对策 |
|---|---|
| publish 刷出**十几万条** `content of private key in the key_path error` 后 `FATAL ERROR ... heap out of memory`（exit 134） | **没有 TTY**：ohpm 靠交互提问取私钥口令，读到空 → 签名失败 → 源码里的 `for (;e === signError;)` 无限重问。**绝不重定向 publish 输出、绝不在 agent 沙箱里跑**；重跑只会再 OOM 一次 |
| 误判为「私钥配错 / 该换未加密密钥」 | ohpm **只接受加密私钥**（内容不含 `ENCRYPTED` 直接 `NotSupportPrivateKey`）。口令只有两个来源：`.ohpmrc` 的 `key_passphrase`，或交互提问 |
| 用 nvm 的 node 跑 ohpm | `ohpm` 包装脚本取 `PATH` 里的 `node` → 固定用 DevEco 自带 v18 |
| 拿整包 sha256 与人对账 | HAR **字节不可复现**（tar mtime 差异）：清单与包内文件内容一致即可，整包 sha 只当单次构建指纹 |
| `git branch -d` 删 release 分支报 `not fully merged` | squash 合并导致分支 tip 不是 main 祖先：先 `git diff <branch> main` 确认零差异，再 `-D` |
| 发布凭据是 `~/.ssh/id_rsa`（GitHub 身份密钥） | 能发但卫生差：建议改用专用发布密钥（须加密）；**绝不把身份密钥口令写进 `.ohpmrc`** |

## Red flags（出现即停）

- 正要在 agent / 无终端环境里跑 `ohpm publish`，或把它的输出重定向到文件
- 想用 `--log_level debug` **重跑一次**「看看卡在哪」（会再 OOM，且方向错）
- 想在设计文档或 README 正文里写具体版本号（版本值只属于 `oh-package.json5` 与 `CHANGELOG.md`）
- 打算替人 push、打 tag、合并 PR，或建议把私钥口令写进配置文件
