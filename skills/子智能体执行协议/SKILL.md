---
name: 子智能体执行协议
description: Use when 你被主智能体通过 Agent 工具创建为子智能体，prompt 中包含 task-id，且工作目录中存在 .task-manifest/ 目录。主智能体不调用本 skill，仅在子智能体 prompt 中引用。
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

## 触发场景

> **本 skill 的调用者是子智能体，不是主智能体。** 触发机制：「任务拆解与派发」在派发子智能体时，将本 skill 的名称写入子智能体的 prompt 中。子智能体启动后识别到自己被分配了 task-id，立即调用本 skill。

### 子智能体自动触发（满足全部条件时触发）
1. 你被主智能体通过 Agent 工具创建
2. 你的 prompt 中明确提到了 `task-id`（如 "你的 task-id 是 build-shared-types"）
3. 工作目录中同时存在 `.task-manifest/task-contract.yaml` **且** `.task-manifest/prompts/` 目录

→ 满足以上 3 条时，你必须立即调用本 skill，从"阶段 1：读取合约"开始执行。

### 主智能体的"强制引用"义务
调用「任务拆解与派发」派发子智能体时，**必须**在子智能体的 prompt 中包含以下引用：
```
你必须遵循「子智能体执行协议」。你的 task-id 是 {task-id}。
先读取 `.task-manifest/prompts/task-{task-id}.md` 了解任务，
再读取 `.task-manifest/task-contract.yaml` 找到你的合约条目，
然后严格按 5 阶段协议工作：阶段 1：读取合约+确认输入。先读取 `.task-manifest/prompts/task-{task-id}.md` 了解任务，再读取 `.task-manifest/task-contract.yaml` 找到你的合约条目，逐一读取 inputs 中的文件路径。阶段 2-5 声明接口→产出实现→自检→完成报告。
```
如果子智能体的 prompt 中**没有**这段引用 → 说明主智能体可能漏掉了。子智能体应执行以下自检：
1. 检查工作目录中是否存在 `.task-manifest/` 目录
2. 如果存在 → 检查 `task-contract.yaml` 是否存在：
   - 如果合约存在 → 读取合约。在 prompt 中搜索 task-id（可能以非标准格式出现）。如果找到 task-id → 主动向主智能体确认："我发现合约中有任务 {task-id}，我是否应执行此任务？"；**如果 prompt 中完全找不到 task-id → 列出合约中所有未完成的任务（无 completion.md 的），向主智能体提问："以下任务尚未完成，我应执行哪一个？"并附上列表**
   - **如果 `task-contract.yaml` 不存在但 `prompts/` 目录存在** → 向主智能体报告："`.task-manifest/` 中存在 prompts 目录但合约文件缺失，请重新生成合约或指定我的任务"
   - **如果 `task-contract.yaml` 和 `prompts/` 都不存在** → 向主智能体报告："`.task-manifest/` 目录存在但为空，请确认是否需要重新拆解任务"
3. 如果 `.task-manifest/` 不存在 → 你不是派发系统的子智能体，正常回答即可

**自举保障**：

决策树（简化版）：
有 task-id？→ 是 → 查合约 → 合约存在？→ 是 → 跳过自举，正常执行
                    → 否 → 报告"合约不存在"
           → 否 → 有 .task-manifest/？→ 是 → 走自举流程
                                        → 否 → 报告主智能体"未找到任务上下文"

即使主智能体忘记引用「子智能体执行协议」且未指定 task-id，只要工作目录中存在 `.task-manifest/` 目录，子智能体应主动检测合约、列出待执行任务、请求主智能体分配。自举不依赖 task-id 的前置存在——task-id 可以在自举过程中由主智能体补充指定。

### 不触发（反例）
- 你在一个普通对话中被问到问题（没有 task-id、没有合约文件）→ 正常回答，不要执行本协议
- 你被要求做一件小事（如"检查这个文件有没有语法错误"）→ 这不是子任务派发，不需要声明/自检
- 你找不到 task-contract.yaml 也没有 task-id → 你不是派发系统的子智能体

### 触发边界
- 本 skill 是子智能体专用的工作规范——主智能体**不调用**本 skill，只引用它
- 如果你不确定自己是不是"子智能体" → 检查 prompt 中是否有 task-id 且工作目录中是否有 .task-manifest/ → 有就是，没有就不是

## 必需要素

- `.task-manifest/task-contract.yaml` 中存在与你的 task-id 匹配的合约条目
- `.task-manifest/prompts/task-{task-id}.md` 存在且包含任务描述和输出接口
- 你知道自己的 task-id（由主智能体在创建你时告知）

## 推荐要素

