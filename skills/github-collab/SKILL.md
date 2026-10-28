---
name: Github协作
description: Use when 需要将代码变更推送到 GitHub、创建 PR、进行 code review、合并分支、使用 git worktree 隔离开发，或任何涉及 Git/GitHub 协作的操作
---
## 触发

- **必须触发**：提交/push/创建 PR/发起合入/合并；代码开发完成需推送远程；创建分支或 worktree 隔离开发；审查 PR 或处理 code review 反馈。
- **不触发**：纯本地只读查询（git log/diff/status 等不改变仓库状态的命令）直接执行；仍在开发中未完成验证的代码（先走闭环开发）；用户明确"只在本地，不要推"。

## 定位

代码编写链的收尾环节：代码写完后如何安全地提交、审查、合并到主分支。上游：智能体闭环开发（阶段4验证通过后调用，含 bug 修复路径）；PR 创建后使用 `/code-review` 或 `gh pr review` 审查。

## 设计决策

- **worktree 隔离**：功能开发/bug 修复在独立 worktree 中进行，完成后合并回主分支。
- **PR 驱动**：永远通过 PR 合入（不直接 push 到 main）。
- **审查前置**：合并前必须通过 code review（自动化 + 人工）。
- **清理闭环**：合并后清理 worktree 和临时分支，不留垃圾。

## 执行流程

### 场景 A：从零开始——隔离开发

**1. 创建隔离环境**（首选 worktree：主目录不受影响、每个 worktree 有独立 `.claude/` 上下文、完成后可一键清理）：
```bash
git worktree add -b feature/<feature-name> ../<worktree-dir> origin/main
```
降级方案（worktree 不可用时）：
```bash
git checkout -b feature/<feature-name> origin/main
```

> 本文统一以 `main` 为默认分支名；若项目默认分支是 `master`，把文中出现的 `main` 全部替换为 `master`。

**2. 确认就绪**：分支从最新 main 创建；工作目录已切换到新分支；项目能正常构建/运行。

### 场景 B：提交变更

**1. 自检清单**（提交前逐项确认）：
- [ ] 所有变更都是有意的（无调试代码、临时注释、实验性改动残留）
- [ ] 通过 lint/format；相关测试全部通过（TDD 测试 + 已有测试）
- [ ] 没有夹带无关改动（scope creep）——`git diff --stat` 确认每个文件都是有意改的
- [ ] 敏感信息已排除（API key、密码、token、内部 URL）
- [ ] 新文件有正确的许可证头（如项目要求）

> 🚨 **强制验证门禁**：自检项全部勾选后**必须**调用「myworkflow:real-world-verify」执行真实验证。不通过 → 拒绝提交，先修复问题。此门禁不可跳过——即使改动"很小"也必须执行。若调用方（智能体闭环开发）已调用过且全部通过，可免重复调用，但须在自检中引用已有验证报告。

**2. 提交策略**：微小（单文件几行）→ 单个 commit；中等（多文件同主题）→ 单 commit 或 2-3 个逻辑分离的 commit（每 commit 做一件事）；大型（多功能跨模块）→ 多个可独立 review 的 commit，用 `git add -p` 精确控制。

**3. commit message 格式**：
```
<type>(<scope>): <subject>   # 一句话概述，≤50 字符，中文
<body>                        # 做了什么、为什么；每行 ≤72 字符
```
type：`feat` 新功能 / `fix` Bug 修复 / `refactor` 重构（不改变行为）/ `docs` 文档 / `test` 测试 / `chore` 构建/工具/依赖。结尾加 `Co-Authored-By: Claude Code <noreply@anthropic.com>`。

**4. 提交并推送**（PowerShell 环境用 `@'...'@` here-string 替代 bash heredoc）：
```bash
git add <files>
git commit -m @'...'@
git push -u origin feature/<feature-name>
```

### 场景 C：创建 PR

**1. PR 描述必须包含**：
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

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
（页脚为固定格式，随 PR 描述一并提交）
```

**2. 创建 PR**：
```bash
gh pr create --title "<type>: <简短描述>" --body-file <pr-body-file> --base main --head feature/<feature-name>
```
常用 flag：`--draft`（标记还需改）/ `--reviewer <username>` / body 含 `Closes #123` 关联 issue / 不加 `--body-file` 则打开浏览器手填。

