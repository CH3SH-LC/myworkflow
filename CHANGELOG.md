# Changelog

## v2.1.1 — 2026-10-28

体检整改：修复五路体检（A–E）确认的 F1–F16 问题；不夹带新功能，不改历史 tag 与提交历史。

### 变更
- 判级与拆分（F1–F4、F6–F7）：`task-router` 补「单个交付物但改动 ≥2 文件 → L2」「用户明确指定级别优先」与 L1 判据收紧；`task-dispatch` / `subagent-protocol` 补「审查/汇总/接口文档不是独立交付物」「同一交付物跨轮次串行接力同样违规」；L2→L3 升级判据三技能统一；极端场景（无可用工具、用户坚持阶段拆分、中途重新判级）补指引；清理「prompt 模板」「滚动补位」旧术语。
- 证据口径（F5）：`agent-dev-loop` / `integration-verify` / `root-cause-analysis` / `real-world-verify` 补 produced（回执）/ verified（可复核证据）/ accepted（owner 验收）三层映射与证据最低要求（命令 + exit code + 产物路径/sha256 或 runId）。
- 命名与说明（F8–F10）：`registry-maintain` 示例 slug 修正为 `myworkflow:storage-analyzer`；locale 6 处技能名与 `component.displayName` 对齐；`subagent-protocol` displayName → 「成员与执行者协作协议」；`cordis.patch.yml` 注释引用修正。
- Host 与门禁（F11–F12）：member 段宽度门禁措辞修正（self 执行宽度门禁已关闭、派发宽度守卫仍在）；`.migration/verify-tier-model.mjs` 增加角色段工具极性断言。
- 仓库文档与配置（F13–F15）：CHANGELOG 补 `v2.0.1` 条目；README 安装示例版本与 references 清单补全；`config/special-skills.json` inventory 刷新为 24 技能；hooks 版本/模型口径同步到 2.1.x。
- 仓库 18 个 `skills/*/SKILL.md` 从 components 重新生成（正文 = 组件 `fullBody`，UTF-8 无 BOM、LF）；6 个非 DSH 技能不动；`plugin.json` ×2 版本 → 2.1.1。

### 验证
- `node src/selfcheck.js` PASS；`node .migration/verify-tier-model.mjs --all` PASS；registry 18/18、errors=[]。
- 18 个仓库 `SKILL.md` 正文与组件 `fullBody` 逐字节一致（LF 归一）；CHANGELOG 版本节数量与 release 数量一致。

## v2.1.0 — 2026-10-28

三级协作模型升级：技能内容与 Host 角色提示词统一为 L1 单智能体 / L2 子智能体 / L3 智能体团队三级模型，明确禁止同一交付物的阶段拆分。

### 变更
- 10 个技能正文按三级模型重写：`task-router`（第一步先判工作级别）、`lightweight-dispatch`（L2 操作规程 + 升级 L3 判据）、`task-dispatch`（L3 拆分契约，含禁止阶段接力的正例/反例）、`subagent-protocol`（协作协议：L2 子智能体 + leader/member/leaf 角色）、`agent-dev-loop` / `integration-verify` / `root-cause-analysis` / `deep-research` / `lessismore` / `real-world-verify`（协作表述改为三级模型口径）；保留各技能原有方法论。
- Host 三段角色提示词（`src/host/skills.js` 文本常量）按三级模型重写：leader 只定目标与边界/建团队/下 mission/监督验收，不亲自产出；member 为持久域 owner、端到端完成；leaf 为最小任务包执行者；三段均写明 leader 与 member 可开 leaf、leaf 不可。
- 仓库 18 个 `skills/*/SKILL.md` 从 components 重新生成（正文 = 组件 `fullBody`，UTF-8 无 BOM、LF）；6 个非 DSH 技能保持不动。
- `plugin.json` ×2 版本 → 2.1.0。

### 验证
- `node src/selfcheck.js` PASS；`node .migration/verify-tier-model.mjs` PASS（组件结构 + 三级模型内容断言 + Host 角色段断言 + 版本/registry/注入阈值）。
- 18 个仓库 `SKILL.md` 正文与组件 `fullBody` 逐字节一致（LF 归一）。

## v2.0.1 — 2026-10-28

修复 v2.0.0 发布提交的误删与版本表述问题（普通前进提交，不改写历史、不强推；`v2.0.0` tag 保持原位）。

### 变更
- R5：恢复 v2.0.0（`0ba4099`）误删的 3 个非 DSH references（与 `1b87e72` 原始 blob 逐字节相同）：`skills/skill-authoring/references/persuasion-principles.md`、`skills/storage-analyzer/references/macos.md`、`skills/storage-analyzer/references/windows.md`。
- R6：plugin / hooks / README 的现行版本表述改为 2.0.0 体系；两处 package 版本字段仍为 2.0.0。
- `v2.0.0` 内容零回退：18 个 DSH 技能与 `skills/**` 一个字节未动；v2.0.0..本提交差异仅为上述 3 个恢复文件 + 6 个版本表述修正文件。

