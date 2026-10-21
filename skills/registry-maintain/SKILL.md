---
name: 专项注册表维护
description: Use when 要新增/改名/下线技能、更新技能清单、或对 skills catalog 做一致性校验时加载。
---

## 核心流程：读事实来源 → 增改删技能 → 一致性校验

**何时加载**：维护技能 catalog、增改删技能、核对技能清单、做一致性校验。**不加载**：正常调用某个技能做事（直接 `skill(name=...)`）；与 catalog 无关的代码开发与文档写作。

**硬步骤**
1. **认事实来源**：`glob components/*/component.json` 读三键、`grep` 查重与旧措辞残留、`skill(name=...)` 验真加载 → 判据：结论落到文件/加载器/运行时三处本机可核查来源；仓库根 skills/ 是冻结基线，不是事实来源。
2. **新增技能**：kebab-case 定名，建 components/<name>/（component.json + parts/*.md + 薄组件 + cordis.patch.yml 加一行）→ 判据：目录名 === name；frontmatter 只有 name/description/whenToUse；description 写能力 + 触发词，不写流程步骤（写了模型会跳过正文）。
3. **改名/下线**：目录名与 name 同时改，`grep` 旧名并逐处改写 → 判据：新名无重复、旧名零残留；下线先清全部引用再删目录，且必须有被替代/重复/失效的确切理由，不因「今天没人提」下线。
4. **跑十项一致性校验**：name 正则、目录名 === name、全 catalog 唯一、description 非空单行、whenToUse 单行、frontmatter 三键、references 无 frontmatter 且相对引用存在、skill 可加载、无旧措辞 → 判据：逐条给通过/不通过与依据。
5. **汇报**：新增 N / 改名 N / 下线 N / 未通过逐条 → 判据：汇报含来源与不确定性，未核实项标注，不无证据声称「校验通过」。

**读失败语义**：skill 没返回正文、glob 为空、team_snapshot 缺字段都属状态未知，先换路径复核，不等于技能不存在。

**完成判据**：三处来源都实读、校验清单逐条有结论、旧名零残留；证据=文件路径 + 行号、skill 加载结果、team_snapshot 字段（需运行时判断时）。

# 专项注册表维护（DSH 技能 catalog）

## 定位

维护本 bundle 的技能 catalog：**18 个组件**（每个技能一个组件行）。事实来源是原生 provider（按名加载读正文、只读线路读清单）与磁盘组件清单 `components/<name>/component.json` + `parts/*.md`；仓库根的 `skills/` 是**冻结的迁移基线**，**不是运行入口、也不是本 catalog 的事实来源**。

**迁移边界（硬性）**

- 不再维护 `config/special-skills.json` 一类注册表文件。
- 不再扫描、读取或写回旧宿主的插件清单与插件目录。
- 不再为任何技能声明工具白名单字段。

所有结论必须能落到三处本机可核查来源：文件、加载器、运行时。

## 事实来源与读取方法

| 来源 | 方法 | 能回答什么 |
|------|------|-----------|
| 文件系统 | `read` 组件清单 `components/<name>/component.json`；`glob` 枚举 `components/*/component.json` 与 `parts/*.md` | 有哪些技能、三键取值、parts 与 references 是否存在 |
| 全文检索 | `grep` | 旧措辞残留、重复 name、失效引用、跨技能引用 |
| 加载器 | `skill(name="myworkflow-xxx")` | 该技能能否真正加载、正文是否可读 |
| 运行时 | `team_snapshot` | 团队 / 成员 / 任务 / attempt / 容量 / 诊断 |

`team_snapshot` 是只读快照，用来回答「谁在跑、卡在哪一步、容量是否满」，**不是**技能清单来源。

**读失败时的读法**：`skill(name=...)` 没返回正文、`glob` 返回空、快照缺字段，都属于**状态未知**，不等于技能不存在或已损坏。先换一条路径复核（改读文件、改检索关键词、重取快照），再下结论。

## catalog 视图

| 字段 | 含义 | 来源 |
|------|------|------|
| name | frontmatter name，且等于目录名 | `read` |
| description | 单行中文：能力 + 触发词 | `read` |
| whenToUse | 单行中文：何时加载 | `read` |
| path | `components/<name>/`（resource base；正文在 parts，清单在 component.json） | `glob` |
| refs | `references/` 下文件清单（这些 .md 无 frontmatter） | `glob` |
| loadable | `skill(name=...)` 是否成功返回正文 | 加载器 |

## 操作清单

### A. 新增一个技能

1. **定名**：kebab-case，只含 `[a-z0-9-]`，首尾为字母或数字，无连续连字符；目录名与 name 完全一致。
2. **建骨架**：新技能 = **新组件** `components/<name>/`（`<name>.js` 薄组件 + `component.json` 清单 + `parts/*.md` 正文 + 可选 `references/`），并在 `cordis.patch.yml` 加一条 `skill-<短名>` 行；**不要**再在仓库根的 `skills/` 下建文件（那是冻结的迁移基线）。frontmatter 只写三键：

   ```markdown
   ---
   name: <与目录名一致的 kebab-case>
   description: <单行中文：能力 + 触发词>
   whenToUse: <单行中文：何时加载>
   ---
   ```

3. **写 description**：写「能力 + 触发词」，绝不写流程步骤——写了流程，模型会照 description 直接做而不读正文。
4. **写正文**：定位 / 何时触发 / 步骤或规则 / 完成标志；细节超出正文承载时才拆到 `references/`。
5. **自检**：跑完 D 段一致性校验；再跑一次 `skill(name="<新名>")` 确认真的能加载。
6. **挂参考**：`references/*.md` 放展开资料（不写 frontmatter），正文用相对路径 `references/xxx.md` 引用——资源根就是技能目录。

### B. 改名一个技能

1. 目录名与 frontmatter name **一起改**，不允许只改一处。
2. `grep` 旧 name 的全部引用（其它技能正文、文档、locale）并逐处改写，旧名零残留。
3. 依赖只允许存在于不同交付物之间，并要求 `version` + `requires`：此处「新目录名已落地」是 published-interface，「各处引用改写」依赖它；标清依赖的是哪一版接口或哪个已核实结果。
4. 复核：新名无重复、旧名零命中、`skill(name="<新名>")` 加载通过。

### C. 下线一个技能

1. 先 `grep` 谁在引用它；引用未清零前不删目录。
2. 引用清零 → 删目录 → 重跑 catalog 扫描与一致性校验 → 汇报移除项。
3. 不因为「今天没人提」就下线；下线必须有明确理由（被替代 / 重复 / 失效）。

### D. 一致性校验（每次操作后必跑）

- [ ] name 匹配 `^[a-z0-9]+(?:-[a-z0-9]+)*$`
- [ ] 目录名 === frontmatter name
- [ ] 全 catalog name 唯一（`grep` 收集后比对）
- [ ] description 非空、单行、≤400 字、含触发词、不含流程步骤
- [ ] whenToUse 非空、单行
- [ ] frontmatter 只有 name / description / whenToUse 三键：无工具白名单键、无 paths/license/version、无 YAML 折叠块（`>` / `|`）、无值内换行
- [ ] `references/*.md` 无 frontmatter；正文里的相对引用目标真实存在
- [ ] `skill(name=...)` 能加载（逐个，或按本轮改动抽样 + 全量枚举名字）
- [ ] 无旧措辞与旧标识残留（`grep` 自查）
- [ ] 汇报：新增 N / 改名 N / 下线 N / 未通过项逐条

## 横向交付合约（怎么切维护工作）

按**可独立交付的产物**切分：一个技能目录就是一份交付物（module / object / evidence-package 三类之一），由一个 owner 端到端负责：调查 → 改写 → 自检 → 修复 → 验收。

- **拒绝同一交付物的阶段接力**：「先背景调查→再设计→再检查」「计划→编码→审查」——这些阶段词落在同一个技能上，就是把一份活拆成三个人接力，交接成本大于收益。
- **横向重排建议**：按技能拆，一个技能一个人从头做到验收；同一技能内部确有前后依赖时，由同一 owner 串行做完。
- **依赖**只允许出现在不同交付物之间，并带 `version` + `requires`（依赖已发布的接口，或依赖已核实的结果）；同一交付物的时序阶段不得用依赖开后门。
- **全局集成**（跨技能命名冲突、catalog 汇总、最终一致性校验）由 leader 与相关 owner 共同负责；不撤走前面的人换一个没有上下文的审查员。收尾修复留在原 owner 手里。

## 事件驱动滚动补位

- 维护多个技能时，任一交付物结算（校验通过）就**立即补位**下一项 ready 的，不等同批其它技能；无全批屏障、无整层等待。
- **慢任务不阻塞其它 ready 项**：某个技能卡在加载排查时，继续推进其它技能的改名、下线、校验。
- **未 ready 不派发**：前置没产出就不开工。**满额时拒绝并保持 ready**（`CAPACITY_FULL`），不排队空等，也不用一次性旁路绕上限。
- 份数按实际待办定：不设固定数量门槛，也不因超过某个数就拆开或停工。

## 阻塞处理顺序

1. **记录确切失败**：报的哪条错、试过什么、影响范围（哪些技能/catalog 项受影响）、此刻仍能做的是什么。
2. **查本机已有条件**：已装服务、bundle 源码（`src/**`、`docs/**`）、现成工具与脚本、当前权限。
3. **能补就补**：缺适配器 / 接口 / 本地桥接就补上，然后继续。
4. **局部阻塞先做其它 ready 项**，并把 blocker 精确挂到受影响的那份交付物上，而不是挂到整个任务。
5. **只有确实需要外部账号、人工决策或无法获得的资源**时，才标记 `needs_user`，并给出已尝试路径与最小下一步。

不设「试三次就结束」，也不无预算地重复同一失败动作；权限拒绝不可绕过，也不改道绕过。

## 用户交互与证据纪律

- 用户已授权任务内的可逆开发（建目录、改正交、拆 references）不重复询问；审批与扩权只有用户入口，模型没有等价工具。
- 只在**真正改变决策且项目里查不到**时才用 `ask_user_question`（例：两个技能重名，且无法从内容判断保留哪个）。
- **证据诚实**：分开「已核实 / 有来源」与「推测 / 未核实」；不夸大，不在没有实际加载或校验的情况下声称「验证通过」。
- **结果分层**：parent 只回简短结论 + 可核查的 evidence/artifact 引用（文件路径、行号、快照字段）；原始材料留在文件或子会话；摘要写明来源、版本、遗漏、不确定性、未完成项。

## 汇报模板

```
新增：<name> — components/<name>/（component.json + parts/*.md + patch 一行）
改名：<old> → <new>（引用改写 <n> 处）
下线：<name>（理由：…）
校验：通过 <a>/<b>；未通过：<逐条>
证据：<文件 + 行号 / 快照字段>
不确定：<未核实项>
```

## 工具

- 文件：`read` `write` `edit` `glob` `grep`；终端：`pwsh`
- 加载校验：`skill(name="myworkflow-xxx")`
- 运行时诊断：`team_snapshot`
- 模块自治：leader 用 `team_define` `team_member_create` `team_mission_assign`；member 用 `team_plan_submit` `team_dispatch_authorize` `team_plan_cancel` `team_subagent_start` `team_work_verify`
- 协作与等待：`team_work_report` `team_ask_owner` `team_message` `team_wait` `team_snapshot`
- 写作细则：`references/skill-authoring.md`

## 完成标志

- [ ] 三处来源都实际读过：`glob` 枚举 + 逐文件 frontmatter + 至少一次 `skill` 加载（需要运行时判断时另加 `team_snapshot`）
- [ ] 一致性校验清单逐条给出结论（通过 / 不通过 + 依据）
- [ ] 新增 / 改名 / 下线已完成，旧名与旧引用零残留
- [ ] 汇报含来源与不确定性，未核实项已标注
- [ ] 未触碰旧注册表文件、旧宿主插件清单、工具白名单字段
