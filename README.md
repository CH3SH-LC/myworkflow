# MyWorkflow

AI 辅助工作全流程技能包 —— 为 Claude Code 提供从请求路由到交付验收的完整工作流。

**当前版本：v5.0.0（hook 入口 → 路由 → 5 类任务 + 四组能力）**

## 设计理念

MyWorkflow 把「Claude 该用哪个技能」这件事收敛成一条链路：**hook 入口 → 路由 → 5 类任务**。

- **入口**：SessionStart hook 注入一条路由锚点，给出 5 类任务的分类概念与开发阶段→skill 链。
- **路由**：代码 / 文稿 / 调研 / 专项 / 简单问答。前四类各有对应技能，简单问答直接回答。
- **5 类任务**：`agent-dev-loop`（代码）、`write-prose` + `polish-prose`（文稿）、`deep-research`（调研）；专项任务查 `config/special-skills.json` 定位，简单问答不调技能。

5 类任务共对应 **4 个任务技能**；其余 **14 个技能不参与任务分类**，而是在上述任一流程中被调用，分四组（4 + 5 + 4 + 2 + 3 = 18）：

| 组 | 数量 | 角色 |
|----|------|------|
| 工具性 | 5 | 路由速查与横切准则：`task-router`、`req-clarify`、`anti-sycophancy`、`lessismore`、`registry-maintain` |
| 子智能体系统 | 4 | 拆解派发与集成验证：`task-dispatch`、`lightweight-dispatch`、`subagent-protocol`、`integration-verify` |
| 项目管理 | 2 | 项目文档体系的建立与维护：`project-init`、`project-maintain` |
| 代码细节 | 3 | 开发主干内部的门禁与收尾：`root-cause-analysis`、`real-world-verify`、`github-collab` |

技能按 `description` 直接触发，无强制分类仪式、无固定澄清链；开发类任务另按**阶段链**调用技能（阶段 3 遇 bug → 根因定位、阶段 4 → 真实验证、提交 → Github 协作、收尾 → 项目维护）。

### v5 变更

| 项目 | v4 | v5 |
|------|----|----|
| 版本 | 4.0.0 | 5.0.0 |
| 技能总数 | 22 | 18 |
| 框架表述 | 扁平化触发 + 阶段感知锚点 | hook 入口 → 路由 → 5 类任务 + 四组能力 |
| 文稿能力 | `humanizer-zh`（去 AI 痕迹） | `write-prose` / `polish-prose`，共用「AI 特征表」方法论 |
| 项目管理 | 四文件体系（CLAUDE/PROGRESS/PROGRESS-LITE/STRUCTURE） | 根目录 `CLAUDE.md` + `STRUCTURE.md`；`docs/` 下 GOAL / STATE / PROGRESS / design / information / research / other |
| 专项技能归属 | 与主干技能同置于 myworkflow | 6 个专项技能迁至 `myworkflow-extra` |
| `large-project-work` 插件 | 与 myworkflow 技能同名并存 | 已删除 |
| hook 锚点 | 分类概念 + 阶段链 | 路由锚点：5 类任务→skill + 开发阶段链 |

## 架构

```
会话启动
  │
  ▼
SessionStart hook（session-init.sh）
  ├─ 主智能体：注入路由锚点（5 类任务→skill + 开发阶段链）
  └─ 自动刷新专项注册表 inventory
  │
  ▼
┌──────────────────────────── 路由 · 5 类任务 ────────────────────────────┐
│                                                                        │
│   代码              文稿                   调研            专项 / 简单   │
│   agent-dev-loop    write-prose            deep-research   ├ 专项 → 查  │
│                     polish-prose                           │  special- │
│                                                            │  skills   │
│                                                            └ 简单 → 直接│
└────────────────────────────────────────────────────────────────────────┘
  │
  │  四组能力（不参与分类，在任一流程中被调用）
  ├─ 工具性(5)：task-router · req-clarify · anti-sycophancy · lessismore · registry-maintain
  ├─ 子智能体系统(4)：task-dispatch · lightweight-dispatch · subagent-protocol · integration-verify
  ├─ 项目管理(2)：project-init · project-maintain
  └─ 代码细节(3)：root-cause-analysis · real-world-verify · github-collab
```

### 18 个技能

