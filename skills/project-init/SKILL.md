---
name: 大项目初始化
description: Use when 开始新的大型项目，或已有项目缺少 CLAUDE.md/PROGRESS.md/PROGRESS-LITE.md/STRUCTURE.md 四文件体系需要补建。触发词：初始化项目、建立项目文档体系、创建CLAUDE.md、项目结构设置、大项目初始化、搭建项目骨架。也适用于项目变复杂后需要从零建立文档管理体系的场景。反例：已有完善四文件体系的项目（应使用「大项目工作维护」）、单文件脚本、临时小工具。
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

# 大项目初始化

## 触发

- **必须触发**：用户要求初始化项目/建立文档体系/创建 CLAUDE.md 等文件/搭建项目骨架；项目变复杂需要规范管理。
- **隐式触发**：CLAUDE.md 不存在，且 Glob 扫描发现 ≥5 个源文件分布在 ≥2 个目录 → **主动建议初始化**，不要默默等待。
- **不触发**：已有四文件体系（用「myworkflow:project-maintain」）、单文件脚本/临时小工具、无额外管理需求的标准框架结构。

## 目标与核心理念

从零建立四文件体系，一次性做对——后续所有智能体都依赖这些文件理解项目。四文件关系：**CLAUDE.md 定规则 → PROGRESS.md 记事实 → PROGRESS-LITE.md 建索引 → STRUCTURE.md 画地图**。

## 前置强制步骤

1. **确认项目根目录**：未指定则 AskUserQuestion 确认（应含 `.git` 或 `package.json` 等标识）。
2. **扫描现有结构**：Glob/Bash 获取完整目录树。
3. **检查四文件状态**：逐一确认 CLAUDE.md / PROGRESS.md / PROGRESS-LITE.md / STRUCTURE.md。
4. **决定初始化范围**：
   - 全部缺失 → 完整六步流程。
   - 部分缺失 → 按表执行，**已有文件必须先读取，新文件须引用其内容以保证一致**：

| 缺失 | 执行步骤 |
|------|---------|
| 仅缺 CLAUDE.md | 第一步+第二步（读 STRUCTURE.md 反向填充目录树） |
| 仅缺 PROGRESS.md / PROGRESS-LITE.md | 第三步/第四步 |
| 仅缺 STRUCTURE.md | 第一步+第五步（读 CLAUDE.md 取项目信息，重新扫描） |
| 缺多个 | 按依赖顺序：CLAUDE.md → STRUCTURE.md → PROGRESS.md → PROGRESS-LITE.md |

   - 全部存在但为空/模板错误 → 询问是否重新生成。

## 六步初始化

### 第一步：收集项目信息

1. 扫描目录结构生成完整目录树。
2. 读已有文件提取信息：`package.json`（名称/技术栈）、`README.md`（定位）、`.git/config`（仓库信息）。
3. 信息不足用 AskUserQuestion 确认：一句话定位？主要给谁用？核心子项目/模块？

### 第二步：创建 CLAUDE.md（最关键——所有智能体的入口）

```markdown
# [项目名称] 工作区指令

## 每次启动会话的强制步骤
**每次新会话开始工作时，必须先调用「myworkflow:project-maintain」skill。** 它引导你：
1. 读取本文件（CLAUDE.md）了解项目规则
2. 读取 PROGRESS-LITE.md 了解最近进展
3. 读取 STRUCTURE.md 了解项目布局
4. 工作完成后强制更新 PROGRESS.md + PROGRESS-LITE.md + STRUCTURE.md

> 不要跳过。文档体系的价值取决于每一次工作都留下记录。

## 当前项目
正在开发 **[项目名称]**（一句话定位）。

## 工作区目录结构
[项目根目录]/
├── CLAUDE.md              # 本文件 — 工作区入口指令
├── README.md              # 项目说明
├── STRUCTURE.md           # 项目结构文档
├── PROGRESS.md            # 详细开发进度
├── PROGRESS-LITE.md       # 精简进度（标签化）
├── src/                   # 源代码
└── docs/                  # 文档

## 目录结构更新规则
仅当根目录（顶层）新增/删除/重命名目录或文件、新增子项目、核心规则变化时更新本文件目录树；日常子目录内文件增删由 STRUCTURE.md 管理。

## 每次变更的文档同步规则
**每次代码修复/重构/功能变更后，必须同步更新：**
1. **PROGRESS.md** — `---` 分隔线后追加详细条目（日期+问题+根因+文件列表+验证）
2. **PROGRESS-LITE.md** — 同步追加精简条目（`[标签]` + 一句话）
3. **STRUCTURE.md** — 文件/目录有增删改则同步目录树
4. **docs/ 相关文档** — 与代码实际状态一致
此规则无例外。文档即代码的一部分。
```

