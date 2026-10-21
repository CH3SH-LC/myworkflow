# Changelog

## v4.0.0 — 2026-10-21

DSH 技能库对齐大版本：18 个技能由 `dsh-myworkflow-skills` 组件统一生成（core + detail parts 拼接，UTF-8 无 BOM）。

### 变更
- 18 个技能同步：frontmatter `name` 来自 `displayName`、`description` 为 `Use when …` 触发语；正文 = core + detail parts。
- 新增 **write-prose（文稿写作）**、**polish-prose（中文成稿润色）** 两个技能；仓库原有 6 个非 DSH 技能（humanizer-zh / pdf-to-markdown / storage-analyzer / file-organize / self-study-guide / skill-authoring）保持不动。
- 新增 **运行时异常处置协议**（5 条）、**诚实汇报门禁**、**task-router / task-dispatch / lightweight-dispatch 三技能边界表**。
- SessionStart 注入精简：31,319 → 29,859 字符；单技能注入 902–1,110 字符。
- 路由回归 44 用例通过。

### 破坏性变更
- 16 个既有技能正文被完整替换为组件化版本（含新增章节）；如本地有基于旧 SKILL.md 的改写，需按 v4 内容重新对齐。
- 根 `plugin.json` 的 `skills` 数组扩到 24 项。

### 验证
- `git ls-remote --tags origin` 含 v4.0.0；`gh release view v4.0.0` 成功。
- 远端 `skills/subagent-protocol/SKILL.md` 含“运行时异常处置”；`skills/task-router/SKILL.md` 含“lightweight-dispatch”边界。
