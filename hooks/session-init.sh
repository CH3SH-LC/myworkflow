#!/usr/bin/env bash
# MyWorkflow v3 — SessionStart 极简注入（v2 的 16KB 五分类仪式已废弃）
# 扁平化路由：模型原生可见可用技能列表，这里只给 1 条行为锚点。

# 子智能体环境：不注入
if [ -n "${CLAUDE_AGENT_TASK_ID:-}" ] || [ -n "${AGENT_MODE:-}" ] || [ -n "${SUBAGENT:-}" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}\n'
  exit 0
fi

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"直接按用户请求调用匹配的 Skill 完成工作；没有匹配的 skill 就自己完成。最多澄清 1 个关键问题，不要多轮确认。"}}\n'
