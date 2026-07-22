---
name: 任务拆解与派发
description: Use when 面对任何非平凡的多步骤任务时，agent 应主动调用本 skill 评估是否需要拆解为并行子任务。适用于所有任务类型——编码、写作、研究、设计、规划、数据处理。触发信号：涉及多个产出物、任务存在可自然分离的子目标、预估需要多个独立步骤、或用户一次请求中描述了多项工作。核心原则：宁可误触发后判定"不需要拆解"，也不因跳过而串行执行可并行的任务。不触发仅限：单一原子操作、简单问答、纯信息查询。
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
  - Agent
  - Glob
  - Grep
  - Bash
  - PowerShell
---

## 触发场景

### 显式触发（用户主动要求）
- 用户说"拆成子任务""并行处理""分给多个智能体""并行化""同时做""分别做"
- 用户说"任务拆解""先拆再派发""并行派发""一起做""都做"
- 用户说"把这个任务拆开并行执行"
- 用户一次请求中描述了多项互不依赖的工作（如"帮我创建 A、B、C 三个文件"）

### 隐式触发（agent 主动判断，满足任意 1 条即触发评估）
> **核心心态：本 skill 的职责是"评估是否需要拆解"，不是"确认需要拆解后才触发"。** 触发后第一步是分析任务，分析结果可以是"不需要拆解，直接做"——这也是合法输出。宁可多触发一次评估，也不错过一个可并行的任务。

1. 任务涉及 **多个产出物**（文件、章节、设计稿、报告、数据表……不限于代码）
2. 任务描述中存在 **可自然分离的子目标**（逻辑上可拆分即满足，不要求产出物数量已确定）
3. 预估任务需要 **≥3 个独立步骤**（独立步骤 = 产生独立中间产出物且可被后续步骤直接引用的步骤。仅产生内存中间值的步骤不计入）
4. 用户请求中描述了多项工作（即使只用"和""还有"连接，未用显式并行关键词）

### 不触发（反例）
- 单一原子操作（改一行字、查一个数、问一个事实）→ 直接做
- 步骤间存在运行时数据依赖（后一步需要前一步的运行时输出作为输入，而非仅依赖其产出文件/类型定义）→ 不拆，串行执行
- 简单的问答、搜索、解释 → 不需要拆解
- 用户只要求 1 个产出物且该产出物不可再分 → 不触发

## 触发边界与 skill 选择指南
- 本 skill 是**前置评估器**：agent 接到任何非平凡任务时，先调本 skill 评估复杂度，再决定是拆解并行还是直接执行
- 如果评估后判定"不需要拆解"→ 这也是合法输出，直接继续执行任务即可
- 如果已是正在进行的拆解任务，用户说"调整粒度""合并某两个任务" → 回到第二步，不走完整流程

## 必需要素

- 用户的复杂需求描述
- 项目上下文（文件结构、技术栈、已有代码）— 主智能体提前读取

## 推荐要素

- 用户对粒度的偏好（粗拆 / 细拆）
- 已知的技术约束（语言、框架、文件命名规范）

## 前置强制步骤

> **核心原则：合约先于执行。** 接口合约是子任务之间的"法律文件"——先定义，后派发。

1. **读取项目上下文**：了解已有代码结构、技术栈、文件布局。如果项目有 CLAUDE.md，读取了解项目约定
2. **确认需求清晰度**：如果用户需求中存在模糊点，先用 AskUserQuestion 追问（最多 3 轮）

## 关联Skill

| 方向 | 关联对象 | 关系 |
|------|---------|------|
| 输入 ← | 智能体闭环开发 | 智能体闭环开发在阶段 3 判断任务复杂度后，满足条件时调用本 skill |
| 输出 → | 子智能体执行协议 | 拆解完成后生成 prompt 模板，引用子智能体执行协议作为子智能体的工作规范 |
| 输出 → | 集成验证与修正 | 产出的 task-contract.yaml 是集成验证与修正的验证依据 |

---

## 目标

帮助主智能体分析用户需求，将其拆解为最少 2 个、最多 12 个隔离子任务，为每个子任务定义精确的接口合约，生成标准化 prompt 模板，经用户审批后派发。

