---
name: 子智能体执行协议
description: Use when 要建 agent 团队、分派模块成员、处理成员/执行者事件与回执、或核对横向交付合约与补位规则时加载。
---

## 核心流程：建团队委托 → 成员自治 → 执行者交回 → 验收

**何时加载**：把可独立交付的产物（module/object/evidence-package）交给模块成员端到端负责，或成员要启动执行者、判断 ready/阻塞时。**不加载**：普通问答、单件小事、无独立交付物的讨论。

**硬步骤**
1. **建团队与委托**：leader 用 `team_define` 登记、`team_member_create` 建常驻成员（模块责任与 `writeScopes`）、`team_mission_assign` 只给目标/边界/输入/验收 → 不逐批派活、不代写 work/plan。
2. **成员自治**：member 用 `team_plan_submit` 提交为自己 work（CAS）、`team_dispatch_authorize` 授权、`team_subagent_start` 启动执行者；一份交付物一个 owner → 依赖带 version + requires，未 ready 不启动，满额保持 ready。
3. **执行者交回**：leaf 用 fresh 上下文接最小任务包，一次实现并自检，用 `team_work_report` 交回真实产物与证据（`attemptId`+`leaseEpoch`）→ 缺输入、改接口、跨模块找 `team_ask_owner`，不越界、不建同级成员。
4. **验收与补位**：owner 用 `team_work_verify` 按验收条件核验；任一结算由调度器补位，无全批屏障 → 超时判进展，「未知/暂停」≠ 失败，迟到回执只归档。
5. **收尾**：缺陷原 owner 修，集成由 leader 与 owner 共担 → 阻塞按 记录→就地取材→补适配器→绕行→needs_user 推进，权限拒绝不绕过。

### 运行时异常处置协议（5 条）

**异常处置**：成员不可达先 inspect 冷恢复补派、不新建；写冲突定单写者；owner failed 由新 owner 新 work 复核，旧 work 留 awaiting_verification；租约陈旧换 self/plain 不重试；投递失败 cold-resume → plain-subagent。

**完成判据**：产物 + 验收映射 + 可核查证据（命令/输出、路径、版本）；idle、超时、非空文件、只说不做都不算完成。
**模板非结算前提**：self-check/completion 可选用；结算以真实产物 + report/verify + runId 为准。

## 触发

- **角色**：leader（登记团队、建模块成员、下**模块委托**、做全局集成；**不替成员写 work/plan**）／member（**持续存在的模块负责人**：自己的 Session、自己的队列、自己的模块知识与验收责任；自己规划、自己提交独立交付项、自己授权派发、自己处理回执与验收）／leaf（member 用 `team_subagent_start` 定向启动的 continuable 执行者，向自己的 owner 回报与求助）。
- **触发场景**：需要为一份可独立交付的产物（module 模块 / object 对象 / evidence-package 证据包）指定唯一 owner，并由该 owner 端到端跑完调查→实现→自检→修复→验收。
- **不触发**：普通问答、单件小事（如"检查语法错误"）、没有可独立交付产物的临时讨论。

## 目标

规范 **agent team** 协作：leader 建团队、给目标与边界；member 作为模块 owner 端到端负责；member 的执行者（continuable leaf）在最小任务包内完成工作。产出可验证的接口、可追溯的声明、可审计的自检记录，并保证**结算即由常驻调度器补位、不空等、不越权**。核心原则：**声明先于产出，声明即承诺；一份交付物一个 owner（member），执行者是它自己的 child。**

## 关联技能

输入 ← leader 下的**模块委托**（`team_mission_assign`：goal / boundaries / inputs / budget / acceptance）与 member 自己用 `team_plan_submit` 提交的 work（deliverable / outputs / acceptance / writeScopes / 依赖 version+requires）；输出 → 交付物 + 证据包 + 回执（`team_work_report`），由 **owner 用 `team_work_verify` 核验**后再做全局集成。加载技能统一写 `skill(name="myworkflow-xxx")`。

## 一、横向交付合约（切分方式）

按**可独立交付的产物**切分，而不是按阶段切分：

