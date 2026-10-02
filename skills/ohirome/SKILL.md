---
name: ohirome
description: Rails 案件で機能の実装が終わったあと、動作確認用の seed.rb と、各ステップに URL・操作・結果と実際の画面のスクリーンショットを並べた手順書 steps.md を生成する。スキルが seed を開発 DB に投入し、開発サーバーをブラウザで操作して撮影する。`/ohirome [比較対象ブランチ]` での明示起動のほか、「動作確認の準備をして」「動作確認用のデータと手順を作って」「動作確認して手順書にまとめて」と依頼されたときに使う。
argument-hint: "[比較対象ブランチ（省略時は release-candidate、無ければ main）]"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git show-ref:*), Bash(git status:*), Bash(bin/rails routes:*), Bash(bin/rails runner:*), Bash(bin/dev:*), Bash(bin/rails server:*), Bash(curl:*), Bash(readlink:*), Bash(ruby -c:*), Bash(mkdir:*), Bash(mv:*), Bash(ls:*), Bash(date:*), mcp__plugin_ohirome_playwright
---

# ohirome: 動作確認の結果を手順書にまとめる

実装した機能の動作確認を、スキル自身がブラウザで実際に行い、その結果を対象案件の中に残す。

```
docs/verification/<YYYYMMDD>_<機能名>/
├─ seed.rb          # 動作確認用データ（bin/rails runner で投入する）
├─ steps.md         # 1 ステップ 1 操作の手順書。各ステップに URL・操作・結果と画面の画像
└─ screenshots/
   ├─ 01.png
   └─ ...
```

ゴールは **steps.md を読むだけで、正常系もエラー系もどう動いたかが分かる** 状態。スキルは OK / NG の判定をしない。期待どおりかどうかは人が steps.md を読んで決める。実際に触りたくなった人は、seed.rb を流して steps.md のとおりに操作すれば同じ画面を再現できる。`/ohirome:video` がこの steps.md を台本にして動画を作るので、書式は雛形どおりに固定する。

## 手順

### 1. 変更を把握する

比較対象ブランチは `$ARGUMENTS`。未指定なら `release-candidate`、それが無ければ `main` を使う（`git show-ref --verify refs/heads/<name>` / `refs/remotes/origin/<name>` で存在を確かめる）。

```bash
git diff <base>...HEAD --stat
git log <base>..HEAD --oneline
git status --short   # 未コミットの変更も対象に含める
```

差分と会話の文脈から、**人が画面で確かめるべき振る舞い**を洗い出す（正常系と、実装した分岐であるバリデーション・権限・状態による出し分けなどのエラー系）。画面を持たない変更（バッチ、API のみなど）しか無い場合は、その旨を伝えて止める。

機能名は英小文字スネークケースで決める（例: `order_quantity_edit`）。日付は `date +%Y%m%d` で取る。

あわせて、**ログインを手順に入れるか**を決める。差分（未コミットの変更を含む）に次のどれかがあれば、ログインまわりを変更したとみなす。

- `app/controllers/**/sessions_controller.rb`、`app/views/devise/**`、`app/views/**/sessions/**`
- `config/initializers/devise.rb`、`config/routes.rb` の `devise_for` や `sign_in` / `login` まわりの行
- User など認証に使うモデルの `devise` の行、認証用の concern（`authenticate_*` や `current_user` を定義している箇所）

| 差分 | steps.md でのログインの扱い |
|---|---|
| ログインまわりを変更した | 変更を見せるため、ログインを手順として書く |
| 変更していない | 手順には書かない。ログイン情報は seed.rb の出力に出し、手順はログインした状態から始める |
| 確認する画面がログイン不要 | どちらにも書かない |

### 2. 画面と URL を特定する

- 変更された controller・view・routes を読む
- `bin/rails routes -g <コントローラ名など>` で、手順に出てくるパスが**実在する**ことを確かめる。推測でパスを書かない
- ボタン・リンク・入力欄のラベルは view（と i18n の locale ファイル）から実際の文言を拾う

