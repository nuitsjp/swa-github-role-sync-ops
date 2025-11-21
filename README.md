# 移行ドキュメント：アクション分離および管理リポジトリ構成

## 1. 背景

現在、リポジトリ swa‑github‑role‑sync にて「アクションA（ロール同期）」および「アクションB（ディスカッションクリーンアップ）」という 2 つの関連性の強いアクションを同一リポジトリで管理しています。
今後、各アクションをより明確に版管理・公開管理できるようにリポジトリ構成を整理し、運用性および保守性の向上を図ります。
そのために、以下のように 3 つのリポジトリ構成とし、管理リポジトリからそれぞれのアクション用リポジトリをサブモジュールとして登録する形を採ります。

* `swa-github-role-sync`（既存アクション A）
* `swa-github-discussion-cleanup`（新アクション B）
* `swa-github-workflows`（管理リポジトリ／ワークフロー定義）

この構成により、ワークフロー定義を一元化しつつ、アクション単位の独立性を高め、バージョン管理・公開戦略・将来的な拡張を容易にします。

---

## 2. 目的

本移行の目的は以下の通りです：

1. 各アクションを明確に分離して管理し、バージョン・リリース運用を整理する。
2. 管理リポジトリをワークフロー中心のものとし、アクションの実装・公開／利用を切り離して運用できるようにする。
3. サブモジュールを用いた構成で、アクションリポジトリを管理リポジトリから参照できる形とし、管理と呼び出しを明確化する。
4. 将来的な運用変更・拡張を見据え、保守負荷を低減し、スケーラブルな構成に移行する。

---

## 3. 決定事項

以下、移行にあたって決定されている事項を明記します：

* 各アクションのバージョン管理ポリシー： **`v1.0.0`** から開始します。
* 管理リポジトリ `swa-github-workflows` の役割：全ワークフロー定義を所持。共通ユーティリティは置かず、依存関係としてアクションリポジトリを参照します。
* 管理ブランチ：別ブランチを用いず、単一のブランチで運用します。
* サブモジュール登録場所：

  * `actions/role-sync` → `swa-github-role-sync`
  * `actions/discussion-cleanup` → `swa-github-discussion-cleanup`
* 依存している他のリポジトリ／ワークフローは現時点で存在しないため、参照整理の必要は現段階ではありません。
* 将来の運用体制：アクションの開発・テスト・リリースも `swa-github-workflows` による CI/CD で実施し、アクションリポジトリ単独で CI を持たない構成とします。

---

## 4. 手順

以下の手順で移行を実施します。

### ステップ 1：準備

1. 新リポジトリ `swa-github-discussion-cleanup` を作成／初期化。
2. `swa-github-role-sync` リポジトリの最新安定版タグ（例 `v1.0.0`）を確認・タグ付け。
3. ドキュメント（README.md／LICENSE 等）を両アクションリポジトリに整備。
4. `swa-github-workflows` 管理リポジトリのクローンまたはアクセス確認。

### ステップ 2：サブモジュール登録

1. `swa-github-workflows` リポジトリのルートに移動。
2. 以下コマンドでサブモジュールを追加（例）：

   ```bash
   git submodule add https://github.com/your-org/swa-github-role-sync.git actions/role-sync
   git submodule add https://github.com/your-org/swa-github-discussion-cleanup.git actions/discussion-cleanup
   git commit -m "Add submodules for role-sync and discussion-cleanup"
   git push
   ```
3. サブモジュールの初期化・更新手順をドキュメント化（例： `git submodule update --init --recursive`）。

### ステップ 3：ワークフロー参照更新

1. `swa-github-workflows/.github/workflows/…` 内で、既存ワークフローが旧アクション参照をしている場合、参照先をサブモジュール内パスかタグ指定に更新。例：

   ```yaml
   uses: ./actions/role-sync@v1.0.0
   ```

   または、

   ```yaml
   uses: your-org/swa-github-role-sync@v1.0.0
   ```
