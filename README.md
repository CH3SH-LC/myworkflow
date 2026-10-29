# MyWorkflow

AI 辅助开发全流程技能包 —— 为 Claude Code 提供从需求理解到代码交付的完整工作流。

**当前版本：v2.3.0（每轮任务纪律 hook：长会话反漂移；技能内容冻结为 15 技能；10 月 v2.0.0-preview 已放弃）**

## 设计理念

MyWorkflow 将 AI 辅助开发拆解为 **21 个自包含技能**，采用 **扁平化架构 + 三级协作判级锚点**：技能直接按 `description` 自动触发，无分类仪式、无路由 hop、无强制澄清链；SessionStart 注入工作级别判定（L1 单智能体 / L2 子智能体 / L3 团队）+ 5 类任务认知 + 加载时机说明（"阶段"只是加载技能的时机，禁止把同一交付物按阶段拆给多个执行者），并指引疑似专项任务查询注册表。

v1.0.x–1.1 系列针对模型更换后的实际使用痛点做了系统性瘦身与重构；v2.0.0-preview（10 月 21 日）为失败的 DSH 对齐预览，v2.0.0（10 月 28 日）回退 9 月内容后正式发布；v2.1.0（10 月 28 日）升级三级协作模型（L1 单智能体 / L2 子智能体 / L3 团队）；v2.1.1（10 月 28 日）体检整改（F1–F17：判级/禁止阶段接力/证据口径/命名与仓库文档配置）；v2.2.0（10 月 29 日）修正 L2/L3 语义与 member/leaf 区别、新增禁止回合内等待与 30s 后台纪律、删除 3 个技能（组件 18→15，仓库技能 24→21）；v2.2.1（10 月 29 日）插件清单补丁（plugin.json skills 数组 24→21，版本 2.2.1）；v2.3.0（10 月 29 日）新增每轮任务纪律 hook（每用户回合 pre-step 注入「skills 意识/弄清需求/遵循指令/去废话」四条，长会话反漂移；不改技能正文）：

| 问题（1.0.x–1.1） | 方案（2.0.0） |
|-----------|----------------|
| SessionStart 注入 16KB 五分类仪式，后半段放弃遵守 | 注入精简到 ~260 字锚点（5 类概念 + 技能加载时机提示） |
| 1.0.2 拆掉执行期钩子后，后半程技能触发概率下降 | 锚点显式列出加载时机：遇 bug→root-cause、真实验证→real-world-verify、提交→github-collab、润色→humanizer-zh；注册表触发词不再截断 |
| 强制"分类→2-5 轮提问→报告→确认"链路 | 技能按描述直接触发，最多澄清 1 个关键问题 |
| 专项任务路由靠硬编码映射，易漂移 | 专项注册表 `config/special-skills.json`（自动扫描 + 人工分类） |
| 修复 bug 独立成顶层 skill | 修复并入智能体闭环开发，找 bug 独立走 root-cause-analysis |
| 技能文件臃肿（单技能最大 1199 行） | 19→22 技能瘦身，root-cause 426→98 行（方法密度优先） |
| 22 个 SKILL.md 带 UTF-8 BOM 导致解析失败 | 全插件去 BOM，技能真实注册可调用 |

## 架构

```
用户请求 ──→ 直接匹配技能 description（级别判定 + 分类概念由 hook 提供）
                 │
    ┌────────────┼─────────────┐
    ▼            ▼             ▼
 编程开发      调研/文稿      任务编排
 (7 skills)   (4 skills)     (6 skills)   +  电脑专项(2) + 行为准则/辅助(2)
    │            │             │
    └────────────┴─────────────┘
      疑似专项 → 查 config/special-skills.json → 调用对应 skill
          Skill 互相引用（myworkflow: 前缀）
```

### 21 个技能

