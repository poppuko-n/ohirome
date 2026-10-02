---
name: ohirome
description: Rails 案件で機能の実装が終わったあと、動作確認用の seed.rb と、各ステップに実際の画面のスクリーンショットと判定（✅/❌）を埋め込んだ手順書 steps.md を生成する。スキルが seed を開発 DB に投入し、開発サーバーをブラウザで操作して撮影する。`/ohirome [比較対象ブランチ]` での明示起動のほか、「動作確認の準備をして」「動作確認用のデータと手順を作って」「動作確認して手順書にまとめて」と依頼されたときに使う。
argument-hint: "[比較対象ブランチ（省略時は release-candidate、無ければ main）]"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git show-ref:*), Bash(git status:*), Bash(bin/rails routes:*), Bash(bin/rails runner:*), Bash(bin/dev:*), Bash(bin/rails server:*), Bash(curl:*), Bash(ruby -c:*), Bash(mkdir:*), Bash(mv:*), Bash(ls:*), Bash(date:*), Bash(crit:*), Bash(which crit:*), mcp__plugin_ohirome_playwright
---

# ohirome: 動作確認の結果を手順書にまとめる

実装した機能の動作確認を、スキル自身がブラウザで実際に行い、その結果を対象案件の中に残す。

```
docs/verification/<YYYYMMDD>_<機能名>/
├─ seed.rb          # 動作確認用データ（bin/rails runner で投入する）
├─ steps.md         # 1 ステップ 1 操作の手順書。各ステップに画面の画像と判定つき
└─ screenshots/
   ├─ 01.png
   └─ ...
```

ゴールは **steps.md を読むだけで、正常系もエラー系も動いていると確認を終えられる** 状態。実際に触りたくなった人は、seed.rb を流して steps.md のとおりに操作すれば同じ画面を再現できる。将来この steps.md をもとにデモ動画を自動作成するので、書式は雛形どおりに固定する。

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
| 変更していない | 手順には書かず、「準備」にログイン情報だけを書く。手順はログインした状態から始める |
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
| 最後に**ログイン情報と、ID の入った実 URL を `puts` する** | 生成時点では ID が分からないため。steps.md からはこの出力の名前で参照する |
| 確認に関係ないレコードは作らない | 手順書と seed の対応を追いやすくするため |
| 手順の途中でデータが変わる場合（数量を 2 → 3 に更新など）も、seed は**変更前の状態**を作る | 再実行のたびに手順の最初の状態へ戻すため。`find_or_create_by!` のブロックは新規作成時しか動かないので、変わる属性は `update!` で毎回戻す |

### 5. steps.md の下書きを作る

`references/steps-template.md` の書式（見出し・`📍`・`操作:`・`確認:`・`判定:`・画像の並び）に**そのまま**従う。中身は架空の例なので、対象機能の内容で書く。この時点では「結果」と各ステップの「判定」・画像は空けておき、手順 9 で埋める。

| ルール |
|---|
| 冒頭に「結果」（手順 9 で埋める）、「確認する機能」（1〜3 行）、「準備（実際に触りたいとき）」（seed 投入コマンド、サーバー起動コマンド、ログイン情報） |
| ログイン情報は雛形の「準備」の 3 と同じ形（ログイン画面のパス、メールアドレス、パスワード、表示名）で 1 行に書く。`/ohirome:video` もこの行を読んでログインする |
| 手順 1 で決めたとおり、ログインまわりを変更していなければ、ログインは手順に書かない。手順 1 は機能の画面を URL で開くところから始め、「準備」の番号付きリストの後に「手順はログインした状態から始める。」と書く |
| **1 ステップ 1 操作**。入力欄 1 つ、クリック 1 回、選択 1 回がそれぞれ 1 ステップ |
| **画面遷移したステップには必ず `📍` 行で URL のパスを書く**。リダイレクト後に表示されるパスを書く（バリデーションエラーで再描画されたときは、フォーム送信先のパスになる点に注意） |
| ID を含むパスは `:id` のまま書き、どのレコードかを `（seed 出力の「注文 #1024」）` のように添える |
| 「確認」行は、画面遷移・保存・削除・エラー表示など**結果が目に見えるステップだけ**に 1 行書く。入力だけのステップには付けない |
| 「確認」には何が見えれば OK かを具体的に書く（表示される文言、値、件数）。コードから根拠を示せない挙動は書かない |
| 正常系のあとに、実装した分岐のエラー系を続ける |
| ラベルや文言は画面の実際の表記を「」で囲んで書く |

サーバー起動コマンドは `bin/dev` があればそれ、無ければ `bin/rails server` を書く。

### 6. セルフチェック

- [ ] `ruby -c docs/verification/<dir>/seed.rb` が `Syntax OK`
- [ ] steps.md の `📍` のパスがすべて `bin/rails routes` に存在する
- [ ] 1 ステップに操作が 2 つ以上入っていない（「〜して〜する」になっていない）
- [ ] steps.md に出てくる名前・数値・ログイン情報が seed.rb と一致している
- [ ] ログインまわりを変更していないのに、ログインが手順に入っていない
- [ ] seed.rb に「テスト」「サンプル」などの語やランダム生成が無い

