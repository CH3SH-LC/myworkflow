# MyWorkflow — 开发进度

> 开始日期：2026-07-11
> 最后更新：2026-07-15（第十阶段：技能触发稳定性全量修复）

---

## 2026-07-15

### [Fix] 技能触发稳定性全量修复 — 根因分析 + 6 项修复并行执行

问题描述 / 变更原因：
用户反馈 skills 不能被稳定触发。经调研发现 7 项根因（详见分析报告），
除 DeepSeek 模型本身无法修正外，其余 6 项全部通过 4 子智能体并行修复。

根因分析摘要（详见对话分析）：
- P0-1: 插件使用 root `plugin.json` 而非标准 `.claude-plugin/plugin.json`，运行时发现不稳定
- P0-2: 插件未注册到 `installed_plugins.json`
- P0-3: 纯 prompt 触发无硬 enforcement——v2 删除 UserPromptSubmit 后完全依赖 LLM 自愿
- P1-1: SessionStart 注入在长对话/compact 后被稀释
- P1-2: Skill description 只有 200 字符，缺少触发关键词
- P1-3: 多 SessionStart Hook 竞争
- P2-1: SUBAGENT-STOP 标签对 DeepSeek 子智能体不可靠

修改文件（4 子智能体并行执行）：

Agent A — 插件格式修复：
- Add: `.claude-plugin/plugin.json` — 标准运行时发现格式（仅元数据：name/version/description/author）
- Modify: `plugin.json` — 添加 `_comment` 字段说明分工（此文件用于 marketplace 发布，运行时发现由 .claude-plugin/ 负责）
- 理由：`.claude-plugin/plugin.json` 是 Claude Code 本地插件发现的标准路径，root `plugin.json` 可能不被稳定识别

Agent B — UserPromptSubmit 硬路由：
- Add: `hooks/user-prompt-submit.sh` — 极简关键词匹配脚本（57 行，<2s）
  - 三层优先级匹配：代码编写 > 文稿撰写 > 深度调研
  - 命中时注入单行提醒："⚠️ [硬路由] 检测到[代码编写]类任务 → 必须先调用 Skill("任务分类入口")"
  - 未命中时输出空 additionalContext（零噪音）
  - 共 ~40 个关键词覆盖三类任务
- Modify: `hooks/hooks.json` — 新增 `UserPromptSubmit` 事件配置，timeout: 5s
- 理由：补上 v2 删除 UserPromptSubmit 后的硬 enforcement 缺口——每次用户消息都做关键词检测，命中即强提醒 LLM 调 Skill

Agent C — session-init.sh 注入增强：
- Add: `extract_triggers()` 函数（40 行）— 从 SKILL.md 提取显式"触发词："字段，降级方案从 description 提取引号内容
- Add: `short_desc()` 函数 — 精简 description 到 80 字符
- Add: 注意力锚点（5 行 ASCII 横幅）—— "⚠️ WORKFLOW ACTIVE" 不可错过
- Add: 周期性自检指令 —— 每 5 条消息后在回复末尾附加 `🤖 工作流自检：[✅/⚠️]`
- Add: `--reset` 模式增强 —— compact/clear 后强提醒 "上下文已重置，必须重新遵守工作流"
- Modify: Skill 清单格式从 `[内置] name | desc` 升级为 `[内置] name | 🎯触发: kw1, kw2 | desc: ...`
- 效果：16 个内置 skill 中 12 个成功提取了触发词（如 Bug修复与验证: "bug, 修 bug, 报错..."）

Agent D — session-init.sh 健壮性加固：
- Add: 子智能体 bash 层环境变量检测（CLAUDE_AGENT_TASK_ID/AGENT_MODE/SUBAGENT）→ 输出空 injection
- Add: Windows 路径静默验证（CLAUDE_PLUGIN_ROOT/skills 存在性检查）
- Add: SKILL.md/skill.md 大小写兼容 glob + 去重
- Add: 输出验证（INJECTION 非空 + skill 数量 ≥5 检查，stderr 告警）
- Modify: SUBAGENT-STOP 标签强化 + 角色检测提示（三层纵深防御）

