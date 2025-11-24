# サブモジュール対応比較

role-sync と discussion-cleanup の周辺サポート有無を整理しました（〇 = 対応あり）。

| 対応内容概要 | role-sync | discussion-cleanup |
| --- | --- | --- |
| OSS ライセンスチェック（`.licensed.yml` と `.licenses/` 管理） | 〇 | - |
| Prettier 整形スクリプト（`format:write` / `format:check`） | 〇 | 〇 |
| ESLint による Lint | 〇 | - |
| Jest ユニットテスト | 〇 | - |
| カバレッジバッジ生成（`npm run coverage`） | 〇 | - |
| dist 整合性チェック（`npm run check:dist`） | 〇 | - |
| ローカル Action 実行（`npm run local-action`） | 〇 | - |
| Rollup ビルドスクリプト（`npm run package`） | 〇 | 〇 |
| 総合検証コマンド（`npm run verify`） | 〇 | - |

## ルートワークスペース共通タスク

リポジトリ直下の `package.json` から、各アクションのスクリプトをまとめて実行できます。

- `npm run format:write` / `npm run format:check` : 双方の Prettier を順番に実行
- `npm run verify:role-sync` : role-sync の従来の `npm run verify`
- `npm run verify:discussion-cleanup` : discussion-cleanup の `npm run package` を呼び出し
- `npm run verify` : 上記 2 つを連続実行
