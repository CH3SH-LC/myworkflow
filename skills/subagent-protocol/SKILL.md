---
name: 子智能体执行协议
description: Use when 你被主智能体通过 Agent 工具创建为子智能体，且满足二者之一——prompt 中包含 task-id，或工作目录中存在 .task-manifest/ 合约目录（无 task-id 时的自举入口）。主智能体不调用本 skill，仅在子智能体 prompt 中引用。
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

## 触发

- **调用者**：子智能体（主智能体不调用本 skill，只引用它）。
- **自动触发**（满足全部 3 条）→ 立即从「阶段1：读取合约」开始：① 被主智能体通过 Agent 工具创建；② prompt 明确提到 `task-id`；③ 工作目录存在 `.task-manifest/task-contract.yaml` 且 `.task-manifest/prompts/`。
- **自举触发**（不满足自动触发时）→ 无 task-id 但工作目录存在 `.task-manifest/` → 走下方「自举保障」，先向主智能体确认执行哪一个任务，不猜测。
- **不触发**：普通问答（无 task-id、无合约）、单件小事（如"检查语法错误"）、找不到 task-contract.yaml 也无 task-id。

### 主智能体强制引用（task-dispatch 派发时必须写入子智能体 prompt）

```
你必须遵循「myworkflow:subagent-protocol」。你的 task-id 是 {task-id}。
先读取 `.task-manifest/prompts/task-{task-id}.md` 了解任务，
再读取 `.task-manifest/task-contract.yaml` 找到你的合约条目，
然后严格按 5 阶段协议工作：阶段 1：读取合约+确认输入。先读取 `.task-manifest/prompts/task-{task-id}.md` 了解任务，再读取 `.task-manifest/task-contract.yaml` 找到你的合约条目，逐一读取 inputs 中的文件路径。阶段 2-5 声明接口→产出实现→自检→完成报告。
```

> **一致性约束**：本模板与 `skills/task-dispatch/SKILL.md`「第七步：派发子智能体」中的同名模板必须**逐字一致**，修改其一时必须同步另一处。（用 slug `myworkflow:subagent-protocol` 而非中文显示名——技能寻址走目录名，中文名不参与寻址，写 slug 才能稳定触发。）

### 自举保障（主智能体漏引用/漏 task-id 时）

有 task-id？→ 查合约 → 存在 → 正常执行；不存在 → 报告"合约不存在"。
无 task-id → 有 `.task-manifest/`？→ 有 → 检测合约：存在 → 列出所有未完成任务（无 completion.md 的），问"以下任务尚未完成，我应执行哪一个？"并附列表；`prompts/` 存在但合约缺失 → 报告"请重新生成合约或指定我的任务"；两者都不存在 → 报告"目录为空，请确认是否重新拆解"。无 `.task-manifest/` → 非派发系统子智能体，正常回答。
（task-id 可在自举中由主智能体补充指定，不依赖前置存在。）

## 目标

规范子智能体工作：产出具备可验证的接口、可追溯的声明、可审计的自检记录。核心原则：**声明先于产出，声明即承诺。**

## 关联Skill

输入 ← 读取「myworkflow:task-dispatch」产出的 task-contract.yaml 与 prompt 模板；输出 → 产出的 interface-declaration.md / self-check.md / completion.md 是「myworkflow:integration-verify」的验证输入。

## 前置强制步骤

1. 确认 task-id：从 prompt 中找；没有 → 检查合约中未完成任务（无 completion.md 的），列出并向主智能体提问（不可猜测）。
2. 读取合约条目：task-contract.yaml 中 `id: {task-id}` 条目，找不到 → 报告。
3. 读取输入文件：逐一读取 inputs 列出的文件；不存在或内容不足 → 提问。

## 执行流程

**主线**：阶段1 读取合约+确认输入 → 阶段2 声明接口 → 阶段3 产出实现 → 阶段4 自检 → 阶段5 完成报告。

### 阶段1：读取合约 + 确认输入

- 找到与 task-id 匹配的合约条目，确认 description、depends_on、inputs、outputs、verification。
- 逐一读取 inputs 文件。
- 关键规则：输入文件不存在→提问；输入不足→提问；依赖任务未完成→等待（以 `.task-manifest/outputs/{dep-task-id}/completion.md` 存在且非空为准，**最多等 10 分钟**，超时报告"依赖任务 {dep-task-id} 未在时限内完成，请确认状态"）；合约有歧义→提问。

### 阶段2：声明接口

写 `.task-manifest/outputs/{task-id}/interface-declaration.md`：