## 执行流程

### 第一步：需求分析

- 读取用户需求，识别隐含的子目标和约束
- 检查项目上下文（已有代码结构、技术栈、文件布局）
- 如果需求不清晰：用 AskUserQuestion 追问（最多 3 轮），每次一个问题
- 将需求压缩为一句话核心目标 + 关键约束列表

### 第二步：模块化拆解

将需求拆成功能/模块单元。对每个候选单元用三个标准判断：

- **职责单一性**：这个单元只做一件事吗？
- **依赖隔离性**：这个单元是否可以不等待其他单元的结果就开工？
- **接口可定义性**：这个单元的输出能否精确描述（文件路径、导出签名）？

用拓扑排序分层：第 0 层（depends_on 为空）→ 全部可并行；第 1 层（仅依赖第 0 层产物）；第 N 层 → 后续层

约束：
- 最少 2 个，最多 12 个子任务。**超过 12 个→强制阻断**，拒绝生成合约，提示用户合并任务
- **少于 2 个→强制阻断**，但阻断前需先确认：第一步分析是否真的判定了需要拆解？（如果判定"不需要拆解"，应已在第一步出口结束本 skill，不应到达此步。如果到达此步但只有 0-1 个子任务，说明第一步的拆解判定有误——回第一步重新评估，输出"评估结论：此任务无需拆解，建议直接执行"。）
- 每个子任务必须有至少一个确定的输出文件。**例外**：纯副作用任务（如数据库迁移、通知发送、配置变更）允许 `outputs: []`，但必须在 description 中标注 `[副作用任务]` 前缀，且 verification 至少包含一个可验证的检查项（如 `test_passes` 或手动验证步骤）
- 依赖关系不能形成环

**合约生成时的自动验证**（写入 `.task-manifest/task-contract.yaml` 之前必须执行）：
1. **任务数量检查**：如果 tasks 列表 <2 → 阻断，提示任务不需要拆解；如果 tasks 列表 >12 → 阻断，提示合并
2. **依赖有效性检查**：每个 `depends_on` 中的 task-id 必须在 tasks 列表中存在 → 不存在的引用阻断
3. **依赖环检查**：对 depends_on 图执行拓扑排序，无法生成合法拓扑序 → 阻断，报告环路径
4. **输出路径唯一性检查**：收集所有 `outputs[].file`，如果有重复路径 → 阻断，报告冲突
5. **自引用检查**：每个 task 的 depends_on 不能包含自己的 task-id（task-3 不能依赖 task-3）

### 第三步：定义接口合约

自动验证通过后，写入 `.task-manifest/task-contract.yaml`。合约格式用 YAML。以下是一个完整的 **user-auth-system 3 任务合约示例**：

```yaml
project: user-auth-system
generated: "2026-07-10T14:30:00Z"
tasks:
  - id: build-shared-types
    description: 定义认证系统所需的全部共享 TypeScript 类型
    depends_on: []
    inputs:
      - file: docs/api-spec.md
        section: "Data Models"
        description: 认证相关的数据模型定义
    outputs:
      - file: src/auth/types.ts
        type: typescript-module
        exports:
          - name: Session
            signature: "interface Session { id: string; userId: string; expiresAt: Date; token: string }"
          - name: UserCredentials
            signature: "interface UserCredentials { email: string; password: string }"
          - name: AuthResult
            signature: "type AuthResult = { success: true; session: Session } | { success: false; error: string }"
    verification:
      - file_exists: "src/auth/types.ts"
      - export_matches: "Session"
      - export_matches: "UserCredentials"
      - export_matches: "AuthResult"

  - id: build-auth-logic
    description: 实现认证核心逻辑——登录、登出、token 验证
    depends_on: [build-shared-types]
    inputs:
      - file: src/auth/types.ts
        description: build-shared-types 产出的类型定义
      - file: docs/api-spec.md
        section: "Auth Endpoints"
        description: 认证 API 端点规格
    outputs:
      - file: src/auth/index.ts
        type: typescript-module
        exports:
          - name: createSession
            signature: "(credentials: UserCredentials) => Promise<AuthResult>"
          - name: validateToken
            signature: "(token: string) => Promise<boolean>"
          - name: destroySession
            signature: "(sessionId: string) => Promise<void>"
    verification:
      - file_exists: "src/auth/index.ts"
      - export_matches: "createSession"
      - export_matches: "validateToken"
      - export_matches: "destroySession"

  - id: build-auth-middleware
    description: 实现 Express/HTTP 认证中间件
    depends_on: [build-shared-types, build-auth-logic]
    inputs:
      - file: src/auth/types.ts
        description: 类型定义
      - file: src/auth/index.ts
        description: 认证核心逻辑的导出签名
    outputs:
      - file: src/auth/middleware.ts
        type: typescript-module
        exports:
          - name: authMiddleware
            signature: "(req: Request, res: Response, next: NextFunction) => Promise<void>"
          - name: requireRole
            signature: "(role: string) => (req: Request, res: Response, next: NextFunction) => Promise<void>"
    verification:
      - file_exists: "src/auth/middleware.ts"
      - export_matches: "authMiddleware"
      - export_matches: "requireRole"
```

