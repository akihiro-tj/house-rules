# house-rules

個人開発の各リポジトリで共有する Claude Code のルール・GitHub Actions・テンプレート。

## 言語

- コミットメッセージと GitHub Actions のワークフロー・ジョブ・ステップ名・action の name と description は英語
- rules の本文・ドキュメント・コード内コメント・PR・イシューは日本語

## 守ること

- rules は `packages/<名前>/.apm/instructions/*.instructions.md` を編集する。各リポの `.claude/rules/` は APM の生成物なので、そちらは直さない
- rule のファイル名は、展開先の `.claude/rules/` で各リポ固有の rule（`ui.md`・`worker.md` など）とぶつからない名前にする
- タグは付けず、各リポは `main` を参照する。マージした変更はそのまますべてのリポに届くので、rule のファイル名・action の inputs や outputs を変えたり消したりするときは、PR の本文に各リポで要る対応を書く
- action は SHA で固定し、コメントでバージョンを書く
- `rulesets/main.json` は各リポに自動では届かない。変えたら、PR の本文に各リポで `scripts/apply-ruleset.sh` を実行し直すことを書く
- rules・フック・パッケージ構成を変えたら `scripts/check-packages.sh` の期待値も直す