| 切分单元 | 说明 | owner 责任 |
|---------|------|-----------|
| module | 一个可单独编译/加载的模块 | 从调查到验收全程 |
| object | 一个可单独验证的对象（配置、数据结构、契约文件） | 从调查到验收全程 |
| evidence-package | 一组来源、数据与结论组成的证据包 | 从采集到结论全程 |

**每份交付物由一个 owner 端到端负责：调查 → 实现 → 自检 → 修复 → 验收。**

**禁止阶段接力**：拒绝「背景调查 → 设计 → 检查」或「计划 → 编码 → 审查」这类让同一交付物被多个角色分段接手的排法。若发现 leader 这样拆，给出**横向重排建议**：把阶段折叠进同一交付物，由同一 owner 连续完成；只有当某一段能独立交付（有自己的接口与验收标准）时，才允许升格为独立交付物并另配 owner（提交新工作项时会被 `PHASE_RELAY_SPLIT` 拒绝）。

**继续既有任务：先复用事实与已解决的错误，再动手**（同一交付物续做沿用原 `workId` + 原 `ownerMemberId`，不靠改 title/kind 开新流程）：

- **已确认事实直接复用**：已冻结的接口版本、已定方案、已排除的做法与原因、已确认的验收条件——不再重新调查，也不再重新征求同意。
- **已解决的错误不重踩**：错误指纹（`code` / `message` / 失败命令）已存在时，不重跑同一个失败；只有**条件变了**（输入、参数、版本、权限来源、调用方）才重试，并在回执里写清改了什么。
- **事实进产物与回执**：新增结论追加进该任务已有的产物，或写进 `team_work_report` 的 `summary` / `unresolved`；不要另开一份长文档让下一个人重读。

## 二、组织形态与启动流程

协作模型（以本插件实现为准）：**1 leader + x 模块成员 + 各成员自己派发的 continuable 子智能体**。

- **leader 只给模块委托**：`team_define`（登记受管团队）→ `team_member_create`（建模块成员：写明模块责任与 `writeScopes`，默认 `fresh` 上下文）→ **`team_mission_assign`**（对该成员下模块委托；**不产生可调度项**）。leader **不逐批派活**，也不替成员写 work/plan。
- **常驻 Host 调度器负责补位**：工作项提交后由调度器按 ready 与容量推进；成员当前 turn 停止、pane 被隐藏，都不影响成员本身（成员有自己的 Session 与队列）。
- **owner 是 member，执行者是 child**：work 由 **member 自己**用 `team_plan_submit` 提交（原子、`planRevision` 递增 CAS）并拥有；实际执行者是该成员用 `team_subagent_start` **定向**启动的 continuable 执行者（校验 team+actor+owner+workId+planRevision+授权+readiness，只预留该 work）。
- **启动顺序**：member 规划（`team_plan_submit`）→ 授权派发（`team_dispatch_authorize`）→ `team_subagent_start` 定向预留 attempt 与容量后启动 → `team_work_report` 结算 → owner `team_work_verify` 验收。回执必须带匹配的 `attemptId` + `leaseEpoch`，否则只归档为迟到结果，不覆盖新版本。
- **满额时拒绝并保持 ready**（`CAPACITY_FULL`）：不排队空等，也不用一次性旁路绕过容量上限。
- **未 ready 不启动**：依赖未满足、输入缺失的工作项一律不启动；也不允许"先启动再空等依赖"。
- **停止要指明范围**：`team_interrupt` 的 `scope=turn` 只停目标执行者当前模型回合（工作项回到 ready），`scope=members` 停每个成员当前回合并保留队列，`scope=team` 取消整队。停止 leader 自己的 turn 不影响成员。
- 需要相邻视角或澄清时：member 用 `team_message`；leaf 用 `team_ask_owner`（`team_message` 对 leaf 会被拒）。等待状态变化用 `team_wait`（先登记等待再核对，不忙轮询）。

## 三、leaf 的最小任务包

leaf 用 **fresh 上下文**接收最小任务包，不要 fork leader 全聊天再让它重读全部历史。任务包必须包含且只包含：

