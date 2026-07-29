---
name: Github协作
description: Use when 需要将代码变更推送到 GitHub、创建 PR、进行 code review、合并分支、使用 git worktree 隔离开发，或任何涉及 Git/GitHub 协作的操作。触发词：提交代码、push、PR、pull request、创建 PR、合并、merge、rebase、分支、branch、worktree、代码审查、code review、推送到远程、发起合入、审查这个 PR。不触发：纯本地只读查询（git log/git diff/git status/git branch -v 等不改变仓库状态的命令）。
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
  - Skill
---

# Github 协作

## 定位

本 skill 是 myworkflow 技能包中**代码编写链的收尾环节**——代码写完了，如何安全地提交、审查、合并到主分支。

**与其他 skill 的关系**：

| Skill | 关系 | 说明 |
|-------|------|------|
| **智能体闭环开发** | 上游 | 闭环开发完成后，阶段 4 验证通过 → 调用本 skill 完成提交和合入 |
| **Bug修复与验证** | 上游 | Bug 修复完成后，步骤 ④ 审查通过 → 调用本 skill 完成提交 |
| **代码审查(code-review)** | 内部工具 | PR 创建后使用 `/code-review` 或 `gh pr review` 进行审查 |

## 触发场景

### 必须触发

1. 用户要求"提交""push""创建 PR""发起 pull request""合入""合并"
2. 代码开发完成，需要推送到远程仓库
3. 需要创建分支或使用 worktree 隔离开发
4. 需要审查 PR 或处理 code review 反馈
5. 用户说"把这个推到 GitHub""发起一个 PR""帮我合并到 main"

### 不触发

- 纯本地 git 查询（git log, git diff, git status）→ 直接执行
- 还在开发中的代码（未完成验证）→ 先走闭环开发完成验证
- 用户明确说"只在本地，不要推"

## 设计决策

> 本 skill 是 myworkflow 的 Git/GitHub 原生协作方案，覆盖隔离开发→提交→PR→审查→合并全流程。

| 决策 | 说明 |
|------|------|
| **worktree 隔离** | 功能开发和 bug 修复在独立 worktree 中进行，完成后合并回主分支 |
| **PR 驱动** | 永远通过 PR 合入（不直接 push 到 main/master） |
| **审查前置** | 合并前必须通过 code review（自动化 + 人工） |
| **清理闭环** | 合并后清理 worktree 和临时分支，不留垃圾 |

## 执行流程

### 场景 A：从零开始——隔离开发

> 触发：用户要在新分支上开发功能/修复 bug。

#### 步骤 1：创建隔离环境

**首选 worktree**（推荐）：

```bash
# 创建工作目录隔离的分支
git worktree add -b feature/<feature-name> ../<worktree-dir> origin/main
```

使用 worktree 的好处：
- 主工作目录不受影响，可以同时处理其他任务
- 每个 worktree 有独立的 `.claude/` 上下文
- 开发完成后可一键清理

**降级方案**（worktree 不可用时）：

```bash
git checkout -b feature/<feature-name> origin/main
```

#### 步骤 2：确认隔离环境就绪

- [ ] 分支已从最新的 main/master 创建
- [ ] 工作目录已切换到新分支
- [ ] 项目能正常构建/运行

---

### 场景 B：提交变更

> 触发：开发完成，验证通过，准备提交。

#### 步骤 1：自检清单

在提交前逐项确认：

- [ ] 所有变更都是有意的（无调试代码、临时注释、实验性改动残留）
- [ ] 改动通过了项目的 lint/format 检查
- [ ] 相关测试全部通过（TDD 测试 + 已有测试）
- [ ] 没有夹带无关改动（scope creep）—— `git diff --stat` 确认每个文件都是有意改的
- [ ] 敏感信息已排除（API key、密码、token、内部 URL）
- [ ] 新文件有正确的许可证头（如项目要求）

> 🚨 **强制验证门禁**：上述自检项全部勾选后，必须调用「myworkflow:real-world-verify」执行真实验证。验证不通过 → 拒绝提交，先修复问题。此门禁不可跳过——即使改动"很小"也必须执行。
>
> 如果调用方（智能体闭环开发/Bug修复与验证）已调用过 real-world-verify 且全部通过，可免去重复调用，但必须在自检中引用已有的验证报告。