- 主智能体已在 prompt 中提供了输入文件的摘要
- 输入文件已在合约的 `inputs` 中列出

## 前置强制步骤

核心原则：声明先于产出。在写任何代码/文档之前，先声明你的接口——声明即承诺。

1. 确认你的 task-id：从主智能体的 prompt 中找到。如果 prompt 中没有明确 task-id → 检查合约中是否有未完成（无 completion.md）的任务，列出并向主智能体提问"以下任务尚未完成，是否由我执行其中某一个？"（不可猜测）
2. 读取合约条目：在 task-contract.yaml 中找到 `id: {你的task-id}` 的条目。如果找不到 → 向主智能体报告
3. 读取输入文件：对合约中 inputs 的每个文件，读取并确认内容充分。如果任何输入文件不存在或内容不足 → 向主智能体提问

## 关联Skill

| 方向 | 关联对象 | 关系 |
|------|----------|------|
| 输入 ← | 任务拆解与派发 | 读取「任务拆解与派发」产出的 task-contract.yaml 和 prompt 模板 |
| 输出 → | 集成验证与修正 | 产出的 interface-declaration.md、self-check.md、completion.md 是「集成验证与修正」的验证输入 |

---

## 目标

规范子智能体的工作行为，确保每个子智能体的产出具有可验证的接口、可追溯的声明、可审计的自检记录。

## 执行流程

**ASCII flow diagram:**

```
读取合约 + 确认输入 → 输入充分？否→向主智能体提问 → 是→阶段2声明→阶段3产出→需要修改声明？是→更新声明→阶段3 / 否→阶段4自检→全部打勾？否→修正→阶段3 / 是→阶段5完成报告→结束
```

**阶段 1：读取合约 + 确认输入**
- 找到 task-contract.yaml 中与你 task-id 匹配的条目
- 确认理解：description、depends_on、inputs、outputs、verification
- 逐一读取所有 inputs 中列出的文件
- 关键规则：输入文件不存在→提问；输入不足以支撑实现→提问；依赖任务未完成→等待（以 `.task-manifest/outputs/{dep-task-id}/completion.md` 存在且非空为准，**最多等待 10 分钟**，超时后向主智能体报告"依赖任务 {dep-task-id} 未在时限内完成，请确认状态"）；合约有歧义→提问

**阶段 2：声明接口**

写 `.task-manifest/outputs/{task-id}/interface-declaration.md`：

```markdown
# 接口声明 — {task-id}
> 本声明是我的接口承诺。「集成验证与修正」将据此验证我的产出。
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

声明规则：必须覆盖合约 outputs 的所有条目（可以多不能少）；签名必须与合约一致；如果合约签名有问题，在风险中标注并继续按合约声明；声明写入后不可秘密修改。

**完整示例 — build-shared-types 任务：**

```markdown
# 接口声明 — build-shared-types
> 本声明是我的接口承诺。「集成验证与修正」将据此验证我的产出。
> 声明时间: 2026-07-10T10:00:00Z

## 我将创建/修改的文件
- [ ] src/auth/types.ts — 定义 API 请求/响应的共享类型
- [ ] src/auth/index.ts — 统一导出所有共享类型 <!-- 注：index.ts 不属于合约要求的 outputs，此处仅为示意。实际声明中只列出合约要求的产出文件。额外产出需标注为"额外产出"并说明理由。 -->

## 我将暴露的接口
| 名称 | 签名 | 所在文件 |
|------|------|----------|
| CreateUserRequest | `{ name: string; email: string; role: "admin" \| "user" }` | src/auth/types.ts |
| UserResponse | `{ id: string; name: string; email: string; role: string; createdAt: string }` | src/auth/types.ts |
| ApiError | `{ code: number; message: string; details?: Record<string, unknown> }` | src/auth/types.ts |
| PaginatedResponse<T> | `{ data: T[]; page: number; totalPages: number; totalItems: number }` | src/auth/types.ts |

## 我需要的外部输入
| 文件 | 内容（节/函数/类型） | 用途 |
|------|---------------------|------|
| api-spec.yaml | `paths./users.post.requestBody` | 推导 CreateUserRequest 字段 |
| api-spec.yaml | `paths./users.get.responses.200` | 推导 UserResponse 和 PaginatedResponse 字段 |