**副作用任务示例**（outputs 为空，verification 用 test_passes）：

```yaml
  - id: run-db-migration
    description: "[副作用任务] 执行数据库迁移脚本，将 user 表升级到 v2 schema"
    depends_on: [build-shared-types]
    inputs:
      - file: src/auth/types.ts
        description: 需要知道最新的类型定义以验证迁移兼容性
    outputs: []  # 纯副作用任务，无产出文件
    verification:
      - test_passes: "npx prisma migrate deploy --name user-v2"
```

**合约规则：**
- 每个 output.file 必须是确定的路径（不允许通配符）
- 每个 output.export 的 signature 是其他子任务引用该接口的唯一依据
- depends_on 中引用的 task-id 必须在 tasks 列表中已存在，不可自引用，不可形成环

### 第四步：生成任务拓扑（给人看）

写入 `.task-manifest/任务拓扑.md`。包含：依赖拓扑图（文本）、并行批次表、接口耦合点标注、风险标注。

使用 user-auth-system 示例展示完整拓扑：

```markdown
# 任务拓扑 — user-auth-system

## 依赖拓扑图

```
                   +-----------------+
                   | build-shared-types|
                   | (第0批, 类型定义) |
                   +--------+--------+
                            |
                   +--------+--------+
                   |  build-auth-logic |
                   | (第1批, 核心逻辑) |
                   +--------+--------+
                            |
                   +--------+-----------+
                   | build-auth-middleware|
                   | (第2批, HTTP中间件)  |
                   +--------------------+
```

## 并行批次表

| 批次 | 层级 | 任务 | 说明 |
|------|------|------|------|
| 第0批 | 0 | build-shared-types | 无依赖，可立即启动 |
| 第1批 | 1 | build-auth-logic | 依赖 build-shared-types |
| 第2批 | 2 | build-auth-middleware | 依赖 build-shared-types 和 build-auth-logic |
```

补充示例（含并行任务）：
```
第0批（无依赖，可并行）: [task-1: 设计数据模型] [task-2: 搭建项目骨架]
第1批（依赖第0批）:    [task-3: 实现 API]  [task-4: 实现前端页面]
第2批（依赖第1批）:    [task-5: 集成测试]
```

### 批次执行说明

- **第0批**：可同时启动所有第0层任务（本示例1个）
- **第1批**：等待第0批产出就绪后启动（本示例1个）
- **第2批**：等待第1批产出就绪后启动（本示例1个）

## 接口耦合点

| 输出任务 | 输出文件 | 被依赖的任务 |
|----------|---------|-------------|
| build-shared-types | src/auth/types.ts | build-auth-logic, build-auth-middleware |
| build-auth-logic | src/auth/index.ts | build-auth-middleware |

