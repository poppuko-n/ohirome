---
name: video
description: ohirome で作り、人が確認した手順書（docs/verification/<dir>/steps.md）をそのまま台本にして、開発サーバーをブラウザで操作しながら録画し、お客さんに渡せるデモ動画（機能ごとのチャプター付きの mp4、ffmpeg が無ければ webm）を作る。`/ohirome:video <docs/verification/<dir>>` での明示起動のほか、「この手順書から動画を作って」「お客さん向けのデモ動画を作って」と依頼されたときに使う。
argument-hint: "<docs/verification/<YYYYMMDD>_<機能名>>"
allowed-tools: Read, Glob, Write, Edit, Bash(bin/rails runner:*), Bash(bin/dev:*), Bash(bin/rails server:*), Bash(curl:*), Bash(readlink:*), Bash(git rev-parse:*), Bash(mkdir:*), Bash(ls:*), Bash(git check-ignore:*), Bash(which ffmpeg:*), Bash(ffmpeg:*), mcp__plugin_ohirome_playwright
---

# ohirome:video: 確認済みの手順書からデモ動画を作る

人が `/ohirome` の steps.md を見て問題ないと判断したあとに使う。steps.md の手順をそのまま録画して、お客さんに渡せる動画にする。確認した内容と動画の内容がずれないよう、**steps.md を台本として使い、書き換えない**。録画が終わったあとに、各ステップへ動画のどこにあたるかの時刻（`🎬` 行）だけを足す。

```
tmp/ohirome/<dir名>/
├─ demo.webm      # 録画そのもの
├─ chapters.txt   # チャプターの時刻とタイトル（ffmpeg のメタデータ形式）
└─ demo.mp4       # 渡す用。チャプター付き（ffmpeg があるときだけ）
```

`tmp/` は git 管理外なので、動画はコミットされない。

## 手順

### 1. 前提をチェックする

対象ディレクトリは `$ARGUMENTS`（例: `docs/verification/20261002_order_quantity_edit`）。未指定なら `docs/verification/` の中を `ls` で見せて、どれにするか聞く。

`<dir>/steps.md` と `<dir>/seed.rb` を読む。どちらかが無ければ動画を作らずに止め、`/ohirome` を先に実行するよう伝える。

steps.md の内容が期待どおりかは、実行する人がすでに確認している前提で進める。

### 2. seed を投入し、サーバーを用意する

1. `bin/rails runner <dir>/seed.rb` を実行する。前回の操作で変わったデータが、手順を始める前の状態に戻る。出力されたログイン情報を控える
2. このスキルのディレクトリから見た `../ohirome/references/server.md` の手順 1〜3 で**ベース URL** を決め、サーバーを用意する。worktree ごとのポートや puma-dev（`https://<名前>.test`）もここで扱う
3. `mkdir -p tmp/ohirome/<dir名>` で動画の置き場を作る（`<dir名>` は `20261002_order_quantity_edit` の部分）。`git check-ignore -q tmp/ohirome/<dir名>` が失敗する（git 管理外になっていない）ときは、動画がコミットされうることを報告で伝える

### 3. 録画を始める

同梱の Playwright MCP（`mcp__plugin_ohirome_playwright__*`）を使う。

1. ページはすべて「ベース URL + パス」で開く。手順にログインが無く、seed の出力にログイン情報があるときは、そのログイン画面を開いてログインする。`browser_start_video` より前の操作は動画に映らないので、ログインは動画に入らない。ログインできなければ録画せずに止め、理由を伝える
2. `browser_navigate` で手順 1 の 📍 のページを開く。📍 のリンク先が今のベース URL で始まっていればそれを、違えばベース URL + 📍 のパスを開く（録画はページが開いていないと始められない）。別の人の環境で作られた steps.md で ID が合わないときは、seed の出力の URL のパスを使う。開いたページのパスが開こうとしたパスと違う（ログイン画面へリダイレクトされたなど）ときは、録画せずに止め、実際に開いたパスを伝える
3. `browser_start_video`: `filename: "tmp/ohirome/<dir名>/demo.webm"`、`size: { width: 1280, height: 800 }`
4. `browser_video_show_actions`: `cursor: "pointer"`、`duration: 800`（マウスポインタの動きと、操作した場所の強調が映る）
5. `browser_evaluate` で `() => Date.now()` を実行し、返ってきた値を**録画の開始時刻**として控える

### 4. 収録する

