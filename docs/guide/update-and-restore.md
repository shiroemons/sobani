# アップデートと画面復元

自動アップデートの仕組みとモニター切断・スリープ時のウィンドウ位置復元を解説します。

[← 目次](README.md)

---

## 自動アップデート

### 概要

Sparkle フレームワーク（`SPUUpdater`）によるセキュアな自動アップデート機能。EdDSA 署名検証により安全性を確保。

### チェックタイミング

| トリガー | 発火タイミング | 動作 |
|---|---|---|
| 起動時 | アプリ起動直後（`SULastCheckTime` をリセットして即時チェック） | 更新があればダイアログを即座に表示。なければ通知なし |
| 自動 | 24時間間隔（`SUScheduledCheckInterval: 86400`） | バックグラウンドで確認し、更新があればダイアログを即座に表示 |
| 手動 | メニューバー「更新を確認...」または管理パネル Settings タブ | Sparkle の標準ダイアログでユーザーに通知（最新版でもダイアログ表示） |

### アップデートフロー

```mermaid
sequenceDiagram
    participant App as Sobani
    participant SM as SparkleManager
    participant SPU as SPUUpdater
    participant Feed as appcast.xml
    participant UI as ユーザー

    Note over App,Feed: チェック
    App->>SM: checkForUpdates() / 自動チェック
    SM->>SPU: checkForUpdates()
    SPU->>Feed: GET appcast.xml
    Feed-->>SPU: リリース情報
    SPU->>SPU: バージョン比較 + EdDSA 署名検証

    alt 新バージョンあり
        SPU->>UI: 更新ダイアログ表示
        UI->>SPU: 「インストールして再起動」
        SPU->>SPU: ダウンロード + 署名検証
        SPU->>App: willInstallUpdate
        SM->>SM: isInstallingUpdate = true
        SPU->>App: アプリ終了 + 新バージョン起動
    else 最新版
        SPU->>UI: 最新版ダイアログ（手動時のみ）
    end
```

### セキュリティ

- すべてのアップデートは EdDSA（Ed25519）署名で検証される
- 公開鍵は `Info.plist` の `SUPublicEDKey` に埋め込み
- 署名が一致しないアップデートは自動的に拒否される

### アプリ終了との統合

- `SparkleManager.isInstallingUpdate` フラグにより、Sparkle がアップデートをインストール中であることを `AppDelegate.applicationShouldTerminate` に伝達
- 通常の終了ガード（`terminateCancel`）をバイパスし、Sparkle によるアプリ再起動を許可

### LSUIElement アプリでの前面表示

Sobani は `LSUIElement`（Dock アイコンなし）アプリのため、Sparkle のダイアログがバックグラウンドに表示されてしまう問題があります。これに対応するため、`SPUStandardUserDriverDelegate` で以下の制御を行っています:

- **ダイアログ表示前**: `NSApp.setActivationPolicy(.regular)` で一時的に Dock アイコンを表示し、`NSApp.activate(ignoringOtherApps: true)` でアプリを前面化
- **セッション終了後**: `NSApp.setActivationPolicy(.accessory)` で Dock アイコンを非表示に復元

### 設定値（Info.plist）

| キー | 値 | 説明 |
|---|---|---|
| `SUFeedURL` | `https://xn--xckxf.jp/sobani/appcast.xml` | アップキャストフィードの URL |
| `SUPublicEDKey` | `1AdG0un/J5hcpoyPEKw7/M4U/oA5mLZ8j6K9+xFtFpg=` | EdDSA 公開鍵 |
| `SUEnableAutomaticChecks` | `true` | 自動チェックの有効化 |
| `SUScheduledCheckInterval` | `86400` | チェック間隔（秒）= 24時間 |
| `SUAutomaticallyUpdate` | `false` | ダイアログなしの自動インストールを無効化 |

---

## 画面復元

モニターの切断やスリープ/復帰が発生した際に、ウィンドウの位置を自動的に復元する仕組みです。3つのフェーズに加え、ディスプレイスリープ（`willSleepNotification` が発火しないケース）にも対応するスナップショット機構を備えています。

macOS のネイティブウィンドウ復元（`NSWindow.isRestorable`）は無効化されており、Sobani 独自の復元ロジックが全ての画面復元を担います。

### 3フェーズの概要

