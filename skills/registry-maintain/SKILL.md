---
name: 专项注册表维护
description: Use when 需要更新专项任务注册表（config/special-skills.json）、添加或移除专项 skill、或回答"有哪些专项技能/专项 skill"时调用。触发词：更新专项清单、专项注册表、有哪些专项、special-skills、注册表维护。不触发：纯使用某个专项 skill（直接调目标 skill）。
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - Glob
  - Grep
  - Bash
  - PowerShell
---

# 专项注册表维护

## 定位

维护 `config/special-skills.json` —— 专项任务路由的数据源。会话启动时注入的锚点指引模型：疑似专项任务 → 查本表找对应 skill。

**本技能只负责 `categories` 段。** `inventory` 段由 `hooks/registry-scan.sh` 在每次会话启动时自动重写，人工不要手改。

## 文件结构

```
config/special-skills.json
├── categories   （人工维护，本技能的职责）分类名 → [skill slug, ...]
└── inventory    （自动生成，勿手改）扫描全部已注册插件技能的清单
```

- **slug 格式**：`<plugin>:<skill目录>`（如 `myworkflow-extra:storage-analyzer`）
- **内置技能**（dataviz、claude-api 等 Claude Code 自带、不在插件目录）：用 `builtin:<name>` 约定引用，扫描不会覆盖
- **哪些插件会被扫进 inventory**：只扫 `installed_plugins.json` 里登记了 `installPath` 且目录真实存在的插件。放在 `plugins/` 下但未注册的目录不会进表。

## 更新流程

1. **重新扫描**：运行 `bash "${CLAUDE_PLUGIN_ROOT}/hooks/registry-scan.sh"`（幂等；只刷新 `inventory`，`categories` 原样保留）
2. **对比差异**：看 `inventory.skills` 相对上次新增/移除了哪些
3. **归类**：有意义的新技能 → 加入对应 `categories`；**不确定归哪类 → 问用户，不要猜**
4. **删除**：技能被移除或插件迁移 → 从 `categories` 删对应 slug，或改其插件前缀
5. **验证**：JSON 合法；`categories` 里每个 slug 都存在于 `inventory`（`builtin:` 前缀的除外）——**零死链**
6. **汇报**：新增 N 项 / 移除 N 项 / 类别变更

## 自动刷新

会话启动时 `hooks/session-init.sh` 会调用扫描脚本刷新 `inventory`，无需人工干预。因此本技能主要用于：

- 安装新插件或迁移技能归属后，把变化反映到 `categories`
- 用户主动要求整理或查看专项清单
- 手动强制刷新（直接运行扫描脚本）

## 与其它 skill 的关系

- `task-router`：疑似专项任务时读本表路由
- `hooks/registry-scan.sh`：负责 `inventory`，本技能负责 `categories`，两者不混改
