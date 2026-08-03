# MyWorkflow — 开发进度速查

> 最后更新：2026-08-04

---

## 2026-08-04

- **[Release] v3.1 → v4.0.0** —— v3（c9ebaa3 拆钩子扁平版）固化到 GitHub 独立 `v3` 分支；master 升 v4（阶段感知锚点 + 注册表触发词修复）

- **[Fix] 后半程技能触发概率下降** —— v3 拆掉 UserPromptSubmit/PostToolUse 执行期强制后，只剩入口期软提示，非入口/后半程 skill（root-cause、real-world-verify、github-collab 等）不触发
  - 根因三连：(1) 锚点"没有匹配的 skill 就自己完成"= 放行跳过；(2) 5 类分类只覆盖入口、无阶段概念；(3) 注册表触发词被 120 字截断（real-world-verify 截在"确"、storage-analyzer 为字面 ">"）
  - [Fix] 锚点改阶段感知：阶段3 bug→root-cause-analysis、子任务完成→integration-verify、阶段4→real-world-verify、提交→github-collab、润色→humanizer-zh；删除放行授权
  - [Fix] registry-scan.sh：YAML 折叠块标量解析 + 去掉 120 字截断（trigger 存完整描述）
  - 结果：inventory 39 项零截断零占位符；不加钩子，保持 v3 无仪式

- **[Cleanup] 注册表严格化：仅扫已注册插件**
  - 根因：registry-scan.sh 全量 os.walk plugins/ 根，把 marketplaces/ 克隆里 30 个从未安装的官方插件 SKILL.md 也扫进 inventory（66 项，多数不认识的技能）
  - [Fix] 改为读 installed_plugins.json 的 installPath 逐项扫描；清理 categories 中 28 个死 slug / 5 个空分类
  - 结果：inventory 66→39（myworkflow 22 / webnovel 9 / microsoft-docs 3 / large-project 2 / 其余 3），9 类 categories、25 slug、零死链

- **[Build] v3.1 专项注册表 + 架构演进实现（细化方案 v2 全量落地）**
  - 专项注册表：`hooks/registry-scan.sh` 扫描已注册插件生成 `config/special-skills.json`（inventory 自动 + categories 人工），SessionStart 自动刷新；`registry-maintain` skill 维护分类
  - 分类 hook：session-init.sh 注入 5 类概念锚点（~200 字）；子智能体上下文反转注入一行协议锚点
  - 架构：bug-fix-verify 删除，修复并入 agent-dev-loop（发现 bug→root-cause 定位→修复→真实验证）；root-cause 426→98 行、agent-dev-loop 173→~100 行（方法密度优先，删模板）
  - 新专项：lessismore（行为准则）、storage-analyzer（卡兹克电脑清理适配，Windows 实测通过）、file-organize（电脑整理）
  - task-router 压至极简速查（14 行）；注册表 66 技能 / 22 myworkflow 技能 / 零死链 / JSON 全合法

## 2026-08-02

- **[Refactor] v3 扁平化轻量重构（更换 deepseek-v4-flash 后全面瘦身）**
  - [Diagnosis] 根因：22/27 SKILL.md 带 UTF-8 BOM → YAML frontmatter 解析失败 → 技能未注册 → `Skill("myworkflow:xxx")` 调用失败（router 失灵硬故障）；SessionStart 注入 16KB 五分类仪式 → 上下文耗尽 → 后半段放弃访问新 skill；三插件撞名（网文/大项目）→ 注册被丢弃；hook 脚本带 BOM → 间歇性失败
  - [Fix] 全插件去 BOM：myworkflow 26 文件 + webnovel-studio 9 文件 + hook 脚本
  - [Migration] 9 网文技能 + tools 迁出 myworkflow → webnovel-studio 成为唯一归属（去 BOM、路径自洽）
  - [Refactor] 重型 hook 拆除：删 UserPromptSubmit 硬路由 + PostToolUse 唠叨；SessionStart 注入 16KB → ~70 字
  - [Refactor] 19 技能瘦身 7642 → 3353 行（-56%）：保留全部功能门禁（多轮需求澄清、dev-loop 主线「需求→设计→开发→检测→自循环」、检测通过才能出循环、大项目维护全功能）；跨文件必须派发子智能体；P2 必须修复不留漏洞
  - [Fix] plugin.json → v3.0.0，skills 数组补全（pdf-to-markdown/self-study-guide）
  - ⚠️ 待办：需重启 Claude Code 生效（BOM 修复后技能才能注册）；git 变更未提交（34 文件，+1319/-11826）

## 2026-07-27

- **[Diagnosis] 触发链路全量自查** —— 用户要求验证 myworkflow 是否能正常触发
  - 验证三层防线全部正常：SessionStart ✅ | UserPromptSubmit ✅ | PostToolUse ✅
  - 26 个 skill 全部有 SKILL.md/skill.md，task-router → 下游路由 8 条链路无断裂
  - 发现 4 个低严重度问题：(1) plugin.json skills 数组缺 9 个条目 (2) 具体写作/skill.md 含 UTF-8 BOM (3) skills/tools/ 非 skill 目录 (4) post-tool-use.sh flag 文件跨 session 共享
  - 结论：触发链路畅通，能正常运行