#### 步骤 2：选择提交策略

| 变更规模 | 策略 | 说明 |
|---------|------|------|
| **微小**（单文件、几行） | 单个 commit | 直接 `git add + git commit` |
| **中等**（多文件、同一主题） | 单 commit 或 2-3 个逻辑分离的 commit | 每个 commit 做一件事 |
| **大型**（多功能、跨模块） | 多个 commit，每个是一个可独立 review 的变更 | 用 `git add -p` 精确控制 |

#### 步骤 3：写 commit message

**格式**：

```
<type>(<scope>): <subject>
  - 一句话概述（50 字符以内，中文）

<body>
  - 详细说明做了什么、为什么这样做（如有必要）
  - 每行 72 字符以内
```

**type 取值**：

| type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `refactor` | 重构（不改变行为） |
| `docs` | 文档 |
| `test` | 测试 |
| `chore` | 构建/工具/依赖 |

**示例**：

```
feat(auth): 添加 JWT token 刷新机制

用户登录后 token 过期需要重新登录。现在添加了自动刷新：
- 在 token 过期前 5 分钟自动刷新
- 刷新失败时清除本地状态并跳转登录页
- 并发请求共享同一个刷新 Promise 避免重复刷新

Co-Authored-By: Claude <noreply@anthropic.com>
```

#### 步骤 4：提交并推送

> 以下示例使用 bash heredoc 语法。如果当前环境为 PowerShell，使用 `@'...'@` here-string 替代。

```bash
git add <files>
git commit -m @'
feat(auth): 添加 JWT token 刷新机制
...
'@
git push -u origin feature/<feature-name>
```

---

### 场景 C：创建 PR

> 触发：代码已推送到远程分支，需要发起合入。

#### 步骤 1：生成 PR 描述

PR 描述必须包含：

```markdown
## 变更概述
[一段话——做了什么、为什么这样做]

## 变更文件
- `path/to/file1` — [改了什么]
- `path/to/file2` — [改了什么]

## 验证方式
- [ ] [验证步骤 1 + 结果]
- [ ] [验证步骤 2 + 结果]

## 回归风险
- [可能受影响的区域 + 是否已检查]

## 截图/录屏（如适用）
[前端变更时附上]

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
（用户可通过项目 CLAUDE.md 的 `pr-footer` 配置项自定义或移除此行）
```

#### 步骤 2：创建 PR

```bash
gh pr create \
  --title "<type>: <简短描述>" \
  --body @<pr-body-file> \
  --base main \
  --head feature/<feature-name>
```

常用选项：

| 场景 | 额外 flag |
|------|----------|
| 标记为 draft（还需要改） | `--draft` |
| 指定 reviewer | `--reviewer <username>` |
| 关联 issue | `--body "Closes #123"` |
| Web 界面手动填写 | 不加 `--body`，会自动打开浏览器 |

#### 步骤 3：确认 PR 就绪

- [ ] PR 标题清晰、描述了变更内容
- [ ] PR 描述包含验证方式和回归检查
- [ ] CI 检查全部通过
- [ ] 如果 CI 未通过 → 修复后 `git push` 会自动更新 PR

---

### 场景 D：Code Review

> 触发：PR 已创建，需要审查或被审查。

#### 作为审查者（Reviewing）

**步骤 1：获取 PR 内容**

```bash
gh pr checkout <PR-NUMBER>   # 切换到 PR 分支
gh pr diff <PR-NUMBER>       # 查看变更
gh pr view <PR-NUMBER>       # 查看 PR 描述和评论
```

**步骤 2：执行审查**

使用 myworkflow 内置的 `/code-review` 命令（如有），或手动从以下维度审查：

| 维度 | 检查要点 |
|------|---------|
| **正确性** | 逻辑是否对？边界条件是否覆盖？错误处理是否完整？ |
| **安全性** | 是否有注入风险？敏感数据是否暴露？权限检查是否到位？ |
| **可维护性** | 命名清晰？结构合理？有必要的注释吗？ |
| **变更范围** | 是否夹带了无关改动？改动是否最小化？ |
| **测试覆盖** | 新增/修改的代码有测试吗？测试是否覆盖了关键路径？ |