2. 更新後、プルリクエストを作成し動作確認（CI実行・テスト）。
3. 問題なしを確認後、マージ・タグリリース。

### ステップ 4：旧リポジトリの整理

1. `swa-github-role-sync` リポジトリ内で、不要なワークフローファイルがあれば削除またはアーカイブ。
2. README に「このリポジトリはアクション実装専用、ワークフロー管理は `swa-github-workflows` に移行しました」と明記。
3. 必要に応じてリポジトリのトピック／READMEリンクを更新。

### ステップ 5：運用ルール策定

1. サブモジュール更新時の手順（例：子リポジトリでタグ更新 → 親リポジトリで `git submodule update` → commit/push）をドキュメント化。
2. バージョン付け規則（例： `v1.0.0`, `v1.0.1`, `v2.0.0`）を明確にし、アクション仕様変更時の対応を定める。
3. ワークフロー定義変更時のレビュー・承認プロセスを設ける。
4. 将来、アクションが増えた場合の拡張方針（例：アクションごとに独立リポジトリ化の検討）を記載。

---

## 5. 期待される成果

* アクション A／B がそれぞれ専用リポジトリで独立運用可能になり、バージョン管理・公開管理が明確になる。
* 管理リポジトリでワークフロー定義を一元管理し、全体構成が理解しやすくなる。
* サブモジュール方式によって、管理リポジトリから参照先を明示し、依存関係・更新手順が整理される。
* 今後の保守・拡張が容易になり、コード・ワークフローの分離によるリスク低減が期待される。

---

## 6. 補足・注意点

* サブモジュールを利用する場合、更新・同期忘れ、バージョン不整合などの管理が発生しやすいため、運用ルール・チェックリストを明文化することを推奨します。
* 他リポジトリからの参照がないという前提ですが、将来参照が発生した場合には、切り替え計画を追加で策定してください。
* アクションリポジトリを Marketplace に公開するかどうか検討される際は、公式の「１リポジトリ＝１アクション」推奨を考慮してください。 ([Stack Overflow][1])

---

以上がドキュメント案です。ご確認の上、修正・追加したい項目があればお知らせください。

[1]: https://stackoverflow.com/questions/66107901/should-actions-be-stored-in-a-separate-repo-or-nested-in-another?utm_source=chatgpt.com "Should actions be stored in a separate repo or nested in ..."

---

## 7. 実施状況と残タスク（2024-05-20 更新）

README の計画に沿って、着手済みの内容と今後のアクションを整理しました。作業を引き継ぐ際は本節を最新化してください。

### 7.1 ステップ 1：準備（完了）

- `gh repo view nuitsjp/swa-github-discussion-cleanup` / `nuitsjp/swa-github-role-sync` で両アクション用リポジトリの存在と `main` ブランチを確認済み。
- `git -C actions/role-sync tag --list` により `v1.0.0` 系タグを確認。次回タグ発行時はアクションリポジトリ側で `git tag vX.Y.Z && git push origin vX.Y.Z` を実行すること。
- `actions/role-sync` / `actions/discussion-cleanup` 配下に README / LICENSE などの基本ドキュメントが揃っていることを確認。
- 管理リポジトリ `swa-github-workflows` へのアクセスと書き込み権限を確認済み（本リポジトリでの作業）。
- `actions/discussion-cleanup` サブモジュールに `swa-github-discussion-cleanup` Action を実装し、`dist/index.js` までビルド済み（実行方法は `.github/workflows/role-sync-*.yml` 参照）。

### 7.2 ステップ 2：サブモジュール登録（完了）

- `.gitmodules` に以下 2 つのサブモジュールを登録済み。
  - `actions/role-sync` → `https://github.com/nuitsjp/swa-github-role-sync.git`
  - `actions/discussion-cleanup` → `https://github.com/nuitsjp/swa-github-discussion-cleanup.git`
- クローン直後は次のコマンドで初期化してください：

  ```bash
  git submodule sync --recursive
  git submodule update --init --recursive
  ```