| 组 | 技能（目录名 / 显示名） | 用途 |
|----|------------------------|------|
| **代码开发** | `agent-dev-loop` 智能体闭环开发 | 功能开发全流程门禁（含 bug 修复路径）：需求→计划→TDD→真实验证→循环 |
| | `registry-maintain` 专项注册表维护 | 维护 config/special-skills.json（categories 人工维护 + inventory 自动扫描） |
| | `root-cause-analysis` 根因定位与全面排查 | 5 Whys + 数据流追踪 + 假设验证 + 五项专项排查技术（只查不修） |
| | `real-world-verify` 真实验证 | 所有编程技能的验证门禁：像用户一样使用产品 |
| | `project-init` 项目文档初始化 | 在文件夹上建立 CLAUDE.md + STRUCTURE.md + docs/ 的 **8 位置文档体系**（含体系识别/迁移与开工门禁） |
| | `project-maintain` 项目工作维护 | 两个调用时机（进入时读文档 + 开工门禁 / 完成时强制同步 + 校验）的 **6 阶段主线** |
| | `github-collab` Github协作 | 隔离开发→提交→PR→审查→合并 |
| **调研/文稿/学习** | `deep-research` 深度调研 | 多源并行搜索→交叉验证→强制 .md 落盘报告 |
| | `humanizer-zh` | 去除中文文本 AI 痕迹 |
| | `pdf-to-markdown` | 扫描版 PDF OCR → Markdown + LaTeX 公式还原 |
| | `self-study-guide` | STEM 教材/论文 → 讲师模式/导师模式学习讲义 |
| **任务编排** | `task-router` 任务分类入口 | 第一步判工作级别（L1 单智能体 / L2 子智能体 / L3 团队），再按 5 类任务给 skill 路径 |
| | `task-dispatch` 任务拆解与派发 | L3 拆分契约：横向切可独立交付物 + 禁止阶段接力的正例/反例 |
| | `lightweight-dispatch` 轻量级派发 | L2 操作规程（≥2 个平铺、无依赖小交付物）+ 升级 L3 的判据 |
| | `subagent-protocol` 成员与执行者协作协议 | L2 子智能体 / L3 leaf 协作协议（回执→可复核证据→owner 验收；禁止阶段拆分） |
| | `integration-verify` 集成验证与修正 | 子智能体产出接口合规验证 + 证据口径（produced / verified / accepted） |
| | `req-clarify` 需求澄清 | 可被任何 skill 调用的澄清工具 |
| **电脑专项** | `storage-analyzer` 电脑清理 | 只读扫描磁盘 → 三色分级 → 交互式 HTML 报告（适配自卡兹克） |
| | `file-organize` 电脑整理 | 编号分类文件夹维护（参考 D:\CH3SH），移动需确认 |
| | `lessismore` | AI 思考与协作的"少即是多"准则 |
| | `skill-authoring` 辅助写技能 | 用 TDD 方法创建、优化、审查 skill |

## 安装

### 前提

自制插件通过 `installed_plugins.json` 注册 + `settings.json` 的 `enabledPlugins` 启用（`@local` scope）。无需 `~/.claude/skills/` 下的 symlink 或 junction。

### 步骤

1. 确保 `~/.claude/plugins/myworkflow/` 存在（本仓库即插件本体）。
2. 在 `installed_plugins.json` 中注册：
   ```json
   "myworkflow@local": [{
     "scope": "user",
     "installPath": "C:\\Users\\Lenovo\\.claude\\plugins\\myworkflow",
     "version": "2.3.0"
   }]
   ```
3. 在 `~/.claude/settings.json` 的 `enabledPlugins` 中启用：
   ```json
   "myworkflow@local": true
   ```
4. **Hook 自动生效**：插件启用后，`hooks/hooks.json` 的 SessionStart hook 自动注册，无需手工合并到 settings.json。

### 验证安装

启动新的 Claude Code 会话，技能列表中应出现全部 21 个 `myworkflow:*` 技能；SessionStart 时注入分类概念锚点：
> 直接按用户请求调用匹配的 Skill 完成工作；没有匹配的 skill 就自己完成。最多澄清 1 个关键问题。任务分 5 类：代码编写 / 文稿撰写 / 深度调研 / 专项任务 / 简单问答。疑似专项任务时，查 myworkflow 插件的 config/special-skills.json 找对应 skill。

## 工作流

```
会话启动
  │
  ▼
SessionStart Hook（~260 字）── 级别判定 + 分类概念锚点 + 注册表自动刷新
  │                              （子智能体上下文 → 一行协议锚点）
  ▼
收到用户请求
  │
  ▼
技能 description 自动匹配 ──→ 命中 → 调用对应 skill
                         └─→ 疑似专项 → 查 config/special-skills.json
  │
  ▼
复杂任务 → task-dispatch 拆解派发 → subagent-protocol → integration-verify
编程任务 → real-world-verify 真实验证（强制门禁，禁止仅跑单测）
发现 bug → root-cause-analysis 定位 → 修复 → 真实验证
```

## 核心设计决策

| # | 决策 | 理由 |
|---|------|------|
| 1 | 先判级别再分类 | L1/L2/L3 与 5 类只是认知锚点——hook 只给判级与分类概念，不给处理指令（禁止阶段拆分） |
| 2 | 专项注册表 config/special-skills.json | 专项 skill 是动态集合，结构化注册表可查询、可自动扫描、不漂移 |
| 3 | 修复 bug 并入开发闭环 | 修复不是独立任务，是开发的一部分；找 bug（root-cause）独立调用 |
| 4 | Description 铁律 | description 只写"何时触发"，不写"技能做什么" |
| 5 | TDD + 真实验证双保险 | TDD 保代码正确性，真实验证保用户体验 |
| 6 | 篇幅服务方法质量 | 低确定性任务（找 bug）短而精、方法密度高；高确定性操作（清理）详细 |
| 7 | 跨文件必须派发子智能体 | 单上下文做不了多文件协作，合约化派发保接口一致 |
| 8 | 反谄媚 + lessismore 内建 | 健康怀疑 + 克制输出，技术诚实优先于迎合 |

