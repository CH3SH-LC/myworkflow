#!/usr/bin/env python3
"""
Chapter Text Checker — 章节正文自动化检测脚本
==============================================
Consolidates all mechanical text checks for Chinese web novel chapters into a single
invocation. Skills call this instead of running 10+ separate Grep/Bash commands,
eliminating repeated permission prompts.

Usage:
    python tools/chapter_check.py <chapter_file_path>
    python tools/chapter_check.py <chapter_file_path> --checks word_count,shi,punctuation
    python tools/chapter_check.py <chapter_file_path> --format markdown

Output: JSON with structured check results. Exit code 0 = all hard-checks passed.
"""

import sys
import json
import re
import os
from pathlib import Path
from collections import Counter

# ── Character Classes ──────────────────────────────────────────────

CJK = re.compile(r'[一-鿿㐀-䶿豈-﫿]')
CJK_PUNCT = re.compile(r'[　-〿＀-￯]')
CHINESE_CHAR = re.compile(r'[一-鿿㐀-䶿豈-﫿　-〿＀-￯]')
EN_HALF_PUNCT = re.compile(r'[,.\?!:;"\'()]')
EN_HALF_PUNCT_INLINE = re.compile(r'(?<![a-zA-Z0-9])[,.\?!:;"\'()](?![a-zA-Z0-9])')
ELLIPSIS_BAD = re.compile(r'(?<!…)\.{3}(?!\.)|。。。')
MDASH = re.compile(r'——')
MDASH_BAD = re.compile(r'--(?!-)')
STRAIGHT_DOUBLE_QUOTE = re.compile(r'(?<!")(?<!\w)"(?!\w)(?!")')
STRAIGHT_SINGLE_QUOTE = re.compile(r"(?<!')(?<!\w)'(?!\w)(?!')")

# Markdown patterns
MD_PATTERNS = [
    (re.compile(r'\*\*.*?\*\*'), '**粗体**'),
    (re.compile(r'(?<!\*)\*(?!\*)(?![* ])'), '*斜体* (行内)'),
    (re.compile(r'^---\s*$', re.MULTILINE), '--- 分割线'),
    (re.compile(r'^>\s', re.MULTILINE), '> 引用'),
    (re.compile(r'^#{1,6}\s', re.MULTILINE), '# 标题标记'),
    (re.compile(r'`{1,3}'), '` 代码标记'),
]

# 排版禁则 — 行首不能出现的标点（全角右向标点）。
# NOTE: " (U+201C) and ' (U+2018) are NOT forbidden at line start — they are valid dialogue openers in Chinese.
FORBIDDEN_LINE_START = set('，。、；：！？…》）》】〉」』')
# 行末不能出现的标点（全角左向标点）
# NOTE: " (U+201D) and ' (U+2019) are NOT forbidden at line end — they are valid dialogue closers in Chinese.
FORBIDDEN_LINE_END = set('《（［【〈「『')

# ── Helper Functions ────────────────────────────────────────────────

def load_file(filepath):
    """Load file, trying UTF-8 with and without BOM."""
    if not os.path.exists(filepath):
        return None, f"文件不存在: {filepath}"
    try:
        with open(filepath, 'r', encoding='utf-8-sig') as f:
            text = f.read()
        return text, None
    except UnicodeDecodeError:
        try:
            with open(filepath, 'r', encoding='gbk') as f:
                text = f.read()
            return text, None
        except Exception as e:
            return None, str(e)
    except Exception as e:
        return None, str(e)

def get_lines_and_paras(text):
    """Split text into lines and paragraphs."""
    lines = text.split('\n')
    # Remove the chapter title line (starts with #)
    body_lines = [l for l in lines if not l.strip().startswith('#')]
    body_text = '\n'.join(body_lines)
    # Paragraphs: separated by blank lines
    paras = [p.strip() for p in body_text.split('\n\n') if p.strip()]
    return lines, body_lines, paras, body_text