## 风险和假设
- api-spec.yaml 中的错误响应格式未显式定义，ApiError 类型基于常见 REST 约定推断
- PaginatedResponse 使用泛型 T，假设调用方在使用时指定具体类型
```

**阶段 3：产出实现**

1. 先建文件骨架（空文件、导出签名桩）
2. 再填实现逻辑
3. 每完成一个文件，在声明中勾选 `- [x]`
4. 发现需要修改声明 → 先更新 interface-declaration.md，再改代码
5. 发现需要超出合约范围的工作 → 先反馈给主智能体确认

**阶段 4：自检**

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
- [x] 没有引用不存在的模块/文件 → 检查方法：对每个 import/require 语句，用 ls/Test-Path 验证路径存在
- [x] 没有孤立的导出 → 检查方法：grep 搜索每个导出的函数/类型名，确认被至少一个其他文件引用或属于合约要求的 outputs

## 错误处理
- [x] {异常路径}
```

自检规则：必须全部[x]才能进入阶段5；如果修正涉及修改接口→先回阶段2更新声明；不要造假（「集成验证与修正」会对比）。

**完整示例 — build-shared-types 任务：**

```markdown
# 自检报告 — build-shared-types
> 自检时间: 2026-07-10T10:30:00Z

## 文件存在性
- [x] src/auth/types.ts — 存在且非空
- [x] src/auth/index.ts — 存在且非空

## 接口签名匹配（与 interface-declaration.md 对比）
- [x] CreateUserRequest: `{ name: string; email: string; role: "admin" | "user" }` — 实际签名一致
- [x] UserResponse: `{ id: string; name: string; email: string; role: string; createdAt: string }` — 实际签名一致
- [x] ApiError: `{ code: number; message: string; details?: Record<string, unknown> }` — 实际签名一致
- [x] PaginatedResponse<T>: `{ data: T[]; page: number; totalPages: number; totalItems: number }` — 实际签名一致

## 功能完整性
- [x] 所有 API 类型定义完整，字段类型匹配 api-spec.yaml
- [x] index.ts 导出了所有 4 个类型（CreateUserRequest、UserResponse、ApiError、PaginatedResponse）
- [x] 泛型 PaginatedResponse<T> 可接受任意类型参数

## 接口自洽
- [x] 所有导出的函数/类型在同一个模块内有定义
- [x] 没有引用不存在的模块/文件
- [x] 没有孤立的导出

## 错误处理
- [x] ApiError 的 details 字段为可选（?），允许不提供额外信息
```

**阶段 5：完成报告**

### 完成状态枚举

子智能体完成时在 completion.md 中声明以下四种状态之一：

| 状态 | 含义 | 触发条件 |
|------|------|---------|
| **DONE** | 全部完成，对正确性有信心 | 所有合约要求已实现、自检全部通过、无已知问题 |
| **DONE_WITH_CONCERNS** | 全部完成，但对某些方面不确定 | 所有合约要求已实现、自检通过，但存在：①代码正确性依赖未验证假设 ②边界处理不确定 ③某 API 行为与预期不同 ④对设计 trade-off 有疑虑 |
| **NEEDS_CONTEXT** | 无法完成，缺少关键信息 | 合约中信息不充分（错误处理策略未指定/目标平台未指定/接口签名有未定义参数等） |
| **BLOCKED** | 无法完成，被外部条件阻止 | 依赖子任务未完成/工具或服务不可用/合约中有不可修复的矛盾 |

#### DONE_WITH_CONCERNS 的设计意图
- **目的**：让子智能体诚实表达不确定，无需隐藏疑虑或阻塞进度
- **不是逃避**：仍要求所有合约要求已实现——不能因"不确定"跳过步骤
- **对主智能体/集成验证与修正**：看到 DONE_WITH_CONCERNS → 优先审查这些疑虑 → 决定接受/修复/深度审查
- **与 DONE 区别**：DONE="我认为没问题"；DONE_WITH_CONCERNS="我认为完成了，但重点看这几个地方"

写 `.task-manifest/outputs/{task-id}/completion.md`：

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

**完整示例 — build-shared-types 任务（DONE 状态）：**

```markdown
# 完成报告 — build-shared-types

**状态**: DONE

## 产出文件清单
- src/auth/types.ts — 定义了 CreateUserRequest、UserResponse、ApiError、PaginatedResponse 四个类型
- src/auth/index.ts — 重导出所有类型，作为公共入口
- .task-manifest/outputs/build-shared-types/interface-declaration.md — 声明了 4 个接口，覆盖合约全部要求
- .task-manifest/outputs/build-shared-types/self-check.md — 6 项自检全部通过

## 自检结果
- [x] 文件存在性
- [x] 接口签名匹配
- [x] 功能完整性
- [x] 接口自洽
- [x] 错误处理
- 全部通过: 是
```

**完整示例 — build-shared-types 任务（DONE_WITH_CONCERNS 状态）：**

