---
name: 项目文档初始化
description: Use when 需要在一个文件夹上建立项目文档体系的场景——用户说"初始化项目""建立项目文档体系""创建 CLAUDE.md""项目结构设置""搭建项目骨架""给这个项目建文档"，或进入一个还没有 CLAUDE.md 的文件夹、准备在这里长期开发东西时。触发词：初始化项目、建立文档体系、创建 CLAUDE.md、项目结构、搭建骨架、补建文档。不触发：已有 CLAUDE.md 与 docs/ 体系的项目（走「myworkflow:project-maintain」）、单文件脚本、临时小工具、只读浏览、纯问答。
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

# 项目文档初始化

## 触发

- **必须触发**：用户要求初始化项目 / 建立文档体系 / 创建 CLAUDE.md / 搭建项目骨架；进入一个没有 CLAUDE.md 的文件夹并准备长期开发。
- **隐式触发**：CLAUDE.md 不存在，但扫描发现 ≥5 个源文件分布在 ≥2 个目录，且用户本轮明确要在该处持续开发 → 主动建议初始化，不默默等待。
- **不触发**：已有 CLAUDE.md 与 `docs/` 体系（走「myworkflow:project-maintain」）、单文件脚本、临时小工具、只读浏览、纯问答。

## 目标
一次把文档体系建对。目标不是"生成几个文件"，而是让后续每个智能体都能**按问题查表定位**，不必判断"这条内容该写哪"。
**8 个位置各回答一个问题**（心智模型，后续所有写文档动作都靠它定位）：

| 文件 / 目录 | 回答 | 谁可写 |
|------|------|--------|
| `CLAUDE.md` | **怎么工作**（规则） | agent |
| `STRUCTURE.md` | **东西在哪**（地图） | agent |
| `docs/GOAL.md` | **为什么做**（长期目标） | **仅用户批准** |
| `docs/design/` | **做什么**（需求与设计） | agent |
| `docs/PROGRESS.md` | **做了什么**（追加式） | agent |
| `docs/STATE.md` | **现在在哪**（刷新式） | agent |
| `docs/information/` | **学到了什么**（经验条目） | agent |
| `docs/research/` | **外部世界怎么说** | deep-research |

> `docs/` 是项目开发过程的文档区，不是文件收容所。旧体系的 `PROGRESS-LITE.md` 在新体系中**取消**，职能由 `docs/PROGRESS.md` 的条目区继承。

## 防破坏护栏（五条，任何写入前先读一遍）
1. **写入白名单**：只允许 Write/Edit `<root>/CLAUDE.md`、`<root>/STRUCTURE.md`、`<root>/docs/**`（`<root>` = 本轮确认的文件夹根）。白名单之外的文件一律不动；确需改动先停下问用户。
2. **docs/ 准入**：只放本项目开发过程产生的文档。判断测试是一个单点事实核查：**「这份文档是这次开发中写出来的吗？不是 → 原地不动」**。禁止把项目里既有的资料、素材、参考文档搬进 `docs/`。
3. **扫描目的限定**：扫描只为"看清现状"，**扫描结果不得作为搬迁依据**。任何移动必须先列逐项计划（源路径 → 目标路径 → 原因），经用户逐项确认后才执行。
4. **迁移只做"复制 + 归档"，不删除**；根目录旧文件默认原样保留；删除必须逐文件确认。
5. **覆盖保护**：写入前若目标已存在必须先 Read；覆盖超过 20 行既有内容前必须展示 diff 摘要并获确认。

## 主线（6 阶段）
```
阶段0 判定文件夹类型 ─[常规]→ 阶段1 只建 CLAUDE.md → 报告
                     ─[项目]→ 阶段2 收集信息+确认 GOAL → 阶段3 生成文件 → 阶段4 两个 index.json → 阶段5 验证与报告
```
### 阶段 0：判定「项目文件夹 vs 常规文件夹」（任何 Write 之前）
> **硬门禁**：进行任何 Write / Edit 之前，必须先 AskUserQuestion 让用户三选一。禁止先建目录再问，禁止用扫描结果代替用户表态。