def _match_context(body_lines, line_idx, match_start, match_end, window=60):
    """
    Build standardized, LLM-actionable context for a match.
    Returns full_line, line_before, line_after, wide_context with enough
    surrounding text for an LLM to understand and modify the matched location.
    """
    stripped = body_lines[line_idx].strip()
    full_line = stripped if len(stripped) <= 300 else stripped[:297] + '…'

    # Find previous non-empty line for narrative context
    line_before = None
    for j in range(line_idx - 1, -1, -1):
        if body_lines[j].strip():
            lb = body_lines[j].strip()
            line_before = lb if len(lb) <= 200 else lb[:197] + '…'
            break

    # Find next non-empty line
    line_after = None
    for j in range(line_idx + 1, len(body_lines)):
        if body_lines[j].strip():
            la = body_lines[j].strip()
            line_after = la if len(la) <= 200 else la[:197] + '…'
            break

    # Wide context around match within the same line
    ctx_start = max(0, match_start - window)
    ctx_end = min(len(stripped), match_end + window)
    wide_context = stripped[ctx_start:ctx_end]
    if ctx_start > 0:
        wide_context = '…' + wide_context
    if ctx_end < len(stripped):
        wide_context = wide_context + '…'

    return {
        "full_line": full_line,
        "line_before": line_before,
        "line_after": line_after,
        "wide_context": wide_context,
    }

# ── Check Functions ─────────────────────────────────────────────────

def check_word_count(text):
    """Check if Chinese character count meets threshold (2500)."""
    cjk_chars = len(CJK.findall(text))
    total_chars = len(text.replace('\n', '').replace('\r', '').replace(' ', ''))
    threshold = 2500
    return {
        "label": "字数统计",
        "chinese_chars": cjk_chars,
        "total_chars_no_whitespace": total_chars,
        "threshold": threshold,
        "passed": cjk_chars >= threshold,
        "delta": cjk_chars - threshold,
        "verdict": "✅ 达标" if cjk_chars >= threshold else f"❌ 不足，差 {threshold - cjk_chars} 字"
    }

def check_shi_judgment(lines):
    """
    Check '是' judgment sentences in narration.
    Pattern: A是B / A就是B / 这便是X / 那正是X / 这才是X / A才是B / A不是B / A是不是B / A还是B
    Limit: ≤2 in narration (excludes dialogue).
    """
    patterns = [
        (re.compile(r'这(便是|才是|就是|正是)\S'), '这便是/这才是/这就是/这正是'),
        (re.compile(r'那(便是|才是|就是|正是)\S'), '那便是/那才是/那就是/那正是'),
        (re.compile(r'.{1,4}?(就是|便是|才是|正是|还是|是不是).'), 'X就是Y / X便是Y / X才是Y / X正是Y / X还是Y / X是不是Y'),
        (re.compile(r'.{1,4}?(?:是|不是).{1,4}?的[人事物]'), 'X是Y的Z (判断句)'),
    ]

    found = []
    # Simple dialogue detection: lines containing full-width quotes likely contain dialogue
    quote_re = re.compile(r'[“”「」『』]')

    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            continue
        # Skip lines that are entirely within quotes or are chapter headings
        if stripped.startswith('#'):
            continue

        # Check each pattern
        for pat, pat_label in patterns:
            for m in pat.finditer(stripped):
                matched_text = m.group()
                # Crude dialogue exclusion: if the match is inside quotes
                start, end = m.start(), m.end()
                before = stripped[:start]
                # Count unclosed quotes before match
                open_quotes = before.count('“') + before.count('「') + before.count('『')
                close_quotes = before.count('”') + before.count('」') + before.count('』')
                inside_quotes = open_quotes > close_quotes

                # Skip emphasis "是...的" pattern for objective facts
                after_context = stripped[end:end+10]
                if after_context.startswith('的') and pat_label == 'X就是Y / X便是Y / X才是Y / X正是Y / X还是Y / X是不是Y':
                    # This might be emphasis pattern "是X的" — still record but flag
                    found.append({
                        "line": i + 1,
                        "text": matched_text + after_context[:3],
                        "pattern": pat_label,
                        "note": "可能为强调句'是…的'，由审查者判定",
                        "in_dialogue": inside_quotes,
                        **_match_context(lines, i, m.start(), m.end())
                    })
                    continue

                found.append({
                    "line": i + 1,
                    "text": matched_text,
                    "pattern": pat_label,
                    "note": "对话内" if inside_quotes else "",
                    "in_dialogue": inside_quotes,
                    **_match_context(lines, i, m.start(), m.end())
                })

    narration_count = sum(1 for f in found if not f["in_dialogue"])
    total_count = len(found)
    limit = 2

    return {
        "label": "\"是\"字判断句检测",
        "total_matches": total_count,
        "narration_matches": narration_count,
        "dialogue_matches": total_count - narration_count,
        "limit": limit,
        "passed": narration_count <= limit,
        "verdict": f"✅ 叙述中 {narration_count} 处 (上限{limit})" if narration_count <= limit
                   else f"❌ 叙述中 {narration_count} 处，超出上限 {limit}",
        "matches": found
    }

