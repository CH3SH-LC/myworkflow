#!/usr/bin/env bash
# MyWorkflow v2 — 五分类路由入口指令注入（六组 skills 组织、五分类运行时路由）
# Fires on: startup (new session), clear, compact
# v2: 只保留 SessionStart，不再使用 UserPromptSubmit 分类

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IS_RESET="${1:-}"

# ── Collect skill info ────────────────────────────────────────

# 1. 本插件内置的 skills
INTERNAL=""
PLUGIN_SKILLS_DIR="${PLUGIN_ROOT}/skills"
if [ -d "$PLUGIN_SKILLS_DIR" ]; then
  for f in "$PLUGIN_SKILLS_DIR"/*/SKILL.md; do
    [ -f "$f" ] || continue
    dir=$(dirname "$f")
    name=$(grep -m1 '^name:' "$f" 2>/dev/null | sed 's/^name: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//')
    desc=$(grep -m1 '^description:' "$f" 2>/dev/null | sed 's/^description: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//' | cut -c1-200)
    [ -n "$name" ] || name=$(basename "$dir")
    INTERNAL="${INTERNAL}  [内置] ${name}: ${desc:-无描述}
"
  done
fi

# 2. 用户全局 skills（专项工作扫描用）
USER_SKILLS_DIR="${HOME}/.claude/skills"
EXTERNAL=""
if [ -d "$USER_SKILLS_DIR" ]; then
  for f in "$USER_SKILLS_DIR"/*/SKILL.md "$USER_SKILLS_DIR"/*/skill.md; do
    [ -f "$f" ] || continue
    dir=$(dirname "$f")
    name=$(grep -m1 '^name:' "$f" 2>/dev/null | sed 's/^name: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//')
    desc=$(grep -m1 '^description:' "$f" 2>/dev/null | sed 's/^description: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//' | cut -c1-200)
    [ -n "$name" ] || name=$(basename "$dir")
    # 跳过本插件已有的（避免重复）
    if [ -d "${PLUGIN_SKILLS_DIR}/${name}" ]; then continue; fi
    EXTERNAL="${EXTERNAL}  [专项] ${name}: ${desc:-无描述}
"
  done
fi

# 3. 用户安装的 plugins 中的 skills
for plugin_dir in "${HOME}"/.claude/plugins/*/skills; do
  [ -d "$plugin_dir" ] || continue
  plugin_name=$(basename "$(dirname "$plugin_dir")")
  # 跳过本插件
  [ "$plugin_name" = "myworkflow" ] && continue
  for f in "$plugin_dir"/*/[Ss][Kk][Ii][Ll][Ll].[Mm][Dd]; do
    [ -f "$f" ] || continue
    dir=$(dirname "$f")
    name=$(grep -m1 '^name:' "$f" 2>/dev/null | sed 's/^name: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//')
    desc=$(grep -m1 '^description:' "$f" 2>/dev/null | sed 's/^description: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//' | cut -c1-200)
    [ -n "$name" ] || name=$(basename "$dir")
    # 避免重复
    if [ -d "${PLUGIN_SKILLS_DIR}/${name}" ]; then continue; fi
    EXTERNAL="${EXTERNAL}  [专项:${plugin_name}] ${name}: ${desc:-无描述}
"
  done
done

# ── Build v2 injection content ────────────────────────────────

INJECTION="## ⚠️ MyWorkflow v2 — 工作流入口指令（本会话强制生效）

<EXTREMELY_IMPORTANT>
处理任何用户请求时，必须按以下三步工作流执行：

### 步骤 1：判断任务类型（五分类）

将用户请求归入以下五类之一：

| # | 分类 | 关键信号 |
|---|------|---------|
| 1 | **代码编写** | 写代码、改代码、重构、修 bug、新建项目、加功能 |
| 2 | **文稿撰写** | 写文档、写报告、润色文本、去 AI 味、翻译 |
| 3 | **深度调研** | 需要多源搜索 + 交叉验证 + 综合报告 |
| 4 | **专项工作** | 有专用 skill 体系的领域（写小说、学习笔记、数据可视化等） |
| 5 | **其它任务** | 无法归入以上 4 类、简单小提问、闲聊 |

不确定时用 AskUserQuestion 确认。多项匹配选最接近的那个。

### 步骤 2：细化需求

在动手之前，通过多次启发式提问逐轮细化用户需求：
- 每次只问一个问题，提供 2-4 个选项
- 覆盖：目标 → 范围 → 约束 → 边界条件
- 最多 5 轮总提问
- 产出结构化需求报告后，等待用户确认

### 步骤 3：按任务类型执行

#### 3.1 代码编写
# 注：大项目工作维护（文档同步）为隐式触发，由 CLAUDE.md 引导，不在此显式路由
先判断是否为新项目（文件夹为空 / 无 CLAUDE.md / 无任何包管理配置文件如 package.json/pyproject.toml/go.mod/Cargo.toml）：
- **新项目** → Skill(\"大项目初始化\")，初始化后再进入以下流程
- **已有项目** → 直接判断子类型：
  - 功能开发/重构/加功能 → Skill(\"智能体闭环开发\")
  - 修 bug/报错/异常/不工作 → Skill(\"Bug修复与验证\")
  - 排查根因/深度排查 → Skill(\"根因定位与全面排查\")
  - 提交代码/创建 PR/合并 → Skill(\"Github协作\")

#### 3.2 文稿撰写
已有文本需去AI味/润色 → Skill(\"humanizer-zh\")；需从零撰写 → 先写初稿，再询问是否润色；纯翻译 → 直接翻译后询问是否润色

#### 3.3 深度调研
→ Skill(\"深度调研\")，传入用户的调研问题

#### 3.4 专项工作
先扫描下方「专项 Skills」清单，找到匹配的专用 skill → 调用对应的 skill。
无匹配 → 降级为「需求澄清 → 直接执行」。

#### 3.5 其它任务
直接回答，简单处理。

### 核心原则
1. 先分类，再澄清需求，最后执行——不可跳步
2. 代码编写类禁止跳过需求澄清直接写代码
3. 不确定分类时 → AskUserQuestion
4. 用户说\"直接做\"→ 精简但不跳过步骤 2（至少确认核心目标 + 输出形式）

### 内置 Skills（可直接调用）

${INTERNAL}

### 专项 Skills（步骤 3.4 扫描用）

${EXTERNAL}
</EXTREMELY_IMPORTANT>

<SUBAGENT-STOP>
如果你是子 agent，忽略上述入口指令。专注执行你的具体任务。
</SUBAGENT-STOP>"

# ── Encode for JSON ───────────────────────────────────────────
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  # 注：当前转义覆盖了常见的 JSON 特殊字符（"、\、/、换行、回车、制表）。
  # 如 skill 名包含 \b 或 \f 等罕见字符，可能需要增强转义。
  printf '%s' "$s"
}

INJECTION_ESC=$(escape_json "$INJECTION")

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$INJECTION_ESC"

exit 0
