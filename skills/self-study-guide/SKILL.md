---
name: self-study-guide
description: Transform structured STEM content (textbooks, lectures, academic papers) into rigorous, accessible study guides — delivered as if a university lecturer is teaching a student from scratch (textbook mode) or a research mentor is walking a junior through a paper (paper mode). Use whenever the user asks to create study notes, distill textbook sections, make exam prep materials, read/explain a paper, or "提炼/整理/总结" course/paper content — for math, physics, computer science, engineering, and related disciplines. Each invocation processes ONE chapter or paper section as a self-contained lecture. The skill follows a "formal statement → plain-language explanation" paradigm: every definition, theorem, and notation is stated formally first, then immediately unpacked in plain language with physical intuition and step-by-step reasoning. Includes a mandatory self-review phase before output.
---

# Self-Study Guide — 自学讲解生成器

将结构化 STEM 内容（教材/讲义/论文）转化为严谨易读的自学讲解，以**大学讲师授课**（教材模式）或**研究导师带读**（论文模式）风格，从零讲解知识点。

## 核心理念

**形式陈述 → 白话解释范式**：每个定义、定理、符号**先给出正式表述，紧接着用直白语言、物理直觉、逐步推导解构**。目标是学生无需老师在场也能自学掌握。

## 两种工作模式

### 教材模式（Textbook Mode）
- 适用：教材章节、课程讲义、习题课、考试复习。
- 风格：讲师身份娓娓道来；每个概念从"为什么需要它"建立动机；公式和定理展示推导思路与直觉；穿插思考题和注意点；口语化但不失严谨。
- 粒度：**每次调用处理 1 个章节**；小节 >5 建议分拆；每小节输出独立文件。

### 论文模式（Paper Mode）
- 适用：学术论文、综述、技术博文。
- 风格：研究导师带读——先讲"解决什么问题"，再讲"核心方法/idea"，逐节展开论证与实验，最后总结意义与局限。
- 粒度：按大章节（Intro/Method/Experiments/Conclusion）分割；过短相关章节可合并；每次输出一个章节讲解。

## 工作流程

### 步骤 1：读取并理解内容
通读章节，识别关键知识点（定义/定理/公式/算法/重要结论），标记哪些详展、哪些略过。

### 步骤 2：构建讲解大纲
- **教材模式**：本节目标 → 前置知识检查 → 核心概念引入（为什么学+直觉）→ 正式讲解（定义→解释→推导→例子）→ 关键注意事项 → 本节小结（一句话 Takeaway）。
- **论文模式**：论文定位 → 问题背景 → 核心贡献 → 逐节讲解（突出方法论与实验设计）→ 批判性思考（优缺点、适用边界）。

### 步骤 3：正式生成讲解（铁律）

| 铁律 | 说明 |
|------|------|
| **先正式再白话** | 每个定义/定理先正式表述再解释 |
| **公式必须有直觉** | 每个公式后跟一句"用人话就是…" |
| **推导不可跳步** | 关键推导完整展示，标注"为什么这一步成立" |
| **例子紧跟概念** | 抽象概念后立即给出具体数字例子 |
| **老师口吻** | "我们来看""注意这里""你可能会问"等互动语言 |
| **不是干巴巴的文档** | 是讲稿——有语气、有节奏、有互动感 |

### 步骤 4：自审查（强制）

生成完成后必须逐项检查，**任何一项不通过则在输出前修复**：

- [ ] **内容完整性**：原章节所有定义、定理、关键公式已覆盖？
- [ ] **讲解风格**：像老师讲课而非干巴巴文档？后者 → 重写。
- [ ] **公式正确性**：LaTeX 语法正确，逻辑与原内容一致。
- [ ] **白话解释到位**：每个形式化表述后都有直白解释？
- [ ] **推导无跳步**：关键推导有完整中间步骤？
- [ ] **章节结构完整**：标题层级正确，文件可独立阅读。

## 输出格式规范

```markdown
# 第X章：章节标题 — 小节标题

> 📖 本节目标：学完之后你能……
> ⏱️ 预计学习时间：XX分钟
> 📋 前置知识：XX、XX

---
## 1. 为什么要学这个
[动机引入——为什么需要这个概念，解决什么问题]

## 2. 核心概念
### 2.1 定义：XXX
> **正式定义**：设 $X$ 为……，则……
> **白话**：用人话就是……
**例子**：$X = 3$ 时，计算得……

### 2.2 定理：XXX
> **定理 X.X**：……
> **直觉**：这个定理在说……
**证明思路**：1. 先假设… 2. 然后推导… 3. 最后得到…

## 3. 注意事项
- ⚠️ 容易犯的错误 / 💡 技巧 / 🔗 与后续章节的联系

## 4. 本节小结
> 🎯 核心Takeaway：一句话
> 📝 自查题：请试着回答……
```

## 长内容处理策略

1. **大章节级调用**：一个章节调一次 skill。
2. **每章重新调用**：不在同一会话连续处理多章（稳定性随上下文增长下降）。
3. **小节分文件**：小节多则每小节独立文件，可用子智能体并行整理同章不同小节。
4. **文件名规范**：`课程名_chXX_XX_小节标题.md`。

## 适用场景

理工科教材自学（数分/线代/大物/离散等）、课程笔记与复习材料、论文精读、技术博文知识提炼——任何"从教师角度把复杂内容讲清楚"的场景。