三选项：**项目文件夹** / **常规文件夹** / **拿不准**。选「项目」→ 阶段 2；选「常规」→ 阶段 1；选「拿不准」→ 用下表客观判定：

| 项目信号（≥2 即偏项目） | 常规信号（≥2 即偏常规） |
|------|------|
| 有 `.git/` 且已有提交历史 | 以资料/文档/素材为主（pdf/docx/xlsx/图片/视频占比高） |
| 有依赖或构建清单：`package.json`/`pyproject.toml`/`requirements.txt`/`go.mod`/`Cargo.toml` | 无构建清单、无测试、无 CI |
| 有测试目录或测试框架配置（`tests/`、`*.test.*`、`pytest.ini`） | 文件命名多为日期/主题/编号，无代码组织痕迹 |
| 有 CI 配置（`.github/workflows/`、`.gitlab-ci.yml`） | 已被编号分类体系管理（如 `D:\CH3SH\1.xxx / 2.xxx` 树） |
| 有 ≥2 个源码目录（`src/` 之外还有实质代码目录） | 用户从未声明开发目标，只是"往这里放东西" |
| 用户已声明要"做出什么"并给出验收标准 | 存在大量与本次无关的历史文件 |

> 项目信号 ≥2 → 项目文件夹；常规信号 ≥2 → 常规文件夹。**两组都 ≥2 时禁止代选，必须回到用户**，把两列信号逐条摆出来让用户拍板。

### 阶段 1：常规文件夹分支（只建 CLAUDE.md）
> **绝对禁止**：在常规文件夹里创建 `docs/`、GOAL.md、PROGRESS.md、design/ 等任何项目文档体系。创建 = 毁坏用户的文件夹。

- CLAUDE.md **不存在** → 新建，内容仅三节：`## 本目录性质（常规文件夹）`、`## 目录工作约定`、`## 变更记录`。
- CLAUDE.md **已存在** → **只允许在文件末尾追加这三节**，**禁止改写、重排、删除任何既有内容**。若同名小节已存在，只在 `## 变更记录` 下追加一行（日期 + 做了什么），不重复追加整节。
- 已存在的 `STRUCTURE.md` **保留原样**（可读、可作参考，但不改不删）。
- 报告一句话：判定为常规文件夹，只登记 CLAUDE.md，未创建 `docs/`，未移动任何文件。

### 阶段 2：项目文件夹 — 收集信息与确认 GOAL

1. **确认项目根**：向上查找 `.git` / 构建清单；不明确就问用户，别猜。
2. **扫描现状**（Glob/Bash 目录树）：为 STRUCTURE.md 与信号判定取事实，**不作搬迁依据**。
3. **提取事实**：`package.json`（名称/技术栈/version）、`README.md`（定位）、`.git/config`、`.env`（端口）。
4. **确认 GOAL（强制，不可跳过）**：问清"最终验收是什么"，必须拿到**可量化判据**（数字 / 阈值 / 分母 / 什么算不达标）。用户答不上来就逐条提议让用户选，**不要替用户写死目标**。

### 阶段 3：生成文件（模板）

生成顺序：`CLAUDE.md → STRUCTURE.md → docs/GOAL.md → docs/PROGRESS.md → docs/STATE.md → docs/design/ → docs/information/ → docs/research/ → docs/other/`。

**3.1 `<root>/CLAUDE.md`**