| 组 | 技能（目录名 / 显示名） | 用途 |
|----|------------------------|------|
| **5 类任务路由** | `agent-dev-loop` 智能体闭环开发 | 代码主干：开工门禁（对应 design 点）→ 需求 → 计划 → TDD → 真实验证 → 收尾同步文档 |
| | `write-prose` 文稿写作 | 从零产出中文文稿：定三件事 → 出骨架 → 成文 → AI 特征表 → 落盘 |
| | `polish-prose` 文稿润色 | 已有成稿的修改与诊断：不改清单 → 改动分级（L1 轻改 / L2 中改 / L3 重写需授权） |
| | `deep-research` 深度调研 | 多源并行搜索 → 交叉验证 → 结构化落盘到 `docs/research/<主题>/` |
| **工具性 (5)** | `task-router` 任务分类入口 | 分类速查表：拿不准归哪类，或长会话内切换任务类型时查 |
| | `req-clarify` 需求澄清 | 可被任何 skill 调用；允许多问，但每问必须有价值且用 `AskUserQuestion` |
| | `anti-sycophancy` 反谄媚 | 通用行为准则：质疑一切、技术诚实、证据驱动，输出带 RISK 标注 |
| | `lessismore` 少即是多 | 思考与协作的克制准则，横切不绑定具体任务 |
| | `registry-maintain` 专项注册表维护 | 维护 `config/special-skills.json` 的 `categories` 段（聚焦分类，inventory 自动生成） |
| **子智能体系统 (4)** | `task-dispatch` 任务拆解与派发 | 结构化拆解复杂任务 + 合约驱动的并行派发 |
| | `lightweight-dispatch` 轻量级派发 | N 个无依赖轻任务快速并行（无合约模式） |
| | `subagent-protocol` 子智能体执行协议 | 子智能体工作规范（由 hook 注入锚点触发） |
| | `integration-verify` 集成验证与修正 | 子智能体产出的接口合规验证 |
| **项目管理 (2)** | `project-init` 项目文档初始化 | 建立根目录 `CLAUDE.md` + `STRUCTURE.md` 与 `docs/` 八位置体系 |
| | `project-maintain` 项目工作维护 | 进入时读文档 + 过开工门禁；完成时强制同步文档 + 校验 |
| **代码细节 (3)** | `root-cause-analysis` 根因定位与全面排查 | 5 Whys + 数据流追踪 + 假设验证 + 五项专项排查技术（只查不修） |
| | `real-world-verify` 真实验证 | 强制门禁：像用户一样使用产品，禁止仅跑单测 |
| | `github-collab` Github协作 | 隔离开发 → 提交 → PR → 审查 → 合并 |

> 「5 类任务路由」列出 4 个技能：第 5 类「简单问答」不调用技能；「专项任务」不在 myworkflow 内，由注册表指向对应插件（含 `myworkflow-extra`）。

## myworkflow-extra

`myworkflow-extra` 是配套的**专项技能集**插件，收纳 6 个不属于开发主干、但需独立触发的专项能力。这些技能原属 myworkflow，在 v5 中迁出——**移出不等于废弃**：它们照常注册，`registry-scan.sh` 会自动把它们收录进 `config/special-skills.json` 的 `inventory`，专项路由仍能找到。

| 技能 | 显示名 | 用途 |
|------|--------|------|
| `pdf-to-markdown` | pdf-to-markdown | 扫描版 PDF 经 OCR 转 Markdown，公式还原为 LaTeX |
| `self-study-guide` | self-study-guide | STEM 教材/论文转讲师或导师模式的学习讲义 |
| `storage-analyzer` | storage-analyzer | 只读扫描磁盘占用 → 三色分级 → 可交互 HTML 报告 |
| `file-organize` | 电脑整理 | 按编号分类体系整理文件夹，移动需确认，不擅自删除 |
| `skill-authoring` | 辅助写技能 | 用 TDD 方法创建、优化、审查 skill |
| `humanizer-zh` | humanizer-zh | **已废弃**，保留备查 |

> `humanizer-zh` 已废弃，中文文稿能力由 myworkflow 的 `write-prose` 与 `polish-prose` 承担。

## 安装

### 前提

自制插件通过 `installed_plugins.json` 注册 + `settings.json` 的 `enabledPlugins` 启用（`@local` scope）。无需 `~/.claude/skills/` 下的 symlink 或 junction。**两个插件都要装**：myworkflow 是主干，myworkflow-extra 提供专项技能。

