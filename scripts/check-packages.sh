#!/usr/bin/env bash
# packages/ の全パッケージをダミーのプロジェクトに apm install し、
# rules と SessionStart フックが期待どおりに展開されるかを確かめる。
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/apm.yml" <<YAML
name: check-packages
version: 0.0.0
targets:
  - claude
dependencies:
  apm:
    - $root/packages/core
    - $root/packages/web-react
    - $root/packages/cloudflare-workers
    - $root/packages/github-actions
executables:
  allow:
    $root/packages/core:
      hooks: true
  deny:
    obra/superpowers:
      hooks: true
YAML

(cd "$work" && apm install)

python3 - "$work" <<'PY'
import json, pathlib, sys

work = pathlib.Path(sys.argv[1])
rules = work / ".claude" / "rules"
errors = []

# rule ごとの期待する paths（None は paths なしの常時読み込み）
expected = {
    "instructions.md": ["CLAUDE.md", ".claude/rules/**"],
    "language.md": None,
    "public-content.md": None,
    "specs.md": None,
    "git.md": None,
    "subagents.md": None,
    "react.md": ["DESIGN.md", "src/**/*.tsx"],
    "testing.md": None,
    "pnpm.md": None,
    "cloudflare-workers.md": ["wrangler.jsonc", ".github/workflows/**"],
    "github-actions.md": [".github/workflows/**", ".github/actions/**"],
}

actual = sorted(p.name for p in rules.glob("*.md"))
if actual != sorted(expected):
    errors.append(f"rules の一覧が違う: {actual}")

for name, paths in expected.items():
    path = rules / name
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    if paths is None:
        if text.startswith("---"):
            errors.append(f"{name} に front matter がある（常時読み込みにならない）")
        continue
    front = text.split("---")[1] if text.startswith("---") else ""
    got = [line.strip().removeprefix("- ").strip('"') for line in front.splitlines() if line.strip().startswith("- ")]
    if got != paths:
        errors.append(f"{name} の paths が違う: {got}")

settings = json.loads((work / ".claude" / "settings.json").read_text(encoding="utf-8"))
commands = [
    h["command"]
    for entry in settings.get("hooks", {}).get("SessionStart", [])
    for h in entry["hooks"]
]
if commands != ['"${CLAUDE_PROJECT_DIR}/.claude/hooks/core/superpowers-session-start.sh"']:
    errors.append(f"SessionStart フックが違う（superpowers 同梱のフックは入らないはず）: {commands}")

if not (work / ".claude" / "skills" / "using-superpowers" / "SKILL.md").exists():
    errors.append("using-superpowers スキルが展開されていない")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print("OK")
PY

# フックが using-superpowers を additionalContext として出力するか
CLAUDE_PROJECT_DIR="$work" "$work/.claude/hooks/core/superpowers-session-start.sh" \
  | python3 -c '
import json, sys
out = json.load(sys.stdin)["hookSpecificOutput"]
assert out["hookEventName"] == "SessionStart"
assert "using-superpowers" in out["additionalContext"]
print("hook OK")
'
