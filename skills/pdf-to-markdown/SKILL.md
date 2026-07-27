---
name: pdf-to-markdown
description: Extract content from scanned/image-based PDFs using OCR, then reconstruct formulas, equations, and technical notation into proper LaTeX using contextual reasoning. Use this skill whenever the user asks to: extract text from scanned PDFs, OCR a PDF, convert scanned textbook/document pages to Markdown, reconstruct formulas/symbols from OCR output, digitize a physical document containing equations, convert image-based PDF to Markdown with LaTeX, or process scanned technical/scientific content. Works with any language supported by Tesseract OCR.
---

# PDF → Markdown 提取与公式补全

将扫描版PDF（图片型PDF）中的内容提取为结构化Markdown文档。流程分为两个阶段：**OCR提取阶段**（用Python脚本自动化完成）和 **公式补全阶段**（用LLM推理重建LaTeX）。

---

## 工作流总览

```
扫描版PDF → [结构检查] → [OCR提取] → [分章保存] → [LLM重建公式] → 完整MD文档
```

核心思想：**Tesseract负责文字识别，LLM负责理解内容并修正公式**。OCR擅长识别普通文字但几乎无法正确处理数学符号；LLM知道正确的公式应该长什么样。两者互补。

---

## 第一阶段：OCR提取

### 环境准备

```bash
pip install PyMuPDF Pillow pytesseract
```

安装 [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)。需要与文档语言对应的语言包。简体中文为 `chi_sim`，从 [tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast) 下载。

设置环境变量（Windows）：
```
set TESSDATA_PREFIX=<你的tessdata目录>
```

### 步骤1：检查PDF结构（scanned vs text）

用 `scripts/structure_check.py` 分析PDF：

```bash
python scripts/structure_check.py <pdf_path>
```

该脚本检查前10页中有多少页含内嵌文字、多少页为图片。如果文字页数趋近于0而图片页数>0，说明是纯扫描版PDF，需要走完整OCR流程。如果已有内嵌文字，可直接提取无需OCR。

### 步骤2：确定章节结构

在正式OCR前，每隔10~20页采样一次OCR，识别文档的结构（目录、章节标题等）。与用户确认章节起止页码后，保存为JSON：

```json
{
  "0": "00_封面",
  "12": "01_第1章_标题",
  "30": "02_第2章_标题"
}
```

### 步骤3：执行OCR

使用 `scripts/ocr_pipeline.py` 全量提取：

```bash
python scripts/ocr_pipeline.py <pdf_path> <输出目录> --breaks breaks.json
```

脚本处理流程：**逐页 → 提取图片 → 灰度化 → 自适应二值化 → Tesseract OCR → 按章节分文件保存**。

输出为原始Markdown文件，每个文件包含该章节所有页面的OCR文字。公式密集页可能输出很少文字——这是正常的，LLM会在第二阶段重建。

---

## 第二阶段：公式补全（核心）

这是整个流程的核心价值所在。OCR输出中公式部分通常是乱码或残缺的，LLM需要**利用自身对该领域的知识**，将公式重建为正确LaTeX。

### 核心理念：LLM即领域专家

LLM不需要预定义学科公式列表——它本身就"知道"各个学科的标准公式体系。你的任务是：

1. **理解内容**——先通读OCR输出的文字，弄明白这段内容在讲什么、属于哪个学科领域
2. **识别公式边界**——从OCR乱码中识别出哪些字符原属于公式（而非正文），根据上下文判断公式的正确形式
3. **用标准LaTeX重写**——将重建的公式以正确LaTeX写出，包含恰当的编号

### 通用OCR错误模式识别

以下错误类型在各种学科、各种语言的文档中普遍存在：