### 耦合风险分析
- **build-shared-types** 是唯一共享耦合点——如果它的导出类型发生变化，下游两个任务都需要同步调整
- **build-auth-logic** 的签名一旦在合约中确认，build-auth-middleware 的实现就可以基于签名独立开发，不等待 build-auth-logic 的真实实现

## 风险标注

| 风险 | 级别 | 说明 |
|------|------|------|
| 共享类型变更 | 中 | types.ts 被两个下游任务依赖，变更需通知所有依赖方 |
| 中间件接口耦合 | 低 | middleware 调用 createSession/validateToken，签名已在合约中确认 |
| 单点阻塞 | 中 | 3 个任务链式依赖，任一任务延期直接影响下游 |
```

### 第五步：生成子任务 prompt 模板

为每个子任务生成 `.task-manifest/prompts/task-{id}.md`。模板包含：任务描述、依赖关系、输入文件表、输出接口表、验证标准、工作协议（引用「myworkflow:子智能体执行协议」的 5 阶段）、约束。

使用 build-shared-types 作为完整 prompt 示例：

```markdown
# 子任务：build-shared-types

## 任务描述
定义认证系统所需的全部共享 TypeScript 类型。本任务是整个认证系统的类型基础，所有类型必须精确、无歧义。

## 依赖关系
- **依赖的任务**：无（第0批，可立即启动）
- **本任务产出被以下任务依赖**：build-auth-logic, build-auth-middleware

## 输入文件

| 文件 | 章节/位置 | 描述 |
|------|----------|------|
| docs/api-spec.md | "Data Models" | 认证相关的数据模型定义 |

## 输出接口

| 导出名 | 签名 |
|--------|------|
| Session | `interface Session { id: string; userId: string; expiresAt: Date; token: string }` |
| UserCredentials | `interface UserCredentials { email: string; password: string }` |
| AuthResult | `type AuthResult = { success: true; session: Session } \| { success: false; error: string }` |

## 验证标准

- [ ] 文件 `src/auth/types.ts` 已存在
- [ ] 导出了 `Session`
- [ ] 导出了 `UserCredentials`
- [ ] 导出了 `AuthResult`
- [ ] 所有类型签名与合约完全一致

## 工作协议

请遵循「myworkflow:子智能体执行协议」的 5 阶段工作规范：
1. **读取合约 + 确认输入**：读取 `.task-manifest/task-contract.yaml` 中你的条目和所有输入文件，确保充分理解
2. **声明接口**：先写 `.task-manifest/outputs/{task-id}/interface-declaration.md` 承诺你的接口——声明先于实现
3. **产出实现**：按声明逐项编码，每完成一个文件在声明中勾选
4. **自检**：写 `.task-manifest/outputs/{task-id}/self-check.md`，逐项核对，全部打勾才能进入下一步
5. **完成报告**：写 `.task-manifest/outputs/{task-id}/completion.md`，列出产出文件和自检结果

## 约束

