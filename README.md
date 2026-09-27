# house-rules

個人開発の各リポジトリで共有する Claude Code のルール・GitHub Actions・テンプレート。

| 種類 | 置き場所 | 各リポへの入れ方 |
|---|---|---|
| Claude Code の rules とフック | `packages/` | [APM](https://github.com/microsoft/apm)（`pip install apm-cli`） |
| composite action | `.github/actions/` | `uses: akihiro-tj/house-rules/.github/actions/<名前>@main` で参照する |
| reusable workflow | `.github/workflows/apm-update.yml` | `uses: akihiro-tj/house-rules/.github/workflows/apm-update.yml@main` で呼ぶ |
| dependabot.yml・.gitignore | `templates/` | コピーする |
| main を守るルールセット | `rulesets/main.json` | `scripts/apply-ruleset.sh` で作る |

## APM のパッケージ

| パッケージ | 中身 |
|---|---|
| `packages/core` | CLAUDE.md と rules の書き方・APM で展開したファイルの扱い・言語・公開コンテンツ・spec の運用・git の運用・サブエージェントの扱い、superpowers（`obra/superpowers`）と SessionStart フック |
| `packages/web-react` | 画面のコード（`DESIGN.md`・`src/**/*.tsx`）・検証・pnpm |
| `packages/cloudflare-workers` | Cloudflare Workers の設定 |
| `packages/github-actions` | GitHub Actions のワークフロー |

rules は `.claude/rules/<名前>.md` に、フックは `.claude/settings.json` に展開される。

### 各リポの apm.yml

必要なパッケージだけを並べる。

```yaml
name: my-app
version: 1.0.0
targets:
  - claude
dependencies:
  apm:
    - akihiro-tj/house-rules/packages/core#main
    - akihiro-tj/house-rules/packages/web-react#main
    - akihiro-tj/house-rules/packages/cloudflare-workers#main
    - akihiro-tj/house-rules/packages/github-actions#main
executables:
  allow:
    github.com/akihiro-tj/house-rules/packages/core:
      hooks: true
  deny:
    obra/superpowers:
      hooks: true
```

`executables` は各リポに必ず書く。依存先の apm.yml に書いた `executables` は利用側に伝わらない。

- **deny（superpowers）**: superpowers 同梱のフックは `${CLAUDE_PLUGIN_ROOT}` を前提にしていて、APM で展開すると動かない。代わりに core のフックが using-superpowers スキルを追加コンテキストとして注入する
- **allow（core）**: `executables` があると、依存先のフックはすべて承認待ちになる。core のフックを通すために許可する
  - キーは `github.com/` から書く。apm-cli 0.32.0 の `apm install` はこの形でしか照合しない。`apm approve` が書く `akihiro-tj/house-rules/packages/core#<version>` では通らない
  - `apm policy explain` と `apm audit` は、この設定を正しく反映しない。前者はフックを blocked と表示する。後者は superpowers のフックが展開されていないことを drift として報告する

`#main` で入れても、lockfile がコミットを固定する。新しい内容を取り込むときは `apm update` を実行する。

## GitHub Actions

### setup-node-pnpm

checkout・pnpm・Node.js（`.node-version`、pnpm のキャッシュ付き）の準備と、`pnpm install --frozen-lockfile` を行う。

```yaml
steps:
  - uses: akihiro-tj/house-rules/.github/actions/setup-node-pnpm@main
  - run: pnpm test
```

### wrangler-preview と wrangler-preview-delete

Cloudflare Workers の PR プレビューを作る（`wrangler preview`）。URL を出力し、PR のコメントを `--edit-last --create-if-none` で更新する。PR を閉じたら削除する。ビルド・アセットの公開・smoke test は呼び出し側に書く。

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
permissions:
  contents: read
  pull-requests: write
concurrency:
  group: preview-${{ github.event.pull_request.number }}
  cancel-in-progress: true
env:
  PREVIEW_NAME: pr-${{ github.event.pull_request.number }}
jobs:
  deploy:
    name: Deploy preview
    if: >-
      github.event.action != 'closed' &&
      github.actor != 'dependabot[bot]' &&
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-24.04
    env:
      CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
      CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    steps:
      - uses: akihiro-tj/house-rules/.github/actions/setup-node-pnpm@main
      - run: pnpm build
      - id: preview
        uses: akihiro-tj/house-rules/.github/actions/wrangler-preview@main
        with:
          name: ${{ env.PREVIEW_NAME }}
      - name: Smoke test
        run: bash scripts/smoke.sh "${{ steps.preview.outputs.url }}"
  cleanup:
    name: Delete preview
    if: >-
      github.event.action == 'closed' &&
      github.actor != 'dependabot[bot]' &&
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-24.04
    env:
      CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
      CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    steps:
      - uses: akihiro-tj/house-rules/.github/actions/setup-node-pnpm@main
      - uses: akihiro-tj/house-rules/.github/actions/wrangler-preview-delete@main
        with:
          name: ${{ env.PREVIEW_NAME }}
```

wrangler はリポの devDependencies から `pnpm exec` で実行する。`jq` と `gh` は GitHub のランナーに入っているものを使う。

### apm-update（reusable workflow）

`apm update` を実行し、差分があれば `apm-update` ブランチに push して PR を作る（開いている PR があれば更新する。中身が前回と同じなら push しない）。lockfile の `resolved_commit` だけが変わったとき（パッケージの外の変更）は PR を作らない。PR の本文には house-rules の変更の比較リンクを載せる。

```yaml
name: APM update
on:
  schedule:
    - cron: "0 0 * * *" # 毎日 9:00（日本時間）
  workflow_dispatch:
jobs:
  update:
    uses: akihiro-tj/house-rules/.github/workflows/apm-update.yml@main
    secrets: inherit
```

`GITHUB_TOKEN` で作った PR では CI が動かないので、GitHub App のトークンで push と PR の作成をする。最初に一度だけ次を行う。

1. GitHub App を作る（Settings → Developer settings → GitHub Apps → New GitHub App）
   - Webhook の Active は外す
   - Repository permissions は Contents と Pull requests を Read and write にする
   - Where can this GitHub App be installed? は Only on this account にする
2. App の設定画面で秘密鍵を作り（Generate a private key）、Client ID を控える
3. App を使うリポにインストールする（Install App）

リポごとに次の Secrets を登録する（Settings → Secrets and variables → Actions）。

| Secret | 値 |
|---|---|
| `APM_UPDATE_CLIENT_ID` | App の Client ID |
| `APM_UPDATE_PRIVATE_KEY` | 秘密鍵（.pem）の中身 |

## テンプレート

`templates/` のファイルをリポにコピーし、必要に応じて書き足す。

```sh
curl -fsSL https://raw.githubusercontent.com/akihiro-tj/house-rules/main/templates/dependabot.yml -o .github/dependabot.yml
curl -fsSL https://raw.githubusercontent.com/akihiro-tj/house-rules/main/templates/gitignore -o .gitignore
```

## ルールセット

各リポのデフォルトブランチを GitHub のルールセットで守る。共通の rule（git.md）の「main に直接コミットしない。PR を作り、CI が通ってからマージする」を GitHub 側で強制するため。

`rulesets/main.json` の中身:

- 削除と強制 push を禁止する
- PR を必須にする。承認は 0 人（一人で運用しているため）、マージ方法は merge・squash・rebase のすべてを許可する
- 必須ステータスチェックはリポごとに渡す（GitHub Actions のジョブの `name`）。ブランチを最新にしてからのマージ（strict）は求めない。毎日来る apm-update の PR のたびに更新作業が要るようになるため
- バイパスできる人はいない

GitHub はリポ内の JSON を読んで自動では反映しないので、スクリプトで作る。同じ名前（`main`）のルールセットがあれば上書きするので、テンプレートを変えたら同じコマンドをもう一度実行する。リポの管理者権限でログインした `gh` と `jq` が要る。

```sh
bash scripts/apply-ruleset.sh akihiro-tj/world-history-map "Check and build"
bash scripts/apply-ruleset.sh akihiro-tj/house-rules "Lint workflows" "Check APM packages"
```

チェック名を変えたとき（ジョブの `name` を変えたときなど）も、新しい名前で実行し直す。古い名前のままだと、そのチェックが来ないまま PR をマージできなくなる。

apm-update の PR は、GitHub App が `apm-update` ブランチに push して作るので、このルールセットでは止まらない（App のトークンで作った PR では CI も動く）。マージは人が行う。

## 更新の届き方

タグは付けず、各リポは `main` を参照する。GitHub Actions は `@main` なので、マージした時点ですべてのリポに届く。APM のパッケージは各リポの lockfile が固定するので、apm-update ワークフローが作る PR をマージしたとき（または各リポで `apm update` を実行したとき）に届く。

## 開発

```sh
pip install apm-cli==0.32.0
bash scripts/check-packages.sh   # 全パッケージをダミーのプロジェクトに入れ、rules とフックの展開を確かめる
```
