---
description: CLAUDE.md と rules の書き方
applyTo: "CLAUDE.md,.claude/rules/**"
---

# CLAUDE.md と rules の書き方

公式のベストプラクティスに従う。迷ったら読む。

- https://code.claude.com/docs/en/best-practices#write-an-effective-claude-md
- https://code.claude.com/docs/en/memory#write-effective-instructions

特に次を守る。

- 1 行ごとに「消したら Claude が失敗するか」を問い、失敗しないなら書かない。コードや `package.json` を読めば分かること、テストや設定が強制していること、コードの横のコメントで足りることは書かない
- 「いま〜」のような状態や、頻繁に変わる情報を書かない。変わらないルールだけを書く
- 特定のファイルを触るときだけ要るものは、`paths` を付けて `.claude/rules/` に置く。同じルールを CLAUDE.md と rules の両方に書かない
- 禁止だけでなく理由も短く書く。理由があれば、書いていない場面にも判断が及ぶ