```markdown
# [项目名称] 工作区指令
## 每次工作的强制步骤
**每次新会话开始时，先调用「myworkflow:project-maintain」skill。** 它引导你：
1. 读本文件（规则）→ 2. 读 `docs/STATE.md`（现在在哪）→ 3. 读 `docs/PROGRESS.md` 条目区（最近做了什么）
4. 读 `docs/GOAL.md` 与 `docs/design/index.json`（要做什么、做到哪）→ 5. 工作完成后回到该 skill 的完成时流程，强制同步文档
> 不要跳过。文档体系的价值取决于每一次工作都留下记录。
## 当前项目
正在开发 **[项目名称]**（一句话定位）。为什么做见 `docs/GOAL.md`。
## 工作规则
1. **先设计后开发**：改动只做 `docs/design/` 中已写明的点；新增功能 / 行为变更 / 新模块必须先生成 design，没有 design 不动手。bug 修复 / 重构 / 配置 / 文档 / 格式化允许豁免，但须在 PROGRESS 条目标注「本次无 design（小场景豁免）」；判断不清时默认按"需要 design"处理。
2. **验收口径**：只有用户明确说"确认没问题 / 可以了 / 通过了 / 我验收通过"才能把点置「完成」；**用户没说话 = 还没验收**，只能停在「待验收」。
3. **文档同步**：每次变更后同步 `docs/PROGRESS.md`、`docs/STATE.md`、`docs/design/index.json`，必要时 `STRUCTURE.md`。
4. **不许搬运**：`docs/` 只放本项目开发过程产生的文档；项目里既有的资料、素材、参考文档原地不动。
## 工作区目录结构
[实际目录树，逐行注释用途；细节见 STRUCTURE.md]
## 目录结构更新规则
仅当根目录（顶层）新增 / 删除 / 重命名目录或文件、新增子项目、核心规则变化时更新本文件目录树；子目录内文件增删由 STRUCTURE.md 管理。
```

**适配要点**：占位符必须替换为实际结构；小型项目（<20 文件）保持简洁；特殊规则（如"改 `.ts` 后必须 build"）追加在「工作规则」之后；**「每次工作的强制步骤」一节不可删除**。

**3.2 `<root>/STRUCTURE.md`**（保留在项目根目录，不在 docs/ 下）

```markdown
# [项目名称] 项目结构
> 最后更新：YYYY-MM-DD　新增、删除、重命名文件或目录时必须同步更新本文件。
---
## 顶层结构
[项目根]/
├── CLAUDE.md              # 工作区入口指令（怎么工作）
├── STRUCTURE.md           # 本文件（东西在哪）
├── src/                   # 源代码
└── docs/                  # 开发文档区：GOAL.md 为什么做（仅用户批准可改）｜STATE.md 现在在哪（刷新式）｜
                           #   PROGRESS.md 做了什么（条目区 + 版本记录区）｜design/ 做什么（含 index.json）｜
                           #   information/ 学到了什么（含 index.json）｜research/ 外部世界怎么说｜other/ 兜底
## [每个主要子目录的结构]
src/  →  index.ts 入口 ／ components/ UI 组件 ／ utils/ 工具函数
## 当前核心事实
- 运行时：Node.js 22；包管理器：pnpm；测试框架：Vitest；默认端口：3000
```

**关键原则**：按重要性分层（顶层 → 主要子目录 → 更深层）；注释写**用途**不照搬文件名；与实际文件系统 100% 一致。「当前核心事实」从配置提取（`.nvmrc`/`.python-version`/`go.mod`/`package.json engines`、lock 文件、依赖中的测试框架、`.env` 的 PORT），**不编造**。

**3.3 `<root>/docs/GOAL.md`**

```markdown
# [项目名称] 目标
> 更新：YYYY-MM-DD。**本文件仅用户批准可改**——agent 只能提议，不得自行写入或改写。
## 最终验收
- [可量化判据 1：数字 / 阈值 / 分母]
- [可量化判据 2]
- 什么不算达标：[明确写出"看起来好但不合格"的情形]
## 为什么做（开发本意）
[2–4 句：解决谁的什么问题，做完之后有什么不同]
## 边界与约束
- 不做什么：
- 已知硬约束（数据 / 环境 / 时间）：
- 验收与成本冲突时的优先级：
```

**3.4 `<root>/docs/PROGRESS.md`**（双层 + 版本号）

