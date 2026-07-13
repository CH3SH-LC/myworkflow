# MyWorkflow

AI 辅助开发全流程技能包 —— 为 Claude Code 提供从需求理解到代码交付的完整工作流。

## 设计理念

MyWorkflow 将 AI 辅助开发拆解为**六组 16 个专业技能**，通过**五分类运行时路由**自动匹配任务类型，确保每次对话都走正确的流程。不依赖外部插件，所有能力内建。

## 架构

```
用户请求 → SessionStart Hook → 五分类路由 → 专业技能执行
                │
    ┌───────────┼───────────┬───────────┬───────────┐
    ▼           ▼           ▼           ▼           ▼
 代码编写    文稿撰写    深度调研    专项工作    其它任务
 (6 skills)  (1 skill)   (1 skill)  (动态注入)  (直接回答)
```

### 六组技能（16 个）

| 组 | 技能 | 用途 |
|----|------|------|
| **入口** | 任务分类入口 | 自动判断任务类型并路由到对应技能 |
| **代码编写** | 智能体闭环开发 | 功能开发全流程：需求→计划→TDD→真实验证→循环 |
| | Bug修复与验证 | 五步闭环：填细节→排查根因→并行修复→审查→循环 |
| | 大项目初始化 | 为项目建立 CLAUDE.md/PROGRESS.md/STRUCTURE.md 四文件体系 |
| | 大项目工作维护 | 工作前读文档 + 工作后同步进度，肌肉记忆式文档维护 |
| | 根因定位与全面排查 | 5 Whys + 数据流追踪 + 假设验证 + 五项专项排查技术 |
| | Github协作 | 五场景闭环：隔离开发→提交→PR→审查→合并 |
| **文稿撰写** | humanizer-zh | 去除中文文本 AI 痕迹，24 项检测模式 |
| **深度调研** | 深度调研 | 多源并行搜索→交叉验证→综合报告 |
| **辅助写技能** | 辅助写技能 | 用 TDD 方法创建和优化 skill |
| **通用技能** | 需求澄清 | 10 阶段：硬门禁→多方案对比→可视化→落盘 |
| | 任务拆解与派发 | 结构化拆解复杂任务 + 合约驱动的并行派发 |
| | 子智能体执行协议 | 子智能体五阶段工作规范：声明→产出→自检→报告 |
| | 集成验证与修正 | 自动验证 + 判断验证 + 修正循环，确保接口合规 |
| | 轻量级派发 | N 个同类任务快速并行（无合约模式） |
| | 反谄媚 | 通用行为准则：质疑一切、技术诚实、证据驱动 |

## 安装

### 方式一：直接克隆

```bash
# 进入 Claude Code 插件目录
cd ~/.claude/plugins/

# 克隆本仓库
git clone https://github.com/Lenovo/myworkflow.git

# 在 ~/.claude/settings.json 中启用 Hook
# 将 hooks/hooks.json 的内容合并到你的 settings.json 的 hooks 配置中
```

### 方式二：手动配置 Hook

在 `~/.claude/settings.json` 中添加：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [{
          "type": "command",
          "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/session-init.sh\"",
          "timeout": 60
        }]
      },
      {
        "matcher": "clear|compact",
        "hooks": [{
          "type": "command",
          "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/session-init.sh\" --reset",
          "timeout": 60
        }]
      }
    ]
  }
}
```

### 验证安装

启动新的 Claude Code 会话，首次回复应包含：

```
📂 任务分类
🛤️ 路由到：...
📋 执行技能：...
```

## 工作流

```
会话启动
  │
  ▼
SessionStart Hook 注入
  ├── 五分类路由指令
  └── 16 个技能清单
  │
  ▼
收到用户请求
  │
  ▼
任务分类入口 ──→ 判断类型
  │
  ├── 代码编写 ──→ 需求澄清（如需）──→ 智能体闭环开发 / Bug修复与验证
  ├── 文稿撰写 ──→ humanizer-zh
  ├── 深度调研 ──→ 深度调研
  ├── 专项工作 ──→ 动态加载的专项技能
  └── 其它任务 ──→ 直接回答
```

## 核心设计决策

| # | 决策 | 理由 |
|---|------|------|
| 1 | 单一 SessionStart Hook | 每次会话注入分类指令 + 技能清单 |
| 2 | 五分类运行时路由 | 代码编写 / 文稿撰写 / 深度调研 / 专项工作 / 其它任务 |
| 3 | Bug 拆为两个技能 | 排查（只找不修）+ 修复（找→修→审→循环） |
| 4 | TDD + 真实验证双保险 | TDD 保代码正确性，真实验证保用户体验 |
| 5 | Description 铁律 | description 只能写"何时触发"，不写"技能做什么" |
| 6 | 审计模式 | 技能包自带自检能力——派子智能体审计→修复→重审直到零 P0/P1 |
| 7 | 反谄媚内建 | AI 应对用户保持健康怀疑，技术诚实优先于迎合 |

## 目录结构

```
myworkflow/
  plugin.json
  README.md
  PROGRESS.md
  PROGRESS-LITE.md
  hooks/
    hooks.json                 # SessionStart Hook 配置
    session-init.sh            # 五分类路由注入脚本
  skills/
    任务分类入口/               # 公共入口路由器
    智能体闭环开发/             # 功能开发闭环
      references/testing-anti-patterns.md
    Bug修复与验证/              # Bug 修复闭环
    大项目初始化/               # 项目骨架搭建
    大项目工作维护/             # 文档持续同步
    根因定位与全面排查/         # 根因追踪
      references/condition-based-waiting.md
      references/defense-in-depth.md
    Github协作/                # Git/GitHub 全流程
    humanizer-zh/              # 中文 AI 痕迹清除
    深度调研/                   # 深度研究报告
    辅助写技能/                 # Skill 创作辅助
      references/persuasion-principles.md
    需求澄清/                   # 需求信息收集
    任务拆解与派发/             # 结构化并行派发
    子智能体执行协议/           # 子智能体工作规范
    集成验证与修正/             # 接口合规验证
    轻量级派发/                 # 轻量并行派发
    反谄媚/                    # 行为准则
```

## 技术细节

- **Hook**: 单一 `SessionStart` 事件，在 `startup` 和 `clear|compact` 时触发
- **注入机制**: Bash 脚本扫描 `skills/` 目录，生成分类路由指令注入到会话上下文
- **技能格式**: 每个技能为独立目录，含 `SKILL.md`（YAML frontmatter + Markdown 正文）
- **参考文献**: 部分技能含 `references/` 子目录，提供深度参考内容
- **平台**: Windows（Git Bash / PowerShell 双版本命令）+ macOS / Linux

## 开发理念

本技能包遵循以下原则开发：

- **闭环优于速度**：宁可多花 30% 时间一次做对，不要花 300% 时间反复修补
- **描述即触发**：技能的 description 字段只写触发条件，不写内部流程
- **审计驱动迭代**：每次大改后派 4 子智能体并行审计，清零 P0/P1 方止
- **YAGNI**：每个方案生成时主动删减不必要功能
- **真实验证 > 单元测试**：代码写完必须以真实用户身份使用并观察行为

## License

MIT
