#!/usr/bin/env bash
# MyWorkflow v2 — 五分类路由入口指令注入（六组 skills 组织、五分类运行时路由）
# Fires on: startup (new session), clear, compact
# v2.1: 增强注入持久性 — 注意力锚点 + 触发词提取 + 周期性自检 + compact 重注入提醒

set -euo pipefail

# 子智能体检测——如果是子 agent 环境，输出空 injection 并退出
if [ -n "${CLAUDE_AGENT_TASK_ID:-}" ] || [ -n "${AGENT_MODE:-}" ] || [ -n "${SUBAGENT:-}" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}\n'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IS_RESET="${1:-}"

# 静默路径验证：skills 目录必须存在
# 优先使用 hook 注入的 CLAUDE_PLUGIN_ROOT，手动测试时使用脚本自行推导的 PLUGIN_ROOT
_VALIDATE_ROOT="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT}}"
if [ ! -d "${_VALIDATE_ROOT}/skills" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}\n'
  exit 0
fi

# ── Helper: extract trigger words from SKILL.md ─────────────────
# Searches both frontmatter description and body for explicit "触发词：/触发词:" markers.
# Falls back to extracting quoted phrases from description if no marker found.
extract_triggers() {
  local skill_file="$1"
  local desc="$2"
  local result=""

  # 1) Try the full file for explicit 触发词： or 触发词:
  local full_text
  full_text=$(cat "$skill_file" 2>/dev/null)
  if echo "$full_text" | grep -q '触发词[：:]\|触发信号[：:]'; then
    result=$(echo "$full_text" | grep -m1 '触发词[：:]\|触发信号[：:]' | sed 's/.*触发词[：:]\|.*触发信号[：:]//' | sed 's/。.*//')
    # Clean up suffixes: 不触发… / 反例… / 不适用于… / 也适用于… / 注意：… / 即使…
    result=$(echo "$result" | sed 's/不触发[：:]*.*//' | sed 's/反例[：:]*.*//' | sed 's/不适用于.*//')
    result=$(echo "$result" | sed 's/也适用于.*//' | sed 's/注意[：:].*//' | sed 's/即使.*//')
    # Replace Chinese 、 with English comma+space
    result=$(echo "$result" | sed 's/、/, /g')
    result=$(echo "$result" | tr -s ' ,' | sed 's/^ *//;s/ *$//;s/,,*/,/g')
    # Limit trigger string to ~70 chars
    result=$(echo "$result" | cut -c1-70)
    printf '%s' "$result"
    return 0
  fi

  # 2) Fallback: extract quoted trigger examples from description
  #    Match patterns like "帮我加个XX" or 「帮我加个XX」
  local quoted
  quoted=$(echo "$desc" | grep -oE '"[^"]{2,20}"' 2>/dev/null | head -4 | sed 's/"//g' | tr '\n' ',' | sed 's/,$//' | sed 's/,,*/,/g')
  if [ -z "$quoted" ]; then
    quoted=$(echo "$desc" | grep -oE '「[^」]{2,20}」' 2>/dev/null | head -4 | sed 's/[「」]//g' | tr '\n' ',' | sed 's/,$//' | sed 's/,,*/,/g')
  fi
  if [ -n "$quoted" ]; then
    result=$(echo "$quoted" | cut -c1-60)
    printf '%s' "$result"
    return 0
  fi

  printf '%s' ""
  return 0
}

# ── Helper: short description (text before 触发词, ≤ 80 chars) ─
short_desc() {
  local desc="$1"
  local s
  s=$(echo "$desc" | sed 's/触发词[：:].*//' | sed 's/。$//')
  s=$(echo "$s" | tr -s ' ' | sed 's/^ *//;s/ *$//' | cut -c1-80)
  printf '%s' "$s"
}

# ── Collect skill info ────────────────────────────────────────