```markdown
# [项目名称] 开发进度
> **版本：0.1.0**（本行为版本号单一权威源，其他文件只能引用它）
> 双层结构：**条目区**（做了什么，最新在最上，每条一行，带版本号）+ **版本记录区**（每版本一段：问题/根因/修改/验证）
> 版本号是两层的 join key。归档：条目区触顶后最老内容移入 `docs/other/progress-archive-YYYY.md`。
---
## 条目
## YYYY-MM-DD
- [New Feature][v0.1.0] 一句话做了什么（严格一行，不写"为什么"）
- [Debug][v0.1.0] ……
---
## 版本记录
### v0.1.0 — YYYY-MM-DD
**问题 / 动机**：（背景与意图）
**根因**：（仅 bug 修复需要：为什么发生、为什么之前没发现、为什么这样修）
**修改**：`路径/文件` — 改了什么；对应 design 点号 `design-01-P1`
**验证**：（真实跑到的命令与结果，不写"已测试"）
```

标签：`[New Feature]` 新增 / `[Debug]` 修复 / `[Change]` 重构优化 / `[Build]` 构建部署；同日多条按此顺序排。

**版本号 a.b.c**（初始值：空体系 `0.0.0`；已有可运行产物 `0.1.0`；有 `package.json` 等代码清单的 `version` 时以代码清单为准）：

| 位 | 语义 | 递增条件 | 谁批准 |
|----|------|---------|--------|
| a | 大版本 | `0` = 未成熟测试期；正式发布 0→1；此后仅完整项目的大变动 | **用户** |
| b | 小版本 | 新增功能 / 功能增强 / 新增模块 | agent 自动 |
| c | debug | 修 bug、重构、性能微调、文档配置调整 | agent 自动 |

> 一次会话至多递增一次（取最高语义）；不产生版本的工作不递增；与代码清单 `version` 不一致时，在版本记录区显式记一行并在 `STATE.md` 列出——递增与写入的权威执行方是「myworkflow:project-maintain」。

**3.5 `<root>/docs/STATE.md`**（刷新式）

```markdown
# [项目名称] 当前状态
> 最后刷新：YYYY-MM-DD。**刷新式**——只回答"现在在哪"，历史一律进 PROGRESS.md。
> 自检：本文件出现 3 条以上上周的内容 → 你把 PROGRESS 的历史抄进来了，删掉。
## 位置
- 当前版本：v0.1.0（与 `docs/PROGRESS.md` 头部一致；若代码清单有 version，以它为准并在此列出差异）
- 正在做：design-01 的 P2（开发中不进 index）／无
- 卡住的：（阻塞点号 + 具体原因；没有就写"无"）
## 下一步（≤5 条，按优先级）
1. …
## 等用户验收
- design-01-P1「…」— 已完成并验证，等用户确认
## 当前生效的约束与环境
- 运行时 / 包管理器 / 测试命令 / 默认端口 / 不能碰的东西
```

**3.6 `<root>/docs/design/design-01-<主题>.md`** — 硬下限 **≥20 行**，必须含 **背景 / 需求 / 验收标准 / 点清单** 四节（下表是骨架，填充后须达标；低于 20 行说明需求没写清，不是"项目小"）。

```markdown
# design-01：<主题>
> 状态：进行中 / 已完成 / 已废弃　创建：YYYY-MM-DD　最后更新：YYYY-MM-DD
> 上游：`docs/GOAL.md`　本文件只管"做什么"，不管"怎么写"。
## 背景
[为什么做这一块：对应 GOAL 的哪条判据、当前缺口是什么]
## 需求
- 需求 1：…
## 验收标准
- [可验证判据：什么算做成、怎么验、什么条件下算不达标]
## 点清单
| 点号 | 内容 | 状态 | 证据 | 备注 |
|------|------|------|------|------|
| design-01-P1 | … | 未开发 | | |
| design-01-P2 | … | 未开发 | | |
> 状态为四态封闭枚举：`未开发` / `阻塞` / `待验收` / `完成`。**"开发中"不写进本表**，它由 `docs/STATE.md` 承载。
> 权威索引是 `docs/design/index.json`；本表的点号与状态必须与 index 完全一致，冲突时按 index 修正本表。
## 不做的事
- [明确排除项，防止范围漂移]
```

