---
name: Github协作
description: Use when 要提交/推送代码、创建或审查 PR、合并分支、用 worktree 隔离开发时加载；不改变仓库状态的只读 git 查询不加载。
---

## 核心流程：隔离 → 提交 → 推送 → PR → 审查 → 合并 → 清理

**何时加载**：提交代码、push、建 PR、合并、建分支或 worktree、审查 PR 或处理 review。**不加载**：纯本地只读查询直接执行；开发未完成或未验证；用户明确「只在本地，不要推」。

**硬步骤**
1. **隔离环境**：查 `git status --porcelain`，未提交改动先问用户；`git worktree add -b feature/<name> ../<dir> origin/main` → 判据：记录 worktree/branch/基点 SHA，切换后能构建。
2. **提交**：自检无调试残留、无关改动、敏感信息，跑真实验证 → 判据：`git diff --stat` 每文件都有意；message 按 `<type>(<scope>): <subject>`，不加 AI 署名。
3. **推送并建 PR**：`git push -u origin feature/<name>`，再 `gh pr create`（含变更/验证）→ 判据：**推送前取得该次推送的明确授权**；未授权停在「已本地提交、待授权推送」；PR 建好 ≠ 可合并。
4. **审查**：按正确性/安全性/可维护性/变更范围/测试覆盖五维取证 → 判据：CI 全过；反馈由原 owner 逐条判断，改完 push 更新 PR。
5. **合并与清理**：合入条件 = ≥1 Approve + CI 通过 + 讨论解决 + 无冲突；默认 `gh pr merge <N> --squash --delete-branch` → 判据：切回 main 并 pull、删本地分支、worktree remove + prune，`git worktree list` 只剩主目录。

**授权红线**：push、开/关/合并 PR、rebase 强推、revert、发布都须逐次取得明确授权；凭据不可用时不写账号密码，退回本地提交并写明下一步。

**完成判据**：PR 已合并（获授权）、远端与本地分支已删、worktree 清干净、main 已更新；证据=命令输出、commit SHA、PR 号、worktree list。

## 触发

- **必须触发**：提交 / push / 创建 PR / 发起合入 / 合并；代码开发完成需推送远程；创建分支或 worktree 隔离开发；审查 PR 或处理 code review 反馈。
- **不触发**：纯本地只读查询（`git log` / `git diff` / `git status` / `git branch -v` 等不改变仓库状态的命令）直接执行；仍在开发中、未完成验证的代码（先走闭环开发）；用户明确"只在本地，不要推"。

## 定位

代码编写链的收尾环节：代码写完后如何安全地提交、审查、合并到主分支。上游是智能体闭环开发，验证通过后才进入本环节（含 bug 修复路径）；PR 创建后进入审查环节。

## 设计决策

- **授权边界优先**：任何改变远端状态的动作（push、开/关/合并 PR、rebase 后强推、revert、发布）都必须先取得用户对该次动作的明确授权。旧流程里存在 PR 步骤，不代表可以自动推送、自动合并、自动改远端。
- **worktree 隔离（手工）**：功能开发 / bug 修复在独立 worktree 中进行，完成后合回主分支；worktree 由 owner 用 pwsh 手工创建并持久记录（见下节）。
- **PR 驱动**：合入走 PR，不直接推 main；但"创建 PR"与"合并 PR"是两次独立授权。
- **审查前置**：合并前完成 code review（自动化检查 + 人工意见）。
- **清理闭环**：合并后清理 worktree 与临时分支，不留垃圾。
- **同一 owner 收尾**：谁做的交付物，谁负责改到通过；不撤走前面的人换无上下文的审查员。

## DSH 环境与工具

本技能在 DSH（DeepSeek Harness）中执行，工具与认证与旧流程不同：

| 事项 | DSH 做法 |
| --- | --- |
| 跑 git / gh | `pwsh`（一次一条可核对命令，输出即证据；PowerShell here-string `@'...'@` 替代 bash heredoc） |
| 读取 / 修改文件 | `read` / `write` / `edit`；查找用 `glob` / `grep` |
| 认证 | 复用本机既有凭据：先 `gh auth status`、`git remote -v`、`git config user.name`。凭据不可用或已过期时，不尝试安装凭据、不写入账号密码；退回本地分支 / 本地 commit，并把"待用户授权或补凭据后的下一步"写清楚 |
| 模块委托与计划 | `team_define`（登记团队）、`team_member_create`（建模块成员）、`team_mission_assign`（leader 下模块委托）、`team_plan_submit` / `team_dispatch_authorize` / `team_plan_cancel`（成员自己提交计划、授权派发、取消未来派发）、`team_snapshot` / `team_wait`（看状态、等变化） |
| 执行者与验收 | `team_subagent_start`（成员定向启动自己的 continuable 执行者）、`team_work_report`（leaf 回执）、`team_ask_owner`（leaf 向自己的 owner 求助/回报）、`team_work_verify`（owner 核验）、`team_message`（成员间消息；**leaf 不可用**）、`team_recover`（对账恢复）、`team_interrupt`（按范围停止） |
| 向用户提问 / 请求授权 | `ask_user_question` |
| 长任务 | `job_list` / `job_output` / `job_kill` |

