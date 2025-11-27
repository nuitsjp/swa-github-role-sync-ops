# GitHubリポジトリの権限でAzure Static Web Appsへのアクセスを制御する

## はじめに

非公開のプロダクト開発において、ドキュメントも非公開にしたいケースは多くあります。Azure Static Web Apps（SWA）はGitHub認証をサポートしており、PRごとにステージング環境が自動作成されるため、ドキュメントのホスティング先として優れた選択肢です。

しかし、SWAのロールベースアクセス制御とGitHubリポジトリの権限は連携していません。リポジトリへのアクセス権を持つユーザーだけがドキュメントを閲覧できるようにするには、SWA側でユーザーを手動登録する必要があります。

この課題を解決するため、GitHubリポジトリの権限をSWAのカスタムロールへ自動同期するGitHub Actionsを開発しました。

## 背景：なぜ招待リンク方式なのか

SWAでGitHub認証を使う場合、カスタム認証プロバイダーを実装してリアルタイムに認可することも可能です。しかし、**ステージング環境では自動化が困難**という問題があります。

詳細は以下の記事で解説しています：

👉 [Azure Static Web AppsでGitHubリポジトリの権限による認可を実現する](https://zenn.dev/nuits_jp/articles/2025-11-18-swa-github-auth)

そこで本プロジェクトでは、招待リンク方式を採用しました。定期的にGitHubリポジトリの権限をスキャンし、SWAのカスタムロールを同期。対象ユーザーにはGitHub Discussionを通じて招待リンクを通知します。

## 提供するActions

本プロジェクトでは2つの再利用可能なGitHub Actionsを提供しています。

### swa-github-role-sync

GitHubリポジトリのコラボレーター権限をSWAのカスタムロールへ同期し、新規ユーザーには招待リンクをDiscussionで通知します。

**主な機能：**
- GitHub権限（admin/maintain/write/triage/read）とSWAロールの1:1マッピング
- `minimum-permission`で同期対象の最小権限レベルを指定可能
- 差分検出による重複招待の抑制
- GitHub ActionsのJob Summaryへの結果出力

```yaml
- uses: nuitsjp/swa-github-role-sync@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    swa-name: my-swa-app
    swa-resource-group: my-swa-rg
    discussion-category-name: Announcements
```

### swa-github-discussion-cleanup

有効期限切れの招待Discussionを自動削除します。

**主な機能：**
- 作成日時ベースの期限切れDiscussion自動削除
- タイトルテンプレートによる削除対象のフィルタリング
- 手動実行時の即時削除モード

```yaml
- uses: nuitsjp/swa-github-discussion-cleanup@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    discussion-category-name: Announcements
    expiration-hours: 168
```

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Actions                           │
│  ┌─────────────────────┐    ┌─────────────────────────────┐    │
│  │ swa-github-role-sync│    │swa-github-discussion-cleanup│    │
│  └──────────┬──────────┘    └──────────────┬──────────────┘    │
└─────────────┼───────────────────────────────┼───────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────┐    ┌─────────────────────────────────┐
│   GitHub Repository     │    │       GitHub Discussions        │
│  (Collaborator権限取得) │    │  (招待通知の作成・削除)         │
└─────────────────────────┘    └─────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Azure Static Web Apps                        │
│                  (カスタムロールの同期)                         │
└─────────────────────────────────────────────────────────────────┘
```

## 動作の流れ

1. **定期実行**：GitHub Actionsが週次（または任意のスケジュール）で実行
2. **権限スキャン**：GitHubリポジトリのコラボレーター一覧と権限を取得
3. **差分検出**：SWAの既存ロール割り当てと比較し、追加・更新・削除を判定
4. **ロール同期**：Azure CLIでSWAのカスタムロールを更新
5. **招待通知**：新規ユーザーにはDiscussionで招待リンクを通知
6. **クリーンアップ**：期限切れのDiscussionを自動削除

## セットアップ

### 前提条件

- Azure Static Web App（Standard SKU推奨）
- GitHub App（`Administration: read`, `Discussions: read & write`権限）
- Azure OIDC認証用のマネージドID

### クイックスタート

Azureリソースの作成からSecretsの登録まで、セットアップスクリプトで一括実行できます：

```bash
curl -fsSL https://raw.githubusercontent.com/nuitsjp/swa-github-role-sync-ops/main/scripts/setup-azure-resources.sh \
  | bash -s -- <owner> <repository>
```

詳細なセットアップ手順は[README](https://github.com/nuitsjp/swa-github-role-sync-ops)を参照してください。

## SWA側の設定

`staticwebapp.config.json`でロールベースのアクセス制御を設定します：

```json
{
  "routes": [
    {
      "route": "/*",
      "allowedRoles": ["github-admin", "github-maintain", "github-write"]
    }
  ],
  "responseOverrides": {
    "401": {
      "redirect": "/.auth/login/github",
      "statusCode": 302
    }
  }
}
```

この設定により、`write`以上の権限を持つユーザーのみがサイトにアクセスできます。

## プロジェクト構成

本プロジェクトはモノレポ構成を採用しており、2つのActionsをサブモジュールとして管理しています：

```
swa-github-role-sync-ops/
├── .github/workflows/        # CI・リリースワークフロー
├── actions/
│   ├── role-sync/            # swa-github-role-sync (サブモジュール)
│   └── discussion-cleanup/   # swa-github-discussion-cleanup (サブモジュール)
├── docs/                     # ドキュメント
├── site/                     # サンプルSWAサイト
└── scripts/                  # セットアップスクリプト
```

両Actionは同等のテスト基盤とセキュリティ設定を持ち、npm workspacesで統一的に管理されています。

## 技術スタック

- **言語**：TypeScript（ESM）
- **ビルド**：Rollup
- **テスト**：Jest（ESM対応）
- **リンター**：ESLint + Prettier
- **セキュリティ**：CodeQL, Dependabot, Checkov

## まとめ

Azure Static Web AppsとGitHubリポジトリの権限を連携させることで、非公開ドキュメントのアクセス制御を自動化できます。

**メリット：**
- リポジトリ権限の変更が自動的にSWAに反映される
- PR作成時のステージング環境でも同じアクセス制御が適用される
- 招待リンクの有効期限管理が自動化される

**リンク：**
- [swa-github-role-sync-ops](https://github.com/nuitsjp/swa-github-role-sync-ops) - メインリポジトリ
- [swa-github-role-sync](https://github.com/nuitsjp/swa-github-role-sync) - Role Sync Action
- [swa-github-discussion-cleanup](https://github.com/nuitsjp/swa-github-discussion-cleanup) - Discussion Cleanup Action
- [Azure SWAでGitHubリポジトリの権限による認可を実現する](https://zenn.dev/nuits_jp/articles/2025-11-18-swa-github-auth) - 背景と技術的な詳細