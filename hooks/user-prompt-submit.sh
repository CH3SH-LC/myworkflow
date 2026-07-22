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
CODE_PATTERN='写代码|改代码|加个|实现|重构|新增|改一下|做个|开发|创建|修|bug|报错|错误|异常|崩溃|不工作|出问题|fix|error|crash|broken|doesn.t work|排查|根因|提交|commit|PR|pull request|合并|merge'

#   Category 2: 文稿撰写
WRITING_PATTERN='去AI味|润色|改写|写文档|写报告|翻译|humanize|写一篇|起草'

#   Category 3: 深度调研 (lowest priority)
RESEARCH_PATTERN='深度调研|全面研究|调研|研究报告|对比分析|技术选型|调查'

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
  REMINDER="⚠️ [硬路由] 检测到[${CATEGORY}]类任务 → 必须先调用 Skill(\"任务分类入口\")，禁止跳过直接写代码。"
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
