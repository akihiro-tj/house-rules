#!/usr/bin/env bash
# rulesets/main.json を元に、リポのデフォルトブランチを守るルールセットを作る。
# 同じ名前のルールセットがあれば上書きする（何度実行しても同じ結果になる）。
#
# 使い方: bash scripts/apply-ruleset.sh <owner/repo> <必須チェック名>...
# 例:     bash scripts/apply-ruleset.sh akihiro-tj/world-history-map "Check and build"
#
# gh（リポの管理者権限でログイン済み）と jq が要る。
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <owner/repo> <required-check>..." >&2
  exit 1
fi

repo="$1"
shift
root="$(cd "$(dirname "$0")/.." && pwd)"
template="$root/rulesets/main.json"

# 必須チェックはすべて GitHub Actions（integration_id 15368）が出すものとして扱う
body="$(jq '(.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks)
  = [$ARGS.positional[] | {context: ., integration_id: 15368}]' "$template" --args "$@")"
name="$(jq -r '.name' "$template")"

# 親（Organization）から継承したものは除き、このリポのルールセットだけを見る
id="$(gh api --paginate "repos/$repo/rulesets?includes_parents=false" \
  | jq -r --arg name "$name" '.[] | select(.name == $name) | .id' | head -n1)"

if [ -n "$id" ]; then
  echo "Updating ruleset \"$name\" ($id) on $repo"
  gh api --method PUT "repos/$repo/rulesets/$id" --input - <<<"$body" >/dev/null
else
  echo "Creating ruleset \"$name\" on $repo"
  gh api --method POST "repos/$repo/rulesets" --input - <<<"$body" >/dev/null
fi