| 字段 | 内容 |
|------|------|
| 目标 | 这份交付物要达成什么（一句话 + 成功判据） |
| 边界 | 可以改哪些文件/目录；不可触碰的范围 |
| 输入证据路径 | 需要读的文件、来源、证据编号 |
| 接口版本 | 上游依赖的 version 与 requires（published-interface 或 verified-result） |
| 输出位置 | 交付物与证据包的落盘路径 |
| 验收 | 验收标准、自检项、由谁复核 |
| 必要约束 | 技术栈、命名、格式、安全与权限约束 |

**leaf 的权限边界**：

- 不得代表 member 修改**别人**的任务；不得创建同级成员（要新成员须由 leader 走 `team_member_create`）。
- 不得扩大范围：只做任务包内的交付物，需要越界先回报 member。
- **调查 + 实现 + 自检 + 修复全在 leaf 内部完成**，不设「调查员交报告给开发员」的接力。
- **求助与回报走自己的 owner**：缺输入、要改接口、跨模块问题 → `team_ask_owner`（**只投向自己的 owner**，入队并唤醒 owner）；正常交回结果用 `team_work_report`。全量 `team_message` **对 leaf 不可用**（会被拒），需要跨成员协调时由 owner 用 `team_message` 与其他成员协商。

## 四、依赖规则

- 依赖**只允许存在于不同交付物之间**；同一交付物内部不得拆成互相依赖的子任务。
- 每条依赖必须写清 **version + requires**：`requires: published-interface@v1`（上游已发布接口）或 `requires: verified-result@v2`（上游已验证结果）。缺任一者，依赖视为未满足。
- 上游未发布/未验证 → 本交付物保持 ready 但不派发，不空等。
- 跨文件但同属一份交付物 → 不拆，由同一 owner 一并改完。

## 五、事件驱动滚动补位（由常驻调度器执行）

- **任一项结算就立即补位**：一次 `team_work_report` 到达，调度器就重算 ready 并补位，不等同批其它任务。
- **无全批屏障、无整层等待**：不存在"等这一层全部完成再进下一层"。慢任务不阻塞其它 ready 项。
- leader 与 member 都不做记账式轮询：用 `team_snapshot` 看 ready、在飞与容量，用 `team_wait` 等下一次变化（超时只表示这段时间没有变化，不代表失败）。
- 交付物粒度与顺序以工作项为准；成员按自己的队列推进，不重复提交同一交付物。

## 六、超时与失败

**超时先判断进展与可恢复性，再决定动作**：

| 观察到 | 判定 | 动作 |
|--------|------|------|
| 有新增产出/新增日志/部分证据 | 仍在推进 | 继续等待或延长，不判失败 |
| 无进展但状态可恢复（进程存活、可续跑） | 状态未知/暂停 | 记录最后进展，用 `team_wait` 继续观察或 `team_recover` 恢复 |
| 无进展且不可恢复（进程消失、输入已消失） | 真正失败 | 记录确切失败并进入阻塞处理顺序 |

**「状态未知/暂停」与「真正失败」严格分开，超时不等于失败。** 不许以固定秒数（如"超过 300 秒即判失败"）作为判据。

## 七、收尾与集成

- **同一 owner 收尾修复**：交付物的缺陷由原 owner 修复，不撤走前面的人换一个无上下文的审查员重跑后半程。
- **全局集成由 leader 与相关 owner 共同负责**：leader 组织集成，相关 owner 提供接口与证据并参与联调验收。
- 不设「独立审查接力」（派新审查员接管完整任务的后半程）；复核只做增量校验，不接管交付物本身。

## 八、阻塞处理顺序

按顺序执行，不得跳步：

1. **记录**：确切失败信息、已尝试的动作、影响范围、当前仍可做的部分。
2. **排查现成资源**：已装服务、源码、现成工具、当前权限。
3. **能补齐就补齐**：能写适配器 / 接口 / 本地桥接解决的，当场补齐。
4. **局部阻塞先绕行**：先做其它 ready 项，并把 blocker 精确挂到受影响的交付物上。
5. **确实需要外部账号、人工决策或无法获得的资源** → 标记 `needs_user`，并给出已尝试路径与最小下一步。

约束：不得固定「试三次就结束」，也不得无预算地无限重试同一失败；**权限拒绝不可绕过**，不要用变通手段回避已拒绝的操作。