## 2026-07-26

- **[Fix] Skill 触发可靠性四层加固** —— 解决 LLM 不主动调用 Skill() 和跨 skill 引用失败问题
  - **F3**: 修复 `extract_triggers()` 和 `short_desc()` 中 `cut -c` 导致的 UTF-8 编码截断（��乱码），移除所有不安全的字节截断
  - **F1**: 重写 session-init.sh 注入指令——所有 `Skill("name")` → `Skill("myworkflow:name")` + `🚨 必须使用 Skill 工具调用` 强制语言 + 响应前强制自检清单（3 问：是否调了 Skill？是否跳过澄清？是否真的用了工具？）
  - **F2**: 新增 `PostToolUse` hook（`post-tool-use.sh`）——执行期兜底：路由 skill 加载后检测下游 Skill() 调用，≥3 次非 Skill 工具调用后注入提醒。注册到 hooks.json
  - **F5**: 增强 `UserPromptSubmit` 关键词覆盖——扩展代码编写/文稿撰写/深度调研三类匹配模式，收缩单字模糊匹配，减少假阳性
  - **未执行**: 联结重建（`~/.claude/skills/` → `plugins/` junctions）→ 记录到 memory，留待后续根因调查

## 2026-07-25

- [Enhance] **深度调研 skill：强制生成本地 .md 报告** —— 落盘从建议升级为硬门禁，新增前置强制步骤 + 阶段 4 落盘规范 + 对话摘要模板

## 2026-07-22（第四次）

- [Refactor] **内部 skill 交叉引用迁移至 myworkflow: 前缀** —— 10 处 Skill() 调用 + 100+ 处文本引用，覆盖 15 个非写作 skill 文件，已推送至 GitHub

## 2026-07-22（第三次）

- [Perf] **session-init.sh 启动性能优化** —— 新窗口斜杠命令卡 27 秒 → 0.25 秒（108×）
  - 根因：每次 SessionStart 扫描 100 个 SKILL.md 文件（649KB），Windows Git Bash 子进程创建开销 1000+ 次累计 27s
  - 修复 1：`extract_triggers()` 中 `cat "$skill_file"` → `head -30`（触发词都在第 3 行 frontmatter，无需读全文）
  - 修复 2：**缓存机制**——首次扫描后缓存到 `.cache/injection.txt`，后续启动仅检查 mtime，命中即直接输出
  - 缓存自动失效：任意 SKILL.md 的 mtime 新于缓存文件时自动重建
  - 涉及文件：`hooks/session-init.sh`
- [Diagnosis] `.claude.json` 膨胀分析 —— 166KB/4379 行，projects 段占 77%（108KB），64 个项目含 19 僵尸+45 活跃（每项目存 20+ 行 lastSessionMetrics）
- [Diagnosis] `history.jsonl` 膨胀分析 —— 657KB/2450 条，纯 CLI 输入历史积累

## 2026-07-22（第二次）

- [Fix] **skills/ 目录联结丢失修复** —— 三个 `@local` 插件仍然不被发现，`.in_use` 标记全部缺失
  - 根因：07-20 创建的 `~/.claude/skills/` 目录联结全部丢失（`skills/` 变为空目录）
  - 没有联结时 Claude Code 不扫描 `plugins/<name>/`，三个插件的 skills/hooks/agents 全部不可见
  - 修复：重新创建三条目录联结（Junction）：
    ```
    ~/.claude/skills/myworkflow          → ~/.claude/plugins/myworkflow        ✅
    ~/.claude/skills/webnovel-studio     → ~/.claude/plugins/webnovel-studio   ✅
    ~/.claude/skills/large-project-work  → ~/.claude/plugins/large-project-work ✅
    ```
  - 深层对比验证：所有官方插件（code-simplifier/skill-creator/…）都在 `cache/` 下且都有 `.in_use/<PID>` 标记；用户的三个 `@local` 插件始终无 `.in_use`，证实从未被加载
  - 官方文档印证：`llmstxt/code_claude_llms_txt` → 本地插件测试用 `--plugin-dir` flag；永久安装需通过 marketplace 注册或 `~/.claude/skills/` 扫描
  - ⚠️ 仍须重启 Claude Code 新 session 才能生效

## 2026-07-22（第一次）

- [Fix] **插件注册 marketplace 修复** —— `@external` 市场不存在，改为 `@local`；新增 `large-project-work@local` 注册
  - `myworkflow@external` → `myworkflow@local` ✅
  - `webnovel-studio@external` → `webnovel-studio@local` ✅
  - 新增 `large-project-work@local`: true ✅
  - 修改文件：`~/.claude/settings.json` 的 `enabledPlugins`
  - 根因：`external` 不是有效 marketplace，本地插件应使用 `@local`
  - 注意：`large-project-work` 如无 `~/.claude/skills/` 目录联结需参照 07-20 方案补充