**符号混淆**（最常见）：
- 希腊字母常被误识别为英文字母：`α/a`、`β/B`、`γ/r`、`δ/d`、`θ/0`、`π/n`、`σ/o`、`φ/p`、`ω/w`、`μ/u`、`λ/λ`、`Δ/△`、`Σ/Z`
- 大型运算符：`∑/Z`、`∫/S`、`∏/T`、`∂/d(草书)`
- 关系符：`≤/<`、`≥/>`、`≠/!=`、`≡/=`、`≈/~~`
- 箭头：`→/->`、`⇒/=>`
- 其他：`∇/V`、`√/V`、`∞/oo`

**数学结构丢失**：
- 分数：OCR会丢失分数线，将 `a/b` 或 ab 拼在一起
- 上下标：`x_i` 可能变成 `xi` 或 `x`，`e^x` 可能变成 `ex`
- 根号：`√x` 可能变成 `Vx`
- 括号匹配：花括号 `{}` 在公式中常丢失
- 多行结构：矩阵、分段函数等复杂结构完全塌陷为单行

**编号混乱**：公式编号如 `(7.1.23)` 可能变成 `(7. 1. 23)`、`(7.1.23).`、`(7.1.23)`（带多余空格或标点）——根据编号体系恢复。

### 公式重建策略

重建公式时遵循以下思考链：

1. **这段落在讲什么物理/数学概念？** — 标题、关键词、上下文会告诉你
2. **这里原本应该是什么公式？** — 考虑学科标准公式 + 语境（"由上式可得"、推导顺序等）
3. **公式编号的逻辑是什么？** — 编号通常反映节号+序号，如 (X.Y.Z)，检查衔接
4. **这个公式的每个符号代表什么？** — 公式中的每个字母/符号在上下文中都有意义，确保重建时保留正确的符号

**示例思考流程**：

> OCR原文：`m将= -k x`
> 上下文："质点在线性回复力作用下的运动"
> 推理方向：这应该是牛顿第二定律的表达，`m a = -k x` 或 `m d²x/dt² = -k x`
> 重建结果：`m\frac{d^2x}{dt^2} = -kx`

### 补全程度判断

不是每个OCR错误都需要"完全补全"。区分三种情况：

| 场景 | 处理方式 |
|------|----------|
| OCR输出基本正确，仅缺下标或符号 | 微调修复 |
| 公式完全乱码，但根据上下文可以确定 | 重建正确LaTeX |
| 有公式残片但上下文完全不足以确定 | 保留OCR原文，加 `<!-- TODO: 需人工确认 -->` 注释 |

### 输出格式规范

每个章节文件按以下结构组织：

```markdown
# 标题

> 提取自《文档名》，经公式补全为LaTeX格式

---

## 节标题

正文文字...

$$
\text{行间公式} \tag{X.X.X}
$$

行内公式如 $E = mc^2$。

### 小节

---

## 习题

X.1 题目...
```

具体说明：
- 行间公式用 `$$...$$` 包裹
- 行内公式用 `$...$`
- 公式编号用 `\tag{X.X.X}` 放在行间公式末尾
- 矢量用 `\vec{...}` 或 `\mathbf{...}`
- 普通文字（非公式部分）保持OCR原样，不要修改
- 移除OCR阶段的元数据提示行，替换为补全说明

### 质量检查清单

补全完成后逐项确认：
- [ ] 所有行间公式用 `$$$$`，行内公式用 `$$`（包裹正确）
- [ ] 希腊字母、上下标、积分求和等符号正确
- [ ] 公式编号格式统一且连续
- [ ] 正文文字（非公式部分）保持原样
- [ ] 章节结构完整（标题层级正确）
- [ ] 文件头标注了公式已补全
- [ ] 不确定的公式加了TODO标记

---

## 适用场景示例

这个技能适用于任何包含公式、符号或特殊记号的扫描文档：

- 理工科教材（数学、物理、化学、工程等）
- 学术论文/预印本中的公式
- 笔记或手稿中包含的数学推导
- 化学方程式、反应式
- 统计或经济模型中的公式
- 任何含有OCR无法正确识别的符号/记号的文档

OCR负责文字——LLM负责理解内容并恢复公式。两者结合可以处理远比单一学科广泛的文档类型。