def check_not_but_pattern(lines):
    """Check '不是…而是…' and related banned patterns."""
    # Negative lookbehind prevents matching conjunctions: 但是/就是/都是/还是/总是/不是
    # [^。！？] prevents crossing sentence boundaries
    patterns = [
        (re.compile(r'不是[^。！？]{1,30}?(?<![但都就还总不])(而是|是|只是)'), '不是…而是/是/只是…'),
        (re.compile(r'没有[^。！？]{1,30}?(而是|只是)'), '没有…而是…'),
    ]
    found = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        for pat, label in patterns:
            for m in pat.finditer(stripped):
                found.append({
                    "line": i + 1,
                    "text": m.group(),
                    "pattern": label,
                    **_match_context(lines, i, m.start(), m.end())
                })
    return {
        "label": "\"不是…而是…\"类转折句式",
        "count": len(found),
        "passed": len(found) == 0,
        "verdict": "✅ 未发现" if not found else f"❌ 发现 {len(found)} 处违规",
        "matches": found
    }

def check_compare_ruyi_pattern(lines):
    """Check '和/跟/同…一样…' comparison patterns."""
    # Only "一样" — broader synonyms (相同/似的/无异/近似/类似) are caught by yiyang check (limit ≤3)
    pat = re.compile(r'(?:和|跟|同|如同)([^。！？]{1,30}?)一样')
    found = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        for m in pat.finditer(stripped):
            found.append({
                "line": i + 1,
                "text": m.group(),
                **_match_context(lines, i, m.start(), m.end())
            })
    return {
        "label": "\"和…一样…\"类比较句式",
        "count": len(found),
        "passed": len(found) == 0,
        "verdict": "✅ 未发现" if not found else f"❌ 发现 {len(found)} 处违规",
        "matches": found
    }

def check_yiyang_synonyms(text):
    """Count '一样' and its near-synonyms. Hard limit: ≤3 per chapter."""
    keywords = {
        '一样': re.findall(r'一样', text),
        '不一样': re.findall(r'不一样', text),
        '同样': re.findall(r'同样', text),
        '相同': re.findall(r'相同', text),
        '不同': re.findall(r'不同', text),
        '类似': re.findall(r'类似', text),
        '似的': re.findall(r'似的', text),
        '近似': re.findall(r'近似', text),
        '无异': re.findall(r'无异', text),
        '没什么两样': re.findall(r'没什么两样', text),
        '没什么不同': re.findall(r'没什么不同', text),
    }
    counts = {k: len(v) for k, v in keywords.items()}
    total = sum(counts.values())
    limit = 3

    # Find all occurrences with line numbers
    lines = text.split('\n')
    body_lines = [l for l in lines if not l.strip().startswith('#')]
    all_occurrences = []
    for word in keywords:
        pat = re.compile(re.escape(word))
        for i, line in enumerate(lines):
            if not line.strip() or line.strip().startswith('#'):
                continue
            body_idx = sum(1 for l in lines[:i] if not l.strip().startswith('#'))
            for m in pat.finditer(line):
                all_occurrences.append({
                    "line": i + 1,
                    "word": word,
                    **_match_context(body_lines, body_idx, m.start(), m.end())
                })

    return {
        "label": "\"一样\"近义词统计",
        "breakdown": counts,
        "total": total,
        "limit": limit,
        "passed": total <= limit,
        "verdict": f"✅ {total} 次 (上限{limit})" if total <= limit else f"❌ {total} 次，超出上限 {limit}",
        "occurrences": all_occurrences
    }

def check_comparison_markers(lines):
    """Check for comparison/contrast markers in narration."""
    patterns = [
        (re.compile(r'与[^。！？]{1,30}?不同'), '与…不同'),
        (re.compile(r'相比之下'), '相比之下'),
        (re.compile(r'而[^。！？]{1,15}?却'), '而…却…'),
        (re.compile(r'曾经[^。！？]{1,40}?现在'), '曾经…现在…'),
        (re.compile(r'相较于'), '相较于'),
        (re.compile(r'比起[^。！？]{1,15}?[，,]'), '比起…'),
    ]
    found = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        for pat, label in patterns:
            for m in pat.finditer(stripped):
                found.append({
                    "line": i + 1,
                    "text": m.group(),
                    "pattern": label,
                    **_match_context(lines, i, m.start(), m.end())
                })
    return {
        "label": "对比/比较手法检测",
        "count": len(found),
        "passed": len(found) == 0,
        "verdict": "✅ 未发现" if not found else f"⚠️ 发现 {len(found)} 处（铁律禁止）",
        "matches": found
    }

