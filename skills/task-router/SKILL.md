---
name: 任务分类入口
description: Use when 需要判断用户请求属于哪类任务、该用哪个执行 skill，或不确定路由时调用。扁平化路由：拿不准用什么 skill 时查阅本表。不适用于子智能体（收到 task-id 的 agent 跳过本 skill）。
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - Agent
  - Glob
  - Grep
  - Bash
  - PowerShell
  - Skill
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
---

## 目标

完成三件事：判断任务类型（五分类）→ 细化需求（多轮澄清）→ 按类型路由到对应执行 skill。

## 步骤 1：判断任务类型

| # | 分类 | 关键信号 | 下一步 |
|---|------|---------|--------|
| 1 | 代码编写 | 写/改代码、重构、修 bug、新建项目、加功能 | → 步骤2 → 步骤3.1 |
| 2 | 文稿撰写 | 写文档/报告、润色、去AI味、翻译 | → 步骤2 → 步骤3.2 |
| 3 | 深度调研 | 多源搜索+交叉验证+综合报告 | → 步骤2 → 步骤3.3 |
| 4 | 专项工作 | 有专用 skill 的领域（写作/学习笔记/可视化等） | → 步骤2 → 步骤3.4 |
| 5 | 其它任务 | 简单小提问、闲聊、无法归类 | → 直接回答 |

判断原则：不确定 → AskUserQuestion 一句话确认；多项匹配 → 选最接近；完全不匹配 → 其它任务。

## 步骤 2：细化需求

适用于分类 1-4（分类 5 跳过）。

1. 读取项目上下文（CLAUDE.md、相关代码）。
2. 逐轮启发式提问：每次一问、2-4 个选项，覆盖目标 → 范围 → 约束 → 边界，最多 5 轮。需求复杂时调用 `Skill("myworkflow:req-clarify")` 深度澄清。
3. 生成结构化需求报告（核心目标/输入输出/涉及范围/约束/边界/验证标准），用户确认后进入步骤 3。

用户说"直接做" → 精简但至少确认核心目标 + 输出形式。

## 步骤 3：按类型执行

### 3.1 代码编写

先判断是否新项目（文件夹空 / 无 CLAUDE.md / 无包管理配置文件）：
- 是 → `Skill("myworkflow:project-init")` → 初始化后回到本流程
- 否 → 按子类型：
  - 功能开发/重构/加功能 → `Skill("myworkflow:agent-dev-loop")`
  - 修 bug/报错/异常/不工作 → `Skill("myworkflow:bug-fix-verify")`
  - 排查根因/深度排查 → `Skill("myworkflow:root-cause-analysis")`
  - 提交代码/创建 PR/合并 → `Skill("myworkflow:github-collab")`

### 3.2 文稿撰写

- 已有文本去AI味/润色 → `Skill("myworkflow:humanizer-zh")`
- 从零撰写 → 先直接写初稿，再询问是否润色
- 纯翻译 → 直接翻译，再询问是否润色

### 3.3 深度调研

→ `Skill("myworkflow:deep-research")`，传入步骤 2 确认的调研问题与范围。不可用时手动执行：多源搜索 → 交叉验证 → 综合报告。

### 3.4 专项工作

扫描会话中的「专项 Skills」清单匹配专用 skill → 调用对应 `Skill(...)`；无匹配 → 降级为需求澄清后直接执行。

已知映射（以会话注入清单为准）：网文写作→具体写作/大纲设计/人物设计（webnovel-studio）；学习笔记→self-study-guide；数据可视化→dataviz；前端设计→frontend-design；PDF 提取→pdf-to-markdown；Skill 开发→skill-creator。

### 3.5 其它任务

直接回答，不走澄清与路由。

## 步骤 4：确认完成

向用户汇报：📂 判定类型 → 🛤️ 路由到哪个 skill → 📋 预计后续流程。

## 常见场景速查

| 用户说 | 分类 | 路由 |
|--------|------|------|
| "帮我加个登录" | 代码编写 | agent-dev-loop |
| "报错了 TypeError" | 代码编写 | bug-fix-verify |
| "新建一个 React 项目" | 代码编写 | project-init → agent-dev-loop |
| "帮我把这段去 AI 味" | 文稿撰写 | humanizer-zh |
| "调研 Next.js vs Nuxt" | 深度调研 | deep-research |
| "找到根因/深度排查" | 代码编写 | root-cause-analysis |
| "提交代码/创建 PR" | 代码编写 | github-collab |
| "写小说第三章" | 专项工作 | webnovel-studio 具体写作 |
| "这段代码什么意思" | 其它任务 | 直接回答 |

## 注意事项

- 分类不确定 → 问用户，不要猜。
- 代码编写类禁止跳过步骤 2 直接写代码。
- 专项技能清单以会话注入为准，不要硬编码。
