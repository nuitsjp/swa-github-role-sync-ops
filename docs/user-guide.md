# ユーザーガイド

Azure Static Web Apps (SWA) のロール同期と招待 Discussion 掃除を GitHub Actions で行うための手順を、CLI ベースでまとめました。ワークフロー例は必要最低限の入力だけを指定しています。テンプレートやロール名を変える場合は「追加設定」を参照してください。

## 前提条件

- Azure CLI (`az`) と GitHub CLI (`gh`) がインストール済みで、ログイン済みであること。
- 対象リポジトリで Discussions を有効化し、招待通知を投稿するカテゴリーを用意しておく（例: `Announcements`）。
- GitHub App を作成済み（`Administration: read`, `Discussions: read & write`、必要に応じて `Members: read`）。App ID と private key を控えておく。
- 実行するワークフローが `contents: read` / `discussions: write` / `id-token: write` 権限を持つよう `permissions` を設定できること。

## Azure リソースの作成

ロール同期に必要な Azure リソース（リソースグループ、Static Web App、マネージド ID）を作成し、GitHub Actions から OIDC でログインできるよう設定します。

### リソース命名規則

Azure Cloud Adoption Framework の[リソース省略形ガイダンス](https://learn.microsoft.com/ja-jp/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)に基づき、以下の命名規則を使用します。

| リソース種別 | プレフィクス | 命名例 |
|-------------|-------------|--------|
| リソースグループ | `rg` | `rg-swa-github-role-sync-ops-prod` |
| Static Web App | `stapp` | `stapp-swa-github-role-sync-ops-prod` |
| マネージド ID | `id` | `id-swa-github-role-sync-ops-prod` |

### 1. リソースグループの作成

```powershell
az group create --name rg-swa-github-role-sync-ops-prod --location japaneast
```

出力例:

```json
{
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-swa-github-role-sync-ops-prod",
  "location": "japaneast",
  "name": "rg-swa-github-role-sync-ops-prod",
  "properties": {
    "provisioningState": "Succeeded"
  }
}
```

### 2. Static Web App の作成

ロール同期機能を使用するには **Standard** SKU 以上が必要です。また、Static Web App は利用可能なリージョンが限られているため、`eastasia` などを指定します。

```powershell
az staticwebapp create `
  --name stapp-swa-github-role-sync-ops-prod `
  --resource-group rg-swa-github-role-sync-ops-prod `
  --location eastasia `
  --sku Standard
```

出力例:

```json
{
  "defaultHostname": "white-sea-0b4ae8400.3.azurestaticapps.net",
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-swa-github-role-sync-ops-prod/providers/Microsoft.Web/staticSites/stapp-swa-github-role-sync-ops-prod",
  "location": "East Asia",
  "name": "stapp-swa-github-role-sync-ops-prod",
  "sku": {
    "name": "Standard",
    "tier": "Standard"
  }
}
```

`defaultHostname` が SWA の URL です。後でカスタムドメインを設定することも可能です。

### 3. マネージド ID の作成

GitHub Actions から OIDC 認証で Azure にアクセスするためのユーザー割り当てマネージド ID を作成します。

```powershell
az identity create `
  --name id-swa-github-role-sync-ops-prod `
  --resource-group rg-swa-github-role-sync-ops-prod `
  --location japaneast
```

出力例:

```json
{
  "clientId": "89020403-e965-44d0-855c-0e617397312c",
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/rg-swa-github-role-sync-ops-prod/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-swa-github-role-sync-ops-prod",
  "principalId": "29a88270-120d-4760-99f1-30dbcd08c578",
  "tenantId": "fe689afa-3572-4db9-8e8a-0f81d5a9d253"
}
```

以下の値を控えておきます（後で GitHub Secrets に登録）:

- `clientId` → `AZURE_CLIENT_ID`
- `tenantId` → `AZURE_TENANT_ID`

サブスクリプション ID は以下で取得できます:

```powershell
az account show --query id --output tsv
```

### 4. OIDC フェデレーション資格情報の作成

GitHub Actions がマネージド ID としてログインできるよう、フェデレーション資格情報を作成します。`subject` の `{owner}/{repo}` は対象リポジトリに置き換えてください。

```powershell
az identity federated-credential create `
  --name fc-github-actions-main `
  --identity-name id-swa-github-role-sync-ops-prod `
  --resource-group rg-swa-github-role-sync-ops-prod `
  --issuer https://token.actions.githubusercontent.com `
  --subject repo:nuitsjp/swa-github-role-sync-ops:ref:refs/heads/main `
  --audiences api://AzureADTokenExchange
```

出力例:

```json
{
  "audiences": ["api://AzureADTokenExchange"],
  "issuer": "https://token.actions.githubusercontent.com",
  "name": "fc-github-actions-main",
  "subject": "repo:nuitsjp/swa-github-role-sync-ops:ref:refs/heads/main"
}
```

> **Note**: `subject` の形式は以下のパターンが利用可能です:
> - 特定ブランチ: `repo:{owner}/{repo}:ref:refs/heads/{branch}`
> - 特定タグ: `repo:{owner}/{repo}:ref:refs/tags/{tag}`
> - 特定環境: `repo:{owner}/{repo}:environment:{environment}`
> - Pull Request: `repo:{owner}/{repo}:pull_request`

### 5. RBAC 権限の付与

マネージド ID に Static Web App への **共同作成者 (Contributor)** 権限を付与します。ロール割り当ての操作に必要です。

```powershell
# マネージド ID の principalId を取得
$principalId = az identity show `
  --name id-swa-github-role-sync-ops-prod `
  --resource-group rg-swa-github-role-sync-ops-prod `
  --query principalId --output tsv

# Static Web App のリソース ID を取得
$swaId = az staticwebapp show `
  --name stapp-swa-github-role-sync-ops-prod `
  --resource-group rg-swa-github-role-sync-ops-prod `
  --query id --output tsv

# ロール割り当てを作成
az role assignment create `
  --assignee-object-id $principalId `
  --assignee-principal-type ServicePrincipal `
  --role "Contributor" `
  --scope $swaId
```

出力例:

```json
{
  "principalId": "29a88270-120d-4760-99f1-30dbcd08c578",
  "principalType": "ServicePrincipal",
  "roleDefinitionId": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
  "scope": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-swa-github-role-sync-ops-prod/providers/Microsoft.Web/staticSites/stapp-swa-github-role-sync-ops-prod"
}
```

### 6. GitHub Secrets の登録

Azure OIDC に必要な 3 つの値を GitHub Secrets に登録します。

```powershell
# マネージド ID の clientId を取得して登録
$clientId = az identity show `
  --name id-swa-github-role-sync-ops-prod `
  --resource-group rg-swa-github-role-sync-ops-prod `
  --query clientId --output tsv
gh secret set AZURE_CLIENT_ID --body $clientId

# テナント ID を取得して登録
$tenantId = az account show --query tenantId --output tsv
gh secret set AZURE_TENANT_ID --body $tenantId

# サブスクリプション ID を取得して登録
$subscriptionId = az account show --query id --output tsv
gh secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId
```

GitHub App 用の Secrets も登録します:

```powershell
gh secret set ROLE_SYNC_APP_ID --body "123456"
gh secret set ROLE_SYNC_APP_PRIVATE_KEY < role-sync-app.private-key.pem
```

Organization Secret にする場合は `--org <ORG>` を付け、必要なら公開範囲を `--repos` で絞ってください。

### GitHub App の作成メモ（UI 操作）

1. GitHub の「Developer settings > GitHub Apps」から「New GitHub App」を作成。
2. **Repository permissions** で `Administration (Read-only)` と `Discussions (Read & write)` を付与。Organization メンバー情報を使う場合は **Organization permissions** で `Members (Read-only)` を付与。
3. 対象 Organization / リポジトリに App をインストールし、App ID と Private key (`.pem`) を取得して Secrets に登録。

## ワークフローのセットアップ

### 1. ロール同期ワークフローを追加

`.github/workflows/role-sync.yml` を作成します。`swa-name`・`swa-resource-group`・`discussion-category-name` を環境に合わせて変更してください。

```yaml
name: Sync SWA roles

on:
  workflow_dispatch:
  schedule:
    - cron: '0 3 * * 1'

jobs:
  sync:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      discussions: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - name: Sync SWA role assignments
        uses: nuitsjp/swa-github-role-sync@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          swa-name: my-swa-app
          swa-resource-group: my-swa-rg
          discussion-category-name: Announcements
```

CLI で手動実行する場合:

```powershell
gh workflow run role-sync.yml --ref main
gh run watch --exit-status
```

### 2. 招待 Discussion の掃除ワークフローを追加（任意）

`cleanup-mode` を `immediate` にすると手動実行時に即時削除されます。定期実行時は `expiration` を維持するのが安全です。

```yaml
name: Cleanup invite discussions
on:
  schedule:
    - cron: '0 4 * * 1'
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      discussions: write
    steps:
      - uses: nuitsjp/swa-github-discussion-cleanup@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          discussion-category-name: Announcements
          expiration-hours: 168
          cleanup-mode: ${{ github.event_name == 'workflow_dispatch' && 'immediate' || 'expiration' }}
```

CLI で手動実行する場合:

```powershell
gh workflow run cleanup-invite-discussions.yml --ref main
gh run watch --exit-status
```

### 3. 結果を確認

- `GITHUB_STEP_SUMMARY` に招待件数・更新件数が表示されます。GitHub Web UI か `gh run view --log` で確認できます。
- 招待 Discussion が指定カテゴリーに作成され、本文に招待 URL が含まれます。
- 掃除ワークフローは削除した件数を出力します。

## 追加設定

- **別リポジトリの権限で同期する**  
  `target-repo` に `owner/repo` を指定し、`github-token` に対象リポジトリへアクセスできる PAT を渡します。
- **ロール名・テンプレートを変更する**  
  - GitHub `admin` に付与するロール: `role-for-admin`（既定: `github-admin`）  
  - GitHub `write`/`maintain` に付与するロール: `role-for-write`（既定: `github-writer`）  
  - テンプレートは `{login}` `{role}` `{inviteUrl}` `{swaName}` `{repo}` `{date}` などのプレースホルダーを利用可能。Discussion 掃除側も同じテンプレートを設定してください。
- **招待リンクの有効期限**  
  `invitation-expiration-hours`（既定 168 時間）を変更すると、掃除ワークフローの `expiration-hours` も合わせる必要があります。
- **カスタムドメインを使う**  
  `swa-domain` に `https://example.com` のようなドメインを指定すると招待 URL がそのドメインで生成されます。

## トラブルシューティング

- `Discussion category "..." not found`：カテゴリー名の誤り、または Discussions が無効です。設定を確認してください。
- `Resource not accessible by integration`：`github-token` の権限不足です。`permissions` ブロックとトークンスコープを確認してください。
- 招待が 0 件で終了する：既に同期済みの場合は何も変更せず終了します。`role-prefix` が異なると差分対象外になる点に注意してください。
