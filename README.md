# ohirome

Rails 案件で機能を実装し終えたあと、**人が手で動作確認を始めるための準備物**を生成する Claude Code スキルです。

`/ohirome` を実行すると、対象案件に次の 2 ファイルができます。

```
docs/verification/<YYYYMMDD>_<機能名>/
├─ seed.rb    # 動作確認用データ（本番を想定した固定値・何度流しても同じ状態）
└─ steps.md   # 1 ステップ 1 操作の手順書（画面遷移ごとに URL パスつき）
```

seed は生成するだけで、実行はしません。

絵で見る概要: [ohirome のしくみ](https://claude.ai/artifact/4j7Di3BjmNjyeUCWeGUuSm?sk=GlGAeEmnZ3BmZBIP55i_OA)

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

生成されたら、seed を投入して手順書どおりに操作します。

```bash
bin/rails runner docs/verification/<YYYYMMDD>_<機能名>/seed.rb
```

## 生成物の例

- [seed.rb の雛形](skills/ohirome/references/seed-template.rb)
- [steps.md の雛形](skills/ohirome/references/steps-template.md)

steps.md の 1 ステップはこの形です。画面遷移したステップには `📍` でパスを、結果が目に見えるステップにだけ「確認」を書きます。

```markdown
### 6. 注文の編集画面を開く
- 📍 `/admin/orders/:id/edit`（seed 出力の「注文 #1024」）
- 操作: #1024 の行の「編集」をクリック
- 確認: 数量欄に「2」が入っている

### 7. 数量を変更する
- 操作: 数量欄を「3」に書き換える
```
