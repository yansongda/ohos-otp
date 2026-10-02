#!/usr/bin/env node
/**
 * ohos-otp 仓库不变量守卫（零依赖；本地与 CI 共用）。
 *
 * 为什么存在：AGENTS.md §2/§5 的分层不变量此前只靠人自觉维护，被无意破坏时
 * 本地单测**仍然是绿的**（internal/ 泄漏进 barrel、新增 @kit 导入点、secret 经
 * console 泄漏、测试被删、错误码集合悄悄变化、版本号与 CHANGELOG 脱节），
 * 只有下游消费方或发布之后才会暴露。这里把它们变成可执行的检查。
 *
 * 用法：node scripts/ci/check-invariants.mjs    # 退出码 0 = 全部通过
 *
 * BASELINE 是刻意保留的人工闸门：真要减少测试数量或调整错误码时，必须把改动
 * 写进本文件，使「删测试」成为一个显式、可评审的动作，而不是顺手删掉。
 */
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = fileURLToPath(new URL('../../', import.meta.url));

const BASELINE = {
  localTestCases: 240, // library/src/test 的 it( 数量（PC Local Test）
  deviceTestCases: 37, // library/src/ohosTest 的 it( 数量（真实 crypto，需设备）
  errorCodeMembers: 17, // OtpErrorCode 成员数：v1 起冻结，不得增删
};

const LIB_SRC = 'library/src/main/ets';
const BARREL = 'library/Index.ets';
const KIT_SOURCE = `${LIB_SRC}/internal/CryptoSource.ets`;

/** 构建产物与依赖目录不参与扫描。 */
const SKIP_DIRS = new Set([
  'node_modules', 'oh_modules', 'build', '.test', '.hvigor', '.preview', '.idea', '.git',
]);

function toPosix(p) {
  return p.split(sep).join('/');
}

function listFiles(absDir) {
  const out = [];
  const walk = (dir) => {
    for (const name of readdirSync(dir)) {
      if (SKIP_DIRS.has(name)) continue;
      const full = join(dir, name);
      if (statSync(full).isDirectory()) walk(full);
      else out.push(full);
    }
  };
  walk(absDir);
  return out;
}

function readText(relPath) {
  return readFileSync(join(REPO_ROOT, relPath), 'utf8');
}

/** 注释行允许提及敏感词（CryptoSource 的文档注释里就有 import 示例）。 */
function isCommentLine(line) {
  return /^\s*(\/\/|\*|\/\*)/.test(line);
}

/** 返回文件里「非注释行」的列表，保持原始行号。 */
function codeLines(relPath) {
  return readText(relPath)
    .split('\n')
    .map((text, i) => ({ no: i + 1, text }))
    .filter((line) => !isCommentLine(line.text));
}

/** 出库源码 = barrel + library/src/main/ets 下全部 .ets。 */
function shippedSources() {
  const files = listFiles(join(REPO_ROOT, LIB_SRC))
    .filter((f) => f.endsWith('.ets'))
    .map((f) => toPosix(relative(REPO_ROOT, f)));
  return [BARREL, ...files];
}

/**
 * 取 JSON5 文本中顶层 `"key": { ... }` 的 body。
 * 不做完整 JSON5 解析：这两个文件只用到「注释 + 对象字面量」，括号配对足够，
 * 且避免为 CI 引入任何依赖。
 */
function objectBody(src, key) {
  const matched = new RegExp(`"${key}"\\s*:\\s*\\{`).exec(src);
  if (!matched) return null;
  const start = src.indexOf('{', matched.index);
  let depth = 0;
  for (let i = start; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}') {
      depth--;
      if (depth === 0) return src.slice(start + 1, i);
    }
  }
  throw new Error(`${key} 的对象字面量括号未闭合`);
}

