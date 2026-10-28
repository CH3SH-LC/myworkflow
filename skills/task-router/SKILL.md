---
name: 任务分类入口
description: Use when 拿不准请求属于哪类任务、该用哪个 skill、疑似专项任务时查表，或在同一会话内从一类任务切到另一类需要确认路径时
---
# 任务分类速查

会话入口是 hook：它在启动时注入 5 类任务的分类概念与阶段链。本表是**备用速查**，用于两种场合——拿不准归哪类时，或长会话内切换任务类型、上下文里已经堆了很多别的东西时。

| 请求类型 | 走 |
|---|---|
| 代码 / 改文件 / 重构 | `Skill("myworkflow:agent-dev-loop")` |
| 文稿 / 从零写作 | `Skill("myworkflow:write-prose")` |
| 文稿 / 润色 / 改写 / 去 AI 味 | `Skill("myworkflow:polish-prose")` |
| 深度调研 | `Skill("myworkflow:deep-research")` |
| 疑似专项任务 | 查 `config/special-skills.json` → 命中则调用对应 skill |
| 简单问答 / 其它 | 直接回答 |

## 不在这张表里的技能

以下技能不参与任务分类，但在上表任一流程中都可能被调用：

- **工具性**：`req-clarify`（需求澄清）、`anti-sycophancy`（质疑准则）、`lessismore`（输出克制）、`registry-maintain`（注册表维护）
- **子智能体系统**：`task-dispatch`、`lightweight-dispatch`、`subagent-protocol`、`integration-verify`
- **项目管理**：`project-init`、`project-maintain`
- **代码细节**：`root-cause-analysis`、`real-world-verify`、`github-collab`