禁止假设存在旧客户端的 hook、环境变量、任务清单文件或斜杠命令；这些在 DSH 中不存在，遇到即改用上述工具。

### worktree 与共享工作区

- 官方 Team 当前不提供每成员独立 cwd：所有成员共享同一工作区。**共享工作区不等于 worktree 隔离**，只是同一目录的协同，因此必须靠"文件写范围 + 提交前核对"来避免互相踩踏。
- 需要真隔离时，owner 用 pwsh 手工创建 worktree，并**持久记录**以下信息（写进任务描述或交付物说明，别只留在会话里）：

```powershell
git worktree add -b feature/<feature-name> ../<worktree-dir> origin/main
# 持久记录：worktree 绝对路径 / cwd / branch / 基点（origin/main 的 SHA）/ 回收方式
git -C ../<worktree-dir> rev-parse HEAD
```

- 创建前**必须先核对用户当前目录没有未提交改动**（`git status --porcelain` 非空就先问用户，不要擅自 stash / checkout / 覆盖）；新建后立即记录 cwd、branch、基点，供回收与复核使用。
- 降级方案（worktree 不可用时）：`git checkout -b feature/<feature-name> origin/main`。
- 本文统一以 `main` 为默认分支名；项目默认分支是 `master` 时，把文中 `main` 全部替换为 `master`。

## 横向交付合约

协作按**可独立交付的产物**切分，而不是按阶段切分。

- 交付物粒度：module（模块）/ object（对象）/ evidence-package（证据包）等能被一个人独立验收的单元。
- 每份交付物由**一个 owner 端到端负责**：调查 → 实现 → 自检 → 修复 → 验收。PR 是交付物的出口，不是把活切成"我改代码、你收尾"的理由。
- **拒绝同一交付物的阶段接力**：不要"背景调查 → 设计 → 检查"或"计划 → 编码 → 审查"这样把一份交付物拆到多个人手上。
- 横向重排建议：把一份交付物压给一个 owner；确实要并行时，按**不同交付物**并行（例如按模块、按对象、按证据包），而不是按阶段并行。同一 owner 收尾修复；全局集成由 leader 与相关 owner 共同负责，不撤走前面的人换无上下文的审查员。
- 依赖只允许存在于**不同交付物之间**，并在契约里要求 `version` + `requires`：`requires` 取 `published-interface`（已发布接口）或 `verified-result`（已验证结果）——即依赖的是对方已稳定产出的东西，不是"对方大概会做完"。

## 建团队与补位

- **leader 只下模块委托、给目标与边界**：`team_define` → `team_member_create` → `team_mission_assign`；Git/GitHub 协作同样按可独立交付的产物切分（一次隔离开发、一个 PR 的修复、一份 review 结论），**由成员自己 `team_plan_submit` + `team_dispatch_authorize` 推进**，leader **不逐批派活**。
- **补位由常驻 Host 调度器执行**：成员当前 turn 停止或 pane 被隐藏都不影响成员与队列；需要停止时用 `team_interrupt` 指明范围（`turn` / `members` / `team`）。
- **未 ready 不启动**：交付物的前置未就绪就不启动，不"先启动再空等"。
- **事件驱动滚动补位**：任一交付物一结算（完成 / 失败 / 阻塞）就立即补位下一项，不等同批其它任务。无全批屏障、无整层等待；慢任务不阻塞其它 ready 项，不做"等同批全部返回"的收口。
- **满额时拒绝并保持 ready**：容量已满时返回 `CAPACITY_FULL`，被拒的 ready 项保持 ready 状态等下一次补位；不排队空等，也不用"一次性旁路"绕过上限。
- **超时处理**：先判断这是"仍在推进"、“状态未知 / 暂停”还是"真正失败"，并评估可恢复性。超时本身不等于失败，不要因为超时就判失败或清掉 worktree / 分支；给下一步可恢复的入口（重查状态、重试、降级到本地）。
- **阻塞处理顺序**：① 记录确切失败、已尝试动作、影响范围、仍可做的部分 → ② 查已装服务、源码、现成工具、当前权限 → ③ 能写适配器 / 接口 / 本地桥接就补齐 → ④ 局部阻塞时先做其它 ready 项，并把 blocker 精确挂到受影响的交付物上 → ⑤ 确实需要外部账号、人工决策或无法获得的资源时标记 `needs_user`，附已尝试路径与最小下一步。不设"试三次就结束"的固定次数，也不对同一失败无预算地无限重试；权限拒绝不可绕过。
- **用户授权任务内的可逆开发不重复询问**：审批与扩权只有用户入口，模型没有等价工具；因此不要自己"批准"自己，也不要把可逆的常规开发反复拿去问。
- **只在真正改变决策且项目里查不到时才提问**（用 `ask_user_question`）。

