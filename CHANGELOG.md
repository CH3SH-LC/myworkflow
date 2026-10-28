# Changelog

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