## 九、用户授权与提问

- 用户授权任务内的**可逆开发不重复询问**；审批与扩权只有用户入口，模型没有等价工具，不要去申请等价权限。
- 只在**真正改变决策且项目里查不到**时才用 `ask_user_question` 向用户提问；其余情况自行查证或做最小可逆尝试。

## 十、证据诚实与结果分层

- 区分「已核实/有来源」与「推测/未核实」；不夸大，不无证据声称"验证通过"。没有证据就写"未验证"。
- **分层返回**：简短结论 + 可核查的 evidence/artifact refs 进 parent；原始材料留在文件或子会话里。
- 摘要必须包含：来源、版本、遗漏、不确定性、未完成项。

## 十一、执行流程（每个 leaf）

1. **读任务包 + 确认输入**：核对目标、边界、输入证据路径、接口 version + requires、输出位置、验收标准。输入缺失或依赖未 ready → 不猜测、不空等，回报 member。
2. **一次完整实现**：直接产出验收需要的完整实现。**不强制脚手架**——不要求先建空骨架/空文件/签名桩，也不强制 interface-declaration.md 之类的前置文档。产物按**验收最小必要**：能跑通、有可核查证据即可。
3. **开发期间核对**：先完成整份交付物或约定的大块产出；不按文件逐次启动测试。若用户要求全部开发后统一测试，跨模块测试门槛也必须遵守。只有**接口需要跨 owner 冻结**时才写可选的接口说明（模板见下），它不是前置仪式。
4. **自检**：验证命令与真实输出随交付物一起给出；**不强制**单独的 self-check.md——证据可以直接进回执的 `evidence`。未过不进结算。
5. **结算**：用 `team_work_report` 交回——**self 形态** `{workId, artifacts:[{path,version}], evidence:[{kind:"verification",ok:true,command}]}`（不带 attemptId）；**delegate 形态**带 `attemptId` + `leaseEpoch`。产物与证据写进回执，**不要求另写** completion.md。

### 阶段2 模板：interface-declaration.md

```markdown
# 接口声明 — {交付物名称}
> 本声明是我的接口承诺，验收与集成将据此核对。
> 声明时间: {ISO 8601 时间戳}

## 我将创建/修改的文件
- [ ] {文件路径} — {用途描述}

## 我将暴露的接口
| 名称 | 签名 | 所在文件 | 版本 |
|------|------|----------|------|
| {name} | {signature} | {file} | {version} |

## 我需要的外部输入（依赖）
| 交付物 | requires | version | 用途 |
|--------|----------|---------|------|
| {deliverable} | published-interface / verified-result | {version} | {说明} |

## 风险和假设
- {假设 1}
- {风险 1}
```

接口说明（**可选**，只在接口需要跨 owner 冻结时写）的规则：覆盖交付物全部 outputs（可多不能少）；签名与约定一致；约定签名有问题 → 在风险中标注并按约定实现；写入后不可秘密修改。不写接口说明不构成违规。

### 阶段4 模板：self-check.md

```markdown
# 自检报告 — {交付物名称}
> 自检时间: {ISO 8601 时间戳}

## 文件存在性
- [x] {file} — 存在且非空

## 接口签名匹配（与 interface-declaration.md 对比）
- [x] {name}: `{signature}` — 实际签名一致

## 功能完整性
- [x] {功能点}

## 接口自洽
- [x] 所有导出的函数/类型在同一个模块内有定义
- [x] 没有引用不存在的模块/文件 → 对每个 import/require 用 glob / read 验证
- [x] 没有孤立的导出 → grep 搜索每个导出名，确认被引用或属约定的 outputs

## 错误处理
- [x] {异常路径}

## 依赖核对
- [x] requires 的 version 与实际使用一致
```

自检规则：必须全部 [x] 才能进入结算；修正涉及接口 → 先更新声明；不造假。

### 阶段5 模板：completion.md，状态为四种之一

