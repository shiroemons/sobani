# トラブルシューティング

Sobani の問題解決に役立つ情報をまとめています。

[← 目次](README.md)

---

## ウィンドウ位置の復元ログを確認する

スリープ復帰やモニター切断時のウィンドウ位置復元に問題がある場合、`os_log` のログで動作を確認できます。

通常時はエラーレベルのログのみ出力されます。詳細なデバッグログを確認するには `--level debug` を指定してください。

**リアルタイムで監視する（詳細ログ含む）:**

```sh
log stream --predicate 'subsystem == "com.shiroemons.Sobani"' --level debug --style compact
```

**直近のログを確認する（詳細ログ含む）:**

```sh
log show --predicate 'subsystem == "com.shiroemons.Sobani"' --level debug --last 5m --style compact
```

ログには以下の情報が記録されます:

| イベント | レベル | ログ例 |
|---------|--------|--------|
| オブザーバ登録 | debug | `[ScreenRestoration] observers registered, screens=3` |
| スクリーン変更検出 | debug | `screenChange: isWake=true, screens=3` |
| スリープ前の状態保存 | info | `[ScreenRestoration] willSleep: saved 3 windows` |
| ウェイク復元開始 | info | `[ScreenRestoration] didWake: 3 windows to restore` |
| ウィンドウ復元結果 | debug | `restore #4: saved={x, y} -> {x, y} -> {x, y}` |
| 復元試行状況 | debug | `attempt #1: restoredAll=true, screens=[...]` |
| モニター未検出 | error | `restore #1: screen not found (displayID=2)` |

> ウィンドウ復元結果の3つの座標は、左から順に「保存時の座標」→「計算後の座標」→「クランプ後の座標」を表します。正常時は3つが一致します。

---

## 画面位置の診断ログを使う

管理パネル（`Option+M`）の「ログ」タブでは、ウィンドウ位置の復元に関する診断ログを GUI で記録・確認できます。

### os_log との使い分け

| | os_log（上記のコマンド） | 診断ログ（管理パネル） |
|---|---|---|
| 対象ユーザー | 開発者・上級ユーザー | すべてのユーザー |
| 操作方法 | ターミナルでコマンド実行 | 管理パネルで GUI 操作 |
| リアルタイム性 | ストリーム監視可能 | ログファイルに蓄積 |
| エクスポート | テキストコピー | JSONL / JSON ファイル出力 |
| フィルター | `--predicate` で条件指定 | テキスト検索・イベント種別選択 |

### 使い方

1. 管理パネルを開く（`Option+M`）
2. サイドバーの「ログ」タブを選択
3. フィルターバー右側のトグルでログ記録を有効にする
4. 問題を再現する（モニター切断、スリープ復帰など）
5. ログテーブルで記録されたイベントを確認する

### ログファイルの場所

```
~/Library/Application Support/Sobani/position_log.jsonl
```

### 開発者への共有方法

問題を報告する際は、ツールバーのエクスポートボタンから JSONL または JSON 形式で書き出したファイルを添付してください。ログには画像ファイル名やパスなどの個人情報は含まれません。

---

[← 目次](README.md)