INTERNAL=""
PLUGIN_SKILLS_DIR="${PLUGIN_ROOT}/skills"
if [ -d "$PLUGIN_SKILLS_DIR" ]; then
  for f in "$PLUGIN_SKILLS_DIR"/*/SKILL.md "$PLUGIN_SKILLS_DIR"/*/skill.md; do
    [ -f "$f" ] || continue
    dir=$(dirname "$f")
    # Dedup: prefer SKILL.md over skill.md in same directory
    if [ -f "${dir}/SKILL.md" ] && [ "$(basename "$f")" = "skill.md" ]; then continue; fi
    name=$(grep -m1 '^name:' "$f" 2>/dev/null | sed 's/^name: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//')
    desc_full=$(grep -m1 '^description:' "$f" 2>/dev/null | sed 's/^description: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//')
    [ -n "$name" ] || name=$(basename "$dir")

    triggers=$(extract_triggers "$f" "$desc_full")
    dshort=$(short_desc "$desc_full")

    if [ -n "$triggers" ]; then
      INTERNAL="${INTERNAL}  [内置] ${name} | 🎯触发: ${triggers} | desc: ${dshort:-无描述}
"
    else
      INTERNAL="${INTERNAL}  [内置] ${name} | desc: ${dshort:-无描述}
"
    fi
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
    desc_full=$(grep -m1 '^description:' "$f" 2>/dev/null | sed 's/^description: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//')
    [ -n "$name" ] || name=$(basename "$dir")
    # 跳过本插件已有的（避免重复）
    if [ -d "${PLUGIN_SKILLS_DIR}/${name}" ]; then continue; fi

    triggers=$(extract_triggers "$f" "$desc_full")
    dshort=$(short_desc "$desc_full")

    if [ -n "$triggers" ]; then
      EXTERNAL="${EXTERNAL}  [专项] ${name} | 🎯触发: ${triggers} | desc: ${dshort:-无描述}
"
    else
      EXTERNAL="${EXTERNAL}  [专项] ${name} | desc: ${dshort:-无描述}
"
    fi
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
    desc_full=$(grep -m1 '^description:' "$f" 2>/dev/null | sed 's/^description: *//' | tr -s ' ' | sed 's/^ *//;s/ *$//')
    [ -n "$name" ] || name=$(basename "$dir")
    # 避免重复
    if [ -d "${PLUGIN_SKILLS_DIR}/${name}" ]; then continue; fi

    triggers=$(extract_triggers "$f" "$desc_full")
    dshort=$(short_desc "$desc_full")

    if [ -n "$triggers" ]; then
      EXTERNAL="${EXTERNAL}  [专项:${plugin_name}] ${name} | 🎯触发: ${triggers} | desc: ${dshort:-无描述}
"
    else
      EXTERNAL="${EXTERNAL}  [专项:${plugin_name}] ${name} | desc: ${dshort:-无描述}
"
    fi
  done
done

# ── Build v2.1 injection content ───────────────────────────────

# ── Reset notice (compact / clear) ─────────────────────────────
RESET_NOTICE=""
if [ "$IS_RESET" = "--reset" ]; then
  RESET_NOTICE="
🔄 上下文已重置 —— 工作流指令刚刚被重新注入到本会话。
   对话历史上的下文已被 compact 清空，但工作流规则不变。
   现在你必须重新阅读下方的完整工作流指令，立即恢复五分类→需求澄清→Skill路由的工作模式。
   尤其注意「内置 Skills」清单中的触发词——根据用户当前请求匹配对应的 Skill。
"
fi

# ── Build INJECTION ────────────────────────────────────────────
INJECTION="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ WORKFLOW ACTIVE — 本会话启用了 myworkflow v2 工作流
   处理任何用户请求前，必须先判断五分类并调用对应 Skill
   这不是建议——这是本会话的运行规则
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET_NOTICE}

<EXTREMELY_IMPORTANT>
处理任何用户请求时，必须按以下三步工作流执行：

### 步骤 1：判断任务类型（五分类）