## 执行流程

### 场景 A：隔离开发环境

1. **核对现状**：`git status --porcelain`、`git branch --show-current`、`git log -1 --oneline`（有未提交改动先问用户）。
2. **创建隔离环境**（worktree，记录 cwd / branch / 基点，见上文）。
3. **确认就绪**：分支从最新 main 创建；工作目录已切到新环境；项目能正常构建 / 运行。

### 场景 B：提交变更

1. **自检清单**（提交前逐项确认，条件允许就用命令取证）：
   - [ ] 所有变更都是有意的（无调试代码、临时注释、实验性改动残留）
   - [ ] 通过 lint / format；相关测试全部通过
   - [ ] 没有夹带无关改动（scope creep）——`git diff --stat` 确认每个文件都是有意改的
   - [ ] 敏感信息已排除（API key、密码、token、内部 URL）
   - [ ] 新文件有正确的许可证头（如项目要求）
   - [ ] 隔离开销已核对：共享工作区里自己没有踩别人的写范围
2. **真实验证**：自检项全部通过后，必须跑真实验证（构建 / 测试 / 可复现的验证命令），把命令与结果作为证据记录下来；验证不通过就修到通过再说提交。若上游闭环开发已跑过同一验证，可引用已有报告，但不得凭空声称"验证通过"。
3. **提交策略**：微小（单文件几行）→ 单个 commit；中等（多文件同主题）→ 单 commit 或 2-3 个逻辑分离的 commit（每 commit 做一件事）；大型（多功能跨模块）→ 多个可独立 review 的 commit，用 `git add -p` 精确控制。
4. **commit message 格式**：

   ```
   <type>(<scope>): <subject>   # 一句话概述，≤50 字符，中文
   <body>                       # 做了什么、为什么；每行 ≤72 字符
   ```

   type：`feat` 新功能 / `fix` Bug 修复 / `refactor` 重构（不改变行为）/ `docs` 文档 / `test` 测试 / `chore` 构建 / 工具 / 依赖。**不添加任何 AI 署名页脚或共同作者标记**，只写真实人类作者信息。
5. **本地提交**（PowerShell 用 here-string）：

   ```powershell
   git add <files>
   git commit -m @'
   feat(scope): 一句话概述

   做了什么、为什么。
   '@
   ```

   `git commit` 只改本地仓库；**推送另见下一步**。

6. **推送（需用户对该次推送明确授权）**：

   ```powershell
   git push -u origin feature/<feature-name>
   ```

   推送前确认：授权已拿到；隔离环境已建立；基点是预期的 main；没有要排除的文件混进本次推送。未获授权时停在这里，报告"已本地提交、待授权推送"。

### 场景 C：创建 PR（需用户授权）

1. **PR 描述必须包含**：

   ```markdown
   ## 变更概述
   [做了什么、为什么这样做]

   ## 变更文件
   - `path/to/file` — [改了什么]

   ## 验证方式
   - [ ] [验证步骤 + 结果]

   ## 回归风险
   - [可能受影响的区域 + 是否已检查]

   ## 截图/录屏（如适用）
   ```

   页脚只写真实来源信息（作者、工具），不加 AI 署名固定文案。

2. **创建 PR**：

   ```powershell
   gh pr create --title "<type>: <简短描述>" --body-file <pr-body-file> --base main --head feature/<feature-name>
   ```

   常用 flag：`--draft`（标记还需改）/ `--reviewer <username>` / body 含 `Closes #123` 关联 issue / 不加 `--body-file` 则打开浏览器手填。**创建 PR 不等于可以合并**。
3. **确认就绪**：PR 标题清晰；描述含验证方式与回归检查；CI 全部通过；CI 未过 → 修复后 `git push` 会自动更新 PR。

### 场景 D：Code Review

**作为审查者**：