**步骤 3：提交审查意见**

三种方式：

1. **行级评论**（推荐，在 Web 界面操作或通过 `gh pr comment` 指定文件）：
   ```bash
   gh pr review <PR-NUMBER> --comment -b "这里需要处理 null 的情况"
   ```
   > 注意：`gh pr review` 不支持 `-f` 指定文件路径。行级评论建议在 GitHub Web 界面的 PR Files Changed 视图中进行。

2. **整体评论**：
   ```bash
   gh pr review <PR-NUMBER> --approve   # 通过
   gh pr review <PR-NUMBER> --request-changes -b "请修复以下问题：..."  # 要求修改
   gh pr review <PR-NUMBER> --comment -b "有几个小建议"  # 仅评论
   ```

3. **Web 界面**（推荐复杂审查）：`gh pr view <PR-NUMBER> --web`

#### 作为被审查者（Receiving Review）

> 遵循「myworkflow:anti-sycophancy」skill 的原则——不盲目接受，验证后再改。

**步骤 1：读取反馈**

```bash
gh pr view <PR-NUMBER> --comments
```

**步骤 2：逐条处理**

| 反馈类型 | 处理方式 |
|---------|---------|
| **正确的建议** | 修改代码，push 更新 PR |
| **技术上不准确的建议** | 礼貌解释为什么不改，用代码/文档引用作为证据 |
| **主观偏好（无技术优劣）** | 如果 reviewer 坚持，接受并修改；如果有理由坚持自己的方案，礼貌说明 |
| **不清楚的建议** | 请 reviewer 澄清——"你指的是 X 还是 Y？能否给个具体示例？" |

**步骤 3：响应评论**

```bash
# 修改完成后
git add <files>
git commit -m "fix: 根据 review 反馈修改 XX"
git push
# PR 自动更新，通知 reviewer 重新审查
```

---

### 场景 E：合并与清理

> 触发：PR 审查通过，CI 绿色，准备合入。

#### 步骤 1：确认合入条件

- [ ] 至少 1 人审查通过（Approved）
- [ ] CI 全部通过
- [ ] 所有 review 讨论已解决
- [ ] 没有 merge conflict（如有 → 先解决冲突）

#### 步骤 2：选择合并方式

| 方式 | 适用场景 | 命令 |
|------|---------|------|
| **Squash merge**（推荐） | 分支上有多个小 commit，合并为一个干净的 commit | `gh pr merge <N> --squash` |
| **Rebase merge** | 每个 commit 都有独立价值，要保持线性历史 | `gh pr merge <N> --rebase` |
| **Merge commit** | 有意义的多个 commit，要保留分支痕迹 | `gh pr merge <N> --merge` |

**默认选择 Squash merge**——除非用户明确要求其他方式。理由：main 分支保持干净，每个 PR 对应一个 commit。

#### 步骤 3：执行合并

```bash
gh pr merge <PR-NUMBER> --squash --delete-branch
```

`--delete-branch`：合并后删除远程分支（保持仓库整洁）。

#### 步骤 4：清理本地

```bash
# 切回主分支
git checkout main
git pull

# 删除本地分支
git branch -d feature/<feature-name>

# 如果使用了 worktree，清理它
git worktree remove ../<worktree-dir> --force   # 如无未提交变更
# 或
git worktree remove ../<worktree-dir>            # 正常清理

# 如果有残留的 worktree 引用
git worktree prune
```

#### 步骤 5：确认清理完毕

```bash
git worktree list    # 应该只有 main 工作目录
git branch           # 本地分支列表，确认已删除开发分支
```

---

## 特殊情况处理

### 解决 Merge Conflict

```bash
# 1. 更新 main
git fetch origin
git checkout main && git pull

# 2. 切回功能分支并 rebase
git checkout feature/<name>
git rebase origin/main

# 3. 解决冲突
# 编辑冲突文件 → git add → git rebase --continue
# 或放弃 rebase：git rebase --abort

# 4. 强制推送（rebase 后必须）
git push --force-with-lease origin feature/<name>
```

### 撤销一个 PR