### 步骤

1. 确保 `~/.claude/plugins/myworkflow/` 与 `~/.claude/plugins/myworkflow-extra/` 存在（本仓库即 myworkflow 插件本体）。
2. 在 `installed_plugins.json` 中注册两个插件：

   ```json
   "myworkflow@local": [{
     "scope": "user",
     "installPath": "C:\\Users\\Lenovo\\.claude\\plugins\\myworkflow",
     "version": "5.0.0"
   }],
   "myworkflow-extra@local": [{
     "scope": "user",
     "installPath": "C:\\Users\\Lenovo\\.claude\\plugins\\myworkflow-extra",
     "version": "1.0.0"
   }]
   ```

3. 在 `~/.claude/settings.json` 的 `enabledPlugins` 中启用：

   ```json
   "myworkflow@local": true,
   "myworkflow-extra@local": true
   ```

4. 在 `marketplaces/local/.claude-plugin/marketplace.json` 的 `plugins[]` 中登记两个插件（`source` 分别指向各自目录）。
5. **Hook 自动生效**：插件启用后，`hooks/hooks.json` 的 SessionStart hook 自动注册，无需手工合并到 settings.json。

### 验证安装

启动新的 Claude Code 会话，技能列表中应出现 18 个 `myworkflow:*` 技能与 6 个 `myworkflow-extra:*` 技能；SessionStart 时注入路由锚点：

> 直接按用户请求调用匹配的 Skill 完成工作——命中即调用，不跳过、不自作主张完成。任务分 5 类：代码 → agent-dev-loop；文稿 → 从零写作 write-prose，润色改写 polish-prose；调研 → deep-research；专项 → 查 myworkflow 插件的 config/special-skills.json（含 myworkflow-extra 下的专项技能）；简单问答 → 直接回答。……开发类任务按阶段调 skill：项目有 docs/GOAL.md → 先调 project-maintain 定位 design 点；阶段3 遇 bug → root-cause-analysis；子任务完成 → integration-verify；阶段4 验证 → real-world-verify；提交 → github-collab；收尾同步文档 → project-maintain。

## 工作流

```
会话启动
  │
  ▼
SessionStart Hook ── 路由锚点（5 类任务 + 阶段链）+ 注册表自动刷新
  │                   （子智能体上下文 → 一行协议锚点）
  ▼
收到用户请求
  │
  ├─ 代码     → agent-dev-loop
  │                └ 有 docs/GOAL.md → 先 project-maintain 定位 design 点 → 开工门禁
  │                └ 阶段 3 遇 bug  → root-cause-analysis（只查不修）
  │                └ 阶段 4 验证    → real-world-verify（强制门禁）
  │                └ 提交          → github-collab
  │                └ 收尾          → project-maintain（同步 PROGRESS / STATE / index）
  ├─ 文稿     → write-prose（无稿）/ polish-prose（有稿）
  ├─ 调研     → deep-research → 落盘 docs/research/<主题>/
  ├─ 专项     → 查 config/special-skills.json → 调用对应插件技能
  └─ 简单问答 → 直接回答
  │
  ▼
复杂任务 → task-dispatch 拆解派发 → subagent-protocol → integration-verify
```

## 核心设计决策

| # | 决策 | 理由 |
|---|------|------|
| 1 | 心智模型为「hook 入口 → 路由 → 5 类任务」 | 入口、主干、能力分组一眼可辨；其余技能明确标注「不参与分类」 |
| 2 | 分类概念在 hook，速查表在 task-router | 会话入口给出分类认知，速查表只在拿不准或长会话切换时兜底 |
| 3 | 专项技能迁至独立插件 + 注册表路由 | 专项是动态集合，与主干解耦后可按需增删；`config/special-skills.json` 可查询、可自动扫描、不漂移 |
| 4 | 文稿拆成「写作」与「润色」两个技能 | 判据是「是否存在用户认可的原稿」；润色侧有「不改清单」与改动分级，防止越权重写 |
| 5 | AI 特征表内联进两个文稿技能 | AI 特征表是核心方法论，抽成跨技能文件会导致读不到即失效；代价是两处需同步维护 |
| 6 | 项目文档体系按「8 个位置各回答一个问题」组织 | 让「这条内容该写哪」成为查表动作而非判断题 |
| 7 | 修复 bug 并入开发闭环 | 修复不是独立任务，是开发的一部分；根因定位独立调用、只查不修 |
| 8 | 用户未明确验收则状态只能停在「待验收」 | 禁止以"我已验证过""测试全绿"自行置为「完成」；`evidence` 为空的点不得进入待验收 |
| 9 | Description 铁律 | description 只写"何时触发"，不写"技能做什么" |
| 10 | 反谄媚 + lessismore 内建 | 健康怀疑 + 克制输出，技术诚实优先于迎合 |

