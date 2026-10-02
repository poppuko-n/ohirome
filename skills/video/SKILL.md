---
name: video
description: ohirome で作り、人が確認した手順書（docs/verification/<dir>/steps.md）をそのまま台本にして、開発サーバーをブラウザで操作しながら録画し、お客さんに渡せるデモ動画（mp4、ffmpeg が無ければ webm）を作る。`/ohirome:video <docs/verification/<dir>>` での明示起動のほか、「この手順書から動画を作って」「お客さん向けのデモ動画を作って」と依頼されたときに使う。
argument-hint: "<docs/verification/<YYYYMMDD>_<機能名>>"
allowed-tools: Read, Glob, Bash(bin/rails runner:*), Bash(bin/dev:*), Bash(bin/rails server:*), Bash(curl:*), Bash(mkdir:*), Bash(ls:*), Bash(git check-ignore:*), Bash(which ffmpeg:*), Bash(ffmpeg:*), mcp__plugin_ohirome_playwright
---

# ohirome:video: 確認済みの手順書からデモ動画を作る

人が `/ohirome` の steps.md を見て問題ないと判断したあとに使う。steps.md の手順をそのまま録画して、お客さんに渡せる動画にする。確認した内容と動画の内容がずれないよう、**steps.md を台本として使い、書き換えない**。

```
tmp/ohirome/<dir名>/
├─ demo.webm   # 録画そのもの
└─ demo.mp4    # 渡す用（ffmpeg があるときだけ）
```

`tmp/` は git 管理外なので、動画はコミットされない。

## 手順

### 1. 前提をチェックする

対象ディレクトリは `$ARGUMENTS`（例: `docs/verification/20261002_order_quantity_edit`）。未指定なら `docs/verification/` の中を `ls` で見せて、どれにするか聞く。

`<dir>/steps.md` と `<dir>/seed.rb` を読む。どちらかが無ければ動画を作らずに止め、`/ohirome` を先に実行するよう伝える。

steps.md の内容が期待どおりかは、実行する人がすでに確認している前提で進める。

### 2. seed を投入し、サーバーを用意する

1. `bin/rails runner <dir>/seed.rb` を実行する。前回の操作で変わったデータが、手順を始める前の状態に戻る。出力されたログイン情報を控える
2. ポートを決める。`Procfile.dev` の web 行に `-p <番号>` や `PORT` があればそれ、無ければ 3000
3. `curl -s -o /dev/null -w '%{http_code}' http://localhost:<port>/` で応答を確かめる
   - **応答あり**: そのサーバーを使う。録画後も止めない
   - **応答なし**: `bin/dev`（無ければ `bin/rails server -p <port>`）を Bash の `run_in_background` で起動し、`curl -s -o /dev/null -w '%{http_code}' --retry 30 --retry-connrefused --retry-delay 2 http://localhost:<port>/` で応答を待つ。**自分で起動したことを覚えておく**
4. `mkdir -p tmp/ohirome/<dir名>` で動画の置き場を作る（`<dir名>` は `20261002_order_quantity_edit` の部分）。`git check-ignore -q tmp/ohirome/<dir名>` が失敗する（git 管理外になっていない）ときは、動画がコミットされうることを報告で伝える

### 3. 録画を始める

同梱の Playwright MCP（`mcp__plugin_ohirome_playwright__*`）を使う。

1. 手順にログインが無く、seed の出力にログイン情報があるときは、そのログイン画面を開いてログインする。`browser_start_video` より前の操作は動画に映らないので、ログインは動画に入らない。ログインできなければ録画せずに止め、理由を伝える
2. `browser_navigate` で手順 1 の 📍 のページを開く（録画はページが開いていないと始められない）。開いたページのパスが 📍 と違う（ID は `:id` に読み替えて比べる。ログイン画面へリダイレクトされたなど）ときは、録画せずに止め、実際に開いたパスを伝える
3. `browser_start_video`: `filename: "tmp/ohirome/<dir名>/demo.webm"`、`size: { width: 1280, height: 800 }`
4. `browser_video_show_actions`: `cursor: "pointer"`、`duration: 800`（マウスポインタの動きと、操作した場所の強調が映る）

### 4. 収録する

1. **オープニング**: `browser_video_chapter` で `title` に steps.md の見出しの機能名、`description` に「確認する機能」の文、`duration: 3000`
2. **各ステップ**（steps.md の手順 1 から順に全部）。「## 正常系」「## 異常系」の見出しに入るところでは、最初に `browser_video_chapter` で `title: "正常系"`（または `"異常系"`）、`duration: 1500` を出す:
   1. `browser_video_chapter` で `title: "<番号>. <見出し>"`、`duration: 1200`
   2. steps.md の「操作」を行う（サブ箇条書きがあれば上から順にすべて）。要素は `browser_snapshot` で特定する。入力は `browser_type` に `slowly: true` を付けて 1 文字ずつ打つ。手順 1 のように「開く」操作は、開いているページでも `browser_navigate` でもう一度開く
   3. `browser_wait_for` で `time: 1` 待ち、結果を見せる
3. **エンディング**: `browser_video_chapter` で `title: "以上です"`、`duration: 2000`

### 5. 録画を止める

`browser_stop_video` で保存し、`browser_close` でブラウザを閉じる。返ってきたパスが `tmp/ohirome/<dir名>/demo.webm` であることを確かめる。

### 6. mp4 に変換する

`which ffmpeg` で ffmpeg があるかを確かめる。

- **ある**: `ffmpeg -y -loglevel error -i tmp/ohirome/<dir名>/demo.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart tmp/ohirome/<dir名>/demo.mp4`
- **無い**: webm のまま残す。報告で「mp4 が必要なら `brew install ffmpeg` のあと `/ohirome:video` をもう一度」と伝える

### 7. 後片付けして報告する

- 手順 2 で**自分で起動したサーバーだけ**止める（起動に使ったバックグラウンドのタスクを止める）。もともと動いていたサーバーには触らない
- 次だけを短く伝える
  - 動画のパス（mp4 があれば mp4、無ければ webm）
  - 要素が見つからないなどで操作できなかったステップがあれば、その番号。あれば「お客さんに渡す前に動画を見て確かめてください」と添える
  - 動画はコミットされないこと（`tmp/` に置いている）