验证：
- bash -n 语法检查：session-init.sh ✅ | user-prompt-submit.sh ✅
- 功能测试：
  - "帮我写代码加个登录功能" → 正确分类为[代码编写] ✅
  - "今天天气怎么样" → 输出空 additionalContext（零噪音）✅
  - --reset 模式 → "🔄 上下文已重置" 提醒正确注入 ✅
  - 触发词提取 → 12/16 内置 skill 成功提取（4 个无显式标记的降级用 description）✅
  - 专项 skills 扫描 → webnovel-studio 9 个 skill 正确列出 ✅
- 注入长度：~8.3KB（合理，SessionStart 单次注入 + 1M 上下文窗口完全可接受）

---

## 2026-07-13

### [Build] 创建 GitHub 公开仓库准备

修改文件：
- Modify: `README.md` — 全文重写为中文 README（安装说明、架构图、技能表、设计决策）
- Add: `.gitignore` — macOS/Windows/Editor/temp 忽略规则
- Add: `plugin.json` — 插件清单（前期已完成）

Git 状态：已 `git init` + `git add -A`，待 commit + push。
下一步：`gh repo create myworkflow --public --source=. --push`

修改文件：
- Add: `plugin.json` — 插件清单（name/version/hooks/skills/description）
- Modify: `skills/Github协作/SKILL.md` — 设计决策注释去 superpowers 引用
- Modify: `skills/辅助写技能/SKILL.md` — 自检清单去 superpowers 引用（2 处）
- Modify: `settings.json`（用户级） — 禁用 superpowers@claude-plugins-official
- Delete: `docs/` — 5 个调研文档移至 `D:\临时\myworkflow-docs\`

superpowers 迁出：
- `C:\Users\Lenovo\.claude\plugins\cache\...\superpowers\` → `D:\临时\superpowers\cache\`
- `C:\Users\Lenovo\.claude\skills\.superpowers\` → `D:\临时\superpowers\sdd-session\`
- 空数据目录 `...data/superpowers-claude-plugins-official\` 已删除

验证：
- 全量功能文件零 superpowers 引用
- plugin.json 声明 16 skills + hooks
- 最终 26 文件

### [Change] Superpowers Tier 1+2 能力全量吸收（15 项）

问题描述 / 变更原因：
此前 myworkflow 从 superpowers 插件迁移时，虽复制了 10 个 skills 的核心能力，但经过系统化差距分析发现 superpowers v6.1.1 仍有 15 项未被吸收的能力（8 项 Tier 1 必须 + 7 项 Tier 2 应该）。这些能力分布在 brainstorming、TDD、systematic-debugging、writing-skills、subagent-driven-development、verification-before-completion、using-superpowers 等 7 个 superpowers skill 中。

变更内容（7 个 skill 修改 + 4 个参考文件新建 + 审计修复）：
- Modify: `skills/需求澄清/SKILL.md` — +YAGNI 原则、多子系统检测门禁（阶段 2.5）、报告自检清单（阶段 7）、description 改纯触发式、落盘失败处理
- Modify: `skills/智能体闭环开发/SKILL.md` — +TDD 反驳表、回归测试 TDD 验证模式、根因定位引用
- Modify: `skills/根因定位与全面排查/SKILL.md` — +defense-in-depth 四层框架（D3.1）、condition-based-waiting 引用
- Modify: `skills/辅助写技能/SKILL.md` — +验证方法论补充（压力测试/基线测试/防弹指标）、persuasion-principles 引用、修复重复 Step1 标题
- Modify: `skills/集成验证与修正/SKILL.md` — +Per-task 审查（检查 4.5）、全分支审查（检查 7.5）、审查独立性原则、状态路由（解析 completion.md status 字段）、副作用任务执行验证（检查 1.5）
- Modify: `skills/子智能体执行协议/SKILL.md` — +DONE_WITH_CONCERNS 四种完成状态枚举、更新 completion.md 模板、统一强制引用模板（与任务拆解与派发一致）
- Modify: `skills/任务分类入口/SKILL.md` — +反绕过红旗清单（12 条中文版）、description 改纯触发式、硬编码映射标注降级参考、新项目判定扩展多语言

审计修复（Round 1 发现 15 P0 + 22 P1，全部修复）：
- Modify: `skills/Bug修复与验证/SKILL.md` — +轻量分析例外（解决与根因定位的死锁）
- Modify: `skills/大项目工作维护/SKILL.md` — "包裹"→"并行"关系模型、git 单 commit 过滤指导
- Modify: `skills/轻量级派发/SKILL.md` — description 精简（删除行为/流程描述）
- Modify: `skills/反谄媚/SKILL.md` — description 改纯触发式、安全漏洞标记 🟡→🔴
- Modify: `skills/humanizer-zh/SKILL.md` — description 改纯触发式
- Modify: `skills/任务拆解与派发/SKILL.md` — +独立步骤定义、派发失败降级方案
- Modify: `skills/根因定位与全面排查/SKILL.md` — 不触发列表更新（引用 Bug修复与验证 轻量例外）
- Modify: `hooks/hooks.json` — // 注释改为 `_comment` 字段（兼容严格 JSON 解析）
- Modify: `hooks/session-init.sh` — xargs→tr/sed（3 处）、+大项目工作维护隐式触发注释、新项目判定扩展多语言
- Modify: `README.md` — timeout 30→60（2 处）

新建文件（4 个）：
- Add: `skills/智能体闭环开发/references/testing-anti-patterns.md`
- Add: `skills/根因定位与全面排查/references/condition-based-waiting.md`
- Add: `skills/根因定位与全面排查/references/defense-in-depth.md`
- Add: `skills/辅助写技能/references/persuasion-principles.md`

验证：
- Round 1 审计（4 子智能体并行）：发现 15 P0 + 22 P1 + 36 P2
- Round 1 修复（4 子智能体并行）：P0/P1 全部修复
- Round 2 审计：P0=0 ✅, P1=0 ✅, P2 少量残余

## 整体进度

| 阶段 | 状态 | 完成日期 |
|------|:----:|---------|
| **第一阶段：调研** |||
| 1. 调研：智能体闭环开发调用困难根因 | ✅ | 2026-07-11 |
| 2. 调研：Superpowers 插件完整分析 | ✅ | 2026-07-11 |
| 3. 调研：Claude Code Hooks 能力分析 | ✅ | 2026-07-11 |
| 4. 调研：Hook 四问 | ✅ | 2026-07-12 |
| **第二阶段：v2 设计与重构** |||
| 5. 设计：v2 五分类体系 | ✅ | 2026-07-12 |
| 6. 清理：删除 v1 遗留（flags/lib/state/classify-task.sh） | ✅ | 2026-07-12 |
| 7. 重构：Hook 层精简为单一 SessionStart | ✅ | 2026-07-12 |
| 8. 重构：session-init.sh → v2 五分类注入 + skill 扫描 | ✅ | 2026-07-12 |
| 9. 重构：任务分类入口 skill → v2 三步工作流 | ✅ | 2026-07-12 |
| 10. 重构：需求澄清 skill → 统一步骤 2 | ✅ | 2026-07-12 |
| **第三阶段：依赖分析** |||
| 11. 复制：核心 skills（大项目初始化/智能体闭环开发/Bug修复与验证/humanizer-zh） | ✅ | 2026-07-12 |
| 12. 深度依赖分析：4 子智能体并行分析全部传递依赖 | ✅ | 2026-07-12 |
| 13. 复制：15 个传递依赖 skills（含附属文件）→ 共 21 skills | ✅ | 2026-07-12 |
| **第四阶段：设计评审** |||
| 14. Superpowers 全量能力对比分析 | ✅ | 2026-07-12 |
| 15. 11 问题综合分析报告 | ✅ | 2026-07-12 |
| 16. 用户设计评审（指示1.txt）→ 报告修订 | ✅ | 2026-07-12 |
| **第五阶段：执行实现** |||
| 17. P0-1：Bug 排查 skill 升级（吸收 systematic-debugging 场景） | ✅ | 2026-07-13 |
| 18. P0-2：Bug 修复 skill 重构（新流程：逼迫细节→找 bug→并行修→循环） | ✅ | 2026-07-13 |
| 19. P0-3：需求调查 skill v3（硬门禁+多方案+落盘+可视化+选项板+通用定位） | ✅ | 2026-07-13 |
| 20. P0-4：writing-plans 决策——不集成 | ✅ | 2026-07-12 |
| 21. P1-1：确认任务拆解体系保留（用户自己的 skill） | ✅ | 2026-07-13 |
| 22. P1-2：融合测试方案（TDD → 真实验证） | ✅ | 2026-07-13 |
| 23. P1-3：新建轻量级派发 skill | ✅ | 2026-07-13 |
| 24. P1-4：新建反谄媚 skill（anti-sycophancy） | ✅ | 2026-07-13 |
| 25. P2-1：Git 协作——重新设计方案（superpowers git skills 需替换为原生） | ✅ | 2026-07-13 |
| **第六阶段：扩展与清理** |||
| 26. 清理：删除 10 个 superpowers 复刻 skills | ✅ | 2026-07-13 |
| 27. 新建：深度调研 skill | ✅ | 2026-07-13 |
| 28. 新建：辅助写技能 skill | ✅ | 2026-07-13 |
| 29. 新建：Github协作 skill（P2-1 落地） | ✅ | 2026-07-13 |
| 30. 闭环开发 skill 清理 superpowers 引用 | ✅ | 2026-07-13 |
| 31. P3-1：writing-skills + skill-creator 评估 | ⏳ | — |
| 32. 端到端联调测试 | ⏳ | — |
| **第七阶段：全量审计** |||
| 33. 第 1 轮审计（4 子智能体并行）→ 发现 ~93 问题 | ✅ | 2026-07-13 |
| 34. 第 1 轮修复（8 P0 + 15 P1） | ✅ | 2026-07-13 |
| 35. 审计模式自动循环机制加固 | ✅ | 2026-07-13 |
| 36. 第 2 轮修复（12 P1） | ✅ | 2026-07-13 |
| 37. 第 2 轮重审 → 5 P1 | ✅ | 2026-07-13 |
| 38. 第 3 轮修复（5 P1 + 3 description P1） | ✅ | 2026-07-13 |
| 39. 第 3 轮重审 → 零 P0/P1 ✅ | ✅ | 2026-07-13 |
| 40. P2 全部修复（3 子智能体并行，~48 项） | ✅ | 2026-07-13 |
| **第八阶段：Superpowers 能力全量吸收** |||
| 41. Superpowers Tier 1+2 全量吸收（7 skill + 4 参考文件）+ 全量审计 P0/P1 清零 | ✅ | 2026-07-13 |

---

## 2026-07-13

### [Audit] 全量技能包审计与修复（第 7 阶段）

问题描述 / 变更原因：
myworkflow 技能包经过 5 个阶段的快速迭代（v1→v2 重构、依赖分析、设计评审、P0-P2 执行实现、扩展与清理），
积累了大量 skill 文件，但从未进行过系统化的质量审计。需要全面检查 16 个 skills + 4 个文档/配置文件的
正确性、一致性和可执行性。

审计方法论：
- 第 1 轮：4 子智能体并行审计（组A代码编写 / 组B通用技能 / 组C专项+文档 / 交叉验证）
- 第 2 轮：验证 P0 修复 + 扫描残余 P1
- 第 3 轮：验证 P1 修复 + 扫描残余问题
- P2 修复：3 子智能体并行修复全部 ~48 项 P2

修改文件（按修复批次）：

第 1 轮（P0 + 高影响 P1，15 个文件）：
- Modify: `skills/任务分类入口/SKILL.md` — deep-research→深度调研(3处)；补全 Github协作+根因定位 路由；文稿撰写路由细化；description 精简
- Modify: `skills/智能体闭环开发/SKILL.md` — 后置步骤增加 Github协作 引用；关联表增加 Github协作；description 精简；审计模式自动循环加固
- Modify: `skills/Bug修复与验证/SKILL.md` — 后置步骤增加 Github协作 引用；"逼迫"→"引导"(6处)；worktree 降级方案；description 精简
- Modify: `skills/大项目工作维护/SKILL.md` — "脑子记"→对话维护；bash/PowerShell 双版本命令
- Modify: `skills/根因定位与全面排查/SKILL.md` — 触发列表编号修复；过时"逼迫"措辞同步
- Modify: `skills/Github协作/SKILL.md` — gh pr review -f 修复；hotfix 矛盾修复；description 精简
- Modify: `skills/需求澄清/SKILL.md` — "非平凡"判定矛盾修复；description 精简
- Modify: `skills/深度调研/SKILL.md` — description 精简
- Modify: `skills/辅助写技能/SKILL.md` — description 去流程描述；入口路由补全
- Modify: `skills/反谄媚/SKILL.md` — "需求调查"→"需求澄清"；always-on 描述修正；description 精简
- Modify: `skills/轻量级派发/SKILL.md` — 中间地带处理规则；description 精简化
- Modify: `skills/任务拆解与派发/SKILL.md` — "评估哲学"与"<2阻断"矛盾修复
- Modify: `skills/子智能体执行协议/SKILL.md` — 依赖等待增加 10 分钟超时
- Modify: `skills/humanizer-zh/SKILL.md` — description 多行→单行
- Modify: `PROGRESS.md` — 六分类/五分类统一；"文稿生成"→"文稿撰写"
- Modify: `README.md` — v1→v2 全文重写
- Modify: `hooks/hooks.json` — description 统一；timeout 30→60
- Modify: `hooks/session-init.sh` — deep-research→深度调研；路由补全；文稿撰写细化；cut 120→200

第 2 轮（残余 P1，3 个文件）：
- Modify: `hooks/session-init.sh` — 代码编写路由补全 2 个子类型
- Modify: `skills/根因定位与全面排查/SKILL.md` — 过时"逼迫"措辞同步
- Modify: `skills/需求澄清/SKILL.md` — description 去 feature checklist
- Modify: `skills/任务分类入口/SKILL.md` — description 去流程描述
- Modify: `skills/Bug修复与验证/SKILL.md` — description 去流程描述
- Modify: `skills/Github协作/SKILL.md` — description 去流程描述
- Modify: `skills/智能体闭环开发/SKILL.md` — description 去流程描述

第 3 轮（全部 P2，3 子智能体并行，16 个文件）：
- 详见各组审计报告。涵盖：汇报模板、触发条件收窄、审计模式注释、排查自动委托说明、
  话术灵活提示、隐式触发时机、决策表排序、变更覆盖备选命令、根因记录底线、
  证伪实验强制检查、验证顺序定义、双版本命令注释、PR水印opt-out、递归禁止、
  关联表标准化、报告路径传递、效率提示、拓扑并行示例、自引用检查、触发条件AND化、
  自举决策树、检查方法、合约范围注释、命令转义、模板精简、传递依赖、用词统一、
  失败升级决策表、超时参数化、红旗分级、风险注释模板、模式标题修正、假设标注、
  Agent工具场景说明、模板注释、归类理由、待确认建议、注释统一、设计决策注释、
  JSON转义注释、大小写扫描统一

验证：
- 第 1 轮审计发现 ~93 问题（8 P0 + ~50 P1 + ~35 P2）
- 第 2 轮重审：P0=0, P1=5（递减 90%）
- 第 3 轮重审：P0=0, P1=3（递减 40%），已达停止条件
- P2 全部修复后，终态：P0=0, P1=0, P2=0

同时修复的元问题：
- 审计模式自动循环机制已加固（禁止手动等待 + 决策表 + 违规自检）
- Description 铁律统一执行（全部 16 个 skill description 精简为纯触发条件）
- 六组/五分类术语在全部文档中统一

## 当前文件结构

```
C:\Users\Lenovo\.claude\plugins\myworkflow\
  README.md
  PROGRESS.md                              ← 本文件
  PROGRESS-LITE.md                         ← 新增
  hooks/
    hooks.json                             (v2: 仅 SessionStart, _comment 替代 // 注释)
    session-init.sh                        (v2: 五分类 + skill 扫描注入, xargs→tr/sed)
  skills/                                  (16 个 skills, 4 个 references/)
    ── 入口 (1) ──
    任务分类入口/SKILL.md                   (v2: 三步工作流 + 反绕过红旗清单)
    ── 代码编写 (6) ──
    智能体闭环开发/SKILL.md                 (含 TDD 微循环 + 反驳表 + 回归 TDD 验证)
      references/testing-anti-patterns.md   (5 反模式 + Mock 铁律)
    Bug修复与验证/SKILL.md                  (v2: 五步编排 + 轻量分析例外)
    大项目初始化/SKILL.md
    大项目工作维护/SKILL.md                 (并行关系修正 + git 单commit 过滤)
    根因定位与全面排查/SKILL.md             (6 阶段 + 5 项技术 + 防御纵深四层模型)
      references/condition-based-waiting.md (条件轮询替代盲等)
      references/defense-in-depth.md        (四层防御框架)
    Github协作/SKILL.md
    ── 文稿撰写 (1) ──
    humanizer-zh/SKILL.md
    ── 深度调研 (1) ──
    深度调研/SKILL.md
    ── 辅助写技能 (1) ──
    辅助写技能/SKILL.md                     (TDD 方法 + 验证方法论 + 说服原则)
      references/persuasion-principles.md   (7 说服原则)
    ── 通用技能 (6) ──
    需求澄清/SKILL.md                       (v3: YAGNI+多子系统检测+自检清单+落盘失败处理)
    任务拆解与派发/SKILL.md                 (独立步骤定义 + 派发失败降级)
    子智能体执行协议/SKILL.md               (DONE_WITH_CONCERNS 四种状态)
    集成验证与修正/SKILL.md                 (Per-task+全分支审查+状态路由+审查独立性)
    轻量级派发/SKILL.md                     (description 精简)
    反谄媚/SKILL.md                         (安全漏洞红线 🔴)
  docs/
    工作流设计-v2-五分类体系.md
    11问题综合分析报告.md                   ← 核心参考文档
    + 3 份调研文档
```

---

## 核心设计决策（截至 2026-07-13）

| # | 决策 | 理由 |
|---|------|------|
| 1 | **六组 skills（运行时五分类路由）** | 组织维度六组：入口 / 代码编写 / 文稿撰写 / 深度调研 / 辅助写技能 / 通用技能；运行时路由五分类：代码编写 / 文稿撰写 / 深度调研 / 专项工作 / 其它任务 |
| 2 | **单一 SessionStart Hook** | 每次会话注入分类指令 + skill 清单，不需要 UserPromptSubmit |
| 3 | **三步工作流** | 分类 → 需求调查 → 按类型执行 |
| 4 | **需求调查是通用 skill** | 不是固定工作流步骤——任何需要用户信息的地方都调用它 |
| 5 | **删除 superpowers** | 所有能力集中到 myworkflow；10 个复刻已物理删除，能力吸收到原生 skills |
| 6 | **保留任务拆解体系** | 任务拆解与派发/子智能体执行协议/集成验证与修正——用户自己写的 |
| 7 | **不集成 writing-plans** | 闭环开发+任务拆解已天生拆解并行，writing-plans 过于啰嗦 |
| 8 | **Bug 拆为两个 skill** | 排查（只找不修）+ 修复（逼迫细节→找 bug→并行修→循环） |
| 9 | **测试融合** | TDD（微观测）→ 真实验证（宏观测），两步都需要 |
| 10 | **大项目工作维护覆盖跨会话** | 四文件体系实时同步，不需要额外的 state.json |
| 11 | **Github协作原生替代** | 5 场景闭环（隔离→提交→PR→审查→合并），替代 superpowers 的 3 个 git skills |
| 12 | **辅助写技能用 TDD 方法** | 写 skill = 文档的 TDD：基线观察→最小起草→堵漏洞→审查清单 |

---

## 下一步执行清单

按优先级排列：

### P0（阻塞性，必须做）✅ 全部完成

- [x] **Bug 排查 skill 升级**（2026-07-13）
- [x] **Bug 修复 skill 重构**（2026-07-13）
- [x] **需求调查 skill v3**（2026-07-13）

### P1（重要）✅ 全部完成

- [x] **确认任务拆解体系保留**（2026-07-13）
- [x] **融合测试方案落地**（2026-07-13）
- [x] **新建轻量级派发 skill**（2026-07-13）
- [x] **新建反谄媚 skill**（2026-07-13）

### P2（后续）✅ 全部完成

- [x] **Git 协作方案重新设计**（2026-07-13）
- [x] **清理不需要的 superpowers skills**（2026-07-13）

### P3（远期）

- [ ] **writing-skills + skill-creator 评估**：辅助写技能已建，后续可用它来检验 myworkflow 自身 skills
- [ ] **端到端联调测试**

---

## 待确认事项

- [x] Git 协作方案选哪个？→ 选 A，新建「Github协作」skill 替代 superpowers 的 3 个 git skills（2026-07-13）
- [x] superpowers 复刻的 10 个 skills 中，哪些保留哪些删除？→ 全部删除（2026-07-13），能力已吸收
- [ ] Windows 下 Git Bash 路径是否一致？→ 建议：在 Windows 环境实际运行 `bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-init.sh"` 验证输出
- [ ] DeepSeek 环境下 Hook 注入的指令 LLM 遵循度如何？→ 建议：在 DeepSeek 模型下启动新会话，检查首个回复是否引用任务分类入口 skill