> **design 内容禁令**：只放需求 / 功能 / 设计。**禁止写具体代码方案**——不写函数签名、数据结构、算法步骤、目录布局。design 是"要什么"，不是"怎么实现"。

**3.7 `<root>/docs/information/information-01-<主题>.md`**

```markdown
# information-01：<主题>
> 创建：YYYY-MM-DD　最后更新：YYYY-MM-DD　索引：`docs/information/index.json`
## 条目
### info-001 — YYYY-MM-DD　一句话结论
- 场景：（在什么情况下遇到的）
- 结论 / 做法：（以后遇到就该这么做）
- 反例 / 坑：（曾经怎么错的、代价是什么）
- 来源：（用户原话 / 实测输出 / 文件路径）
```

信息条目涵盖：试错结论、用户偏好、环境事实、易踩的坑。

**3.8 `<root>/docs/research/`、`<root>/docs/other/`**

- `research/`：由 `deep-research` 落盘，**不建 index.json**，靠日期 + slug 文件名检索；允许按调研要点建子文件夹。
- `other/`：兜底，**严格准入**——只有确实不属于上述任何一类、且**确实是本次开发产生的**文档才放这里；准入提问仍是那一句「这份文档是这次开发中写出来的吗？不是 → 原地不动」。归档文件命名为 `progress-archive-YYYY.md`。

### 阶段 4：两个 index.json（schema 与示例）

> **写入权**：`index.json` 只由「myworkflow:project-maintain」写入。本阶段只负责建出初始文件，后续任何状态变更都不得由其他技能直接改。

**`docs/design/index.json`** 字段：根级 `schema_version`（固定 1）/ `project` / `updated` / `status_enum`（固定四态）；`designs[]` 每项含 `id`（与文件名前缀一致）、`file`（相对 `docs/design/` 的文件名，必须能在磁盘定位）、`title`、`created`、`updated`、`goal_check`（GOAL 回望那一行的原文）；`points[]` 每项含 `id`（如 `design-01-P1`，全局唯一）、`design`、`file`（必须等于其 `designs[].file`）、`title`、`status`（四态枚举之一）、`evidence`（可指认的证据：验证输出、命令与结果、截图路径）、`updated`、`note`（如"历史文档补登记"）。

```json
{
  "schema_version": 1, "project": "CoCo", "updated": "2026-09-15",
  "status_enum": ["未开发", "阻塞", "待验收", "完成"],
  "designs": [
    { "id": "design-01", "file": "design-01-用户登录.md", "title": "用户登录", "created": "2026-09-15", "updated": "2026-09-15", "goal_check": "GOAL 回望：本 design 与 GOAL 的「登录流程可用」一致" }
  ],
  "points": [
    { "id": "design-01-P1", "design": "design-01", "file": "design-01-用户登录.md", "title": "支持手机号 + 验证码登录", "status": "待验收", "evidence": "pnpm vitest run tests/login.test.ts → 8 passed；手工走通验证码登录进入首页", "updated": "2026-09-15", "note": "" },
    { "id": "design-01-P2", "design": "design-01", "file": "design-01-用户登录.md", "title": "记住登录状态 7 天", "status": "未开发", "evidence": "", "updated": "2026-09-15", "note": "" }
  ]
}
```

**`docs/information/index.json`** 字段：根级同上（以 `entries[]` 取代 `designs`/`points`）；`entries[]` 每项含 `id`（如 `info-001`，与正文条目号一致）、`file`（相对 `docs/information/`）、`title`（一句话结论）、`tags`（标签数组，用于筛选）、`summary`（2–3 句展开，够判断"要不要点开"）、`created`、`updated`。