```bash
# 关闭 PR（不删除分支）
gh pr close <PR-NUMBER>

# 如果需要撤销已合并的 PR，用 git revert
git revert -m 1 <merge-commit-SHA>
git push origin main
```

### 紧急 Hotfix

> 跳过完整 worktree 隔离流程，从 main 快速创建 hotfix 分支进行修复。

```bash
# 1. 从 main 创建 hotfix 分支
git checkout main && git pull
git checkout -b hotfix/<description>

# 2. 修复 + 提交 + 推送
git add <files>
git commit -m "fix: <紧急修复描述>"
git push -u origin hotfix/<description>

# 3. 创建 PR（标注为紧急）
gh pr create --title "fix(urgent): <描述>" --base main

# 4. 合并后清理（同场景 E）
```

---

## 快速参考

| 你要做什么 | 看哪个场景 |
|-----------|-----------|
| 开始新功能，需要隔离环境 | 场景 A：隔离开发 |
| 代码写完，准备提交 | 场景 B：提交变更 |
| 已推送，要发起合入 | 场景 C：创建 PR |
| 需要审查别人的 PR | 场景 D：作为审查者 |
| 收到了 code review 反馈 | 场景 D：作为被审查者 |
| PR 通过了，要合入 | 场景 E：合并与清理 |
| 有冲突不会解决 | 特殊情况：Merge Conflict |
| PR 创建错了要关掉 | 特殊情况：撤销 PR |
| 紧急线上 bug，不走完整流程 | 特殊情况：紧急 Hotfix |

## 常见错误

| 错误 | 正确做法 |
|------|---------|
| 直接在 main 上开发和提交 | 永远在分支上工作，通过 PR 合入 |
| `git push --force` 覆盖别人的提交 | 用 `--force-with-lease`——拒绝覆盖你未拉取的提交 |
| squash merge 后不删除远程分支 | `gh pr merge --delete-branch` 自动清理 |
| worktree 用完后不清理 | `git worktree remove` + `git worktree prune` |
| commit message 写"fix bug" | 写清楚修了什么 bug、为什么这样修 |
| PR 描述为空 | PR 描述 = 给 reviewer 的上下文。写清楚做了什么、为什么、怎么验证 |
| 合并后不切回 main 并 pull | 本地 main 过时 → 下次从旧 main 创建分支 → 冲突 |
| 收到 review 反馈后不改就直接 merge | 先处理每条反馈（同意则改，不同意则解释），再合入 |
| 未经审查直接 merge 到 main | 永远需要审查——《反谄媚》原则：不要跳过必要步骤 |

## 危险信号

- 你准备 `git push --force` 不加 `--with-lease` → **会覆盖别人的提交。换 `--force-with-lease`**
- `git status` 显示你不在任何分支上（detached HEAD）→ **先 `git checkout -b <name>` 创建分支再工作**
- 你想跳过 PR 直接 push 到 main → **除非是紧急 hotfix 且用户明确同意，否则不行**
- 多个 worktree 但忘记清理 → **运行 `git worktree list` 查看所有，清理不用的**
- 合并后 `git branch` 显示 10+ 个旧分支 → **定期清理：`git branch -d <name>`**
- CI 红色时你想 merge → **先修 CI，红色不合并**

## 完成标志

**场景 A（隔离开发）**：
- [ ] worktree 已创建（或分支已从 main 切出）
- [ ] 工作目录已切换到新环境

**场景 B（提交变更）**：
- [ ] 自检清单全部通过
- [ ] commit message 符合格式
- [ ] 已推送到远程分支

**场景 C（创建 PR）**：
- [ ] PR 描述完整（概述 + 文件 + 验证 + 回归）
- [ ] PR 已创建（gh pr create 成功）
- [ ] CI 通过

**场景 D（审查）**：
- [ ] 审查覆盖了正确性/安全性/可维护性/变更范围/测试覆盖
- [ ] 审查意见已提交（approve / request-changes / comment）
- [ ] 如收到反馈 → 逐条处理并 push 更新

**场景 E（合并与清理）**：
- [ ] PR 已合并到 main
- [ ] 远程分支已删除
- [ ] 本地分支已删除
- [ ] worktree 已清理（如使用）
- [ ] 已切回 main 并 pull 到最新