```markdown
# 完成报告 — build-shared-types

**状态**: DONE_WITH_CONCERNS

## 产出文件清单
- src/auth/types.ts — 定义了 CreateUserRequest、UserResponse、ApiError、PaginatedResponse 四个类型
- src/auth/index.ts — 重导出所有类型，作为公共入口
- .task-manifest/outputs/build-shared-types/interface-declaration.md — 声明了 4 个接口，覆盖合约全部要求
- .task-manifest/outputs/build-shared-types/self-check.md — 6 项自检全部通过

## 自检结果
- [x] 文件存在性
- [x] 接口签名匹配
- [x] 功能完整性
- [x] 接口自洽
- [x] 错误处理
- 全部通过: 是

## 已知担忧 (DONE_WITH_CONCERNS 时填写)
- 担忧: ApiError.details 定义为 `Record<string, unknown>`，前端的错误展示组件可能需要更具体的类型 — 影响: 前端类型安全性可能不足
- 担忧: 未验证 PaginatedResponse 的泛型在运行时与后端响应结构完全匹配 — 影响: 运行时可能出现类型断言失败
```

### 产出物汇总

| 文件 | 存放路径 | 阶段 | 用途 |
|------|----------|------|------|
| interface-declaration.md | .task-manifest/outputs/{task-id}/ | 声明 | 接口承诺 |
| 实际代码/产出文件 | 合约中指定路径 | 实现 | 实际产物 |
| self-check.md | .task-manifest/outputs/{task-id}/ | 自检 | 自检清单 |
| completion.md | .task-manifest/outputs/{task-id}/ | 完成 | 完成信号 |

### 核心约束速查

| 规则 | 说明 |
|------|------|
| 声明先于实现 | 没写 interface-declaration.md 就写代码 = 违规 |
| 签名即承诺 | 修改函数签名必须同步更新声明 |
| 自检不通过不交活 | self-check.md 必须全部 [x] |
| 输入缺失不猜测 | 输入文件不存在或内容不足 → 向主智能体提问 |
| 范围不蔓延 | 不修改合约中未列出的文件 |

## 后置更新步骤

1. 确认所有 3 个元文件已生成（interface-declaration.md、self-check.md、completion.md），且实际代码产出已完成
2. 确认 self-check.md 全部 [x]
3. 确认元文件路径正确
4. 向主智能体报告完成

## 快速参考

| 你遇到了什么情况 | 怎么做 |
|-----------------|--------|
| 开工前不确定从哪里开始 | 阶段 1：读取合约 → 确认输入 |
| 不知道该导出什么 | 看合约中的 outputs.exports |
| 发现合约中的签名定义有问题 | 在声明中标注风险，继续按合约声明 |
| 实现中发现需要多建一个文件 | 停止 → 更新声明 → 反馈主智能体 |
| 输入文件的内容不够支撑实现 | 向主智能体提问 |
| self-check 发现签名不匹配 | 代码错→改代码；声明错→更新声明 |

## 常见错误

| 错误 | 为什么错 | 正确做法 |
|------|---------|---------|
| 跳过阶段2直接写代码 | 「集成验证与修正」没有声明文件就无法验证 | 先写 interface-declaration.md |
| 输入文件不存在时自己猜 | 猜测的接口与实际不一致→集成崩 | 向主智能体提问 |
| self-check 造假 | 「集成验证与修正」检查诚实度→标记不可信 | 诚实自检，没通过就修 |
| 修改代码后忘记更新声明 | 声明和实际不一致→接口不匹配 | 改代码前先想：声明需要同步更新吗 |
| 产出超出合约范围不告知 | 范围蔓延→可能与其他子任务冲突 | 先反馈，获确认后再做 |
| 完成报告中没有写已知问题 | 「集成验证与修正」和后续维护者不知道限制 | 诚实记录 |

## 危险信号 — 停下重新检查

- interface-declaration.md 的接口表格为空 → 你还没有理解自己的任务
- 声明中的文件数少于合约 outputs 数 → 没有覆盖合约要求
- self-check.md 中有未勾选项但你正在写 completion.md → 跳过了修正步骤
- 实际代码引用了合约和声明都未列出的外部模块 → 引入了隐藏依赖
- prompt 中没有找到自己的 task-id → 可能在做错误的任务

## 完成标志

- [ ] interface-declaration.md 已写入，覆盖合约所有 outputs
- [ ] 所有代码/文档产出文件已创建，内容完成
- [ ] self-check.md 已写入，全部项目 [x]
- [ ] completion.md 已写入，产出清单完整
- [ ] 所有元文件在 .task-manifest/outputs/{task-id}/ 下
- [ ] 已向主智能体报告完成
