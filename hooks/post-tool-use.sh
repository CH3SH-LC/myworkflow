#!/usr/bin/env bash
# MyWorkflow v2.2 — PostToolUse 执行期兜底
# Fires after every tool call.
# Purpose: detect when a routing skill (task-router/req-clarify) was loaded
#          but the downstream Skill() call hasn't happened after N tool calls.
# Design: < 0.1s typical, grep-only JSON parsing, temp-file flag.

set -euo pipefail

INPUT=$(cat)

# ── Fast grep-based JSON extraction (no python overhead) ─────────
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' 2>/dev/null | head -1 | sed 's/"tool_name":"//;s/"$//')

# ── Not a tool call we track ────────────────────────────────────
if [ -z "${TOOL_NAME:-}" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":""}}\n'
  exit 0
fi

FLAG_DIR="${HOME}/.claude/plugins/myworkflow/.cache"
mkdir -p "$FLAG_DIR"
FLAG_FILE="${FLAG_DIR}/routing-pending.txt"

# ── Case 1: A Skill was loaded ──────────────────────────────────
if [ "$TOOL_NAME" = "Skill" ]; then
  SKILL_NAME=$(echo "$INPUT" | grep -o '"skill":"[^"]*"' 2>/dev/null | head -1 | sed 's/"skill":"//;s/"$//')

  # Routing skills: these should be followed by a downstream Skill() call
  case "$SKILL_NAME" in
    *"task-router"*|*"req-clarify"*)
      echo "0" > "$FLAG_FILE"
      ;;
    *)
      # Any other Skill call = downstream routing happened, clear flag
      rm -f "$FLAG_FILE"
      ;;
  esac

  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":""}}\n'
  exit 0
fi

# ── Case 2: Non-Skill tool call, check if routing is pending ────
if [ -f "$FLAG_FILE" ]; then
  COUNT=$(cat "$FLAG_FILE" 2>/dev/null || echo "0")
  # Verify COUNT is a valid integer, default to 0 if not
  case "$COUNT" in
    ''|*[!0-9]*) COUNT=0 ;;
  esac
  COUNT=$((COUNT + 1))

  if [ "$COUNT" -ge 3 ]; then
    # 3+ non-Skill tool calls after routing skill loaded — inject reminder
    REMINDER="⚠️ [执行期检查] 路由 skill 加载后已执行 ${COUNT} 个操作但尚未调用下游 Skill()。如果当前任务属于代码编写/文稿撰写/深度调研，请立即使用 Skill 工具调用对应的下游 skill（如 Skill(\"myworkflow:agent-dev-loop\")、Skill(\"myworkflow:bug-fix-verify\") 等）。"
    REMINDER_ESC="${REMINDER//\\/\\\\}"
    REMINDER_ESC="${REMINDER_ESC//\"/\\\"}"
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$REMINDER_ESC"
    rm -f "$FLAG_FILE"
    exit 0
  fi

  echo "$COUNT" > "$FLAG_FILE"
fi

printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":""}}\n'
exit 0
