# MyWorkflow

AI 辅助开发全流程技能包 —— 为 Claude Code 提供从需求理解到代码交付的完整工作流。

**当前版本：v3.0.0（扁平化轻量版）**

## 设计理念

MyWorkflow 将 AI 辅助开发拆解为 **19 个自包含技能**，采用 **扁平化架构**：技能直接按 `description` 自动触发，无分类仪式、无路由 hop、无强制澄清链。每个技能负责一个清晰的职责，可独立调用、可互相引用。

v3 针对模型更换后的实际使用痛点做了系统性瘦身：

| 问题（v2） | 方案（v3） |
|-----------|-----------|
| SessionStart 注入 16KB 五分类仪式，后半段放弃遵守 | 注入精简到 ~70 字行为锚点 |
| 强制"分类→2-5 轮提问→报告→确认"链路 | 技能按描述直接触发，最多澄清 1 个关键问题 |
| 三插件撞名导致注册被丢弃 | 网文/大项目技能迁出，myworkflow 只保留自含技能 |
| 技能文件臃肿（单技能最大 1199 行） | 19 技能从 7642 → 3353 行（-56%），功能门禁全保留 |
| 22 个 SKILL.md 带 UTF-8 BOM 导致解析失败 | 全插件去 BOM，技能真实注册可调用 |

## 架构

```
用户请求 ──→ 直接匹配技能 description
                 │
    ┌────────────┼─────────────┐
    ▼            ▼             ▼
 编程开发      调研/文稿      任务编排
 (7 skills)   (4 skills)     (6 skills)   +  行为准则/辅助 (2 skills)
    │            │             │
    └────────────┴─────────────┘
          Skill 互相引用（myworkflow: 前缀）
```

### 19 个技能

| 组 | 技能（目录名 / 显示名） | 用途 |
|----|------------------------|------|
| **代码开发** | `agent-dev-loop` 智能体闭环开发 | 功能开发全流程门禁：需求→计划→TDD→真实验证→循环 |
| | `bug-fix-verify` Bug修复与验证 | 五步闭环：填细节→排查根因→并行修复→审查→循环 |
| | `root-cause-analysis` 根因定位与全面排查 | 5 Whys + 数据流追踪 + 假设验证 + 五项专项排查技术 |
| | `real-world-verify` 真实验证 | 所有编程技能的验证门禁：像用户一样使用产品 |
| | `project-init` 大项目初始化 | 建立 CLAUDE.md/PROGRESS.md/STRUCTURE.md 四文件体系 |
| | `project-maintain` 大项目工作维护 | 工作前读文档 + 工作后同步进度 |
| | `github-collab` Github协作 | 隔离开发→提交→PR→审查→合并 |
| **调研/文稿/学习** | `deep-research` 深度调研 | 多源并行搜索→交叉验证→强制 .md 落盘报告 |
| | `humanizer-zh` | 去除中文文本 AI 痕迹 |
| | `pdf-to-markdown` | 扫描版 PDF OCR → Markdown + LaTeX 公式还原 |
| | `self-study-guide` | STEM 教材/论文 → 讲师模式/导师模式学习讲义 |
| **任务编排** | `task-router` 任务分类入口 | 扁平化路由表：拿不准用什么 skill 时查阅 |
| | `task-dispatch` 任务拆解与派发 | 结构化拆解复杂任务 + 合约驱动的并行派发 |
| | `lightweight-dispatch` 轻量级派发 | N 个无依赖轻任务快速并行（无合约模式） |
| | `subagent-protocol` 子智能体执行协议 | 子智能体五阶段工作规范 |
| | `integration-verify` 集成验证与修正 | 子智能体产出接口合规验证 |
| | `req-clarify` 需求澄清 | 可被任何 skill 调用的澄清工具 |
| **行为准则/辅助** | `anti-sycophancy` 反谄媚 | 通用行为准则：质疑一切、技术诚实、证据驱动 |
| | `skill-authoring` 辅助写技能 | 用 TDD 方法创建、优化、审查 skill |

## 安装

### 前提

三个自制插件通过 `installed_plugins.json` 注册 + `settings.json` 的 `enabledPlugins` 启用（`@local` scope）。无需 `~/.claude/skills/` 下的 symlink 或 junction。

### 步骤

1. 确保 `~/.claude/plugins/myworkflow/` 存在（本仓库即插件本体）。
2. 在 `installed_plugins.json` 中注册：
   ```json
   "myworkflow@local": [{
     "scope": "user",
     "installPath": "C:\\Users\\Lenovo\\.claude\\plugins\\myworkflow",
     "version": "3.0.0"
   }]
   ```
3. 在 `~/.claude/settings.json` 的 `enabledPlugins` 中启用：
   ```json
   "myworkflow@local": true
   ```
4. **Hook 自动生效**：插件启用后，`hooks/hooks.json` 的 SessionStart hook 自动注册，无需手工合并到 settings.json。