- 只修改/创建本任务指定的输出文件，不修改其他模块
- 导出的签名必须与合约完全一致（下游任务依赖精确签名）
- 文件路径必须精确匹配：`src/auth/types.ts`
```

### 第六步：用户审批

展示审批摘要：

> "共拆分为 {N} 个子任务，分 {M} 个并行批次。第 0 批（{X} 个，可同时启动）：{task-id 列表}。审批通过后将派发给 {N} 个子智能体并行执行。是否批准？"

**如果用户批准**：进入第七步，按拓扑顺序派发。

**如果用户拒绝或要求调整**：回到对应步骤——
- 粒度太细/太粗 → 回第二步（合并或拆分任务）
- 接口定义不对 → 回第三步（修改合约中对应条目）
- 依赖关系有误 → 回第二步（调整 depends_on），然后重新生成合约和拓扑
- 用户有新的约束 → 回第一步（重新分析需求）
调整后重新走第四、五、六步（更新拓扑、prompt、重新审批）。直到用户批准才进入第七步。

### 第七步：派发子智能体

用户批准后按拓扑顺序派发。每个子智能体的 Agent prompt **必须**包含以下精确引用（直接复制，替换 {task-id}）：

```
你必须遵循「myworkflow:子智能体执行协议」。你的 task-id 是 {task-id}。
先读取 `.task-manifest/prompts/task-{task-id}.md` 了解任务，
再读取 `.task-manifest/task-contract.yaml` 找到你的合约条目，
然后严格按 5 阶段协议工作：阶段 1：读取合约+确认输入。先读取 `.task-manifest/prompts/task-{task-id}.md` 了解任务，再读取 `.task-manifest/task-contract.yaml` 找到你的合约条目，逐一读取 inputs 中的文件路径。阶段 2-5 声明接口→产出实现→自检→完成报告。
```

不可省略或改写此引用模板——它确保子智能体正确触发「myworkflow:子智能体执行协议」。

**派发失败降级**：单次 Agent 调用失败 → 重试 1 次（间隔 5 秒）；仍失败 → 该任务降级为串行由主智能体直接执行；主智能体也无法执行 → 报告用户并列出未派发任务列表。

---

## 后置更新步骤

1. 确认 `.task-manifest/` 目录已创建
2. 确认用户已审批
3. 确认所有 prompt 模板已生成
4. 派发第 0 批子智能体
5. 监控所有子智能体的 completion.md：全部就绪后触发「myworkflow:集成验证与修正」；若派发后超 30 分钟仍有缺失则同样触发（集成验证会处理缺失场景）
6. 收到子智能体的依赖超时报告后，立即检查依赖任务状态。如依赖方崩溃，不等 30 分钟立即触发集成验证与修正。

---

## 快速参考

| 你在做什么 | 看哪里 |
|-----------|--------|
| 首次拆解一个复杂任务 | 第一步 → 第七步全部走完 |
| 只想看合约格式 | 第三步：接口合约模板 |
| 不确定某个模块要不要拆 | 第二步：三个判断标准 |
| 想看完整示例 | 第三步中的 user-auth-system 示例 |

---

## 常见错误

| 错误 | 为什么错 | 正确做法 |
|------|---------|---------|
| 所有任务都放在第 0 批 | 意味着没有识别出真正的依赖关系 | 诚实标注依赖 |
| 依赖形成环（A 依赖 B，B 依赖 A） | 两个模块互相等待——永远无法开工 | 拆出一个共享模块 C |
| 接口签名写成"见代码"或"待定" | 模糊的签名等于没有合约 | 签名必须精确到参数名和类型 |
| 跳过用户审批直接派发 | 拆解方案影响全局 | 第六步不可跳过 |
| 子任务超过 12 个 | 粒度过细——管理成本超过并行收益 | 合并相关任务 |
| 忘记生成任务拓扑 | 只有合约没有拓扑，用户无法审批 | 第四步必须执行 |

---

## 危险信号 — 停下重新检查

- 所有子任务的 depends_on 都为空 → 要么太简单，要么没认真分析依赖
- 合约中某个 output.file 出现在两个子任务中 → 互相覆盖文件（自动验证已阻断，此信号用于手动检查场景）
- 某个子任务的 inputs 为空且 depends_on 非空 → 依赖关系可能不真实
- 用户说"你定就行"但不审批 → 核心拆解方案不能由 AI 拍板
- 合约中出现通配符路径 → 接口不可验证
- **`.task-manifest/task-contract.yaml` 被意外删除** → 所有子智能体和「myworkflow:集成验证与修正」无法工作。恢复路径：（1）检查 git 历史 `git log -- .task-manifest/task-contract.yaml`（2）如果 git 中有→`git checkout` 恢复（3）如果没有→必须重新走本 skill 的第三步生成合约。子智能体的实际代码产出不受影响，新合约可以直接引用已有文件路径

---

## 完成标志

- [ ] 需求已分析，模糊点已追问（如有）
- [ ] 子任务列表已生成（2-12 个）
- [ ] `.task-manifest/task-contract.yaml` 已写入，所有字段完整
- [ ] 依赖拓扑无环
- [ ] 任务拓扑.md 已写入，包含风险标注
- [ ] 每个子任务的 prompt 模板已生成
- [ ] 用户已审批拆解方案
- [ ] 第 0 批子智能体已派发