### 3. 必要なデータを特定する

次を読み、手順を最後まで通すのに必要なレコードとログインユーザーを洗い出す。

- `db/schema.rb`（NOT NULL・デフォルト値・外部キー）
- 関係するモデルのバリデーションと関連
- `spec/factories`（有効な属性の組み合わせの手本になる）
- 既存の `db/seeds.rb` や `db/seeds/`（ログインユーザーの作り方、既存データとの衝突）
- 認証の仕組み（Devise なら `password` 属性、confirmable なら `confirmed_at` が必要など）

### 4. seed.rb を生成する

`references/seed-template.rb` の形に沿って書く。雛形のモデル名や値は架空の例なので、対象案件の実際のモデル・属性に置き換える。

| ルール | 理由 |
|---|---|
| 先頭で `abort '...' unless Rails.env.development?` | 本番や他環境で誤って流さないため |
| `find_or_create_by!(<一意なキー>) do ... end` で作る | 何度流しても重複せず、同じ状態になる |
| 中身は**本番にありそうな自然な値**にする（例:「山田 花子」「株式会社みどり商事」「春の新作ブレンド 200g」） | 画像にそのまま写り、デモ動画にも使うため。「テスト」「サンプル」「test」「【動作確認】」などの語は使わない |
| 値は Faker / Gimei でランダムに作らず、**固定値で書く** | 冪等にし、steps.md に書く名前や数値と一致させるため |
| メールアドレスは `example.com` / `example.jp` などの予約ドメインにする | 実在の宛先に送られないようにするため |
| 最後に**ログイン情報（ログイン画面の URL、メールアドレス、パスワード、表示名）と、ID の入った実 URL を `puts` する** | 生成時点では ID が分からないため。steps.md からはこの出力の名前で参照する。`/ohirome` と `/ohirome:video` はこの出力を見てログインする |
| 確認に関係ないレコードは作らない | 手順書と seed の対応を追いやすくするため |
| 手順の途中でデータが変わる場合（数量を 2 → 3 に更新など）も、seed は**変更前の状態**を作る | 再実行のたびに手順の最初の状態へ戻すため。`find_or_create_by!` のブロックは新規作成時しか動かないので、変わる属性は `update!` で毎回戻す |

### 5. steps.md の下書きを作る

`references/steps-template.md` の書式（「## 正常系」「## 異常系」の見出し、各ステップの見出し・`📍`・`操作:`・`結果:`・画像の並び）に**そのまま**従う。中身は架空の例なので、対象機能の内容で書く。この時点では各ステップの `📍`（開く予定のパス）と `操作` だけを書き、`結果` と画像は手順 9 で埋める。

| ルール |
|---|
| 冒頭は「確認する機能」（1〜3 行）だけ。ログイン情報や準備の手順は書かない（seed.rb の出力にある） |
| 手順 1 で決めたとおり、ログインまわりを変更していなければ、ログインは手順に書かない。手順 1 は機能の画面を URL で開くところから始める |
| **1 ステップ 1 操作**。入力欄 1 つ、クリック 1 回、選択 1 回がそれぞれ 1 ステップ |
| **全ステップに `📍` 行で URL のパスを書く**（下書きではただのパス。手順 9 で実際の URL へのリンクにする）。下書きでは ID が分からないので `:id` と書き、どのレコードかを `（seed 出力の「注文 #1024」）` のように添える。手順 9 で実際の ID に置き換える |
| 手順を「## 正常系」と「## 異常系」の見出しで分ける。正常系は機能がうまく動く流れ、異常系はバリデーション・権限・状態による出し分けなど実装したエラーの流れ。番号は両方をまたいで通しで振る。異常系が無ければ「## 異常系」ごと書かない |
| ラベルや文言は画面の実際の表記を「」で囲んで書く |

### 6. セルフチェック