def check_metaphor_markers(lines):
    """Check for metaphor/simile markers. Each section ≤1 metaphor."""
    patterns = [
        (re.compile(r'像\S'), '像…'),
        (re.compile(r'仿佛'), '仿佛'),
        (re.compile(r'似乎'), '似乎'),
        (re.compile(r'.{2,}似的'), '…似的'),
        (re.compile(r'如同'), '如同'),
    ]
    found = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        for pat, label in patterns:
            for m in pat.finditer(stripped):
                found.append({
                    "line": i + 1,
                    "text": m.group(),
                    "marker": label,
                    **_match_context(lines, i, m.start(), m.end())
                })
    # Count per section (sections split by blank line / chapter markers)
    section_counts = {}
    current_section = 1
    for f_item in found:
        # Simple: group by every 50 lines as a "section"
        sec = f_item["line"] // 50 + 1
        section_counts[sec] = section_counts.get(sec, 0) + 1

    sections_over_limit = {k: v for k, v in section_counts.items() if v > 1}
    has_issues = len(sections_over_limit) > 0
    return {
        "label": "比喻/暗喻检测",
        "total_count": len(found),
        "by_section_50lines": section_counts,
        "sections_over_1_per_section": sections_over_limit,
        "has_issues": has_issues,
        "passed": not has_issues,
        "verdict": "✅ 分布合理" if not sections_over_limit
                   else f"⚠️ {len(sections_over_limit)} 个区间比喻超过1个",
        "matches": found
    }

def check_english_punctuation(body_text):
    """Check for English half-width punctuation in Chinese text."""
    # Only check in lines that contain Chinese characters
    lines = body_text.split('\n')
    found = []
    punct_map = {',': '，', '.': '。', '?': '？', '!': '！', ':': '：', ';': '；',
                 '(': '（', ')': '）'}
    for i, line in enumerate(lines):
        if not CJK.search(line):
            continue  # Skip lines without Chinese
        for m in EN_HALF_PUNCT.finditer(line):
            ch = m.group()
            if ch in punct_map:
                found.append({
                    "line": i + 1,
                    "char": ch,
                    "should_be": punct_map[ch],
                    **_match_context(lines, i, m.start(), m.end())
                })
    return {
        "label": "英文半角标点检测",
        "count": len(found),
        "passed": len(found) == 0,
        "verdict": "✅ 未发现" if not found else f"❌ 发现 {len(found)} 处英文标点",
        "matches": found
    }

def check_markdown_formatting(body_text):
    """Check for Markdown formatting in body text."""
    body_lines = body_text.split('\n')
    found = []
    for i, line in enumerate(body_lines):
        if line.strip().startswith('#'):
            continue  # Allow only chapter title
        for pat, label in MD_PATTERNS:
            for m in pat.finditer(line):
                found.append({
                    "line": i + 1,
                    "text": m.group()[:30],
                    "markdown_type": label,
                    **_match_context(body_lines, i, m.start(), m.end())
                })
    return {
        "label": "Markdown 格式标记检测",
        "count": len(found),
        "passed": len(found) == 0,
        "verdict": "✅ 未发现" if not found else f"❌ 发现 {len(found)} 处 Markdown 标记",
        "matches": found
    }

def check_em_dash(body_lines):
    """Count em dashes (——). Limit: ≤1 per chapter, only for interrupted dialogue."""
    found = []
    for i, line in enumerate(body_lines):
        stripped = line.strip()
        if not stripped:
            continue
        for m in MDASH.finditer(stripped):
            found.append({
                "line": i + 1,
                "text": m.group(),
                **_match_context(body_lines, i, m.start(), m.end())
            })
    # Also check for double-hyphen used as dash
    bad_dashes = []
    for i, line in enumerate(body_lines):
        for m in MDASH_BAD.finditer(line.strip()):
            bad_dashes.append({
                "line": i + 1,
                "text": m.group(),
                "note": "使用了 '--' 替代 '——'",
                **_match_context(body_lines, i, m.start(), m.end())
            })

    limit = 1
    return {
        "label": "破折号检测",
        "count": len(found),
        "limit": limit,
        "passed": len(found) <= limit,
        "bad_format_count": len(bad_dashes),
        "verdict": f"✅ {len(found)} 处 (上限{limit})" if len(found) <= limit
                   else f"❌ {len(found)} 处，超出上限 {limit}",
        "matches": found,
        "bad_format_matches": bad_dashes
    }