1. **オープニング**: `browser_video_chapter` で `title` に steps.md の `#` 見出しの名前（「動作確認手順」は除く）、`description` に目次の表の機能名を「、」でつないだもの、`duration: 3000`
2. **各ステップ**（steps.md の手順 1 から順に全部）。見出しに入るところでは、最初に次のチャプターを出す。`## <記号>. <機能名>` と「### 異常系」の見出しでは、カードを出す直前に `browser_evaluate` で `() => Date.now()` を実行し、`返ってきた値 - 録画の開始時刻`（ミリ秒）を手順 6 の**チャプターの開始位置**として控える:
   - `## <記号>. <機能名>` の見出し: `browser_video_chapter` で `title: "<記号>. <機能名>"`、`description` にその下の `>` の文、`duration: 2500`
   - 「### 正常系」「### 異常系」の見出し: `browser_video_chapter` で `title: "正常系"`（または `"異常系"`）、`duration: 1500`

   そのうえで各ステップを次のとおり収録する:
   1. `browser_evaluate` で `() => Date.now()` を実行し、`(返ってきた値 - 録画の開始時刻) / 1000` の小数点以下を切り捨てた秒数を、そのステップの**動画内の位置**として控える
   2. `browser_video_chapter` で `title: "<番号>. <見出し>"`、`duration: 1200`
   3. steps.md の「操作」を 1 つ行う。要素は `browser_snapshot` で特定する。入力は `browser_type` に `slowly: true` を付けて 1 文字ずつ打つ。手順 1 のように「開く」操作は、開いているページでも `browser_navigate` でもう一度開く
   4. `browser_wait_for` で `time: 1` 待ち、結果を見せる
3. **エンディング**: `browser_video_chapter` で `title: "以上です"`、`duration: 2000`。出し終えたら `browser_evaluate` で `() => Date.now()` を実行し、`返ってきた値 - 録画の開始時刻`（ミリ秒）を**録画の終了位置**として控える

### 5. 録画を止める

`browser_stop_video` で保存し、`browser_close` でブラウザを閉じる。返ってきたパスが `tmp/ohirome/<dir名>/demo.webm` であることを確かめる。

### 6. チャプターを付けて mp4 に変換する

手順 4 で控えた位置から、チャプターを機能ごとに作る。機能に異常系があるときは、正常系と異常系を別のチャプターにする。

| チャプター | 開始位置 | タイトル |
|---|---|---|
| オープニング | 0 | `オープニング` |
| 機能（異常系が無い） | その機能のカードの直前 | `<記号>. <機能名>` |
| 機能の正常系（異常系がある） | その機能のカードの直前 | `<記号>. <機能名>（正常系）` |
| 機能の異常系 | 「異常系」のカードの直前 | `<記号>. <機能名>（異常系）` |

各チャプターの終了位置は次のチャプターの開始位置、最後のチャプターの終了位置は録画の終了位置にする（エンディングは最後のチャプターに含める）。

`Write` で `tmp/ohirome/<dir名>/chapters.txt` を次の形で書く（UTF-8）。タイトルに `=`、`;`、`#`、`\` があれば、前に `\` を付ける。

```
;FFMETADATA1
[CHAPTER]
TIMEBASE=1/1000
START=0
END=3120
title=オープニング
[CHAPTER]
TIMEBASE=1/1000
START=3120
END=41870
title=A. 注文の数量を変更できる（正常系）
...
```

`which ffmpeg` で ffmpeg があるかを確かめる。

- **ある**: `ffmpeg -y -loglevel error -i tmp/ohirome/<dir名>/demo.webm -i tmp/ohirome/<dir名>/chapters.txt -map 0 -map_metadata 1 -map_chapters 1 -c:v libx264 -pix_fmt yuv420p -movflags +faststart tmp/ohirome/<dir名>/demo.mp4`
- **無い**: webm のまま残す（チャプターは付かない）。報告で「チャプター付きの mp4 が必要なら `brew install ffmpeg` のあと `/ohirome:video` をもう一度」と伝える

### 7. steps.md に動画の時刻を書く

手順 4 で控えた位置を使い、steps.md の各ステップの `**結果:**` 行の次に 1 行足す。

```markdown
- 🎬 0:42
```

- `分:秒`（秒は 2 桁）で書く。リンクにはしない
- すでに `🎬` 行があれば（撮り直したとき）、その行を書き換える。新しい行は足さない
- `🎬` 行以外は**一文字も変えない**。見出し・`📍`・操作・結果・画像はそのまま
- 操作できなかったステップにも、控えた時刻を書く

### 8. 後片付けして報告する

- 手順 2 で**自分で起動したサーバーだけ**止める（起動に使ったバックグラウンドのタスクを止める）。もともと動いていたサーバーには触らない
- 次だけを短く伝える
  - 動画のパス（mp4 があれば mp4、無ければ webm）
  - チャプターの一覧を `0:00 オープニング` の形で（mp4 のチャプターは QuickTime Player や VLC で表示される。Chrome などブラウザの再生画面には出ないので、一覧を添えて渡すと親切なこと）
  - 要素が見つからないなどで操作できなかったステップがあれば、その番号。あれば「お客さんに渡す前に動画を見て確かめてください」と添える
  - 動画はコミットされないこと（`tmp/` に置いている）
  - steps.md の各ステップに `🎬` で動画の時刻を書いたこと。撮り直すと時刻が変わり、steps.md に差分が出ること