- [ ] `ruby -c docs/verification/<dir>/seed.rb` が `Syntax OK`
- [ ] steps.md の `📍` のパスがすべて `bin/rails routes` に存在する
- [ ] 1 ステップに操作が 2 つ以上入っていない（「〜して〜する」になっていない）
- [ ] steps.md に出てくる名前・数値が seed.rb と一致している
- [ ] seed.rb の `puts` にログイン情報（ログイン画面の URL、メールアドレス、パスワード）がある（ログインが必要な画面のとき）
- [ ] ログインまわりを変更していないのに、ログインが手順に入っていない
- [ ] seed.rb に「テスト」「サンプル」などの語やランダム生成が無い

### 7. seed を投入し、サーバーを用意する

1. `bin/rails runner docs/verification/<dir>/seed.rb` を実行する。失敗したら seed.rb を直して再実行する。出力されたログイン情報と ID 入りの URL を控える
2. `references/server.md` の手順 1〜3 で**ベース URL** を決め、サーバーを用意する。worktree ごとのポートや puma-dev（`https://<名前>.test`）もここで扱う
3. `mkdir -p docs/verification/<dir>/screenshots` で画像の置き場を作る

### 8. ブラウザで 1 ステップずつ実行する

同梱の Playwright MCP（`mcp__plugin_ohirome_playwright__*`）を使う。ブラウザは毎回まっさらな状態（前回のログインは残っていない）で、画面サイズは 1280×800。

ページはすべて「ベース URL + パス」で開く。steps.md の手順にログインが無く、ログインが必要な画面のときは、手順 1 の前に seed の出力のログイン情報（ログイン画面のパス、メールアドレス、パスワード）でログインする。このログインは撮影しない。

steps.md のステップを上から順に、次の 3 つを繰り返す。

1. **操作する**: `browser_snapshot` で要素を特定し、`browser_navigate` / `browser_click` / `browser_type` / `browser_select_option` などで steps.md に書いた操作を 1 つだけ行う。画面遷移を伴う操作は、遷移が終わるまで待ってから次へ進む
2. **撮影する**: `browser_take_screenshot` を `filename: "docs/verification/<dir>/screenshots/NN.png"`（NN はステップ番号を 2 桁にしたもの、案件のルートからの相対パス）、`fullPage: true` で呼ぶ。保存できなかった場合は filename を付けずに撮り、返ってきたパスから `mv` で移す
3. **結果を控える**: 操作のあとに開いていた**完全な URL**（ベース URL と ID を含む）と、`browser_snapshot` で画面に出ていたこと（表示されたメッセージ、値、件数、エラー文）を控える。期待どおりかどうかは判断しない。見えたことをそのまま書く

ログインできない、画面が開けないなど、それ以上進めないときはそこで止める。それまでのステップだけを steps.md に残し、止まった理由を報告する。

全ステップが終わったら `browser_close` でブラウザを閉じる。

### 9. steps.md を仕上げ、後片付けする

- 各ステップを仕上げる
  - `📍` を `[<実際のパス>](<手順 8 で控えた完全な URL>)` のリンクに書き直す。表示のパスも `:id` ではなく実際の ID にする（例: `[/admin/orders/37/edit](http://localhost:3000/admin/orders/37/edit)`）。押すと実際の画面が開く
  - `- 結果: <画面に出たこと>` を書く。入力だけのステップは「数量欄が「3」になった」のように短く書く
  - 箇条書きの後に空行を挟んで `![<番号>. <見出し>](screenshots/NN.png)`
- `references/server.md` の手順 4 のとおり、**自分で起動したサーバーだけ**止める
- 案件のルートに `.playwright-mcp/` ができていたら削除してよいか確認する（コミットに混ぜないため）

### 10. 報告する

次だけを短く伝える。

- 生成したファイルのパス
- 使ったベース URL（📍 のリンク先はこの URL。別の人の環境ではポートや ID が違い、開けないことがある）
- 途中で止まった場合は、どのステップで、なぜ止まったか
- steps.md を読んで問題がなければ `/ohirome:video docs/verification/<dir>` で動画を作れること