/** 对象 body 去掉注释后只剩下空白/逗号，才算「空」。 */
function isEmptyObjectBody(body) {
  const stripped = body.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');
  return !/["'\w]/.test(stripped);
}

function countCases(relDir) {
  let total = 0;
  for (const file of listFiles(join(REPO_ROOT, relDir))) {
    if (!file.endsWith('.ets')) continue;
    total += (readFileSync(file, 'utf8').match(/^[ \t]*it\(/gm) || []).length;
  }
  return total;
}

const checks = [];
const check = (name, fn) => checks.push({ name, fn });

check(`@kit 只出现在 ${KIT_SOURCE}`, () => {
  const violations = [];
  for (const rel of shippedSources()) {
    readText(rel)
      .split('\n')
      .forEach((text, i) => {
        if (!text.includes('@kit.') || isCommentLine(text)) return;
        if (rel !== KIT_SOURCE) violations.push(`${rel}:${i + 1}`);
      });
  }
  if (violations.length > 0) {
    throw new Error(`越界出现 ${violations.join(', ')}；新增系统 API 必须落在 ${KIT_SOURCE}`);
  }
  // 反向保护：kit 导入被整体删掉时，上面那条检查会「因为没人引用」而永远通过
  const imports = codeLines(KIT_SOURCE).filter((l) => /from\s+'@kit\./.test(l.text)).length;
  if (imports === 0) throw new Error(`${KIT_SOURCE} 已无 @kit 导入，守卫失去意义`);
  return `1 个导入点 / ${imports} 条 kit import`;
});

check('barrel 不导出 internal/*，且 main 指向 Index.ets', () => {
  const leaked = codeLines(BARREL).filter((l) => /^\s*export\b/.test(l.text) && /internal\//.test(l.text));
  if (leaked.length > 0) {
    throw new Error(`Index.ets:${leaked.map((l) => l.no).join(',')} 导出了 internal/*`);
  }
  const main = /"main"\s*:\s*"([^"]+)"/.exec(readText('library/oh-package.json5'));
  if (!main) throw new Error('library/oh-package.json5 缺少 main 字段');
  if (main[1] !== 'Index.ets') throw new Error(`main 应为 Index.ets，实际为 ${main[1]}`);
  return 'Index.ets 为唯一对外入口';
});

check('运行时依赖保持为空', () => {
  const offenders = [];
  for (const manifest of ['oh-package.json5', 'library/oh-package.json5']) {
    const body = objectBody(readText(manifest), 'dependencies');
    if (body === null) continue; // 没有该字段 = 没有运行时依赖
    if (!isEmptyObjectBody(body)) offenders.push(manifest);
  }
  if (offenders.length > 0) throw new Error(`${offenders.join(', ')} 出现了运行时依赖（本库要求零依赖）`);
  return '根工程与 library 均为 {}';
});

check('库源码零 console / hilog（secret 不外泄）', () => {
  const hits = [];
  for (const rel of shippedSources()) {
    for (const line of codeLines(rel)) {
      if (/\bconsole\s*\.|\bhilog\b|\bHiLog\b/.test(line.text)) hits.push(`${rel}:${line.no}`);
    }
  }
  if (hits.length > 0) throw new Error(`发现日志调用 ${hits.join(', ')}`);
  return '无输出语句';
});

check('未使用 padStart / URLSearchParams（ArkTS 不支持）', () => {
  const hits = [];
  for (const rel of shippedSources()) {
    for (const line of codeLines(rel)) {
      if (/\.padStart\s*\(|new\s+URLSearchParams\b/.test(line.text)) hits.push(`${rel}:${line.no}`);
    }
  }
  if (hits.length > 0) throw new Error(`发现 ArkTS 不可用 API：${hits.join(', ')}`);
  return '仅用 ArkTS 可用 API';
});

check(`测试数量不减少（本地 ≥ ${BASELINE.localTestCases}，设备 ≥ ${BASELINE.deviceTestCases}）`, () => {
  const local = countCases('library/src/test');
  const device = countCases('library/src/ohosTest');
  const problems = [];
  if (local < BASELINE.localTestCases) problems.push(`library/src/test ${local} < ${BASELINE.localTestCases}`);
  if (device < BASELINE.deviceTestCases) problems.push(`library/src/ohosTest ${device} < ${BASELINE.deviceTestCases}`);
  if (problems.length > 0) throw new Error(`${problems.join('；')}（确需减少时请同步修改 BASELINE）`);
  return `本地 ${local} / 设备 ${device}`;
});

check(`OtpErrorCode 恰为 ${BASELINE.errorCodeMembers} 个成员`, () => {
  const matched = /export enum OtpErrorCode\s*\{([\s\S]*?)\n\}/.exec(readText('library/src/main/ets/OtpError.ets'));
  if (!matched) throw new Error('未找到 OtpErrorCode 枚举定义');
  const members = matched[1].split('\n').filter((l) => /^\s*[A-Z0-9_]+\s*=/.test(l)).length;
  if (members !== BASELINE.errorCodeMembers) {
    throw new Error(`实际 ${members} 个；错误码集合自 v1 冻结，仅版本升级时可显式调整基线`);
  }
  return `${members} 个错误码`;
});

check('版本号与 CHANGELOG 一致', () => {
  const version = /"version"\s*:\s*"([^"]+)"/.exec(readText('library/oh-package.json5'))?.[1];
  if (!version) throw new Error('library/oh-package.json5 缺少 version');
  const heading = /^##\s+(\S+)/m.exec(readText('library/CHANGELOG.md'))?.[1];
  if (!heading) throw new Error('library/CHANGELOG.md 缺少版本标题');
  if (heading !== version) throw new Error(`oh-package.json5 为 ${version}，CHANGELOG 最新标题为 ${heading}`);
  return `v${version}`;
});

check('README 保留安装命令', () => {
  for (const readme of ['library/README.md', 'library/README-cn.md']) {
    if (!readText(readme).includes('ohpm install @yansongda/otp')) {
      throw new Error(`${readme} 缺少 'ohpm install @yansongda/otp'`);
    }
  }
  return 'README / README-cn 均已声明安装方式';
});

console.log(`\n仓库不变量检查：${toPosix(REPO_ROOT)}\n`);
let failed = 0;
for (const c of checks) {
  try {
    const detail = c.fn();
    console.log(`  ✓ ${c.name}${detail ? `  —  ${detail}` : ''}`);
  } catch (error) {
    failed++;
    console.log(`  ✗ ${c.name}  —  ${error.message}`);
  }
}
console.log(`\n${checks.length - failed}/${checks.length} 通过${failed ? `，${failed} 项失败` : ''}\n`);
process.exit(failed ? 1 : 0);