1. 获取内容：`gh pr checkout <N>` / `gh pr diff <N>` / `gh pr view <N>`。
2. 按维度审查：**正确性**（逻辑 / 边界 / 错误处理）、**安全性**（注入 / 敏感数据 / 权限）、**可维护性**（命名 / 结构 / 注释）、**变更范围**（无无关改动 / 改动最小化）、**测试覆盖**（关键路径有测试）。
3. 提交意见：行级评论建议在 GitHub Web 的 Files Changed 视图进行（`gh pr review` 不支持 `-f` 指定文件）；整体评论 `gh pr review <N> --approve` / `--request-changes -b "..."` / `--comment -b "..."`；复杂审查 `gh pr view <N> --web`。
4. 审查结论要诚实分层：区分"已核实 / 有来源"与"推测 / 未核实"，写清依据（命令、文件、行号）；不给无证据的"看起来没问题"。

**作为被审查者**（验证后再改，不盲目接受）：

1. 读反馈：`gh pr view <N> --comments`。
2. 逐条处理：正确的建议 → 修改并 push 更新 PR；技术上不准确的建议 → 礼貌解释为何不改（用代码 / 文档引用作证据）；主观偏好（无技术优劣）→ reviewer 坚持则接受，有理由坚持自己方案则礼貌说明；不清楚的建议 → 请 reviewer 澄清。
3. 响应：改完 `git add` + `commit` + `push`，PR 自动更新，通知 reviewer 重新审查。
4. 反馈修复由**原 owner** 完成，保持上下文连续。

### 场景 E：合并与清理（需用户对该次合并明确授权）

1. **合入条件**：至少 1 人审查通过（Approved）；CI 全部通过；所有 review 讨论已解决；无 merge conflict（有则先解决）。
2. **合并方式**：默认 **Squash merge**（`gh pr merge <N> --squash`——main 保持干净，每个 PR 对应一个 commit），除非用户明确要求 Rebase merge（每个 commit 都有独立价值、保持线性历史，`--rebase`）或 Merge commit（保留分支痕迹，`--merge`）。
3. **执行合并**（先确认已获授权）：

   ```powershell
   gh pr merge <PR-NUMBER> --squash --delete-branch   # --delete-branch 合并后删除远程分支
   ```

4. **清理本地**：

   ```powershell
   git checkout main; git pull
   git branch -d feature/<feature-name>
   git worktree remove ../<worktree-dir> --force   # 有未提交变更时才加 --force
   git worktree prune                              # 残留 worktree 引用清理
   ```

5. **确认清理完毕**：`git worktree list`（只剩 main 工作目录）；`git branch`（开发分支已删除）。清理前先确认没有仍在推进或状态未知的交付物依赖这个 worktree。

## 特殊情况

### 解决 Merge Conflict

```powershell
git fetch origin; git checkout main; git pull
git checkout feature/<name>; git rebase origin/main
# 编辑冲突文件 → git add → git rebase --continue；放弃 rebase：git rebase --abort
git push --force-with-lease origin feature/<name>   # rebase 后必须强制推送，仍需用户授权
```

### 撤销一个 PR

```powershell
gh pr close <PR-NUMBER>                     # 关闭 PR（不删除分支）
git revert -m 1 <merge-commit-SHA>; git push origin main   # 撤销已合并的 PR，仍需用户授权
```

### 紧急 Hotfix

跳过完整 worktree 隔离流程，从 main 快速修复（推送与合并同样需要授权）：

```powershell
git checkout main; git pull; git checkout -b hotfix/<description>
git add <files>; git commit -m "fix: <紧急修复描述>"; git push -u origin hotfix/<description>
gh pr create --title "fix(urgent): <描述>" --base main
# 合并后清理同场景 E
```

## 结果汇报

- 回给 parent 的是**分层结果**：简短结论（做了什么 / 当前状态 / 卡在哪）+ 可核查的 evidence / artifact refs（命令、SHA、分支名、PR 号、文件路径），原始材料留在文件或子会话里。
- 摘要须含：来源、版本、遗漏、不确定性、未完成项。明确写出"已核实"与"推测"的边界，不夸大，不无证据声称"验证通过"。

## 完成标志

- **场景 A**：worktree 已创建（或分支从 main 切出），cwd / branch / 基点已记录；工作目录已切到新环境。
- **场景 B**：自检清单全部通过；真实验证有证据；commit message 符合格式；本地提交完成，推送已获授权并成功。
- **场景 C**：PR 描述完整（概述 + 文件 + 验证 + 回归）；`gh pr create` 成功；CI 通过。
- **场景 D**：审查覆盖正确性 / 安全性 / 可维护性 / 变更范围 / 测试覆盖；意见已提交（approve / request-changes / comment）；收到反馈则逐条处理并 push。
- **场景 E**：PR 已合并到 main（获授权）；远程分支已删除；本地分支已删除；worktree 已清理（如使用）；已切回 main 并 pull 到最新。