def check_ellipsis(text):
    """Check correct ellipsis format: …… (U+2026 U+2026), not ... or 。。。"""
    lines = text.split('\n')
    body_lines = [l for l in lines if not l.strip().startswith('#')]
    bad_found = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        # Map original line index to body_lines index for context
        body_idx = sum(1 for l in lines[:i] if not l.strip().startswith('#'))
        for m in ELLIPSIS_BAD.finditer(stripped):
            bad_found.append({
                "line": i + 1,
                "text": m.group(),
                "note": "应使用 '……' (二字宽省略号)",
                **_match_context(body_lines, body_idx, m.start(), m.end())
            })
    return {
        "label": "省略号格式检测",
        "count": len(bad_found),
        "passed": len(bad_found) == 0,
        "verdict": "✅ 格式正确" if not bad_found else f"❌ 发现 {len(bad_found)} 处错误格式",
        "matches": bad_found
    }

def check_quote_style(text):
    """Check for straight quotes vs. curly full-width quotes."""
    lines = text.split('\n')
    body_lines = [l for l in lines if not l.strip().startswith('#')]
    bad_found = []
    # Find lines with Chinese characters that use straight quotes
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        if not CJK.search(stripped):
            continue
        # Check for straight double quotes used as Chinese quotes
        straight_dq = re.findall(r'(?<!\w)"([^"]*?)"(?!\w)', stripped)
        body_idx = sum(1 for l in lines[:i] if not l.strip().startswith('#'))
        for match in straight_dq:
            if CJK.search(match) or len(match) > 0:
                pos = stripped.find(match)
                bad_found.append({
                    "line": i + 1,
                    "text": f'"{match}"',
                    "note": "应使用全角弯引号 \"\"（外层双引号）替代英文直引号",
                    **_match_context(body_lines, body_idx, max(0, pos-1), pos + len(match) + 1)
                })
    return {
        "label": "引号格式检测",
        "count": len(bad_found),
        "passed": len(bad_found) == 0,
        "verdict": "✅ 格式正确" if not bad_found else f"❌ 发现 {len(bad_found)} 处英文直引号",
        "matches": bad_found
    }

def check_typography_forbidden(body_lines):
    """Check for forbidden characters at line start/end (排版禁则)."""
    line_start_violations = []
    line_end_violations = []

    for i, line in enumerate(body_lines):
        stripped = line.strip()
        if not stripped:
            continue
        first_char = stripped[0]
        last_char = stripped[-1]
        if first_char in FORBIDDEN_LINE_START:
            line_start_violations.append({
                "line": i + 1,
                "char": first_char,
                "note": f"行首禁止出现 '{first_char}'",
                **_match_context(body_lines, i, 0, 1)
            })
        if last_char in FORBIDDEN_LINE_END:
            line_end_violations.append({
                "line": i + 1,
                "char": last_char,
                "note": f"行末禁止出现 '{last_char}'",
                **_match_context(body_lines, i, len(stripped)-1, len(stripped))
            })

    has_issues = len(line_start_violations) > 0 or len(line_end_violations) > 0
    return {
        "label": "排版禁则检测",
        "line_start_violations": line_start_violations,
        "line_end_violations": line_end_violations,
        "passed": not has_issues,
        "verdict": "✅ 无禁则违规" if not has_issues
                   else f"⚠️ 行首 {len(line_start_violations)} 处 / 行末 {len(line_end_violations)} 处违规"
    }

