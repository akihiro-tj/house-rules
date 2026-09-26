#!/usr/bin/env bash
# APM が展開した using-superpowers スキルを SessionStart の追加コンテキストとして注入する。
# superpowers 同梱のフックはプラグイン構成（${CLAUDE_PLUGIN_ROOT}）前提で、
# APM 展開後のディレクトリ構成では動かないため代わりに使う。
set -euo pipefail

skill_file="${CLAUDE_PROJECT_DIR:-.}/.claude/skills/using-superpowers/SKILL.md"
[ -f "$skill_file" ] || exit 0

python3 - "$skill_file" <<'PY'
import json, sys

with open(sys.argv[1], encoding="utf-8") as f:
    content = f.read()

context = (
    "<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n"
    "**Below is the full content of your 'superpowers:using-superpowers' skill - "
    "your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n"
    f"{content}\n</EXTREMELY_IMPORTANT>"
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}))
PY
