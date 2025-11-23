# GitHub Actions アクション公開・リリース運用ドキュメント (swa-github-workflows)

`swa-github-role-sync` / `swa-github-discussion-cleanup` を GitHub Marketplace に公開・継続運用するための手順を、本ハーネスリポジトリ向けにまとめています。両アクションはサブモジュールのため、タグ作成はこのリポジトリのワークフローから実行します。

---

## 1. 前提条件

- サブモジュール側リポジトリが **Public** であること。(`action.yml`/`action.yaml` がルートに存在)
- Marketplace 公開要件に従い、サブモジュール側に `/.github/workflows` を置かないこと。
- リポジトリ所有者が GitHub Marketplace Developer Agreement に同意済みで、2FA などのセキュリティ設定が有効。
- `ACTIONS_RELEASE_TOKEN` にサブモジュール両方への `contents:write` 権限があること。

## 2. リリースの基本フロー

1. **実装・ビルド・テスト**
   - `actions/role-sync`: `npm ci && npm run verify` を実行し、`dist/` を最新化してコミット。
   - `actions/discussion-cleanup`: `npm ci && npm run package` を実行し、`dist/` を最新化してコミット。
2. **タグ作成・Release 作成 (このリポジトリから実行)**
   - `Release Role Sync` (`.github/workflows/release-role-sync.yml`) または `Release Discussion Cleanup` (`.github/workflows/release-discussion-cleanup.yml`) を手動実行。
   - `version` 未指定の場合は最新 SemVer を自動インクリメント。プレリリース (`-beta` など) 以外はメジャーのローリングタグ（例 `v1`）も更新。
   - ワークフローがサブモジュールリポジトリで GitHub Release を自動作成し、`GITHUB_STEP_SUMMARY` にリポジトリトップ・タグ・Release URL を出力するので結果画面で確認。
3. **Marketplace 公開 (初回のみ UI で確認)**
   - すでに Marketplace 公開済みならワークフローによる Release 作成で新バージョンが反映されます。
   - 初回公開時のみ、GitHub Release 作成画面の「Publish this action to the GitHub Marketplace」にチェックが入っているかを確認してください（UI 操作が必要）。
   - 変更点・互換性はリリースノートに記載。
4. **ドキュメント更新**
   - README の使用例 (`uses: owner/repo@vX` とフルタグ) を新バージョンに合わせて更新。
   - 互換性に応じてメジャーバージョン運用方針（`@v1` 推奨など）を明記。

## 3. バージョニングとローリングタグ

- 互換性を維持する変更はマイナー／パッチでリリースし、メジャー互換性破壊時のみ `v2` など新メジャーを開始。
- プレリリースタグ（`-beta` など）はローリングタグを更新しません。
- ローリングタグはワークフローが自動でメジャー名（例 `v1`）を付け替えます。`immutable` な Release に紐づくタグを手動で force push しないよう注意。

## 4. 初回公開時の追加チェック

- README に使用例と入力／出力の説明を記載。
- Marketplace 公開チェックボックスにチェックを入れる。
- 公開後、マーケットプレイス上で Action が表示されていることを確認。

## 5. 運用チェックリスト

- [ ] サブモジュールの `dist/` が最新でコミット済み。
- [ ] `ACTIONS_RELEASE_TOKEN` で両リポジトリにプッシュできる。
- [ ] `Release Role Sync` / `Release Discussion Cleanup` を実行し、`GITHUB_STEP_SUMMARY` でタグとリンクを確認。
- [ ] ワークフローが作成した GitHub Release を確認し、初回のみ Marketplace 公開チェックが入っていることを UI で確認。
- [ ] README や使用例を最新化。
- [ ] メジャー互換性破壊の場合は新メジャータグを切り、旧メジャー利用者への案内を記載。

## 6. 参考リンク

- [Publishing actions in GitHub Marketplace](https://docs.github.com/actions/creating-actions/publishing-actions-in-github-marketplace)
- [Releasing and maintaining actions](https://docs.github.com/actions/creating-actions/releasing-and-maintaining-actions)
- [Creating and publishing actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions)