def check_punctuation_hierarchy(body_text):
    """
    Check punctuation hierarchy: flag paragraphs with too many periods (文气断裂)
    and paragraphs with 顿号 abuse. Rule: favor commas over periods for web-novel flow.

    Chinese web novel prose must use commas heavily to connect clauses, with periods
    reserved for paragraph ends and strong semantic breaks. A paragraph where periods
    outnumber or approach commas is almost certainly fragmented.

    Detection rules (any one triggers a flag):
    1. Periods >= commas AND periods >= 3 → severe comma deficiency (硬性违规)
    2. Periods >= 3 AND comma:period ratio < 2:1 → 文气断裂
    3. Periods >= 5 → always flagged (severe fragmentation)
    4. 顿号 abuse: >=4 顿号 and 顿号 > commas
    """
    paras = [p.strip() for p in body_text.split('\n\n') if p.strip()]
    flagged = []
    period_heavy = 0
    dun_heavy = 0
    ratio_violations = 0

    # Chapter-level stats
    total_commas = 0
    total_periods = 0
    total_exclaim_question = 0
    total_cjk = 0

    for pi, para in enumerate(paras):
        comma_count = para.count('，')
        period_count = para.count('。')
        exclaim_question = para.count('！') + para.count('？')
        cjk_chars = len(CJK.findall(para))

        total_commas += comma_count
        total_periods += period_count
        total_exclaim_question += exclaim_question
        total_cjk += cjk_chars

        total_sentence_ends = max(1, period_count + exclaim_question)
        avg_chars_per_segment = round(cjk_chars / total_sentence_ends, 0)

        is_violation = False
        notes = []

        # Rule 1: Periods >= commas → severe comma deficiency (most common AI error)
        if period_count >= 3 and period_count >= comma_count:
            is_violation = True
            ratio_violations += 1
            notes.append(
                f"句号({period_count})≥逗号({comma_count})——严重逗号缺失。"
                f"网文追求'一口气读完'的流畅感，应用逗号连接分句，句号仅用于段落收束或强转折"
            )

        # Rule 2: Periods >= 3 AND comma:period ratio < 2:1
        elif period_count >= 3 and comma_count < period_count * 2:
            is_violation = True
            notes.append(
                f"逗号({comma_count})不足句号({period_count})的2倍——文气可能断裂。"
                f"逐句检查：能用逗号合并的短句改为逗号连接"
            )

        # Rule 3: Periods >= 5 → always flag
        elif period_count >= 5:
            is_violation = True
            notes.append(
                f"段落内 {period_count} 个句号，平均每 {avg_chars_per_segment} 字一个句号——文气断裂"
            )

        if is_violation:
            period_heavy += 1
            note = "；".join(notes)
            entry = {
                "para_index": pi + 1,
                "periods": period_count,
                "commas": comma_count,
                "comma_period_ratio": round(comma_count / max(1, period_count), 1),
                "cjk_chars": cjk_chars,
                "avg_chars_per_segment": avg_chars_per_segment,
                "note": note,
                "preview": para[:200] + ('…' if len(para) > 200 else '')
            }
            if len(para) <= 500:
                entry["full_para"] = para
            flagged.append(entry)

        # Check for 顿号 abuse in action sequences
        dun_count = para.count('、')
        if dun_count >= 4 and comma_count < dun_count:
            dun_heavy += 1
            flagged.append({
                "para_index": pi + 1,
                "顿号": dun_count,
                "逗号": comma_count,
                "note": "顿号过多，可能替代逗号用于动作序列——动作承接用逗号，顿号仅用于词/短语并列",
                "preview": para[:200] + ('…' if len(para) > 200 else '')
            })

    # Chapter-level ratio
    chapter_comma_period_ratio = round(total_commas / max(1, total_periods), 1)
    chapter_passed = chapter_comma_period_ratio >= 2.0

    has_issues = len(flagged) > 0

    verdict_parts = []
    if period_heavy > 0:
        verdict_parts.append(f"{period_heavy} 段句号过多/逗号不足")
    if dun_heavy > 0:
        verdict_parts.append(f"{dun_heavy} 段顿号滥用")
    if ratio_violations > 0:
        verdict_parts.append(f"{ratio_violations} 段句号≥逗号(严重)")

    return {
        "label": "标点层级检测",
        "period_heavy_paras": period_heavy,
        "ratio_violation_paras": ratio_violations,
        "dun_abuse_paras": dun_heavy,
        "chapter_comma_count": total_commas,
        "chapter_period_count": total_periods,
        "chapter_comma_period_ratio": chapter_comma_period_ratio,
        "chapter_ratio_passed": chapter_passed,
        "chapter_ratio_note": (
            f"全章逗号({total_commas})与句号({total_periods})之比为 {chapter_comma_period_ratio}:1"
            f"{'——✅ 流畅' if chapter_passed else '——❌ 句号过多，文气断裂。中文网文逗号:句号应至少2:1，理想为3:1以上'}"
        ),
        "passed": not has_issues,
        "verdict": ("✅ 标点层级正常" if not has_issues
                   else "❌ " + "；".join(verdict_parts)),
        "flagged_paragraphs": flagged
    }