## 目录结构

```
myworkflow/
  plugin.json                  # marketplace 发布清单（v5.0.0，声明 18 个技能）
  .claude-plugin/plugin.json   # 运行时发现元数据（v5.0.0）
  README.md
  hooks/
    hooks.json                 # 仅 SessionStart（startup + clear|compact，timeout 15s）
    session-init.sh            # 路由式锚点（5 类任务→skill + 开发阶段链）；子智能体注入协议锚点
    registry-scan.sh           # 专项注册表扫描生成器（幂等，~1s）
  config/
    special-skills.json        # 专项注册表（categories 人工 + inventory 自动）
  skills/                      # 18 个技能，每技能一个 SKILL.md
    task-router/               # 任务分类入口（速查表）
    agent-dev-loop/            # 智能体闭环开发（含开工门禁与 bug 修复路径）
      references/testing-anti-patterns.md
    write-prose/               # 文稿写作
      references/style-profiles.md
    polish-prose/              # 文稿润色
      references/before-after-zh.md
    deep-research/             # 深度调研（多文件结构化，落盘 docs/research/）
    root-cause-analysis/       # 根因定位与全面排查
      references/condition-based-waiting.md
      references/defense-in-depth.md
    real-world-verify/         # 真实验证（强制门禁）
    github-collab/             # Github协作
    project-init/              # 项目文档初始化
    project-maintain/          # 项目工作维护
    registry-maintain/         # 专项注册表维护
    req-clarify/               # 需求澄清
    anti-sycophancy/           # 反谄媚
    lessismore/                # 少即是多（行为准则）
    task-dispatch/             # 任务拆解与派发
    lightweight-dispatch/      # 轻量级派发
    subagent-protocol/         # 子智能体执行协议
    integration-verify/        # 集成验证与修正
```

### 项目文档体系（由 project-init / project-maintain 落地到目标项目）

```
<项目根>/
├── CLAUDE.md           # 怎么工作（规则）
├── STRUCTURE.md        # 东西在哪（地图）
└── docs/
    ├── GOAL.md         # 为什么做（仅用户批准可改）
    ├── STATE.md        # 现在在哪（刷新式）
    ├── PROGRESS.md     # 做了什么（追加式，条目区 + 版本记录区）
    ├── design/         # 做什么（需求与设计）+ index.json
    ├── information/    # 学到了什么（经验条目）+ index.json
    ├── research/       # 外部世界怎么说（deep-research 落盘）
    └── other/          # 兜底，严格准入
```

## 技术细节

- **Hook**：单一 `SessionStart` 事件，在 `startup` 和 `clear|compact` 时触发，timeout 15s。
- **注入机制**：`session-init.sh` 主智能体注入一条路由锚点（5 类任务→skill + 开发阶段链）并触发注册表刷新；子智能体环境（`CLAUDE_AGENT_TASK_ID`/`AGENT_MODE`/`SUBAGENT`）注入一行协议锚点，不扫描注册表。
- **专项注册表**：`registry-scan.sh` 每次 SessionStart 自动刷新 `config/special-skills.json` 的 `inventory`（只扫已注册插件，保真）；`categories` 由 `registry-maintain` 人工维护，聚焦分类。
- **技能格式**：每个技能为独立目录，含 `SKILL.md`（YAML frontmatter + Markdown 正文），frontmatter 无 BOM。
- **发现机制**：`installed_plugins.json` + `enabledPlugins@local`，不依赖 `~/.claude/skills/` symlink/junction。
- **跨 skill 引用**：myworkflow 内部统一 `myworkflow:` 前缀（如 `Skill("myworkflow:task-dispatch")`）；跨插件引用写作 `myworkflow-extra:<slug>`。
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
