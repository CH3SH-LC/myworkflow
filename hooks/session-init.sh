#!/usr/bin/env bash
# MyWorkflow v2.1.1 — SessionStart 注入
# 主智能体：阶段感知锚点（分类概念 + 阶段→skill 链）+ 注册表自动刷新
# 子智能体：一行协议锚点（不扫描注册表）
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# 子智能体环境：注入协议锚点
if [ -n "${CLAUDE_AGENT_TASK_ID:-}" ] || [ -n "${AGENT_MODE:-}" ] || [ -n "${SUBAGENT:-}" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"你是子智能体：先明确任务边界与接口，按 myworkflow:subagent-protocol 规范执行，完成后自检再报告（L2 子智能体 / L3 leaf 均适用本协议）。"}}\n'
  exit 0
fi

# 主智能体：注册表自动刷新（幂等、失败静默；~1s，保证 inventory 新鲜）
bash "$PLUGIN_ROOT/hooks/registry-scan.sh" >/dev/null 2>&1 || true

# 主智能体：分类概念锚点
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"先判工作级别再分类：L1 单智能体（单文件或纯问答，直接做完）/ L2 子智能体（≥2 个平铺无依赖小交付物，派 subagent 端到端完成）/ L3 团队（多域、接口依赖、需持续负责人）。级别或分类拿不准时查 myworkflow:task-router。\n然后直接按用户请求调用匹配的 Skill 完成工作——命中即调用，不跳过、不自作主张完成。任务分 5 类：代码编写 / 文稿撰写 / 深度调研 / 专项任务 / 简单问答；疑似专项任务时，查 myworkflow 插件的 config/special-skills.json 找对应 skill。\n开发类流程中，“阶段”只是加载技能的时机，不是把同一个交付物按阶段拆给多个执行者的理由（禁止阶段拆分）。遇 bug → myworkflow:root-cause-analysis；子任务产出完成 → myworkflow:integration-verify；真实验证 → myworkflow:real-world-verify；提交远程 → myworkflow:github-collab；润色文本 → myworkflow:polish-prose。最多澄清 1 个关键问题。"}}\n'