**适配要点**：模板中的 `[项目根目录]/`、`src/`、`docs/` 是占位符，必须替换为第一步扫描到的实际结构；小型项目（<20 文件）保持简洁；特殊规则（如"改 `.ts` 后必须 build"）追加在同步规则后；**"每次启动会话的强制步骤"一节不可删除**（连接初始化与维护的桥梁）；确保「myworkflow:project-maintain」skill 已安装。

### 第三步：创建 PROGRESS.md

```markdown
# [项目名称] 开发进度记录

> 本文件记录每次代码变更的完整过程。精简版见 PROGRESS-LITE.md。
> 新条目追加位置：在 `---` 分隔线之后、已有最新条目之前。

---
```

追加位置：`---` 线上是文件头，线下是内容区；新条目插在 `---` 下一行，第一个 `## YYYY-MM-DD` 永远是最新日期。条目格式详见「myworkflow:project-maintain」阶段 3.1/3.2，此处仅定义空模板。

### 第四步：创建 PROGRESS-LITE.md

```markdown
# [项目名称] 开发进度（精简版）

> 标签：[New Feature] 新功能 / [Debug] 修复 / [Change] 变更 / [Build] 构建
> 详细记录见 PROGRESS.md

---
```

条目格式（每条严格一行，不写"为什么"）：
```markdown
## YYYY-MM-DD
- [标签] 一句话描述做了什么
```

### 第五步：创建 STRUCTURE.md

基于第一步目录树生成，**每个文件和目录都要有注释说明用途**：

```markdown
# [项目名称] 项目结构

> 最后更新：YYYY-MM-DD
> 新增、删除、重命名文件或目录时必须同步更新本文件。

---
## 顶层结构
[项目根目录]/
├── CLAUDE.md              # 工作区入口指令
├── README.md              # 项目说明
├── STRUCTURE.md           # 本文件
├── PROGRESS.md            # 详细开发进度
├── PROGRESS-LITE.md       # 精简开发进度
├── src/                   # 源代码
├── tests/                 # 测试
└── docs/                  # 文档

## [每个主要子目录的结构]
src/
├── index.ts               # 入口文件
├── components/            # UI 组件
└── utils/                 # 工具函数

## 当前核心事实
- 运行时：Node.js 22；包管理器：pnpm；测试框架：Vitest；默认端口：3000
```

**关键原则**：按重要性分层（顶层→主要子目录→更深层）；注释写用途，不照搬文件名；结构与实际文件系统 100% 一致。"当前核心事实"从配置提取，不编造：运行时/语言（`.nvmrc`/`.python-version`/`go.mod`/`package.json engines`）、包管理器（lock 文件）、测试框架（依赖中的 vitest/jest 等）、默认端口（`.env` 的 PORT）、数据库（`prisma/` 等）、其他约定（README/CONTRIBUTING）。

### 第六步：完成确认与验证

**验证清单**：
```
□ 1. 4 个文件均存在且非空（Glob 或 ls 确认）
□ 2. CLAUDE.md 中「myworkflow:project-maintain」引用格式正确
□ 3. STRUCTURE.md 目录树与实际文件系统一致（抽查关键目录）
□ 4. 「myworkflow:project-maintain」skill 已安装（读其 SKILL.md；不存在则警告）
```

**完成报告**：
```
📋 四文件体系初始化完成：
✓ CLAUDE.md — 工作区入口，已写入对大项目工作维护的引用
✓ PROGRESS.md — 详细进度记录（空模板）
✓ PROGRESS-LITE.md — 精简进度索引（空模板）
✓ STRUCTURE.md — 项目结构地图，[N] 个目录已记录
后续每次工作开始，CLAUDE.md 会引导调用「myworkflow:project-maintain」。
```

## 设计要点

- **CLAUDE.md 是入口而非百科全书**：只写规则和引用；空间信息归 STRUCTURE.md，时间信息归 PROGRESS.md。
- **PROGRESS.md 的价值在根因**：记录"为什么发生、为什么这样修"才是未来智能体需要的上下文。
- **PROGRESS-LITE.md 只做快速扫描**：每条严格一行，让智能体一次读几百条。
- **STRUCTURE.md 的核心是注释**：每行注释都是后续智能体的路标。
- **价值靠纪律维持**：CLAUDE.md 中对维护 skill 的强制引用是技术保障。
