# house-rules

個人開発の各リポジトリで共有する Claude Code のルール・GitHub Actions・テンプレート。

## 言語

- コミットメッセージと GitHub Actions のワークフロー・ジョブ・ステップ名・action の name と description は英語
- rules の本文・ドキュメント・コード内コメント・PR・イシューは日本語

## 守ること

- rules は `packages/<名前>/.apm/instructions/*.instructions.md` を編集する。各リポの `.claude/rules/` は APM の生成物なので、そちらは直さない
- rule のファイル名は、展開先の `.claude/rules/` で各リポ固有の rule（`ui.md`・`worker.md` など）とぶつからない名前にする
- 各リポは `@v1` と `#v1` で参照するので、タグを打った後の変更はすべてのリポに届く。互換性を壊す変更（rule のファイル名・action の inputs や outputs の変更・削除）はメジャーバージョンを上げる
- action は SHA で固定し、コメントでバージョンを書く
- rules・フック・パッケージ構成を変えたら `scripts/check-packages.sh` の期待値も直す