def check_cn_en_spacing(body_lines):
    """Check for missing spaces between Chinese and English/digits."""
    # Pattern: Chinese char directly followed by ASCII letter/digit, or vice versa
    cn_en_no_space = re.compile(r'[一-鿿][a-zA-Z0-9]|[a-zA-Z0-9][一-鿿]')
    # Exceptions: chapter numbers, years, etc.
    exceptions = re.compile(r'第\d+[章节卷]|\d+世纪|\d+年代|\d+年|\d+月|\d+日|第\d+')
    found = []
    for i, line in enumerate(body_lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        for m in cn_en_no_space.finditer(stripped):
            matched = m.group()
            # Check if it's a known exception
            full_context = stripped[max(0,m.start()-3):m.end()+3]
            if exceptions.search(full_context):
                continue
            found.append({
                "line": i + 1,
                "text": matched,
                "note": "中文与西文/数字之间应加半角空格",
                **_match_context(body_lines, i, m.start(), m.end())
            })
    return {
        "label": "中英文混排空格检测",
        "count": len(found),
        "passed": len(found) == 0,
        "verdict": "✅ 空格规范" if not found else f"⚠️ 发现 {len(found)} 处缺少空格",
        "matches": found
    }

def check_swear_words(body_lines):
    """Check for profanity / swear words that may violate the '脏话控制' rule."""
    swear_patterns = [
        (re.compile(r'他妈'), '他妈'),
        (re.compile(r'你妈'), '你妈'),
        (re.compile(r'操你'), '操你'),
        (re.compile(r'日的'), '日的'),
        (re.compile(r'娘的'), '娘的'),
        (re.compile(r'你丫'), '你丫'),
        (re.compile(r'特么'), '特么'),
        (re.compile(r'卧槽'), '卧槽'),
        (re.compile(r'我操'), '我操'),
        (re.compile(r'妈的'), '妈的'),
        (re.compile(r'尼玛'), '尼玛'),
        (re.compile(r'滚蛋'), '滚蛋'),
    ]
    found = []
    for i, line in enumerate(body_lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        for pat, label in swear_patterns:
            for m in pat.finditer(stripped):
                found.append({
                    "line": i + 1,
                    "text": m.group(),
                    "marker": label,
                    "note": "检查是否为角色极端情绪的自然流露（非作者加强语气）",
                    **_match_context(body_lines, i, m.start(), m.end())
                })
    return {
        "label": "脏话检测",
        "count": len(found),
        "passed": len(found) == 0,
        "verdict": "✅ 未发现" if not found else f"⚠️ 发现 {len(found)} 处，需人工判断是否为角色情绪自然流露",
        "matches": found
    }


def check_direct_character(body_lines):
    """Check for direct character descriptions banned by the '人物塑造铁律'."""
    patterns = [
        (re.compile(r'.{1,4}是.{1,8}的人'), 'X是Y的人'),
        (re.compile(r'性格.{1,8}'), '性格X'),
        (re.compile(r'向来.{1,8}'), '向来X'),
        (re.compile(r'一向.{1,8}'), '一向X'),
        (re.compile(r'天生.{1,8}'), '天生X'),
        (re.compile(r'他.{1,4}是个.{1,8}'), '他是个X'),
        (re.compile(r'她.{1,4}是个.{1,8}'), '她是个X'),
    ]
    found = []
    for i, line in enumerate(body_lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        for pat, label in patterns:
            for m in pat.finditer(stripped):
                found.append({
                    "line": i + 1,
                    "text": m.group(),
                    "pattern": label,
                    "note": "直接性格描述——应改为动作/神态/语言呈现",
                    **_match_context(body_lines, i, m.start(), m.end())
                })
    return {
        "label": "直接性格描述检测",
        "count": len(found),
        "passed": len(found) == 0,
        "verdict": "✅ 未发现" if not found else f"❌ 发现 {len(found)} 处违规",
        "matches": found
    }


# ── Main ────────────────────────────────────────────────────────────

ALL_CHECKS = {
    "word_count":      (check_word_count,       "字数统计",       True),
    "shi":             (check_shi_judgment,      "\"是\"字判断句",  True),
    "not_but":         (check_not_but_pattern,   "不是…而是…",    True),
    "compare_ruyi":    (check_compare_ruyi_pattern, "和…一样…",   True),
    "yiyang":          (check_yiyang_synonyms,   "一样近义词",     True),
    "comparison":      (check_comparison_markers, "对比手法",      True),
    "metaphor":        (check_metaphor_markers,   "比喻检测",      True),
    "en_punct":        (check_english_punctuation, "英文标点",     True),
    "markdown":        (check_markdown_formatting, "Markdown标记", True),
    "em_dash":         (check_em_dash,            "破折号",        True),
    "ellipsis":        (check_ellipsis,           "省略号格式",    True),
    "quotes":          (check_quote_style,        "引号格式",      True),
    "typography":      (check_typography_forbidden, "排版禁则",    True),
    "punct_hierarchy": (check_punctuation_hierarchy, "标点层级",   True),
    "cn_en_space":     (check_cn_en_spacing,      "中英文空格",    True),
    "swear":           (check_swear_words,        "脏话检测",      True),
    "direct_char":     (check_direct_character,    "直接性格描述",  True),
}

def _safe(s):
    """Replace emoji characters with ASCII-safe alternatives for Windows consoles."""
    replacements = {
        '✅': '[PASS]', '❌': '[FAIL]', '⚠️': '[WARN]',
        '"': '"', '"': '"', ''': '\'', ''': '\'',
    }
    for old, new in replacements.items():
        s = s.replace(old, new)
    return s

def main():
    # Fix encoding for Windows PowerShell
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

    import argparse
    parser = argparse.ArgumentParser(
        description="章节正文自动化检测 — 一次调用完成所有机械性文本检查",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python tools/chapter_check.py 正文/第01章-开端.md
  python tools/chapter_check.py chapter.md --checks word_count,shi,en_punct
  python tools/chapter_check.py chapter.md --format markdown
        """
    )
    parser.add_argument("filepath", help="章节文件路径")
    parser.add_argument("--checks", help="逗号分隔的检查项 (默认全部)", default="all")
    parser.add_argument("--format", choices=["json", "markdown", "summary"],
                        default="json", help="输出格式 (默认json)")
    parser.add_argument("--threshold", type=int, default=2500,
                        help="字数下限 (默认2500)")
    args = parser.parse_args()

    # Load file
    text, error = load_file(args.filepath)
    if error:
        result = {"error": error, "file": args.filepath}
        print(json.dumps(result, ensure_ascii=False, indent=2))
        sys.exit(1)

    lines, body_lines, paras, body_text = get_lines_and_paras(text)

    # Determine which checks to run
    if args.checks == "all":
        selected = list(ALL_CHECKS.keys())
    else:
        selected = [c.strip() for c in args.checks.split(',') if c.strip() in ALL_CHECKS]

    # Run checks
    results = {}
    summary = {"total": len(selected), "passed": 0, "failed": 0, "warning": 0}

    for check_key in selected:
        fn, label, is_hard = ALL_CHECKS[check_key]

        # Some checks need lines, others need full text
        if check_key in ("word_count", "yiyang", "ellipsis", "quotes"):
            check_result = fn(text)
        elif check_key in ("en_punct", "markdown", "punct_hierarchy"):
            check_result = fn(body_text)
        elif check_key == "typography":
            check_result = fn(body_lines)
        elif check_key == "em_dash":
            check_result = fn(body_lines)
        elif check_key == "cn_en_space":
            check_result = fn(body_lines)
        else:
            check_result = fn(body_lines)

        # Override threshold if needed
        if check_key == "word_count" and args.threshold != 2500:
            check_result["threshold"] = args.threshold
            check_result["passed"] = check_result["chinese_chars"] >= args.threshold
            check_result["verdict"] = (
                f"✅ 达标" if check_result["passed"]
                else f"❌ 不足，差 {args.threshold - check_result['chinese_chars']} 字"
            )

        results[check_key] = check_result

        if check_result["passed"]:
            summary["passed"] += 1
        else:
            summary["failed"] += 1

    # Build final output
    output = {
        "file": os.path.abspath(args.filepath),
        "filename": os.path.basename(args.filepath),
        "summary": summary,
        "checks": results
    }

    # Format output
    if args.format == "json":
        print(json.dumps(output, ensure_ascii=False, indent=2))
    elif args.format == "summary":
        print(f"\n{'='*50}")
        print(f"  章节自动化检测报告")
        print(f"  文件: {output['filename']}")
        print(f"{'='*50}")
        for key, check in results.items():
            print(f"  [{_safe(check['label'])}] {_safe(check['verdict'])}")
        print(f"{'='*50}")
        print(f"  通过: {summary['passed']}/{summary['total']}")
        print(f"{'='*50}\n")
    elif args.format == "markdown":
        print(f"## 章节自动化检测报告")
        print(f"\n**文件**: `{output['filename']}`\n")
        print(f"| 检查项 | 结果 |")
        print(f"|--------|------|")
        for key, check in results.items():
            print(f"| {_safe(check['label'])} | {_safe(check['verdict'])} |")
        print(f"\n**通过: {summary['passed']}/{summary['total']}**\n")

        # Show details for failed checks
        for key, check in results.items():
            if not check["passed"] and "matches" in check:
                print(f"\n### {check['label']}\n")
                for m in check["matches"][:10]:
                    loc = f"L{m.get('line', '?')}"
                    ctx = m.get('context', m.get('text', ''))
                    print(f"- **{loc}**: `{ctx}`")
                if len(check.get("matches", [])) > 10:
                    print(f"\n*…还有 {len(check['matches']) - 10} 处未显示*")

    # Exit code
    sys.exit(0 if summary["failed"] == 0 else 1)

if __name__ == "__main__":
    main()
