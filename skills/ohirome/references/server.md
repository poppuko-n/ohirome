# ベース URL を決め、サーバーを用意する

`/ohirome` と `/ohirome:video` の両方がこの手順を使う。開発環境の URL は人によって違う（`localhost:3000`、worktree ごとに別のポート、puma-dev の `https://<名前>.test` など）ので、推測せずに次の順で決める。決めたものを**ベース URL** と呼び、撮影・録画・📍 のリンクはすべてこれを使う。

`.env` などの環境変数ファイルは読まない（秘密の値が入っていることがあり、読み取りを禁止している人もいる）。

## 1. 名前を決める

- **リポジトリ名**: `git rev-parse --path-format=absolute --git-common-dir` の 1 つ上のディレクトリ名（worktree でも本体の名前になる。例: `foufou`）
- **作業ディレクトリ名**: `git rev-parse --show-toplevel` のディレクトリ名（worktree ならその名前。例: `add-plan`）

## 2. ベース URL とポートを決める

上から順に試し、最初に当てはまったものを使う。

| 条件 | ベース URL | ポート |
|---|---|---|
| `~/.puma-dev/` に `<リポジトリ名>-<作業ディレクトリ名>` のファイルがある（worktree。例: `foufou-add-plan`） | `https://<そのファイル名>.<ドメイン>` | ファイルの中身（例: `3018`）。中身がディレクトリへのシンボリックリンクなら無し |
| 本体で作業していて、`~/.puma-dev/<リポジトリ名>` がある（例: `foufou`） | 同上 | 同上 |
| `Procfile.dev` の `web:` 行に `-p 3005` のように番号が直書き | `http://localhost:<番号>` | その番号 |
| `Procfile.dev` の `web:` 行が `-p ${RAILS_PORT:-3000}` のように環境変数を使っている | `http://localhost:<:- の後ろの既定値>` をまず試す | 既定値。手順 3 で応答が無ければ、URL を人に聞く（worktree ごとに `.env` でポートを変えている可能性があるため） |
| どれでもない | `http://localhost:3000` | 3000 |

ドメインは puma-dev の起動設定（macOS なら `~/Library/LaunchAgents/io.puma.dev.plist`）の `-d` の値。見つからなければ `test`。

## 3. サーバーを確認し、必要なら起動する

- **ポートがある（localhost、または puma-dev のファイルの中身がポート番号）**: `curl -s -o /dev/null -w '%{http_code}' http://localhost:<ポート>/` で応答を確かめる
  - **応答あり**: そのサーバーを使う。終わっても止めない
  - **応答なし**: 表の 4 行目（環境変数のポートで既定値を試した）なら、起動せずに「開発サーバーの URL（例: `http://localhost:3018` や `https://foufou-add-plan.test`）」を人に聞き、その URL をベース URL にしてやり直す。それ以外は `bin/dev`（無ければ `bin/rails server -p <ポート>`）を Bash の `run_in_background` で起動し、`curl -s -o /dev/null -w '%{http_code}' --retry 30 --retry-connrefused --retry-delay 2 http://localhost:<ポート>/` で応答を待つ。**自分で起動したことを覚えておく**
  - 起動しても応答しない場合は、サーバーのログを見て原因を伝えて止める
- **puma-dev のファイルがディレクトリへのシンボリックリンク**（puma-dev が自分で Rails を起動する方式）: サーバーは起動しない。`curl -sk -o /dev/null -w '%{http_code}' --max-time 60 <ベース URL>/` で応答を確かめ、応答が無ければ原因を伝えて止める
- puma-dev 経由のときは、最後に `curl -sk -o /dev/null -w '%{http_code}' <ベース URL>/` でベース URL 自体にも届くことを確かめる。届かなければ `http://localhost:<ポート>` をベース URL にする

## 4. 後片付け

手順 3 で**自分で起動したサーバーだけ**止める（起動に使ったバックグラウンドのタスクを止める）。もともと動いていたサーバーや puma-dev には触らない。
