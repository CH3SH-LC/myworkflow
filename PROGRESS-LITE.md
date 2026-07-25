# MyWorkflow — 开发进度速查

> 最后更新：2026-07-22

---

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
  - ⚠️ 待验证：插件 skills 以 `myworkflow:技能名` 命名空间注册，session-init.sh 中写的是裸名 `Skill("任务分类入口")`，可能需改为 `Skill("myworkflow:任务分类入口")`。部分技能（大项目初始化等）在 `~/.claude/skills/` 有直接副本可走老路径，但仅插件独有的技能（任务分类入口、Github协作、需求澄清、任务拆解与派发、辅助写技能、集成验证与修正、轻量级派发、子智能体执行协议、反谄媚）需验证裸名是否能正常调用

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
