---
description: 画面のコードと DESIGN.md
applyTo: "DESIGN.md,src/**/*.tsx"
---

# 画面

- ロジックは React から切り離した純関数にして、Vitest で確かめられるようにする
- 色・余白・角丸・文字は DESIGN.md の front matter だけで定義し、コードやスタイルに値を直接書かない
- DESIGN.md を変えたら `pnpm tokens` を実行し、生成物もコミットする
