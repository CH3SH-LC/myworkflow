#!/usr/bin/env bash
# MyWorkflow registry-scan.sh
# 扫描全部本地插件技能，刷新 config/special-skills.json 的 inventory 段（categories 保留不动）。
# 用法: bash registry-scan.sh [plugins_root] [out_file]
# 始终全量扫描（单次 python os.walk，约 1s）：mtime 快速路径会因手工编辑 categories 而漏刷新 inventory。
# 幂等，可随时手动跑。
set -uo pipefail

PLUGINS_ROOT="${1:-$HOME/.claude/plugins}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_FILE="${2:-$SCRIPT_DIR/../config/special-skills.json}"

python - "$PLUGINS_ROOT" "$OUT_FILE" <<'PYEOF'
import sys, os, re, json, time

plugins_root, out_file = sys.argv[1], sys.argv[2]

skills, seen = [], set()
for root, dirs, files in os.walk(plugins_root):
    depth = root[len(plugins_root):].count(os.sep)
    if depth > 8:
        dirs[:] = []
        continue
    dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules', '.cache', '__pycache__')]
    for fn in files:
        if fn.lower() != 'skill.md':
            continue
        p = os.path.join(root, fn)
        skill_dir = os.path.basename(os.path.dirname(p))

        # 解析 plugin 名：找最后一个 "skills" 段，向前定位插件目录
        parts = p.split(os.sep)
        si = None
        for idx in range(len(parts) - 2, -1, -1):
            if parts[idx] == 'skills':
                si = idx
                break
        if si is None:
            plugin_dir = 'unknown'
        elif si >= 4 and parts[si - 4] == 'cache':
            # plugins/cache/<marketplace>/<plugin>/<ver>/skills/<skill>/
            plugin_dir = parts[si - 2]
        else:
            # plugins/<plugin>/skills/<skill>/ 或 marketplaces/.../plugins/<plugin>/skills/<skill>/
            plugin_dir = parts[si - 1]
        key = f"{plugin_dir}:{skill_dir}"
        if key in seen:
            continue
        seen.add(key)
        name, desc = skill_dir, ''
        try:
            with open(p, encoding='utf-8', errors='replace') as fh:
                content = fh.read(4000)
            m = re.match(r'^---\s*\n(.*?)\n---', content, re.S)
            if m:
                fm = m.group(1)
                nm = re.search(r'^\s*name:\s*(.+)$', fm, re.M)
                if nm:
                    name = nm.group(1).strip().strip('"\'')
                dm = re.search(r'^\s*description:\s*(.+)$', fm, re.M)
                if dm:
                    desc = dm.group(1).strip()
        except Exception:
            pass
        skills.append({
            "plugin": plugin_dir,
            "slug": key,
            "name": name,
            "trigger": desc[:120]
        })

skills.sort(key=lambda s: (s["plugin"], s["slug"]))

data = {"version": 1, "categories": {}}
if os.path.exists(out_file):
    try:
        with open(out_file, encoding='utf-8') as fh:
            old = json.load(fh)
        data["categories"] = old.get("categories", {})
    except Exception:
        pass

data["inventory"] = {
    "updatedAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "count": len(skills),
    "skills": skills,
}

os.makedirs(os.path.dirname(out_file), exist_ok=True)
with open(out_file, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
print(f"registry-scan: {len(skills)} skills -> {out_file}")
PYEOF
