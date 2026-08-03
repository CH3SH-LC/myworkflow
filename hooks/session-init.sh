#!/usr/bin/env bash
# MyWorkflow — SessionStart 注入
# 主智能体：分类概念锚点 + 注册表自动刷新
# 子智能体：一行协议锚点（不扫描注册表）
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# 子智能体环境：注入协议锚点
if [ -n "${CLAUDE_AGENT_TASK_ID:-}" ] || [ -n "${AGENT_MODE:-}" ] || [ -n "${SUBAGENT:-}" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"你是子智能体：先明确任务边界与接口，按 myworkflow:subagent-protocol 规范执行，完成后自检再报告。"}}\n'
  exit 0
fi

# 主智能体：注册表自动刷新（幂等、失败静默；~1s，保证 inventory 新鲜）
bash "$PLUGIN_ROOT/hooks/registry-scan.sh" >/dev/null 2>&1 || true

# 主智能体：分类概念锚点
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"直接按用户请求调用匹配的 Skill 完成工作——命中即调用，不跳过、不自作主张完成。任务分 5 类：代码编写 / 文稿撰写 / 深度调研 / 专项任务 / 简单问答；疑似专项任务时，查 myworkflow 插件的 config/special-skills.json 找对应 skill。开发类任务全程按阶段调 skill：阶段3 遇 bug → myworkflow:root-cause-analysis；子任务产出完成 → myworkflow:integration-verify；阶段4 真实验证 → myworkflow:real-world-verify；提交远程 → myworkflow:github-collab；润色文本 → myworkflow:humanizer-zh。最多澄清 1 个关键问题。"}}\n'
