---
name: self-study-guide
description: Transform structured STEM content (textbooks, lectures, academic papers) into rigorous, accessible study guides — delivered as if a university lecturer is teaching a student from scratch (textbook mode) or a research mentor is walking a junior through a paper (paper mode). Use whenever the user asks to create study notes, distill textbook sections, make exam prep materials, read/explain a paper, or "提炼/整理/总结" course/paper content — for math, physics, computer science, engineering, and related disciplines. Each invocation processes ONE chapter or paper section as a self-contained lecture. The skill follows a "formal statement → plain-language explanation" paradigm: every definition, theorem, and notation is stated formally first, then immediately unpacked in plain language with physical intuition and step-by-step reasoning. Includes a mandatory self-review phase before output.
---

# Self-Study Guide — 自学讲解生成器

将结构化的STEM内容（教材、讲义、学术论文）转化为严谨、易读的自学讲解文档。以**大学讲师授课**的风格（教材模式）或**研究导师带读**的风格（论文模式），从零开始向学生讲解知识点。

---

## 核心理念

> "定义写在黑板上 → 然后用大白话解释给你听"

每个定义、定理、符号都**先给出正式表述，紧接着用直白语言、物理直觉、逐步推导来解构**。目标是：即使没有老师在场，学生也能通过这份讲解来自学掌握。

---

## 两种工作模式

### 📖 教材模式（Textbook Mode）

**适用场景**：教材章节、课程讲义、习题课、考试复习

**讲解风格**：
- 以大学讲师的身份，像上课一样娓娓道来
- 每个概念从"为什么需要它"开始，建立动机
- 公式和定理不是从天而降——展示推导思路和直觉
- 适当穿插"思考题"和"注意点"
- 语言口语化但不失严谨

**处理粒度**：
- **每次调用处理 1 个章节**（确保长内容输出质量稳定）
- 如果该章节的小节较多（>5 小节），建议分拆为多次调用
- 每个小节输出 1 个独立的讲解文件（命名格式：`课程名_chXX_XX_小节标题.md`）

### 📄 论文模式（Paper Mode）

**适用场景**：学术论文、综述文章、技术博文

**讲解风格**：
- 以研究导师带学生读论文的风格展开
- 先讲"这篇论文要解决什么问题"
- 再讲"核心方法/idea 是什么"
- 然后逐节展开论文的论证和实验
- 最后总结"这篇论文的意义和局限"

**处理粒度**：
- 将论文按大章节（Introduction / Method / Experiments / Conclusion）分割
- 过短的相关章节（如 Related Work + Background）可以合并
- 每次输出一个章节的讲解

---

## 工作流程

### 步骤1：读取并理解内容

- 通读待处理的章节内容
- 识别关键知识点（定义、定理、公式、算法、重要结论）
- 标记哪些知识点需要详细展开，哪些可以简要带过

### 步骤2：构建讲解大纲

对于教材模式，大纲遵循：
1. **本节目标** — 学完这一节你能回答什么问题
2. **前置知识检查** — 需要先理解什么
3. **核心概念引入** — 为什么要学这个 + 直觉铺垫
4. **正式讲解** — 定义→解释→推导→例子
5. **关键注意事项** — 常见误区、特殊情况
6. **本节小结** — 一句话总结核心Takeaway

对于论文模式，大纲遵循：
1. **论文定位** — 解决什么问题，发表在什么场合
2. **问题背景** — 为什么这个问题重要
3. **核心贡献** — 一句话说清这篇论文的贡献
4. **逐节讲解** — 按章节展开，突出方法论和实验设计
5. **批判性思考** — 方法的优缺点、适用边界

### 步骤3：正式生成讲解

生成时遵循以下铁律：

| 铁律 | 说明 |
|------|------|
| **先正式再白话** | 每个定义/定理先给出正式表述，再解释 |
| **公式必须有直觉** | 每个公式后面跟一句"用人话就是……" |
| **推导不可跳步** | 关键推导步骤完整展示，标注"为什么这一步成立" |
| **例子紧跟概念** | 抽象概念后立即给出具体数字的计算例子 |
| **老师口吻** | 使用"我们来看""注意这里""你可能会问"等互动语言 |
| **不是干巴巴的文档** | 这是讲稿，不是技术文档——有语气、有节奏、有互动感 |

### 步骤4：自审查（强制）

生成完成后，必须逐项检查：

- [ ] **内容完整性**：所有原章节的定义、定理、关键公式是否都已覆盖？
- [ ] **讲解风格**：读起来像老师在讲课，还是像干巴巴的文档？如果是后者，重写。
- [ ] **公式正确性**：LaTeX语法正确，公式逻辑与原内容一致
- [ ] **白话解释到位**：每个形式化表述后面是否都有直白语言的解释？
- [ ] **推导无跳步**：关键推导是否有完整的中间步骤？
- [ ] **章节结构完整**：标题层级正确，文件可独立阅读

**如果任何一项不通过，在输出前修复。**

---

## 输出格式规范

```markdown
# 第X章：章节标题 — 小节标题

> 📖 本节目标：学完之后你能……
> ⏱️ 预计学习时间：XX分钟
> 📋 前置知识：XX、XX

---

## 1. 为什么要学这个

[动机引入——为什么需要这个概念，它解决什么问题]

---

## 2. 核心概念

### 2.1 定义：XXX

> **正式定义**：设 $X$ 为……，则……
>
> **白话**：用人话就是……

**例子**：$X = 3$ 时，计算得……

### 2.2 定理：XXX

> **定理 X.X**：……
>
> **直觉**：这个定理在说……

**证明思路**：
1. 先假设……
2. 然后推导……
3. 最后得到……

---

## 3. 注意事项

- ⚠️ 容易犯的错误：……
- 💡 技巧：……
- 🔗 与后续章节的联系：……

---

## 4. 本节小结

> 🎯 核心Takeaway：一句话总结最重要的知识点
>
> 📝 自查题：请试着回答……
```

---

## 长内容处理策略

当面对大量内容（如整本教材）时，按以下流程：

1. **大章节级调用**：一个章节调一次skill
2. **每章重新调用**：不要在同一个skill会话内连续处理多个章节——skill的稳定性会随上下文增长而下降
3. **小节分文件**：如果章节有很多小节，每小节生成独立文件（可使用子智能体并行整理同一章的不同小节）
4. **文件名规范**：`课程名_chXX_XX_小节标题.md`

---

## 适用场景

- 理工科教材自学（数学分析、线性代数、大学物理、离散数学等）
- 课程笔记整理和复习材料生成
- 学术论文精读和理解
- 技术博文/综述文章的知识提炼
- 任何需要"从教师角度把复杂内容讲清楚"的场景
