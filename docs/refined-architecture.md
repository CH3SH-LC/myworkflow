# MyWorkflow 细化方案 v2

> 上游：`docs/my-architecture.md`（你的原始想法）
> 状态：**已实现（2026-08-04，v3.1.0）**——P0/P1/P2 全部落地，见 PROGRESS.md 第十八阶段
> 最后更新：2026-08-04

本文件是「你的想法」与「当前 v3 实现」融合后的细化方案。逐条标注采纳 / 修正 / 否决，并给出任务规划。

---

## 0. 与原始想法的关系

| 想法条目 | 判定 | 说明 |
|---------|------|------|
| 专项任务按 JSON 注册表判断 | ✅ 采纳 | 核心价值，全盘吸收（但改为自动生成） |
| 子智能体协作换 hook | ✅ 采纳 | 你的直觉正确：子智能体是独立上下文，hook 强制注入才可靠 |
| 主入口=强制任务分类 | 🔄 修正 | 分类有价值，但"强制仪式"v2 实证失败 → 降为 hook 概念锚点 |
| 修复 bug 独立于开发 | 🔄 修正 | 修复是开发的一部分；找 bug（root-cause）独立调用 |
| 纯粹压缩 skill 篇幅 | 🔄 修正 | 篇幅服务方法质量，低确定性任务要"短而精"，不是删方法 |
| lessismore / 电脑清理整理 | ✅ 采纳 | 独立任务；电脑清理直接适配卡兹克 storage-analyzer |

---

## 1. 分类层：hook 概念锚点（替代强制分类仪式）

**为什么否决"强制分类"**：v2 实证失败——deepseek-v4-flash 对"分类→2~5 轮提问→报告→确认"仪式做 2-3 次就放弃，16KB 注入烧上下文。当前模型更适合"描述直接触发"。

**方案**：分类概念放 hook，只给"存在 5 类"这个认知，不给处理指令。

`session-init.sh` 注入内容（~120 字）：

```
直接按用户请求调用匹配的 Skill 完成工作；没有匹配的 skill 就自己完成。最多澄清 1 个关键问题。
任务分 5 类：代码编写 / 文稿撰写 / 深度调研 / 专项任务 / 简单问答。
疑似专项任务时，查 config/special-skills.json 找对应 skill。
```

**task-router 降级**：101 行 → ~100 字极简速查（一张 6 行分类表 + 指向 JSON）。概念解释权上移给 hook，它只剩"拿不准时翻阅的快照"。路由表"修 bug → bug-fix-verify"的分支同步改为 → agent-dev-loop（见第 4 节）。

---

## 2. 篇幅标尺：确定性 → 方法质量（修正"纯粹压缩"）

**错误理解**：按行数压缩。低确定性任务（找 bug）不是"删方法"，恰恰相反——开放性强 = 更依赖优秀思路指导，没有方法框架的模型找不到 bug。

**正确标尺**：篇幅服务于方法质量。区分两类内容：

| 内容类型 | 处理 |
|---------|------|
| **心智模型 / 方法框架**（5 Whys、数据流逆向、假设-验证循环、专项技术） | **保留并强化**——写准、写透，这是 low 确定性任务的唯一抓手 |
| **机械步骤 / 模板 / 命令清单 / 重复话术 / 展开例子** | **删**——模型会自动产出，规定字段反而僵化 |

**矩阵**：

| 任务确定性 | 篇幅 | 写法 | 例 |
|-----------|------|------|-----|
| 概念触发类 | ≤100 字 | 只给分类/触发概念 | task-router |
| 高确定性操作 | 详细 | 可复制步骤/命令/检查点 | 电脑清理、pdf→md、github-collab、project-init/maintain |
| 中确定性流程 | 中等 | 流程骨架 + 关键门禁 | deep-research、humanizer、req-clarify、integration-verify |
| 低确定性/创造性 | 短，**方法密度高** | 精讲方法框架，删展开例子 | root-cause、agent-dev-loop、lessismore(新) |

**对 root-cause-analysis 的修正理解**：从 426 行压缩到 ~200 行是**副作用**，不是目标。目标是——把五项专项技术（竞态排查/插桩/Bisect/防御性/Flaky）讲得更精准、决策路径更清晰，同时删掉展开例子、模板、重复话术。

---

## 3. 核心门禁 vs 操作细节

**原则**：核心流程硬约束（gate 不可删），具体怎么做放开（交给模型）。

以 agent-dev-loop 为例：

**硬约束（保留）**
- 五阶段主线不可跳：需求→计划→实现→真实验证→循环
- 真实验证门禁：阶段 4 必须调 `real-world-verify`；TDD 全绿是前置
- 循环规则：每个 ❌ 必须处理；≤3 轮后停下上报