| 状态 | 含义 | 触发条件 |
|------|------|---------|
| **DONE** | 全部完成，对正确性有信心 | 全部实现、自检全过、无已知问题 |
| **DONE_WITH_CONCERNS** | 完成但有疑虑（诚实表达不确定；leader 应优先看这些疑虑） | 全部实现但存在：①正确性依赖未验证假设 ②边界处理不确定 ③某接口行为与预期不同 ④对 trade-off 有疑虑 |
| **NEEDS_CONTEXT** | 无法完成，缺关键信息 | 任务包信息不充分（错误处理策略未指定/目标平台未指定/接口签名有未定义参数等） |
| **BLOCKED** | 无法完成，被外部条件阻止 | 依赖交付物未就绪/工具或服务不可用/约定有不可修复矛盾；须附阻塞处理顺序中已走到哪一步 |

```markdown
# 完成报告 — {交付物名称}

**状态**: [DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED]

## 产出文件清单
- [文件路径] — [简述]

## 证据与引用
- 已核实: [来源/证据编号 → 结论]
- 未核实/推测: [内容 → 为什么无法核实]

## 自检结果
- [ ] 文件存在性
- [ ] 接口签名匹配
- [ ] 功能完整性
- [ ] 接口自洽
- [ ] 错误处理
- [ ] 依赖核对
- 全部通过: [是/否]

## 已知担忧 (DONE_WITH_CONCERNS 时填写)
- 担忧: [具体技术担忧] — 影响: [可能影响什么]

## 缺失信息 (NEEDS_CONTEXT 时填写)
- 缺失: [什么信息] — 影响决策: [哪个决策]

## 阻塞原因 (BLOCKED 时填写)
- 阻塞: [什么原因] — 已尝试: [按阻塞处理顺序走到第几步] — 最小下一步: [动作]
```

核心约束：**以真实产物与可核查证据为准**——是否完成看产物、命令输出与验收条件，不看有没有写某个声明文件；interface-declaration.md 只在**接口需要跨 owner 冻结**时作为可选记录，**不是前置仪式**，不写不构成违规。签名即承诺（改签名要同步通知相关 owner）；自检不通过不交活；输入缺失不猜测（用 `team_ask_owner` 回报）；范围不蔓延（不修改任务包未列文件）；未 ready 不启动、不空等。

## 十二、完成标志

- [ ] 交付物已按最小任务包定义的范围完成，产出文件齐备
- [ ] 跨 owner 接口需要冻结时，已记录 outputs 与依赖 version；无需为普通任务额外创建 interface-declaration.md
- [ ] 验证证据已写入回执；self-check.md 可选，不能用勾选代替真实命令结果
- [ ] 状态、未核实项及阻塞已如实回报；completion.md 可选，不以文件存在判定完成
- [ ] 已用 `team_work_report` 结算；后续补位由常驻调度器完成（leader 不逐批派活）
- [ ] 无越权：未替他人改任务、未创建同级成员、未绕过已拒绝的权限

## 成员执行与完成合同

用户禁止拆分完整流程时，由同一执行者完成调查到开发；允许团队时按独立交付物横向分工，不按调查/设计/编码/复核分段换人。owner 对成品、修复和验收持续负责。

leader 负责模块委托。member 按原 workId 与计划修订提交和授权；leaf 只执行最小任务包，遇到缺失输入用 team_ask_owner。不要绕过已拒绝的权限，也不要用新 workId 重新包装原失败。

继续既有任务先复用已确认事实和已解决的错误；核对错误指纹，只有输入、权限、版本或调用条件改变才重试，并记录变化。

先完成整份开发或约定的大块产出，按用户要求统一测试。开发过程可以读代码、检查输入和核对接口，不以此谎称功能已通过。验证未发生时记未验证；测试失败由原 owner 修复。

完成看真实产物、接口版本、验收映射和可信命令结果；interface-declaration.md、self-check.md、completion.md 均非必需，已有回执能承载证据就不另造文档。只有跨 owner 接口需要冻结时保留可追踪声明。

team_work_report 的 self/delegate 参数依据当前工具 schema；delegate 回执须匹配 attemptId/leaseEpoch，旧回执不能覆盖新修订；owner 用 team_work_verify 验收。按键成功、非空文件、idle、超时、子进程结束都不等于完成。

并发扩容前加载 myworkflow-task-dispatch 的高并发执行入口；实际 running、预留、未知状态分列，不把并发配置数当成果。