```mermaid
flowchart TD
    Event{"イベント発生"}

    Event -->|"NSApplication<br/>didChangeScreenParameters"| P0
    Event -->|"NSWorkspace<br/>willSleep"| P1S
    Event -->|"NSWorkspace<br/>didWake"| P1W
    Event -->|"imageWindowState<br/>DidChange"| SNAP["updateScreenSnapshot<br/>(0.3秒デバウンス)"]
    SNAP --> SNAPSTORE["screenSnapshot に保存"]

    subgraph Phase0["Phase 0: モニター切断 / ディスプレイスリープ"]
        P0["handleScreenChange"]
        P0RACE{"wakeContext.states<br/>非空 & !isActive?"}
        P0SNAP{"screenSnapshot<br/>にスクリーン減少?"}
        P0CHK{"wakeContext<br/>.isActive?"}
        P0VIS{"各ウィンドウ<br/>画面内?"}
        P0MOVE["メイン画面に移動<br/>+ addPending"]
        P0REST{"ペンディングに<br/>復元可能なもの?"}
        P0OK["元の位置に復元<br/>+ removePending"]

        P0 --> P0RACE
        P0RACE -->|"Yes (レース条件)"| P0ACTIVATE["wakeContext.isActive = true"]
        P0RACE -->|No| P0SNAP
        P0SNAP -->|"Yes (ディスプレイスリープ)"| P0COPY["screenSnapshot → wakeContext<br/>isActive = true"]
        P0SNAP -->|No| P0CHK
        P0ACTIVATE --> P0CHK
        P0COPY --> P0CHK
        P0CHK -->|Yes| P0SKIP["1.5秒デバウンスで<br/>attemptWakeRestoration() を実行"]
        P0CHK -->|No| P0VIS
        P0VIS -->|画面内| P0SKIP2["変更なし"]
        P0VIS -->|画面外| P0MOVE
        P0MOVE --> P0REST
        P0REST -->|あり| P0OK
        P0REST -->|なし| P0WAIT["キュー待機<br/>(300秒で期限切れ)"]
    end

    subgraph Phase1["Phase 1: スリープ/復帰"]
        P1S["handleWillSleep<br/>captureWindowStates() で<br/>全ウィンドウの状態保存"]
        P1W["handleDidWake<br/>3秒後に復元開始"]
        P1FIND{"保存時の<br/>モニター検索"}
        P1ID["displayID 一致"]
        P1GEO["geometry フォールバック<br/>(100px 許容差)"]
        P1RESTORE["相対座標で復元<br/>+ クランプ"]
        P1RETRY{"リトライ<br/>(最大10回<br/>3秒間隔)"}
        P1PENDING["未復元 →<br/>ペンディングキューへ"]

        P1S --> P1W
        P1W --> P1FIND
        P1FIND --> P1ID
        P1FIND --> P1GEO
        P1ID --> P1RESTORE
        P1GEO --> P1RESTORE
        P1FIND -->|未検出| P1RETRY
        P1RETRY -->|再試行| P1FIND
        P1RETRY -->|上限到達| P1PENDING
    end

    P1PENDING --> P0
```

### Phase 0: モニター切断 / ディスプレイスリープ

`NSApplication.didChangeScreenParametersNotification` を受信したとき、`handleScreenChange` はまず以下の2つのチェックを行います:

1. **レース条件チェック**: `wakeContext.states` が非空（`handleWillSleep` が保存済み）かつ `wakeContext.isActive` が `false`（`handleDidWake` 未着）の場合、ウェイクモードを有効化します。これは `willSleepNotification`（`NSWorkspace.notificationCenter`）と `didChangeScreenParametersNotification`（`NotificationCenter.default`）が異なる通知センターから配信されるため、配信順序が保証されないことへの対策です。
2. **スナップショットチェック**: `wakeContext` が空で、`screenSnapshot` に保存されたスクリーン構成と比較してスクリーンが減少している場合、スナップショットから `wakeContext` に復元データをコピーしてウェイクモードを有効化します。これによりホットコーナー等によるディスプレイスリープ（`willSleepNotification` が発火しない）にも対応します。

ウェイクモードが有効化された場合はデバウンス（1.5秒）後に `attemptWakeRestoration()` が呼び出され、Phase 1 と同じ復元ロジックが実行されます。

