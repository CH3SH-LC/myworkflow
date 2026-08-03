#!/usr/bin/env bash
# MyWorkflow v4 registry-scan.sh
# 扫描 installed_plugins.json 注册的全部插件技能，刷新 config/special-skills.json 的 inventory 段（categories 保留不动）。
# 用法: bash registry-scan.sh [plugins_root] [out_file]
# 只扫真正注册的插件（installed_plugins.json 的 installPath），不再全量 os.walk plugins/ 根目录，
# 避免把 marketplaces/ 克隆里从未安装的官方插件源码扫进 inventory。
# 幂等，可随时手动跑。
set -uo pipefail

PLUGINS_ROOT="${1:-$HOME/.claude/plugins}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_FILE="${2:-$SCRIPT_DIR/../config/special-skills.json}"

python - "$PLUGINS_ROOT" "$OUT_FILE" <<'PYEOF'
import sys, os, re, json, time

def parse_frontmatter(content):
    """解析 SKILL.md frontmatter，返回 (name, description)。description 折叠为单行、不截断；
    兼容 YAML 折叠块标量（`>`/`|`），避免多行描述只取到标记符（如 storage-analyzer 的 `>`）。"""
    m = re.match(r'^---\s*\n(.*?)\n---', content, re.S)
    if not m:
        return None, ''
    lines = m.group(1).split('\n')
    name = desc = None
    i = 0
    while i < len(lines):
        mm = re.match(r'^\s*([A-Za-z][\w-]*):\s*(.*)$', lines[i])
        if mm:
            key, val = mm.group(1), mm.group(2)
            if key == 'name' and name is None:
                name = val.strip().strip('"\'')
            elif key == 'description' and desc is None:
                if val.rstrip() in ('>', '|', '>-', '|-'):  # 折叠/字面块标量
                    parts, i = [], i + 1
                    while i < len(lines) and re.match(r'^\s+\S', lines[i]):
                        parts.append(lines[i].strip())
                        i += 1
                    desc = ' '.join(parts)
                    continue
                else:
                    desc = val.strip()
        i += 1
    return (name or ''), (desc or '')

plugins_root, out_file = sys.argv[1], sys.argv[2]

registry_file = os.path.join(plugins_root, 'installed_plugins.json')
if not os.path.exists(registry_file):
    print(f"registry-scan: 未找到 {registry_file}，无法扫描", file=sys.stderr)
    sys.exit(1)

with open(registry_file, encoding='utf-8') as fh:
    registry = json.load(fh)

skills, seen = [], set()
for entry_key, entries in registry.get('plugins', {}).items():
    plugin_name = entry_key.split('@')[0]
    for entry in entries:
        install_path = entry.get('installPath')
        if not install_path or not os.path.isdir(install_path):
            continue
        for root, dirs, files in os.walk(install_path):
            depth = root[len(install_path):].count(os.sep)
            if depth > 12:
                dirs[:] = []
                continue
            dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules', '.cache', '__pycache__')]
            for fn in files:
                if fn.lower() != 'skill.md':
                    continue
                p = os.path.join(root, fn)
                skill_dir = os.path.basename(os.path.dirname(p))
                key = f"{plugin_name}:{skill_dir}"
                if key in seen:
                    continue
                seen.add(key)
                try:
                    with open(p, encoding='utf-8', errors='replace') as fh:
                        content = fh.read(4000)
                    name, desc = parse_frontmatter(content)
                except Exception:
                    name, desc = skill_dir, ''
                if not name:
                    name = skill_dir
                skills.append({
                    "plugin": plugin_name,
                    "slug": key,
                    "name": name,
                    "trigger": desc
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