```json
{
  "schema_version": 1, "project": "CoCo", "updated": "2026-09-15",
  "entries": [
    { "id": "info-001", "file": "information-01-构建与测试.md", "title": "构建前必须先跑代码生成，否则 TS 类型缺失", "tags": ["构建", "测试"], "summary": "直接 pnpm build 会因缺失生成代码报类型错误；正确顺序是先 pnpm gen 再 pnpm build。", "created": "2026-09-15", "updated": "2026-09-15" }
  ]
}
```

**状态机四条硬门禁**（建库即生效，后续由 project-maintain 执行）：

> 未开发 / 阻塞 / 待验收 / 完成 四态封闭枚举，**"开发中"不写进 index**——它由 `docs/STATE.md` 承载。

> `evidence` 为空的点不得置「待验收」。必须有可指认的证据（验证输出、命令与结果、截图路径），不接受"已测试"这类无证据表述。

> 除非用户在本轮对话中明确说出"确认没问题 / 可以了 / 通过了 / 我验收通过"，否则状态只能停留在「待验收」。禁止以"我已经验证过""测试全绿"为由自行置为「完成」。**用户没说话 = 还没验收。**

> 置「阻塞」必须写具体原因（卡在哪、缺什么、依赖谁）；只写"没做完"不许置阻塞。

### 阶段 5：验证与完成报告

```
□ 1. CLAUDE.md / STRUCTURE.md / docs/{GOAL,STATE,PROGRESS}.md 均存在且非空
□ 2. docs/ 下 design、information、research、other 四个目录已建
□ 3. 两个 index.json 可被 json.load 解析，字段齐全，status_enum 与示例枚举一致
□ 4. PROGRESS.md 头部有版本号一行；STATE.md 有"最后刷新"日期；STRUCTURE.md 与实际文件系统一致（抽查关键目录）
□ 5. 白名单自查：本轮所有写入都在 CLAUDE.md / STRUCTURE.md / docs/** 之内
□ 6. 无搬迁自查：本轮没有移动、重命名或删除任何既有文件
```

```
📋 文档体系初始化完成：✓ CLAUDE.md（已写入对「myworkflow:project-maintain」的强制引用）✓ STRUCTURE.md（[N] 个目录）✓ docs/GOAL.md（用户已确认）✓ docs/PROGRESS.md（双层）✓ docs/STATE.md（刷新式）✓ 两个 index.json（可解析）
```

## 产出物

- **项目文件夹**：`<root>/CLAUDE.md`、`<root>/STRUCTURE.md`、`<root>/docs/{GOAL.md,STATE.md,PROGRESS.md}`、两个 `index.json`、首份 design 与 information 主题文件、`research/` 与 `other/` 空目录。
- **常规文件夹**：仅 `<root>/CLAUDE.md`（新建或追加三节），**不产出任何其他文件**。

## 完成标志

- [ ] 已 AskUserQuestion 完成三选一（选"拿不准"时按信号表判定；两组都 ≥2 时已回到用户，未代选）
- [ ] 常规文件夹：未创建 `docs/`，未改动既有内容，仅新增 / 追加 CLAUDE.md 三节
- [ ] 项目文件夹：GOAL 已由用户确认且含可量化判据
- [ ] 8 个位置的文件全部生成，模板占位符已替换为实际内容
- [ ] 两个 index.json 已建且可解析，状态为四态封闭枚举，四条硬门禁已写入
- [ ] 验证清单 6 项全过；五条防破坏护栏逐条自查通过；完成报告已输出

## 常见问题

- **用户说不清 GOAL？** 逐条提议让用户选，不替用户写死；宁可留空并标"待用户确认"，也不要编造目标。
- **文件夹里已有一堆旧文档？** 原地不动；用户明确要求迁移时走「myworkflow:project-maintain」阶段 0（复制 + 归档，逐项确认）。
- **半新半旧（有 CLAUDE.md 无 docs/）？** 判为项目文件夹后按阶段 3 补齐；已存在文件先 Read 再定补写还是追加，覆盖超过 20 行前须展示 diff 摘要并获确认。