ウェイクモードが有効でない場合は、デバウンス（1秒）後に `attemptPendingRestorations()` を呼び出し、以下を実行します:

1. 全ウィンドウの位置を確認し、いずれかの画面内に収まっているか検査します。
   - 画面外のウィンドウ → メイン画面の表示可能領域に移動し、`displayID: 0` としてペンディングキューに追加します。
2. 既存のペンディングキューを確認し、元のモニターが再接続されている場合は元の位置に復元して `removePending` します。

### Phase 1: スリープ/復帰

**スリープ前 (`handleWillSleep`):**

- ペンディングキューと `wakeContext` をクリアします。
- `captureWindowStates()` で全ウィンドウの現在の状態（位置・サイズ・`displayID`・画面フレーム・ウィンドウの生の origin（captureState の座標変換を回避））をキャプチャし、`wakeContext` に保存します。

**復帰後 (`handleDidWake`):**

- `wakeContext.isActive = true`、`retryCount = 0` に設定します。
- 3秒の遅延後に `attemptWakeRestoration` を開始します（macOS がモニターを再認識する時間を確保するため）。
- 各ウィンドウについて、スリープ前に記録した `displayID` と一致するモニターを検索します。
  - **displayID 一致**: そのモニター上の相対座標で復元し、画面内にクランプします。
  - **geometry フォールバック**: `displayID` が一致しない場合、スクリーンフレームの位置を 100px の許容差で比較し、最も近いモニターに復元します。
  - **未検出**: リトライキューに入れます。
- リトライは最大10回、3秒間隔で実行されます。
- 最初の2回（インクリメント後の retryCount ≤ 2）は成功しても、macOS の自動移動に対抗するための追加リトライも実行します。
- 最大リトライ回数に達した後も未復元のウィンドウは `moveUnrestoredToPendingQueue` でペンディングキューに移行し、`wakeContext` をクリアします。

### Phase 2: モニター再接続（ペンディングキュー）

`ScreenRestorationManager` がペンディング状態のウィンドウ情報を `pending_restorations.json` に永続化します。

| 項目 | 内容 |
|---|---|
| 保存場所 | `~/Library/Application Support/Sobani/pending_restorations.json` |
| タイムアウト | 300秒（期限切れエントリは自動削除） |
| 復元条件 | `displayID` の一致、または保存時の画面フレームとの geometry マッチ。`displayID` が 0 の場合は元の位置が画面上に表示可能かで判定 |

**`PendingRestoration` の主なフィールド:**

```swift
struct PendingRestoration: Codable {
    let windowId: Int
    let originalState: WindowState
    let displayID: CGDirectDisplayID
    let adjustedOriginX: CGFloat
    let adjustedOriginY: CGFloat
    let createdAt: Date
    let screenFrameX: CGFloat?
    let screenFrameY: CGFloat?
    let screenFrameWidth: CGFloat?
    let screenFrameHeight: CGFloat?
}
```

`restorableEntries()` を呼び出すと、期限切れエントリを除去した上で、現在接続されているモニターと `displayID` または geometry が一致するエントリを返します。一致したエントリは元の位置に復元され、`removePending` でキューから削除されます。

### スナップショット機構

`willSleepNotification` が発火しないケース（ホットコーナーによるディスプレイスリープ等）に対応するため、ウィンドウ位置をプロアクティブに保存する仕組みです。

**保存タイミング:**

- `imageWindowStateDidChange` / `imageWindowListDidChange` 通知を受信したとき（0.3秒デバウンス付き）
- アプリ起動完了時（`applicationDidFinishLaunching`）

**保存先:** `AppDelegate.screenSnapshot`（`WakeRestorationContext` 型、メモリ内のみ）

**保存内容:** `captureWindowStates()` で `handleWillSleep` と同一の情報（全ウィンドウの `WindowState`・生の origin・`displayID`・画面フレーム）をキャプチャします。

**復元中のガード:** `wakeContext.isActive` が `true` のとき（復元処理中）はスナップショットを更新しません。macOS が一時的に移動したウィンドウの位置を保存しないためです。

**使用タイミング:** `handleScreenChange` でスクリーン減少を検知し、`wakeContext` が空の場合に `screenSnapshot` から `wakeContext` にコピーしてウェイクモードを有効化します。

---

[← 目次](README.md)