```markdown
# 接口声明 — {task-id}
> 本声明是我的接口承诺。「myworkflow:integration-verify」将据此验证我的产出。
> 声明时间: {ISO 8601 时间戳}

## 我将创建/修改的文件
- [ ] {文件路径} — {用途描述}

## 我将暴露的接口
| 名称 | 签名 | 所在文件 |
|------|------|----------|
| {name} | {signature} | {file} |

## 我需要的外部输入
| 文件 | 内容（节/函数/类型） | 用途 |
|------|---------------------|------|
| {path} | {具体部分} | {说明} |

## 风险和假设
- {假设 1}
- {风险 1}
```

声明规则：必须覆盖合约 outputs 全部条目（可多不能少）；签名必须与合约一致；合约签名有问题 → 在风险中标注并继续按合约声明；声明写入后不可秘密修改。

### 阶段3：产出实现

1. 先建文件骨架（空文件、导出签名桩），再填实现逻辑。
2. 每完成一个文件，在声明中勾选 `- [x]`。
3. 需要修改声明 → 先更新 interface-declaration.md 再改代码。
4. 需要超出合约范围的工作 → 先反馈主智能体确认。

### 阶段4：自检

写 `.task-manifest/outputs/{task-id}/self-check.md`：

```markdown
# 自检报告 — {task-id}
> 自检时间: {ISO 8601 时间戳}

## 文件存在性
- [x] {file} — 存在且非空

## 接口签名匹配（与 interface-declaration.md 对比）
- [x] {name}: `{signature}` — 实际签名一致

## 功能完整性
- [x] {功能点}

## 接口自洽
- [x] 所有导出的函数/类型在同一个模块内有定义
- [x] 没有引用不存在的模块/文件 → 对每个 import/require 用 ls/Test-Path 验证
- [x] 没有孤立的导出 → grep 搜索每个导出名，确认被引用或属合约要求的 outputs

## 错误处理
- [x] {异常路径}
```

自检规则：必须全部 [x] 才能进入阶段5；修正涉及接口 → 先回阶段2更新声明；不造假（「myworkflow:integration-verify」会对比）。

### 阶段5：完成报告

写 `.task-manifest/outputs/{task-id}/completion.md`，状态为四种之一：

| 状态 | 含义 | 触发条件 |
|------|------|---------|
| **DONE** | 全部完成，对正确性有信心 | 合约全实现、自检全过、无已知问题 |
| **DONE_WITH_CONCERNS** | 完成但有疑虑（诚实表达不确定，非逃避；主智能体应优先审查这些疑虑） | 全部实现但存在：①正确性依赖未验证假设 ②边界处理不确定 ③某 API 行为与预期不同 ④对 trade-off 有疑虑 |
| **NEEDS_CONTEXT** | 无法完成，缺关键信息 | 合约信息不充分（错误处理策略未指定/目标平台未指定/接口签名有未定义参数等） |
| **BLOCKED** | 无法完成，被外部条件阻止 | 依赖子任务未完成/工具或服务不可用/合约有不可修复矛盾 |

```markdown
# 完成报告 — {task-id}

**状态**: [DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED]

## 产出文件清单
- [文件路径] — [简述]

## 自检结果
- [ ] 文件存在性
- [ ] 接口签名匹配
- [ ] 功能完整性
- [ ] 接口自洽
- [ ] 错误处理
- 全部通过: [是/否]

## 已知担忧 (DONE_WITH_CONCERNS 时填写)
- 担忧: [具体技术担忧] — 影响: [可能影响什么]

## 缺失信息 (NEEDS_CONTEXT 时填写)
- 缺失: [什么信息] — 影响决策: [哪个决策]

## 阻塞原因 (BLOCKED 时填写)
- 阻塞: [什么原因] — 可能解决: [方案]
```

核心约束：声明先于实现（未写 interface-declaration.md 就写代码=违规）；签名即承诺（改签名必同步更新声明）；自检不通过不交活（必须全部 [x]）；输入缺失不猜测（提问）；范围不蔓延（不修改合约未列文件）。

## 后置更新

1. 确认 3 个元文件（interface-declaration.md、self-check.md、completion.md）已生成，且实际代码产出已完成，路径均在 `.task-manifest/outputs/{task-id}/`。
2. 确认 self-check.md 全部 [x]。
3. 向主智能体报告完成。

## 完成标志

- [ ] interface-declaration.md 已写入，覆盖合约所有 outputs
- [ ] 所有代码/文档产出文件已创建，内容完成
- [ ] self-check.md 已写入，全部项目 [x]
- [ ] completion.md 已写入，产出清单完整
- [ ] 所有元文件在 .task-manifest/outputs/{task-id}/ 下
- [ ] 已向主智能体报告完成
