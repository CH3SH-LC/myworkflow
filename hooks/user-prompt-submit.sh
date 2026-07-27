#!/usr/bin/env bash
# MyWorkflow v2 — UserPromptSubmit 关键词硬路由
# Fires on: every user message (stdin = user prompt text)
# Purpose: lightweight keyword matching to inject routing reminders
# Design: < 2 seconds, grep-only, no file I/O
# Priority: 代码编写 > 文稿撰写 > 深度调研 (first match wins)

set -euo pipefail

# ── Read user input from stdin ─────────────────────────────────
USER_INPUT=$(cat)

# ── Empty input guard ──────────────────────────────────────────
if [ -z "${USER_INPUT:-}" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":""}}\n'
  exit 0
fi

# ── Keyword patterns (ordered by priority) ─────────────────────
#   Category 1: 代码编写 (highest priority)
#   Design: multi-char Chinese or 3+ ASCII chars to avoid single-char false positives
CODE_PATTERN='写代码|改代码|加个|加功能|添[加个]|实现|重构|新增|改一下|改这个|改那个|做个|做个功能|开发|创建项目|新建|修复|修.bug|修一下|怎么修|如何改|报错|错误|异常|崩溃|不工作|出问题|出了问题|坏了|不对.*怎么|帮我写|帮我改|帮我加|帮我做|能不能.*改|可以.*加|优化|重写|解决.*问题|排查|根因|提交.*代码|commit|PR|pull.request|合并.*分支|merge|bug|fix|error|crash|broken|doesn.t work|not working|写个.*功能|改个|弄个'

#   Category 2: 文稿撰写
WRITING_PATTERN='去AI味|润色|润一下|改写|写文档|写报告|写一篇|起草|翻译|humanize|写个文档|写个报告|帮我写.*文章|帮我写.*文档|太像AI|去机器人味'

#   Category 3: 深度调研 (lowest priority)
#   Narrowed "调查"/"调研" to multi-char compounds to reduce false positives
RESEARCH_PATTERN='深度调研|全面研究|研究报告|对比分析|技术选型|帮我调研|调研一下|调查一下|有什么方案|帮我研究|横向对比|方案对比'

# ── Match in priority order (grep -q exits on first match) ─────
CATEGORY=""

if printf '%s' "$USER_INPUT" | grep -qiE "$CODE_PATTERN"; then
  CATEGORY="代码编写"
elif printf '%s' "$USER_INPUT" | grep -qiE "$WRITING_PATTERN"; then
  CATEGORY="文稿撰写"
elif printf '%s' "$USER_INPUT" | grep -qiE "$RESEARCH_PATTERN"; then
  CATEGORY="深度调研"
fi

# ── Build output ───────────────────────────────────────────────
if [ -n "$CATEGORY" ]; then
  REMINDER="⚠️ [硬路由] 检测到[${CATEGORY}]类任务 → 必须先调用 Skill(\"myworkflow:task-router\")，禁止跳过直接写代码。"
else
  REMINDER=""
fi

# ── JSON escape ────────────────────────────────────────────────
# Minimal escape: only characters that MUST be escaped in JSON strings
# The reminder message is a single line with no control chars, so
# only double-quote and backslash need handling.
REMINDER_ESC="${REMINDER//\\/\\\\}"
REMINDER_ESC="${REMINDER_ESC//\"/\\\"}"

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$REMINDER_ESC"

exit 0