**3. 确认就绪**：PR 标题清晰；描述含验证方式与回归检查；CI 全部通过；CI 未过 → 修复后 `git push` 会自动更新 PR。

### 场景 D：Code Review

**作为审查者**：
1. 获取内容：`gh pr checkout <N>` / `gh pr diff <N>` / `gh pr view <N>`。
2. 用 `/code-review` 或手动按维度审查：**正确性**（逻辑/边界/错误处理）、**安全性**（注入/敏感数据/权限）、**可维护性**（命名/结构/注释）、**变更范围**（无无关改动/改动最小化）、**测试覆盖**（关键路径有测试）。
3. 提交意见：行级评论建议在 GitHub Web 的 Files Changed 视图进行（`gh pr review` 不支持 `-f` 指定文件）；整体评论 `gh pr review <N> --approve` / `--request-changes -b "..."` / `--comment -b "..."`；复杂审查 `gh pr view <N> --web`。

**作为被审查者**（先验证再行动——验证后再改，不盲目接受）：
1. 读反馈：`gh pr view <N> --comments`。
2. 逐条处理：正确的建议 → 修改并 push 更新 PR；技术上不准确的建议 → 礼貌解释为何不改（用代码/文档引用作证据）；主观偏好（无技术优劣）→ reviewer 坚持则接受，有理由坚持自己方案则礼貌说明；不清楚的建议 → 请 reviewer 澄清。
3. 响应：改完 `git add + commit + push`，PR 自动更新，通知 reviewer 重新审查。

### 场景 E：合并与清理

**1. 合入条件**：至少 1 人审查通过（Approved）；CI 全部通过；所有 review 讨论已解决；无 merge conflict（有则先解决）。

**2. 合并方式**：默认 **Squash merge**（`gh pr merge <N> --squash`——main 保持干净，每个 PR 对应一个 commit），除非用户明确要求 Rebase merge（每个 commit 都有独立价值、保持线性历史，`--rebase`）或 Merge commit（保留分支痕迹，`--merge`）。

**3. 执行合并**：
```bash
gh pr merge <PR-NUMBER> --squash --delete-branch   # --delete-branch 合并后删除远程分支
```

**4. 清理本地**：
```bash
git checkout main && git pull
git branch -d feature/<feature-name>
git worktree remove ../<worktree-dir> --force   # 有未提交变更时；否则不加 --force
git worktree prune                              # 残留 worktree 引用清理
```

**5. 确认清理完毕**：`git worktree list`（只剩 main 工作目录）；`git branch`（开发分支已删除）。

## 特殊情况

### 解决 Merge Conflict
```bash
git fetch origin && git checkout main && git pull
git checkout feature/<name> && git rebase origin/main
# 编辑冲突文件 → git add → git rebase --continue；放弃 rebase：git rebase --abort
git push --force-with-lease origin feature/<name>   # rebase 后必须强制推送
```

### 撤销一个 PR
```bash
gh pr close <PR-NUMBER>                     # 关闭 PR（不删除分支）
git revert -m 1 <merge-commit-SHA> && git push origin main   # 撤销已合并的 PR
```

### 紧急 Hotfix
跳过完整 worktree 隔离流程，从 main 快速修复：
```bash
git checkout main && git pull && git checkout -b hotfix/<description>
git add <files> && git commit -m "fix: <紧急修复描述>" && git push -u origin hotfix/<description>
gh pr create --title "fix(urgent): <描述>" --base main
# 合并后清理同场景 E
```

## 完成标志

**场景 A**：worktree 已创建（或分支从 main 切出）；工作目录已切换到新环境。
**场景 B**：自检清单全部通过；commit message 符合格式；已推送到远程分支。
**场景 C**：PR 描述完整（概述+文件+验证+回归）；`gh pr create` 成功；CI 通过。
**场景 D**：审查覆盖正确性/安全性/可维护性/变更范围/测试覆盖；审查意见已提交（approve/request-changes/comment）；收到反馈则逐条处理并 push。
**场景 E**：PR 已合并到 main；远程分支已删除；本地分支已删除；worktree 已清理（如使用）；已切回 main 并 pull 到最新。