### 验证
- GitHub compare `0ba4099...e6f3049` 恰为 9 个文件（3 added references + 6 modified），无其它增删；tag `v2.0.1` → `e6f3049`。

## v2.0.0 — 2026-10-28

回退到 9 月内容后重新发布的正式 2.0：18 个技能正文恢复为 2026-09-17（preview 分支 `787cf78`）的原文，同时保留 DSH 原生组件化与全 core 注入。

### 变更
- 18 个 `skills/<name>/SKILL.md` 重新生成：正文与 `dsh-myworkflow-skills` 组件 `fullBody` 逐字节一致（UTF-8 无 BOM、LF）。
- 注入规则回到「全 core」：所有 parts 显式 `tier: "core"`，`body === fullBody`，不再生成细节索引、不再受 2200 字符预算切分。
- 移除 10 月新增的协作协议与证据门禁正文（横向交付合约 / 事件驱动滚动补位 / 证据与结果分层 / 运行时异常处置协议 / 诚实汇报门禁）。
- Host 侧 v6/v7 门禁关闭（skillTrigger / triage / delegation / memberDomain / commandGate / contextAnchor 均置 false），并删除对应 dev 检查脚本；`src/selfcheck.js` 精简为结构校验。
- write-prose / polish-prose 维持 9 月版正文；仓库原有 6 个非 DSH 技能（humanizer-zh / pdf-to-markdown / storage-analyzer / file-organize / self-study-guide / skill-authoring）保持不动。
- references 与组件对齐：`agent-dev-loop` / `polish-prose` / `root-cause-analysis` / `write-prose` 四个目录；仓库多余 references 目录（skill-authoring / storage-analyzer）删除。

### 验证
- 本地 DSH 包：`node .migration/rebuild-sept.mjs --check --all` → 18/18 PASS。
- 本地 DSH 包：`node .migration/verify-sept.mjs --all` → 18/18 PASS，`REGISTRY.errors = []`。
- 18 个 `SKILL.md` 正文与组件 `fullBody` 逐字节一致（LF 归一）。

### 说明
- 对比 `v2.0.0-preview`（2026-10-21，旧编号 v4.0.0）：该预览内容臃肿、已被判定失败，本版不回滚其 10 月新增协议与门禁。
- 本版不修改 git 提交历史；历史提交信息中的旧版号字样保留原样。

## v2.0.0-preview — 2026-10-21（旧编号 v4.0.0）

> 该预览已被放弃，内容不回滚进正式版。

DSH 技能库对齐大版本：18 个技能由 `dsh-myworkflow-skills` 组件统一生成（core + detail parts 拼接，UTF-8 无 BOM）。

### 变更
- 18 个技能同步：frontmatter `name` 来自 `displayName`、`description` 为 `Use when …` 触发语；正文 = core + detail parts。
- 新增 **write-prose（文稿写作）**、**polish-prose（中文成稿润色）** 两个技能；仓库原有 6 个非 DSH 技能保持不动。
- 新增 **运行时异常处置协议**（5 条）、**诚实汇报门禁**、**task-router / task-dispatch / lightweight-dispatch 三技能边界表**。
- SessionStart 注入精简：31,319 → 29,859 字符；单技能注入 902–1,110 字符。
- 路由回归 44 用例通过。

### 破坏性变更
- 16 个既有技能正文被完整替换为组件化版本（含新增章节）；如本地有基于旧 SKILL.md 的改写，需按预览版内容重新对齐。
- 根 `plugin.json` 的 `skills` 数组扩到 24 项。

### 验证
- 当时以旧编号 v4.0.0 发布：`git ls-remote --tags origin` 含旧 tag、`gh release view` 成功（旧编号 tag/release 已按新编号方案清理）。

## v1.1.0 — 2026-09-17

preview 分支末尾（提交 `787cf78`）：hook 路由 + 技能归位 + write-prose / polish-prose（= 9 月最新内容）。

## v1.0.3 — 2026-08-04

专项注册表体系 + 版本提升（原内部称呼 "v3.1"）；技能目录 22 个。

## v1.0.2 — 2026-08-04

扁平化轻量重构：删除执行期钩子，技能改为扁平触发（旧 tag v3.0.0 所指）；技能目录 19 个。

## v1.0.1 — 2026-07-29

新增 real-world-verify 技能（5 步验证门）。

## v1.0.0 — 2026-07-13

初始版本：16 个技能 + 单 SessionStart hook + 4 个参考文件（提交信息中的内部称呼 "v2 plugin" 不改写）。
