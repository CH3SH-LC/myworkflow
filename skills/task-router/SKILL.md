---
name: 任务分类入口
description: Use when 拿不准请求属于哪类任务、该用哪个 skill，或疑似专项任务时查表。分类概念由会话注入（hook）提供，本表只作速查。不适用于子智能体。
---

# 任务分类速查

| 请求类型 | 走 |
|---|---|
| 代码/改文件/重构 | `Skill("myworkflow:agent-dev-loop")` |
| 文稿/去AI味/润色 | `Skill("myworkflow:humanizer-zh")` |
| 深度调研 | `Skill("myworkflow:deep-research")` |
| 疑似专项任务 | 查 `config/special-skills.json` → 命中则调用对应 skill |
| 简单问答/其它 | 直接回答 |
