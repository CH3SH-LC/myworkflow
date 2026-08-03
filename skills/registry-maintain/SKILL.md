---
name: 专项注册表维护
description: Use when 需要更新专项任务注册表（config/special-skills.json）、添加或移除专项 skill、或回答"有哪些专项技能/专项 skill"时调用。触发词：更新专项清单、专项注册表、有哪些专项、special-skills、注册表维护。不触发：纯使用某个专项 skill（直接调目标 skill）。
---

# 专项注册表维护

## 定位

维护 `config/special-skills.json` —— 专项任务路由的数据源。分类 hook 在会话注入时指引模型：疑似专项任务 → 查本表找对应 skill。

## 文件结构

```
config/special-skills.json
├── categories   （人工维护）任务类 → [skill slug, ...]
└── inventory    （自动生成，勿手改）扫描全部本地插件技能的清单
```

- **slug 格式**：`<plugin>:<skill目录>`（如 `webnovel-studio:具体写作`）
- **内置技能**（dataviz、claude-api 等 Claude Code 自带、不在插件目录）：用 `builtin:<name>` 约定引用，扫描不会覆盖

## 更新流程

1. **重新扫描**：运行 `bash <插件根>/hooks/registry-scan.sh`（幂等；只刷新 `inventory`，`categories` 保留不动）
2. **对比差异**：看 `inventory.skills` 相对上次新增/移除了哪些
3. **归类**：有意义的新技能 → 加入对应 `categories`；不确定归哪类 → 问用户，不要猜
4. **删除**：技能被移除 → 从 `categories` 删对应 slug
5. **验证**：JSON 合法；`categories` 里每个 slug 存在于 `inventory`（或 `builtin:` 前缀）
6. **汇报**：新增 N 项 / 移除 N 项 / 类别变更

## 自动刷新

SessionStart 时 `session-init.sh` 已做 mtime 守卫的自动刷新（只更新 `inventory`）。本 skill 用于：
- 安装新插件后，把新专项登记进 `categories`
- 用户主动要求整理/查看专项清单
- 手动强刷（运行扫描脚本）

## 与其它 skill 的关系

- `task-router`：疑似专项时读本表路由
- 安装新插件后：调本 skill 登记进 `categories`