**操作细节（删）**
- 复杂度门控 4 级表 → 一句话"按规模选通道，跨文件可派子智能体"
- 需求确认/计划模板 → 删
- TDD RED/GREEN/REFACTOR 展开 → 压成 2 行
- 审计模式章节 → 移 references/

---

## 4. 架构变更：修复 bug 不再独立（新增）

**现状（v3）**：`bug-fix-verify` 是独立顶层 skill（五步闭环），分类里"修 bug"独立路由。

**变更（对齐你的想法）**：
- **修复 = 开发的一部分**：任何修复都发生在开发闭环内，`agent-dev-loop` 增加路径「开发中发现 bug → 调 root-cause-analysis 定位 → 修复 → 真实验证」。
- **找 bug 独立**：`root-cause-analysis` 是唯一独立调用的"找 bug" skill（只定位不修，报告回流）。
- **`bug-fix-verify` 吸收进 agent-dev-loop 后删除独立 skill**。

**影响面（同步任务）**：
- `task-router` 路由表："修 bug"分支 → agent-dev-loop（不再指向 bug-fix-verify）
- 各 SKILL.md 中 `Skill("myworkflow:bug-fix-verify")` 引用 → 改为 agent-dev-loop / root-cause-analysis
- `root-cause-analysis` 的"修复回流"说明 → 指向 agent-dev-loop 的修复路径
- `agent-dev-loop` 触发描述中"独立 bug 修复用 Bug修复与验证" → 删除（bug 修复不再有独立入口）

---

## 5. 电脑清理：直接适配卡兹克 storage-analyzer

**来源**：[khazix-skills/storage-analyzer](https://github.com/KKKKhazix/khazix-skills)（Agent Skills 标准 SKILL.md，支持 Claude Code）。

**已具备的价值（不重造）**：只读扫描 + 三色分级清理决策（🟢自动可删 / 🟡用户决定 / 🔴永不删）+ 浏览器二次确认 + 本机 token 安全模式。

**适配步骤**：
1. 拉取 `storage-analyzer` 目录（SKILL.md + 脚本）
2. 转 myworkflow 格式：frontmatter 补 `name/description`（触发词：帮我清理 / C盘满了 / storage analysis）
3. 注册进 `special-skills.json` 的「电脑任务」类
4. **Windows 11 实测**（原 skill 标注 Windows 首次谨慎）——适配主要工作量在这

---

## 6. 任务规划（修订版）

### P0 —— 分类概念 + 专项注册表闭环

| # | 任务 | 形式 | 篇幅 |
|---|------|------|------|
| T1 | `registry-maintain` skill：扫描生成 `config/special-skills.json`（两层：任务类→skill） | 新建 skill | 中 |
| T2 | 分类 hook 改造：`session-init.sh` 注入 5 类概念 + 专项指引（~120 字） | 改 hook | — |
| T3 | task-router 压至 ~100 字速查 + 改"修 bug"路由 | 改 skill | 压 |
| T4 | 注册表自动刷新：SessionStart mtime 守卫（并入 T1/T2） | hook | — |

### P1 —— 架构合并 + 方法优化

| # | 任务 | 形式 | 说明 |
|---|------|------|------|
| T5 | 子智能体协议 hook 注入（反转 session-init.sh 对子智能体的跳过） | hook | 子智能体上下文注入一行协议锚点 |
| T6 | **bug-fix-verify 吸收进 agent-dev-loop**（删除独立 skill + 同步全部引用） | 架构级 | 见第 4 节；先做，T7/T8 依赖它 |
| T7 | root-cause 方法优化（强化五项专项技术指导，删展开例子/模板） | 改 skill | 篇幅目标 ~200 行，方法密度提升 |
| T8 | agent-dev-loop 优化（保留 gate + 吸收 bug 修复路径，删门控表/模板） | 改 skill | 行数非目标 |

### P2 —— 独立专项

| # | 任务 | 形式 |
|---|------|------|
| T10 | lessismore skill（AI 思考/与人类协作，少即是多） | 新建，**短而精** |
| T11 | storage-analyzer 适配（电脑清理） | 新建，**详细** + Windows 实测 |
| T12 | 电脑整理 skill（参考 `D:\CH3SH` 组织方式） | 新建，中详细 |

### 执行顺序

```
P0:  T1 → T2 → T3   （分类概念 + 专项清单闭环）
P1:  T6 → T7 / T8   （架构合并先行，两个优化并行）
P2:  T10 → T11 → T12（独立，逐个做）
```

---

## 7. 一句话总结

> 采纳你两个最值钱的想法（JSON 专项注册表 + 子智能体 hook 直觉）；修正两点：分类只做概念锚点不搞强制仪式，修复 bug 并入开发而找 bug 独立。篇幅不按行数压，按"方法质量"写——low 确定性任务短而精，high 确定性任务详而全。