### 7. seed を投入し、サーバーを用意する

1. `bin/rails runner docs/verification/<dir>/seed.rb` を実行する。失敗したら seed.rb を直して再実行する。出力された ID 入りの URL を控える
2. ポートを決める。`Procfile.dev` の web 行に `-p <番号>` や `PORT` があればそれ、無ければ 3000
3. `curl -s -o /dev/null -w '%{http_code}' http://localhost:<port>/` で応答を確かめる
   - **応答あり**: そのサーバーを使う。撮影後も止めない
   - **応答なし**: `bin/dev`（無ければ `bin/rails server -p <port>`）を Bash の `run_in_background` で起動し、`curl -s -o /dev/null -w '%{http_code}' --retry 30 --retry-connrefused --retry-delay 2 http://localhost:<port>/` で応答を待つ。**自分で起動したことを覚えておく**
   - 起動しても応答しない場合は、サーバーのログを見て原因を伝えて止める
4. `mkdir -p docs/verification/<dir>/screenshots` で画像の置き場を作る

### 8. ブラウザで 1 ステップずつ実行する

同梱の Playwright MCP（`mcp__plugin_ohirome_playwright__*`）を使う。ブラウザは毎回まっさらな状態（前回のログインは残っていない）で、画面サイズは 1280×800。

steps.md の手順にログインが無く、「準備」にログイン情報があるときは、手順 1 の前にそのとおりログインする。このログインは撮影も判定もしない。ログインできなければ全ステップを ⏭ にして中断する。

steps.md のステップを上から順に、次の 3 つを繰り返す。

1. **操作する**: `browser_snapshot` で要素を特定し、`browser_navigate` / `browser_click` / `browser_type` / `browser_select_option` などで steps.md に書いた操作を 1 つだけ行う。画面遷移を伴う操作は、遷移が終わるまで待ってから次へ進む
2. **撮影する**: `browser_take_screenshot` を `filename: "docs/verification/<dir>/screenshots/NN.png"`（NN はステップ番号を 2 桁にしたもの、案件のルートからの相対パス）、`fullPage: true` で呼ぶ。保存できなかった場合は filename を付けずに撮り、返ってきたパスから `mv` で移す
3. **判定する**（「確認」行があるステップだけ）:
   - 📍 行があれば、現在の URL のパス（ID は `:id` に読み替える）が一致するか
   - 「確認」に書いた文言や値が、`browser_snapshot` の内容に実際にあるか
   - 一致すれば ✅、しなければ ❌ とし、❌ のときは**実際に見えたもの**（表示されたエラー文、違った値、遷移先のパス）を控える

期待と違っても止めずに最後まで進める。ログインできない、画面が開けないなど、それ以上進めない場合だけ中断し、そこまでの結果を残す。

全ステップが終わったら `browser_close` でブラウザを閉じる。

### 9. steps.md を仕上げ、後片付けする

- 各ステップに判定と画像を入れる
  - 「確認」があるステップ: `- 判定: ✅ 期待どおり` または `- 判定: ❌ <期待と違った点>（実際は<見えたもの>）`
  - 全ステップ: 箇条書きの後に空行を挟んで `![<番号>. <見出し>](screenshots/NN.png)`
  - 中断して実行できなかったステップ: `- 判定: ⏭ 未実行（<理由>）`。画像は付けない
- 冒頭の「結果」を埋める: `確認 <「確認」があるステップ数> か所中 <✅ の数> か所が期待どおり（全 <ステップ数> ステップ、<YYYY-MM-DD> 撮影）`。❌ や ⏭ があれば、その番号を次の行に並べる
- 手順 7 で**自分で起動したサーバーだけ**止める（起動に使ったバックグラウンドのタスクを止める）。もともと動いていたサーバーには触らない
- 案件のルートに `.playwright-mcp/` ができていたら削除してよいか確認する（コミットに混ぜないため）

### 10. 報告する

次だけを短く伝える。

- 生成したファイルのパス
- 結果（確認の何か所中いくつ期待どおりか）。❌ があれば、そのステップと実際に見えたものを一覧で
- 実際に触りたいとき: `bin/rails runner docs/verification/<dir>/seed.rb` を流して steps.md のとおりに操作する

### 11. レビューを受ける

続けて steps.md を crit でブラウザに開き、人のコメントを反映する。

- `which crit` が成功したら、このスキルのディレクトリから見て `../review/SKILL.md` を読み、その手順 2 から、対象ディレクトリを `docs/verification/<dir>` として進める
- 失敗したら、「`brew install crit` で crit を入れると、`/ohirome:review docs/verification/<dir>` で画像を見ながら steps.md にコメントでき、Claude が反映する」と伝えて終わる
