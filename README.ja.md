# swa-github-workflows

本リポジトリは Azure Static Web Apps (SWA) のロール同期を行う GitHub Action（[swa-github-role-sync](https://github.com/nuitsjp/swa-github-role-sync)）と、招待 Discussion を整理する補助 Action（[swa-github-discussion-cleanup](https://github.com/nuitsjp/swa-github-discussion-cleanup)）を開発・テストするためのハーネスです。両 Action はサブモジュールとして同梱され、本リポジトリ側で CI/CD、検証ワークフロー、サンプルサイトを提供します。

> **重要**
> サブモジュールは GitHub Marketplace 公開要件により `/.github/workflows` を持てないため、本リポジトリが開発者向けワークフローを肩代わりしています。ここで定義しているワークフローは再利用を目的とせず、Action を改良・検証するためのものです。

## 目的

- [swa-github-role-sync](https://github.com/nuitsjp/swa-github-role-sync) と [swa-github-discussion-cleanup](https://github.com/nuitsjp/swa-github-discussion-cleanup) の開発・検証に必要な CI/CD を別リポジトリで維持する。
- ロール同期結果を手元で確認できる SWA サンプルサイトと、/.auth/me を確認するための最小セットを提供する。
- パッケージ化やリリースフロー、依存監査など Marketplace 公開前の品質ゲートを自動化する。

## リポジトリ構成

| パス | 説明 |
| --- | --- |
| `.github/workflows/` | 開発・検証用 GitHub Actions ワークフロー群（CI、リリース補助、サイトデプロイなど） |
| `actions/role-sync/` | [nuitsjp/swa-github-role-sync](https://github.com/nuitsjp/swa-github-role-sync) サブモジュール（ロール同期 Action 本体） |
| `actions/discussion-cleanup/` | [`nuitsjp/swa-github-discussion-cleanup`](https://github.com/nuitsjp/swa-github-discussion-cleanup) サブモジュール（招待 Discussion 掃除 Action） |
| `site/` | SWA へデプロイする検証サイトと `staticwebapp.config.json` |
| `.vscode/` | 推奨エディタ設定（スペルチェック辞書） |

## 前提条件

### GitHub

- Discussion を有効化したリポジトリで運用します。`Announcements` など招待掲示用カテゴリを作成してください。
- 以下のシークレットを Organization またはリポジトリに登録します。
  - `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID`：OIDC で `azure/login` を実行するサービス プリンシパル。
  - `AZURE_STATIC_WEB_APPS_API_TOKEN`：`Azure/static-web-apps-deploy@v1` で検証サイトを更新するためのトークン。
- `ACTIONS_RELEASE_TOKEN`：`repo`、`discussions`、`read:org`を含むPAT。`nuitsjp/swa-github-role-sync`と`nuitsjp/swa-github-discussion-cleanup`の両方に書き込み権限を付けたトークンを1つ発行し、本リポジトリのシークレットとして登録します（運用で使い回すため頻繁に変更しません）。ローカル検証ワークフローでは未設定時に`GITHUB_TOKEN`をフォールバックしますが、リリースでは必須です。
- ワークフロー全体で `discussions: write`、`id-token: write`、`contents: read` 権限が必要です。`Settings > Actions > General` で既定権限を確認してください。

### Azure

- 対象 SWA は Standard プラン以上で、GitHub 認証プロバイダーを有効化していること。
- サービス プリンシパルは対象リソース グループに対して `Contributor` 以上の権限を持っている必要があります。
- 招待メールに記載されるドメイン（例：`https://<app-name>.azurestaticapps.net`）を把握し、必要に応じて Action のテンプレート入力を調整してください。

## 提供する開発用ワークフロー

- `role-sync-npm-ci.yml`：`actions/role-sync` のフォーマット、Lint、テスト、Rollup ビルド、ライセンスチェック、CodeQL、依存監査をまとめて実行します。
- `role-sync-release.yml`：手動トリガーで SemVer タグを作成し、[`nuitsjp/swa-github-role-sync`](https://github.com/nuitsjp/swa-github-role-sync) リポジトリにタグとリリースノートを公開します。
- `role-sync-self-local.yml`：サブモジュール版の Action を直接呼び出し、ロール同期と招待 Discussion 掃除を検証するジョブです。
- `role-sync-self-released.yml`：公開済み [`nuitsjp/swa-github-role-sync@v1`](https://github.com/nuitsjp/swa-github-role-sync/tree/v1) を使った検証ジョブ。ローカル版との差分テストに利用します。
- `deploy-site.yml`：`site/` を SWA にデプロイし、/.auth/me でロール割り当てを確認するためのサイトを公開します。
- `delete-discussions.yml`：開発中に残った招待 Discussion を手動／一括で削除するためのワークフローです。

## 同梱アクション

- `actions/role-sync`：GitHub チーム権限（`admin` / `write`）を SWA のカスタムロールにマッピングし、`az staticwebapp users invite|update` で招待・更新します。結果は Discussion と `GITHUB_STEP_SUMMARY` に出力されます。
- `actions/discussion-cleanup`：招待 Discussion のタイトル テンプレートに基づき経過時間を判定し、期限切れまたは手動指定に応じて削除します。

## クイックスタート

1. リポジトリを取得して移動します。
    ```bash
    git clone https://github.com/nuitsjp/swa-github-workflows.git
    cd swa-github-workflows
    ```
2. サブモジュールを再帰的に初期化して取得します。
    ```bash
    git submodule update --init --recursive
    ```
3. ブランチやタグの検証が必要な場合は最新化します。
    ```bash
    git submodule update --remote --merge
    ```
4. 検証したいワークフローを GitHub Web UI から手動実行します。トップバーの「Run workflow」から対象ブランチや入力値（必要な場合）を指定してください。
5. /.auth/me の挙動を確認したい場合は `Role Sync - Deploy Site` を実行し、SWA ドメインでロールが反映されているか確認します。

シークレット（`AZURE_*`、`AZURE_STATIC_WEB_APPS_API_TOKEN`、`ACTIONS_RELEASE_TOKEN`）は運用側で共有管理しているため、通常は追加・更新不要です。値を差し替える必要が生じた場合のみ、運用担当者と調整してください。

## ワークフローの役割と利用方法

| ワークフロー | 役割 | 主な手動入力 |
| --- | --- | --- |
| `Role Sync - Release` | `actions/role-sync` サブモジュールのリリース。新しい SemVer タグを作成し、GitHub Release を公開します。 | `version`: リリースしたい SemVer 文字列（例 `1.1.0-beta.0`）。`ACTIONS_RELEASE_TOKEN` の権限を確認してから実行してください。 |
| `Discussion Cleanup - Release` | `actions/discussion-cleanup` サブモジュールのリリース。ロール同期リリースと同様にタグと GitHub Release を生成します。 | `version`: リリースしたい SemVer 文字列。`ACTIONS_RELEASE_TOKEN` が両リポジトリへ書き込めることを確認してください。 |
| `Role Sync - Self Sync (Local Action)` | チェックアウト済みサブモジュールを使ってロール同期と招待 Discussion 整理をテストします。 | なし（既定値を使用）。必要に応じて `.github/workflows/role-sync-self-local.yml` の `env` を編集します。 |
| `Role Sync - Self Sync (Released Package)` | 公開済み `nuitsjp/swa-github-role-sync@v1` の挙動を本番相当設定で検証します。 | なし。必要に応じて `SWA_NAME` などの環境変数を編集。 |
| `Role Sync - Deploy Site` | `site/` の静的サイトを SWA にデプロイし、/.auth/me でロールを確認できるようにします。 | なし。 |
| `Role Sync - Delete Discussions` | 招待 Discussion のまとめ削除。`cleanup-mode` により即時削除 (`immediate`) と期限チェック (`expiration`) を切り替えられます。 | `cleanup-mode`（任意、既定 `expiration`）; 必要に応じて `expiration-hours` などを Web UI で変更可能。 |

定期実行・プルリク連動のワークフロー（`role-sync-npm-ci.yml` など）は基本的に手動操作を想定していません。挙動を確認したい場合は、該当ワークフローの「Run workflow」から対象ブランチを選び、必要に応じて入力値を与えて実行してください。

## 開発メモ

- 定期運用にはリリース済み Action を利用する一方で、`role-sync-self-local.yml` で未リリースの変更を事前検証できます。
- 招待 Discussion の削除だけが目的なら `delete-discussions.yml` を `immediate` で起動して一括削除してください。
- サブモジュール更新後は `git status` で差分を確認し、必要なら各サブモジュール側でテスト（`npm ci`, `npm run verify` など）を実行してください。

## ライセンス

本リポジトリはサブモジュールの成果物を束ねています。[swa-github-role-sync](https://github.com/nuitsjp/swa-github-role-sync) と [swa-github-discussion-cleanup](https://github.com/nuitsjp/swa-github-discussion-cleanup) はどちらも MIT License で提供されているため、詳細は各サブモジュールの `LICENSE` を参照してください。