| # | 分类 | 关键信号 |
|---|------|---------|
| 1 | 代码编写 | 写代码、改代码、重构、修 bug、新建项目、加功能 |
| 2 | 文稿撰写 | 写文档、报告、润色、去AI味、翻译 |
| 3 | 深度调研 | 多源搜索 + 交叉验证 + 综合报告 |
| 4 | 专项工作 | 有专用 skill 体系的领域（写作、学习笔记、数据可视化等） |
| 5 | 其它任务 | 简单小提问、闲聊、无法归类 |

不确定时用 AskUserQuestion 确认。多项匹配选最接近的那个。

### 步骤 2：细化需求
逐轮启发式提问（每次一个问题，2-4 个选项），覆盖目标→范围→约束→边界，最多 5 轮。产出结构化需求报告后等待用户确认。

### 步骤 3：按任务类型执行

#### 3.1 代码编写
先判断是否为新项目（无 CLAUDE.md / 无包管理配置文件）：
- 新项目 → Skill(\"大项目初始化\")，初始化后再进入以下流程
- 已有项目 → 判断子类型：
  - 功能开发/重构/加功能 → Skill(\"智能体闭环开发\")
  - 修 bug/报错/异常/不工作 → Skill(\"Bug修复与验证\")
  - 排查根因/深度排查 → Skill(\"根因定位与全面排查\")
  - 提交代码/创建 PR/合并 → Skill(\"Github协作\")

#### 3.2 文稿撰写
去AI味/润色 → Skill(\"humanizer-zh\")；从零撰写 → 先写初稿再询问润色；翻译 → 翻译后询问润色

#### 3.3 深度调研
→ Skill(\"深度调研\")

#### 3.4 专项工作
扫描下方「专项 Skills」清单，匹配专用 skill → 调用。无匹配 → 降级为直接执行。

#### 3.5 其它任务
直接回答，简单处理。

### 核心原则
1. 先分类，再澄清需求，最后执行——不可跳步
2. 代码编写类禁止跳过需求澄清直接写代码
3. 不确定分类时 → AskUserQuestion
4. 用户说\"直接做\"→ 精简但不跳过步骤 2（至少确认核心目标 + 输出形式）

### ⏱ 周期性自检（强制执行）
每处理完 5 条以上用户消息后，在回复末尾附加 1 行自检：
> 🤖 工作流自检：[✅ 已分类 / ⚠️ 未分类-立即纠正]
如果发现偏离（⚠️），立即停下当前操作，回到步骤 1 重新分类并路由。

### 内置 Skills（可直接调用——注意触发词用于精确匹配）

${INTERNAL}
### 专项 Skills（步骤 3.4 扫描用——注意触发词用于精确匹配）

${EXTERNAL}
> 🔍 角色检测：如果你正在执行一个已被明确分配的具体子任务（而非直接响应用户的顶层会话），上述工作流入口指令不适用于你。专注你的子任务即可。

</EXTREMELY_IMPORTANT>

<SUBAGENT-STOP>
⛔ 如果你是一个子 agent / sub-agent / 被派发的任务执行者：
   你已经收到了具体的 task-id 和任务描述。
   请忽略上述所有工作流入口指令，直接执行你的具体任务。
   不要调用 Skill("任务分类入口")，不要做五分类路由。
</SUBAGENT-STOP>"

# ── Encode for JSON ───────────────────────────────────────────
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

INJECTION_ESC=$(escape_json "$INJECTION")

# ── Output validation ──────────────────────────────────────────
if [ -z "$INJECTION" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}\n'
  echo "[myworkflow] WARNING: INJECTION is empty, exiting with empty injection" >&2
  exit 0
fi

# Count skills (warn if fewer than 5)
skill_count=$(echo "$INJECTION" | grep -cE '\[内置\]|\[专项' || echo 0)
if [ "$skill_count" -lt 5 ] 2>/dev/null; then
  echo "[myworkflow] WARNING: Only $skill_count skill entries found (expected >= 5)" >&2
fi

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$INJECTION_ESC"

exit 0
