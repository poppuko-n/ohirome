# ohirome

Rails 案件で機能を実装し終えたあと、**動作確認を代わりに行い、その結果を手順書にまとめる** Claude Code スキルです。

`/ohirome` を実行すると、スキルが seed を開発 DB に入れ、開発サーバーをブラウザで操作して各ステップの画面を撮ります。対象案件には次のファイルができます。

```
docs/verification/<YYYYMMDD>_<機能名>/
├─ seed.rb          # 動作確認用データ（本番を想定した固定値・何度流しても同じ状態）
├─ steps.md         # 1 ステップ 1 操作の手順書。各ステップに画面の画像と判定（✅ / ❌）つき
└─ screenshots/     # 各ステップの画面
```

正常系もエラー系も、steps.md を読むだけで動作確認を終えられます。実際に触ってみたくなったら、seed を流して steps.md のとおりに操作してください。

絵で見る概要: [ohirome のしくみ](https://claude.ai/artifact/4j7Di3BjmNjyeUCWeGUuSm?sk=GlGAeEmnZ3BmZBIP55i_OA)

## 必要なもの

- Claude Code
- Node.js（`npx` が使えること）。画面の操作に同梱の [Playwright MCP](https://github.com/microsoft/playwright-mcp) を使います
- 対象の Rails 案件の開発環境（`bin/rails runner` と `bin/dev` または `bin/rails server` が動くこと）

## 導入

Claude Code で次を実行します。

```
/plugin marketplace add poppuko-n/ohirome
/plugin install ohirome@ohirome
```

## 使い方

機能の実装が終わったブランチで実行します。

```
/ohirome                  # release-candidate（無ければ main）との差分から生成
/ohirome develop          # 比較対象ブランチを指定
```

実行中にスキルが行うこと:

- seed.rb を開発 DB に投入する（冪等なので何度流しても同じ状態になる）
- 開発サーバーが動いていなければ起動し、撮影が終わったら止める（もともと動いていたサーバーには触らない）
- 画面の見えないブラウザで手順を 1 ステップずつ実行し、撮影と判定をする

実際に触りたいときは、seed を流してから steps.md のとおりに操作します。

```bash
bin/rails runner docs/verification/<YYYYMMDD>_<機能名>/seed.rb
```

## 生成物の例

- [seed.rb の雛形](skills/ohirome/references/seed-template.rb)
- [steps.md の雛形](skills/ohirome/references/steps-template.md)

steps.md の 1 ステップはこの形です。画面遷移したステップには `📍` でパスを、結果が目に見えるステップにだけ「確認」と「判定」を書きます。画像はすべてのステップに付きます。

```markdown
### 8. 変更を保存する
- 📍 `/admin/orders/:id`
- 操作: 「更新する」ボタンをクリック
- 確認: 「注文を更新しました」と表示され、数量が 3 になっている
- 判定: ✅ 期待どおり

![8. 変更を保存する](screenshots/08.png)
```