- 子リポジトリのタグ更新を取り込む場合：

  ```bash
  cd actions/role-sync   # または discussion-cleanup
  git fetch --tags
  git checkout v1.0.1    # 例：利用したいタグ
  cd -
  git add actions/role-sync
  git commit -m "chore: bump role-sync submodule to v1.0.1"
  ```

### 7.3 ステップ 3：ワークフロー参照更新（進行中）

- `.github/workflows` 配下に次のワークフローを移設済み：
  - `role-sync-sync.yml` / `role-sync-sync-package.yml`
  - `role-sync-delete-discussions.yml`
  - `role-sync-deploy-site.yml`
  - `role-sync-npm-ci.yml`
  - `role-sync-release.yml`
- すべてのワークフローで `actions/checkout@v4` + `submodules: recursive` を使用し、`./actions/role-sync` / `./actions/discussion-cleanup` を参照するように更新。
- アクションリポジトリに対して issue / release / push を行うステップでは `ROLE_SYNC_REPO_TOKEN`（PAT、`repo`+`discussions` 権限）を参照するように変更しています。まだ未設定の場合はリポジトリ Secrets に追加してください。
- `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` は `swa-github-workflows` 側に登録されている前提で Azure ログイン手順を残しています。
- 今後の TODO：
  - 新ワークフローの実行確認（PAT と Azure Secrets を登録したうえで `workflow_dispatch` を試験）。
  - 既存通知先が `nuitsjp/swa-github-role-sync` 固定になっているため、必要に応じて `env.ROLE_SYNC_REPO` を環境依存で切り替えられるようにする。
  - `role-sync-release.yml` は `workflow_dispatch` のみをサポートしているため、タグ push 連動が必要な場合は Event 設計を再検討する。

### 7.4 ステップ 4：旧リポジトリ整理（進行中）

- `swa-github-role-sync` から `.github/workflows/*.yml` を削除し、本リポジトリへ移行済み。
- `README.md` / `README.ja.md` に「ワークフローは `swa-github-workflows` へ移管」「Discussion クリーンアップは `swa-github-discussion-cleanup` へ分離」した旨を追記済み。
- 残タスク：ドキュメント本文に記載されている `uses: nuitsjp/swa-github-role-sync/cleanup-discussions@v1` のサンプルを新リポジトリ参照へ置換し、Marketplace への公開ポリシー記述をアップデートする。

### 7.5 ステップ 5：運用ルール策定（部分的に未実施）

- サブモジュール更新フロー案：
  1. 子リポジトリで修正 → `npm test` などを実施。
  2. 子リポジトリでタグ付け。
  3. 親リポジトリで `git submodule update --remote --merge` を実行。
  4. Pull Request でレビュー。
- バージョニング：SemVer を採用し、Breaking Change 時のみメジャーを上げる。
- レビュー体制：最低 1 名承認、リリースチェックリスト（テスト結果・SWA への反映確認、`ROLE_SYNC_REPO_TOKEN` 設定確認）を PR テンプレート化する。
- 今後アクションが増えた場合は `actions/<action-name>` ディレクトリを追加し、同手順でサブモジュール登録。
- Secrets 運用：
  - `ROLE_SYNC_REPO_TOKEN`（PAT, repo+discussions）… role-sync リポジトリへの push / Discussion 操作に使用。
  - `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` … Azure Static Web Apps OIDC 用。
  - 必要に応じて SWA 関連の追加シークレットやデプロイトークンを整理する。

### 7.6 Azure Static Web Apps 連携メモ

- `az staticwebapp list` により管理対象の SWA を棚卸し済み。
- `az staticwebapp show -n stapp-swa-github-roles-provider -g rg-swa-github-roles-provider` で対象アプリの `repositoryUrl` が `https://github.com/nuitsjp/swa-github-repo-auth` であることを確認。ワークフロー更新後は SWA 側のデプロイトークン／ブランチ設定に変更が必要か確認してください。
- 必要に応じて `az staticwebapp appsettings set` などでシークレットを管理し、GitHub ワークフローと整合を取ります。

---
