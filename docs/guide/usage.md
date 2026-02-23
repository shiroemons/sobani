[目次](README.md)

# 操作ガイド

Sobani の操作方法をビジュアルに解説します。

---

## 起動の流れ

アプリを起動すると、メニューバーにアイコンが表示されます。前回の状態が保存されている場合はそれを復元し、初回起動時はデフォルト画像でウィンドウが表示されます。

```mermaid
flowchart TD
    A[Sobani.app を起動] --> B[メニューバーにアイコン表示]
    B --> C{前回の状態が存在する?}
    C -- はい --> D[ウィンドウ状態を復元\n位置・サイズ・画像・向き・透明度]
    C -- いいえ --> E[デフォルト画像でウィンドウを表示]
    D --> F[操作可能な状態]
    E --> F
```

---

## メニュー構造

### 図A: ステータスバーメニュー構造

メニューバーのアイコンをクリックすると、以下の構造のメニューが表示されます。

```mermaid
flowchart TD
    ICON[メニューバーアイコン] --> ABOUT[Sobaniについて]
    ICON --> UPDATE[アップデートを確認]
    ICON --> LOGIN[ログイン時に起動 ✓]
    ICON --> SEP1[---]
    ICON --> WINDOWS[表示中: X体]
    WINDOWS --> WIN_LIST[ウィンドウ一覧\nZオーダー順]
    WIN_LIST --> WIN_ACTIONS[各ウィンドウの操作]
    WIN_ACTIONS --> LAYER[重ね順変更]
    WIN_ACTIONS --> FLIP[左右反転]
    WIN_ACTIONS --> ADJUST[調整パネル]
    WIN_ACTIONS --> RESET[リセット]
    WIN_ACTIONS --> CLOSE_ONE[閉じる]
    ICON --> SEP2[---]
    ICON --> FRONT[すべて手前に表示]
    ICON --> TOGGLE[すべて非表示 / すべて表示]
    ICON --> RESET_ROT[すべての回転をリセット]
    ICON --> RESET_OPA[すべての透明度をリセット]
    ICON --> SEP3[---]
    ICON --> ADD[画像を追加表示]
    ADD --> ADD_FILE[画像を選択して追加]
    ADD --> ADD_DEFAULT[デフォルト]
    ADD --> ADD_REG[登録画像...]
    ICON --> CLOSE_ALL[すべて閉じる]
    ICON --> SEP4[---]
    ICON --> CHANGE_DEFAULT[デフォルト画像を変更]
    ICON --> RESET_DEFAULT[デフォルト画像をリセット]
    ICON --> SEP5[---]
    ICON --> LANG[言語]
    LANG --> LANG_SYS[システム言語を使う]
    LANG --> LANG_JA[日本語]
    LANG --> LANG_EN[English]
    ICON --> SEP6[---]
    ICON --> QUIT[終了]
```

### 図B: 右クリックメニュー構造

キャラクターウィンドウを右クリックすると、以下の構造のコンテキストメニューが表示されます。

```mermaid
flowchart TD
    RC[右クリック] --> CHANGE[表示画像の変更]
    CHANGE --> CHANGE_FILE[画像を変更...]
    CHANGE --> CHANGE_DEFAULT[デフォルトに戻す]
    CHANGE --> CHANGE_REG[登録画像...]

    RC --> ADD[画像を追加表示]
    ADD --> ADD_FILE[画像を選択して追加]
    ADD --> ADD_DEFAULT[デフォルト]
    ADD --> ADD_REG[登録画像...]

    RC --> DELETE[登録画像を削除]
    DELETE --> DELETE_REG[登録画像...]

    RC --> VIEW[表示の調整]
    VIEW --> FLIP[左右反転]
    VIEW --> PANEL[調整パネルを開く]
    VIEW --> RESET_ROT[回転をリセット]
    VIEW --> RESET_OPA[透明度をリセット]
    VIEW --> RESET_ALL[表示をリセット]

    RC --> CLOSE[この画像を閉じる]
    RC --> QUIT[終了]
```

---

## 画像管理の流れ

Sobani では、PNG・JPEG・GIF・TIFF・HEIC 形式の画像を登録して使用できます。登録した画像は `~/Library/Application Support/Sobani/images/` に保存され、アプリを再起動しても引き続き利用できます。

### 図C: 画像の登録から表示までの流れ

```mermaid
flowchart LR
    A[画像を選択\nファイル選択ダイアログ] --> B{拡張子チェック\nPNG/JPEG/GIF\nTIFF/HEIC}
    B -- 非対応形式 --> Z[エラー: 対応外の形式]
    B -- 対応形式 --> C{同名ファイルが\n存在する?}
    C -- はい --> D[ファイルをリネーム\n例: image_1.png]
    C -- いいえ --> E[そのままコピー]
    D --> F[~/Library/Application Support\n/Sobani/images/ に保存]
    E --> F
    F --> G[ウィンドウに表示]
    G --> H[メニューに登録画像として追加]
```

登録済みの画像はステータスバーメニューおよび右クリックメニューの「登録画像」サブメニューから選択できます。不要になった画像は右クリックメニューの「登録画像を削除」から削除できます。

---

## 調整パネル

調整パネルでは、キャラクターの回転角度と透明度を細かく調整できます。

- **回転ダイアル**: 0°〜360° の範囲でドラッグ操作により回転を指定します。5° 単位でスナップします。
- **透明度スライダー**: 10%〜100% の範囲で透明度を調整します。

調整パネルはステータスバーメニューの「表示中」サブメニュー内の各ウィンドウ操作、または右クリックメニューの「表示の調整 → 調整パネルを開く」から起動できます。

---

## キーボードショートカット

| キー | 動作 |
|------|------|
| `d` | デフォルト画像に戻す |
| `o` | 画像を変更 |
| `n` | 新しいウィンドウを開く |
| `w` | ウィンドウを閉じる |
| `f` | すべて手前に表示 |
| `Option+H` | 表示/非表示切り替え |
| `q` | 終了 |

---

[目次](README.md)
