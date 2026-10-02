---
name: review
description: ohirome で作った手順書（docs/verification/<dir>/steps.md）を crit でブラウザに表示し、人が画像を見ながら行ごとに付けたコメントを、steps.md・seed.rb・スクリーンショットに反映する。`/ohirome` の最後にも自動で行われるので、これを単独で使うのは、前に作った手順書にあとからコメントしたいとき。`/ohirome:review <docs/verification/<dir>>` での明示起動のほか、「手順書にコメントしたい」「手順書をレビューして直して」と依頼されたときに使う。
argument-hint: "<docs/verification/<YYYYMMDD>_<機能名>>"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(crit:*), Bash(which crit:*), Bash(git diff:*), Bash(git status:*), Bash(bin/rails routes:*), Bash(bin/rails runner:*), Bash(bin/dev:*), Bash(bin/rails server:*), Bash(curl:*), Bash(ruby -c:*), Bash(mkdir:*), Bash(mv:*), Bash(ls:*), Bash(date:*), mcp__plugin_ohirome_playwright
---

# ohirome:review: 手順書へのコメントを反映する

`/ohirome` の steps.md を、エディタではなくブラウザで画像を見ながらレビューできるようにする。コメントの表示と受け取りは [crit](https://crit.md) に任せ、このスキルはコメントを steps.md・seed.rb・スクリーンショットに反映することに集中する。

```
/ohirome:review <dir>
  → crit で steps.md を開く（人が行ごとにコメントし、Finish Review を押す）
  → コメントを「文章だけ直す」「撮り直す」に分けて反映する
  → crit で次のラウンドを開く … コメントが 0 件になったら終わり
```

## 手順

### 1. 前提をチェックする

対象ディレクトリは `$ARGUMENTS`（例: `docs/verification/20261002_order_quantity_edit`）。未指定なら `docs/verification/` の中を `ls` で見せて、どれにするか聞く。

- `<dir>/steps.md` が無ければ、`/ohirome` で先に作るよう伝えて止める
- `which crit` が失敗したら、`brew install crit` で入れるよう伝えて止める

### 2. crit を開き、レビューが終わるのを待つ

`crit <dir>/steps.md` を Bash の `run_in_background` で起動する。起動時に出る URL をそのまま伝え、「画像を見ながら気になる行にコメントし、終わったら Finish Review を押してください」と添える。

**コマンドが終わるまで先に進まない。** 終わったことが、人のレビューが終わった合図になる。ユーザーに何かを入力してもらう必要はない。

終わったら stdout と stderr を読む。コメントが 0 件（stderr に `approved: true`）なら手順 5 へ進む。

### 3. コメントを分ける

各コメントの `quote`（選んだ文字列）と `anchor` で、どのステップのどこへのコメントかを特定し、次のどれかに分ける。

| 分類 | 当てはまるコメント | 反映のしかた |
|---|---|---|
| 文章だけ直す | 見出し・「確認する機能」・「準備」の言い回し、「確認」の書き方（確かめる中身は変わらない） | steps.md を Edit で直す。画像と判定はそのまま |
| 撮り直す | 手順の追加・削除・並べ替え、「操作」「📍」の変更、「確認」で確かめる中身の変更、seed の値（名前・数量など）の変更 | 手順 4 で全ステップを撮り直す |
| 質問 | 「なぜこうなっている？」など、直すことを求めていない | 直さず、答えだけ返す |

撮り直しは**全ステップ**で行う。途中のステップは前のステップの操作でできた画面から始まるので、1 ステップだけ撮り直すと前後の画面と食い違うため。

どちらにも決めきれないコメントは、撮り直すほうに入れる。

### 4. 反映する

1. 「文章だけ直す」コメントを steps.md に反映する
2. 「撮り直す」コメントが 1 件でもあれば、このスキルのディレクトリから見て `../ohirome/SKILL.md` を読み、次に従う
   - 手順・確認・seed の書き方は、その手順 4・5 のルールに従って seed.rb と steps.md を直す。直したステップの「判定」と画像は消しておく
   - その手順 6 のセルフチェックをする
   - その手順 7〜9 のとおりに seed を投入し、全ステップを実行・撮影・判定して、「結果」を書き直す。ステップが減ったときは、使われなくなった `screenshots/NN.png` を消してよいか確認する
3. 各コメントに、何をしたかを返信する。まとめて返すときは JSON で 1 回にする

```bash
echo '[
  {"reply_to": "<コメントID>", "body": "「確認」の書き方を直しました"},
  {"reply_to": "<コメントID>", "body": "数量 0 のエラー系を手順 8 に足し、全ステップを撮り直しました（❌ なし）"}
]' | crit comment --json --author 'Claude Code'
```

コメントを解決済み（`--resolve`）にはしない。解決するかはレビューした人が決める。

撮り直して ❌ が出たときは、返信にそのステップ番号と実際に見えたものを書く。

反映し終えたら、もう一度 `crit <dir>/steps.md` を `run_in_background` で起動し（前のラウンドの完了を crit に伝え、次の Finish Review を待つ）、「直したので、ブラウザで差分を見て Finish Review を押してください」と伝えて、手順 2 の「終わったら」に戻る。

### 5. 報告する

次だけを短く伝える。

- 反映したコメントの数（文章だけ直した / 撮り直した / 質問に答えた）
- 撮り直した場合は、新しい「結果」の行。❌ があればそのステップと実際に見えたもの
- お客さん向けの動画が必要なら `/ohirome:video <dir>` を使えること（❌ や ⏭ が無いときだけ）
