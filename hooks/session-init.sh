#!/usr/bin/env bash
# MyWorkflow v5 — SessionStart 注入
# 主智能体：路由锚点（5 类任务→skill + 开发阶段链）+ 注册表自动刷新
# 子智能体：一行协议锚点（不扫描注册表）
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# 子智能体环境：注入协议锚点
if [ -n "${CLAUDE_AGENT_TASK_ID:-}" ] || [ -n "${AGENT_MODE:-}" ] || [ -n "${SUBAGENT:-}" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"你是子智能体：先明确任务边界与接口，按 myworkflow:subagent-protocol 规范执行，完成后自检再报告。"}}\n'
  exit 0
fi

# 主智能体：注册表自动刷新（幂等，~1s，保证 inventory 新鲜）
# stdout 必须丢弃——hook 的 stdout 只能是下面那一行合法 JSON。
# stderr 不重定向：刷新失败（如注册表损坏）时让错误浮到 hook 的 stderr，否则会静默无感。
bash "$PLUGIN_ROOT/hooks/registry-scan.sh" >/dev/null || true

# 主智能体：路由锚点 + 阶段链（v5）
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"直接按用户请求调用匹配的 Skill 完成工作——命中即调用，不跳过、不自作主张完成。任务分 5 类：代码 → agent-dev-loop；文稿 → 从零写作 write-prose，润色改写 polish-prose；调研 → deep-research；专项 → 查 myworkflow 插件的 config/special-skills.json（含 myworkflow-extra 下的专项技能）；简单问答 → 直接回答。技能统一 myworkflow: 前缀。开发类任务按阶段调 skill：项目有 docs/GOAL.md → 先调 project-maintain 定位 design 点；阶段3 遇 bug → root-cause-analysis；子任务完成 → integration-verify；阶段4 验证 → real-world-verify；提交 → github-collab；收尾同步文档 → project-maintain。最多澄清 1 个关键问题。"}}\n'
