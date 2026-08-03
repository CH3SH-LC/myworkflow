---
name: pdf-to-markdown
description: Extract content from scanned/image-based PDFs using OCR, then reconstruct formulas, equations, and technical notation into proper LaTeX using contextual reasoning. Use this skill whenever the user asks to: extract text from scanned PDFs, OCR a PDF, convert scanned textbook/document pages to Markdown, reconstruct formulas/symbols from OCR output, digitize a physical document containing equations, convert image-based PDF to Markdown with LaTeX, or process scanned technical/scientific content. Works with any language supported by Tesseract OCR.
---

# PDF → Markdown 提取与公式补全

将扫描版（图片型）PDF 提取为结构化 Markdown，两阶段：**OCR 提取**（Python 脚本自动化）+ **公式补全**（LLM 推理重建 LaTeX）。核心：Tesseract 负责文字，LLM 负责理解内容并修正公式——OCR 几乎无法处理数学符号，LLM 知道正确公式应长什么样。

**主线**：扫描 PDF → 结构检查 → OCR 提取 → 分章保存 → LLM 重建公式 → 完整 MD。

## 第一阶段：OCR 提取

### 环境准备

```bash
pip install PyMuPDF Pillow pytesseract
```
安装 [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) 及对应语言包（简体中文 `chi_sim`，从 [tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast) 下载）。Windows 设置 `TESSDATA_PREFIX=<tessdata目录>`。

### 步骤 1：检查 PDF 结构（scanned vs text）

```bash
python scripts/structure_check.py <pdf_path>
```
检查前 10 页含内嵌文字/图片的比例：文字页≈0 且图片页>0 → 纯扫描版，走完整 OCR；已有内嵌文字 → 直接提取。

### 步骤 2：确定章节结构

正式 OCR 前每隔 10~20 页采样一次，识别目录/章节标题；与用户确认起止页码后存 JSON：
```json
{ "0": "00_封面", "12": "01_第1章_标题", "30": "02_第2章_标题" }
```

### 步骤 3：执行 OCR

```bash
python scripts/ocr_pipeline.py <pdf_path> <输出目录> --breaks breaks.json
```
流程：逐页 → 提取图片 → 灰度化 → 自适应二值化 → Tesseract OCR → 按章节分文件。输出原始 Markdown，公式密集页可能文字很少——正常，第二阶段重建。

## 第二阶段：公式补全（核心）

### 核心理念：LLM 即领域专家

不需要预定义学科公式列表——LLM 本身就"知道"各学科标准公式。任务：
1. **理解内容**——通读 OCR 文字，弄清讲什么、属哪个学科。
2. **识别公式边界**——从 OCR 乱码中识别哪些字符原属公式，按上下文判断正确形式。
3. **用标准 LaTeX 重写**——含恰当的公式编号。

### 通用 OCR 错误模式

**符号混淆**（最常见）：希腊字母误识别为英文字母 `α/a、β/B、γ/r、δ/d、θ/0、π/n、σ/o、φ/p、ω/w、μ/u、Δ/△、Σ/Z`；大型运算符 `∑/Z、∫/S、∏/T、∂/d`；关系符 `≤/<、≥/>、≠/!=、≡/=、≈/~~`；箭头 `→/->、⇒/=>`；其他 `∇/V、√/V、∞/oo`。

**数学结构丢失**：分数丢分数线（`a/b` 拼成 ab）；上下标丢失（`x_i`→`xi`，`e^x`→`ex`）；根号 `√x`→`Vx`；花括号 `{}` 丢失；矩阵/分段函数等复杂结构塌陷为单行。

**编号混乱**：`(7.1.23)` 可能变 `(7. 1. 23)`/`(7.1.23).`——根据编号体系恢复。

### 公式重建策略

思考链：这段落在讲什么物理/数学概念？这里原本应是什么公式（学科标准 + 语境如"由上式可得"）？编号逻辑是什么（节号+序号如 X.Y.Z）？每个符号代表什么（保留正确符号）？

示例：OCR `m将= -k x` + 上下文"质点在线性回复力作用下的运动" → 重建 `m\frac{d^2x}{dt^2} = -kx`。

### 补全程度判断

| 场景 | 处理 |
|------|------|
| OCR 基本正确，仅缺下标/符号 | 微调修复 |
| 公式完全乱码但上下文可确定 | 重建正确 LaTeX |
| 有残片但上下文不足 | 保留 OCR 原文，加 `<!-- TODO: 需人工确认 -->` 注释 |

### 输出格式规范

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
## 习题
X.1 题目...
```

说明：行间公式 `$$...$$`、行内 `$...$`、编号 `\tag{X.X.X}` 放行间公式末尾、矢量用 `\vec{}`/`\mathbf{}`、普通文字保持 OCR 原样、移除 OCR 元数据提示行替换为补全说明。

### 质量检查清单

- [ ] 行间公式用 `$$`、行内用 `$`（包裹正确）
- [ ] 希腊字母、上下标、积分求和符号正确
- [ ] 公式编号格式统一且连续
- [ ] 正文文字（非公式）保持原样
- [ ] 章节结构完整（标题层级正确）
- [ ] 文件头标注公式已补全
- [ ] 不确定的公式加 TODO 标记

## 适用场景

理工科教材（数理化/工程）、含公式的学术论文/预印本、笔记/手稿推导、化学方程式、统计/经济模型——任何含 OCR 无法正确识别符号的扫描文档。