## 2026-07-20

- [Fix] **插件发现路径修复** —— Claude Code 不会扫描 `~/.claude/plugins/<name>/`，只识别 `~/.claude/skills/<name>/`（skills-directory）或 marketplace 注册的插件
  - 根因：P0-2（未注册到 `installed_plugins.json`）之前被标记为已知但未实际解决
  - 修复：创建目录联结 `~/.claude/skills/myworkflow` → `~/.claude/plugins/myworkflow`（零空间占用，文件保留原位）
  - 修复前 `claude plugin list` 不显示 myworkflow，所有 skills/hooks 均不被发现
  - 修复后 Claude Code 通过 `~/.claude/skills/` 扫描自动发现插件，skills 和 hooks 都会被加载
  - 注意：需要重启 Claude Code 新 session 才能生效
  - ⚠️ 待验证：插件 skills 以 `myworkflow:技能名` 命名空间注册，session-init.sh 中写的是裸名 `Skill("任务分类入口")`，可能需改为 `Skill("myworkflow:task-router")`。部分技能（大项目初始化等）在 `~/.claude/skills/` 有直接副本可走老路径，但仅插件独有的技能（任务分类入口、Github协作、需求澄清、任务拆解与派发、辅助写技能、集成验证与修正、轻量级派发、子智能体执行协议、反谄媚）需验证裸名是否能正常调用

## 2026-07-15

- [Fix] 技能触发稳定性全量修复（P0-1~P2-2），4 子智能体并行执行
  - Agent A: 插件格式迁移 → `.claude-plugin/plugin.json` 标准格式
  - Agent B: 新增 `UserPromptSubmit` Hook 做关键词硬路由
  - Agent C: `session-init.sh` 增强——触发词提取 + 注意力锚点 + 周期性自检 + compact 重注入
  - Agent D: `session-init.sh` 加固——SUBAGENT-STOP 三层检测 + Windows 路径验证 + 大小写兼容 + 输出验证
- [Verify] 全量集成验证通过：bash 语法 ✅ | 关键词匹配 ✅ | 触发词提取 ✅ | reset 模式 ✅

## 2026-07-13

- [Build] GitHub 仓库准备：git init + 中文 README + .gitignore（待 push）
- [Build] 插件整理：plugin.json + 清理 superpowers 全体系至 D:\临时
- [Change] Superpowers Tier 1+2 全量吸收（7 skill + 4 参考文件）+ 全量审计 P0/P1 清零
- [Change] Round 1 审计修复：15 P0 + 22 P1 全部修复（Bug修复与验证、大项目工作维护、轻量级派发、反谄媚、humanizer-zh、任务拆解与派发、hooks、session-init.sh、README.md）
- [Audit] 全量审计 Round 1（4 子智能体并行，73 问题）→ Round 1 修复清零 → Round 2 验证通过

## 2026-07-13（前续）

- [Audit] 第 3 轮重审 → 零 P0/P1
- [Audit] 第 3 轮修复（5 P1 + 3 description P1）
- [Audit] 第 2 轮重审 → 5 P1
- [Audit] 第 2 轮修复（12 P1）
- [Audit] 审计模式自动循环机制加固
- [Audit] 第 1 轮修复（8 P0 + 15 P1）
- [Audit] 第 1 轮审计（4 子智能体并行）→ 发现 ~93 问题
- [Change] 闭环开发 skill 清理 superpowers 引用
- [New Feature] Github协作 skill（P2-1 落地）
- [New Feature] 辅助写技能 skill
- [New Feature] 深度调研 skill
- [Change] 删除 10 个 superpowers 复刻 skills
- [New Feature] 反谄媚 skill（anti-sycophancy）
- [New Feature] 轻量级派发 skill
- [Change] 融合测试方案（TDD → 真实验证）
- [Change] 确认任务拆解体系保留
- [New Feature] 需求调查 skill v3
- [Change] Bug 修复 skill 重构
- [Change] Bug 排查 skill 升级
- [Design] 11 问题综合分析报告 → 用户评审 → 修订
- [Design] Superpowers 全量能力对比分析
- [Build] 复制 15 个传递依赖 skills
- [Build] 深度依赖分析（4 子智能体并行）
- [Build] 复制核心 skills
- [Change] 需求澄清 skill → v3 统一步骤 2
- [Change] 任务分类入口 skill → v2 三步工作流
- [Change] session-init.sh → v2 五分类注入 + skill 扫描
- [Change] Hook 层精简为单一 SessionStart
- [Change] 清理 v1 遗留（flags/lib/state/classify-task.sh）
- [Design] v2 五分类体系
- [Research] Hook 四问
- [Research] Claude Code Hooks 能力分析
- [Research] Superpowers 插件完整分析
- [Research] 智能体闭环开发调用困难根因