### 验证安装

启动新的 Claude Code 会话，技能列表中应出现全部 19 个 `myworkflow:*` 技能；SessionStart 时注入约 70 字行为锚点：
> 直接按用户请求调用匹配的 Skill 完成工作；没有匹配的 skill 就自己完成。最多澄清 1 个关键问题，不要多轮确认。

## 工作流

```
会话启动
  │
  ▼
SessionStart Hook（~70 字）── 行为锚点
  │
  ▼
收到用户请求
  │
  ▼
技能 description 自动匹配 ──→ 命中 → 调用对应 skill
                         └─→ 无命中 → 直接完成（skill 是手段不是仪式）
  │
  ▼
复杂任务 → task-dispatch 拆解派发 → subagent-protocol → integration-verify
编程任务 → real-world-verify 真实验证（强制门禁，禁止仅跑单测）
```

## 核心设计决策

| # | 决策 | 理由 |
|---|------|------|
| 1 | 扁平化：技能按 description 直接触发 | 消除分类仪式与路由 hop，降低模型使用门槛 |
| 2 | 单一 SessionStart hook，注入 ~70 字 | 每次会话极简行为锚点，不烧上下文 |
| 3 | Description 铁律 | description 只写"何时触发"，不写"技能做什么" |
| 4 | TDD + 真实验证双保险 | TDD 保代码正确性，真实验证保用户体验 |
| 5 | 跨文件必须派发子智能体 | 单上下文做不了多文件协作，合约化派发保接口一致 |
| 6 | 反谄媚内建 | AI 应对用户保持健康怀疑，技术诚实优先于迎合 |
| 7 | P2 必须修复不留漏洞 | 任何一级问题都是漏洞，不允许带病出循环 |
| 8 | 自含技能，无撞名 | 网文/大项目技能迁出，避免多插件注册被丢弃 |

## 目录结构

```
myworkflow/
  plugin.json                  # marketplace 发布清单（v3.0.0）
  .claude-plugin/plugin.json   # 运行时发现元数据（v3.0.0）
  README.md
  PROGRESS.md                  # 完整开发进度
  PROGRESS-LITE.md             # 进度速查
  hooks/
    hooks.json                 # 仅 SessionStart（startup + clear|compact，timeout 10s）
    session-init.sh            # 极简注入脚本（~70 字行为锚点，子智能体环境跳过）
  skills/                      # 19 个技能，每技能一个 SKILL.md
    task-router/               # 任务分类入口
    agent-dev-loop/            # 智能体闭环开发
      references/testing-anti-patterns.md
    bug-fix-verify/            # Bug修复与验证
    root-cause-analysis/       # 根因定位与全面排查
      references/condition-based-waiting.md
      references/defense-in-depth.md
    real-world-verify/         # 真实验证（强制门禁）
    project-init/              # 大项目初始化
    project-maintain/          # 大项目工作维护
    github-collab/             # Github协作
    deep-research/             # 深度调研
    humanizer-zh/              # 中文 AI 痕迹清除
    pdf-to-markdown/           # 扫描 PDF → Markdown/LaTeX
    self-study-guide/          # STEM 学习讲义
    task-dispatch/             # 任务拆解与派发
    lightweight-dispatch/      # 轻量级派发
    subagent-protocol/         # 子智能体执行协议
    integration-verify/        # 集成验证与修正
    req-clarify/               # 需求澄清
    anti-sycophancy/           # 反谄媚
    skill-authoring/           # 辅助写技能
      references/persuasion-principles.md
```

## 技术细节

- **Hook**：单一 `SessionStart` 事件，在 `startup` 和 `clear|compact` 时触发，timeout 10s。
- **注入机制**：`session-init.sh` 输出 ~70 字 JSON `additionalContext`；子智能体环境（`CLAUDE_AGENT_TASK_ID`/`AGENT_MODE`/`SUBAGENT`）跳过注入。
- **技能格式**：每个技能为独立目录，含 `SKILL.md`（YAML frontmatter + Markdown 正文），frontmatter 无 BOM。
- **发现机制**：`installed_plugins.json` + `enabledPlugins@local`，不依赖 `~/.claude/skills/` symlink/junction。
- **跨 skill 引用**：统一 `myworkflow:` 前缀（如 `Skill("myworkflow:task-dispatch")`）。
- **平台**：Windows（Git Bash / PowerShell 双版本命令）+ macOS / Linux。

## 开发理念

- **闭环优于速度**：宁可多花 30% 时间一次做对，不要花 300% 时间反复修补
- **描述即触发**：技能的 description 字段只写触发条件，不写内部流程
- **审计驱动迭代**：每次大改后派子智能体并行审计，清零 P0/P1/P2 方止
- **YAGNI**：每个方案生成时主动删减不必要功能
- **真实验证 > 单元测试**：代码写完必须以真实用户身份使用并观察行为

## License

MIT
