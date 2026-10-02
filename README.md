# ohirome

Rails 案件で機能を実装し終えたあと、**動作確認を代わりに行い、その結果を手順書にまとめる** Claude Code スキルです。

`/ohirome` を実行すると、スキルが seed を開発 DB に入れ、開発サーバーをブラウザで操作して各ステップの画面を撮ります。対象案件には次のファイルができます。

```
docs/verification/<YYYYMMDD>_<機能名>/
├─ seed.rb          # 動作確認用データ（本番を想定した固定値・何度流しても同じ状態）
├─ steps.md         # 1 ステップ 1 操作の手順書。各ステップに URL・操作・結果と画面の画像
└─ screenshots/     # 各ステップの画面
```

正常系もエラー系も、steps.md を読むだけでどう動いたかが分かります。期待どおりかどうかは、読んだ人が判断します。実際に触ってみたくなったら、seed を流して steps.md のとおりに操作してください。

確認して問題がなければ、`/ohirome:video` で同じ手順を録画し、お客さんに渡せるデモ動画を作れます。

絵で見る概要: [ohirome のしくみ](https://claude.ai/artifact/4j7Di3BjmNjyeUCWeGUuSm?sk=GlGAeEmnZ3BmZBIP55i_OA)

## 必要なもの

- Claude Code
- Node.js と pnpm
- 対象の Rails 案件の開発環境（`bin/rails runner` と `bin/dev` が動くこと）

## 導入

```
/plugin marketplace add poppuko-n/ohirome
/plugin install ohirome@ohirome
```

動画（`/ohirome:video`）も使う場合は、録画用の ffmpeg を入れます。

```bash
pnpm dlx playwright install ffmpeg   # 録画に必須
brew install ffmpeg                  # mp4 にしたい場合だけ
```

## 使い方

機能の実装が終わったブランチで実行します。

```
/ohirome                  # release-candidate（無ければ main）との差分から生成
/ohirome develop          # 比較対象ブランチを指定
```

実行中にスキルが行うこと:

- seed.rb を開発 DB に投入する（冪等なので何度流しても同じ状態になる）
- 開発サーバーの URL を決める。puma-dev（`https://<名前>.test`）や worktree ごとのポートにも対応し、分からないときは聞く
- 開発サーバーが動いていなければ起動し、撮影が終わったら止める（もともと動いていたサーバーには触らない）
- 画面の見えないブラウザで手順を 1 ステップずつ実行し、撮影して結果を書き留める
- ログインまわりを変更していなければ、ログインは手順に書かず、手順 1 の前に済ませる（ログインの変更を含むときだけ、ログインも手順として撮る）

実際に触りたいときは、seed を流してから steps.md のとおりに操作します。

```bash
bin/rails runner docs/verification/<YYYYMMDD>_<機能名>/seed.rb
```

### お客さん向けの動画を作る

steps.md を確認して問題がなければ、そのディレクトリを渡して実行します。

```
/ohirome:video docs/verification/<YYYYMMDD>_<機能名>
```

- steps.md の手順をそのまま台本にして録画します（エラー系も含めた全ステップ）
- ログインまわりを変更していなければ、ログインは手順書にも動画にも入りません。録画を始める前にログインを済ませます
- 冒頭に機能名、各ステップの前に「番号. 見出し」のカードが入り、マウスポインタと操作箇所が映ります
- 動画は `tmp/ohirome/<YYYYMMDD>_<機能名>/demo.mp4`（ffmpeg が無ければ `demo.webm`）にできます。`tmp/` に置くのでコミットされません
- 録画のあと、steps.md の各ステップに `🎬 0:42` のように、動画のどこにあたるかの時刻を足します

## 生成物の例

- [seed.rb の雛形](skills/ohirome/references/seed-template.rb)
- [steps.md の雛形](skills/ohirome/references/steps-template.md)

steps.md は機能ごとに見出しが分かれ、冒頭の目次でどの機能がどのステップにあたるかが分かります。機能は「確認する人が、ひとつの目的のために続けて触る操作のまとまり」で分けるので、タスクの数とは一致しません（例: 「注文の登録」「注文の編集」「出荷ボタンの変更」→「注文を登録・編集できる」「出荷ボタンで出荷済みにできる」の 2 つ）。各機能の中は「正常系」と「異常系」に分かれます。

```markdown
| | 機能 | 正常系 | 異常系 |
|---|---|---|---|
| A | [注文の数量を変更できる](#a-注文の数量を変更できる) | 1〜4 | 5〜7 |
| B | [注文を出荷済みにできる](#b-注文を出荷済みにできる) | 8〜9 | なし |

---

## A. 注文の数量を変更できる

> 管理者が注文の数量を変更できる。数量 0 以下ではエラーになる。

### 正常系

#### 1. 注文一覧を開く
...
```

1 ステップはこの形です。どのステップにも、開いていた URL のパス（`📍`。押すと実際の画面が開く）、操作、結果（操作したあと画面に出たこと）、画像が付きます。

```markdown
#### 4. 変更を保存する
- 📍 [/admin/orders/37](http://localhost:3000/admin/orders/37)
- **操作:** 「更新する」ボタンをクリック
- **結果:** 「注文を更新しました」と表示され、数量が 3 になった

![4. 変更を保存する](screenshots/04.png)
```