## 目录结构

```
myworkflow/
  plugin.json                  # marketplace 发布清单（v2.3.0）
  .claude-plugin/plugin.json   # 运行时发现元数据（v2.3.0）
  README.md
  PROGRESS.md                  # 完整开发进度
  PROGRESS-LITE.md             # 进度速查
  hooks/
    hooks.json                 # 仅 SessionStart（startup + clear|compact，timeout 15s）
    session-init.sh            # 分类概念锚点 + 注册表刷新；子智能体注入协议锚点
    registry-scan.sh           # 专项注册表扫描生成器（幂等，~1s）
  config/
    special-skills.json        # 专项注册表（categories 人工 + inventory 自动）
  skills/                      # 21 个技能，每技能一个 SKILL.md
    task-router/               # 任务分类入口（先判级别）
    agent-dev-loop/            # 智能体闭环开发（含 bug 修复路径）
      references/testing-anti-patterns.md
    registry-maintain/         # 专项注册表维护
    root-cause-analysis/       # 根因定位与全面排查
      references/condition-based-waiting.md
      references/defense-in-depth.md
    real-world-verify/         # 真实验证（强制门禁）
    project-init/              # 项目文档初始化
    project-maintain/          # 项目工作维护
    github-collab/             # Github协作
    deep-research/             # 深度调研
    humanizer-zh/              # 中文 AI 痕迹清除
    pdf-to-markdown/           # 扫描 PDF → Markdown/LaTeX
    self-study-guide/          # STEM 学习讲义
    task-dispatch/             # 任务拆解与派发
    lightweight-dispatch/      # 轻量级派发
    subagent-protocol/         # 成员与执行者协作协议
    integration-verify/        # 集成验证与修正
    req-clarify/               # 需求澄清
    storage-analyzer/          # 电脑清理（卡兹克适配，含 scripts/ 与 references/）
      references/macos.md
      references/windows.md
    file-organize/             # 电脑整理
    lessismore/                # 少即是多（行为准则）
    skill-authoring/           # 辅助写技能
      references/persuasion-principles.md
  docs/
    my-architecture.md         # 原始设计想法
    refined-architecture.md    # 细化方案 v2
    architecture-topology.md   # 技能连接拓扑（维护用）
```

## 架构拓扑

技能之间的连接结构（DAG 分层、编排铁三角、验证门禁、外部插件挂接）见 **`docs/architecture-topology.md`** —— 内含可渲染的 Mermaid 图与维护边表。改动任何技能引用后请同步该文件。

## 技术细节

- **Hook**：单一 `SessionStart` 事件，在 `startup` 和 `clear|compact` 时触发，timeout 15s。
- **注入机制**：`session-init.sh` 主智能体注入 ~200 字分类概念锚点 + 触发注册表刷新；子智能体环境（`CLAUDE_AGENT_TASK_ID`/`AGENT_MODE`/`SUBAGENT`）注入一行协议锚点。
- **专项注册表**：`registry-scan.sh` 每次 SessionStart 自动刷新 `config/special-skills.json` 的 `inventory`（自动扫描，保真）；`categories` 由 `registry-maintain` skill 人工维护。
- **技能格式**：每个技能为独立目录，含 `SKILL.md`（YAML frontmatter + Markdown 正文），frontmatter 无 BOM。
- **发现机制**：`installed_plugins.json` + `enabledPlugins@local`，不依赖 `~/.claude/skills/` symlink/junction。
- **跨 skill 引用**：统一 `myworkflow:` 前缀（如 `Skill("myworkflow:task-dispatch")`）。
- **平台**：Windows（Git Bash / PowerShell 双版本命令）+ macOS / Linux。

## 开发理念

- **闭环优于速度**：宁可多花 30% 时间一次做对，不要花 300% 时间反复修补
- **描述即触发**：技能的 description 字段只写触发条件，不写内部流程
- **篇幅服务方法质量**：低确定性任务短而精（给方法框架），高确定性操作详细（步骤可复制）
- **审计驱动迭代**：每次大改后派子智能体并行审计，清零 P0/P1/P2 方止
- **YAGNI**：每个方案生成时主动删减不必要功能
- **真实验证 > 单元测试**：代码写完必须以真实用户身份使用并观察行为

## License

MIT
