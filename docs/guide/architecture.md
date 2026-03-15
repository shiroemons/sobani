# アーキテクチャ

Sobani の内部構造を解説します。

[← 目次](README.md)

## 技術スタック

- Swift 6 / Cocoa (AppKit)
- macOS 13.0+
- 外部依存なし
- LSUIElement（ドックアイコンなし）

## コンポーネント関係図

```mermaid
classDiagram
    class AppDelegate {
        +characterWindows: [CharacterWindow]
        +zOrderedWindows: [CharacterWindow]
        +statusItem: NSStatusItem
        +screenRestorationManager: ScreenRestorationManager
        +wakeContext: WakeRestorationContext
        +setupStatusBar()
        +createNewWindow()
    }
    class CharacterWindow {
        +window: NSWindow
        +imageView: DraggableImageView
        +windowId: Int
        +delegate: CharacterWindowDelegate
    }
    class DraggableImageView {
        +isFlippedHorizontally: Bool
        +rotationAngle: CGFloat
        +opacityLevel: CGFloat
    }
    class AdjustmentPanelController {
        +delegate: AdjustmentPanelDelegate
    }
    class ImageManager {
        +shared: ImageManager
        +registerImage()
        +loadRegisteredImage()
        +removeRegisteredImage()
    }
    class WindowStateManager {
        +shared: WindowStateManager
        +saveStates()
        +loadStates()
    }
    class UpdateManager {
        +shared: UpdateManager
        +checkForUpdate()
    }
    class ScreenRestorationManager {
        +addPending()
        +restorableEntries()
    }
    class LanguageManager {
        +shared: LanguageManager
        +currentLanguage: Language
    }
    class LaunchAtLoginManager {
        +shared: LaunchAtLoginManager
        +isEnabled: Bool
        +toggle()
        +status: SMAppServiceStatus
    }
    class LayoutPresetManager {
        +shared: LayoutPresetManager
        +savePreset()
        +loadPreset()
        +deletePreset()
    }
    class UnconstrainedWindow {
        +constrainFrameRect()
    }
    class FloatingMenuController {
        +delegate: FloatingMenuDelegate
        +show(near:)
        +dismiss()
    }
    class CropEditorPanelController {
        +delegate: CropEditorPanelDelegate
        +currentCropRect: CropRect
        +history: CropEditHistory
        +show(image:near:)
        +dismiss()
    }
    class CropEditorCanvasView {
        +cropRect: CropRect
        +image: NSImage
    }
    class CropEditorToolbarView {
        +straightenMode: StraightenMode
        +toolbarMode: ToolbarMode
    }
    class CropEditHistory {
        +record(state:)
        +undo()
        +redo()
    }
    class CropRect {
        +x: CGFloat
        +y: CGFloat
        +width: CGFloat
        +height: CGFloat
        +straightenAngle: CGFloat
        +quarterTurns: Int
        +isFlippedInCrop: Bool
        +aspectRatioPreset: String?
        +verticalPerspective: CGFloat
        +horizontalPerspective: CGFloat
    }
    class AspectRatioSelectorView {
        +selectedPreset: AspectRatioPreset
    }
    class ManagementPanelController {
        +delegate: ManagementPanelDelegate
        +toggle()
        +show()
        +dismiss()
        +switchTab(tab:)
    }
    class HotkeyManager {
        +shared: HotkeyManager
        +binding(for:)
        +setBinding(_:for:)
        +resetBinding(for:)
        +resetAllBindings()
        +hasSystemConflict(_:)
        +hasSobaniConflict(_:excluding:)
    }

    AppDelegate --> CharacterWindow : manages
    AppDelegate ..|> CharacterWindowDelegate
    AppDelegate ..|> UpdateManagerDelegate
    AppDelegate ..|> NSMenuDelegate
    CharacterWindow --> DraggableImageView : contains
    CharacterWindow --> AdjustmentPanelController : opens
    CharacterWindow ..|> AdjustmentPanelDelegate
    CharacterWindow ..|> NSMenuDelegate
    AppDelegate --> ImageManager : uses
    AppDelegate --> WindowStateManager : uses
    AppDelegate --> UpdateManager : uses
    AppDelegate --> ScreenRestorationManager : owns
    AppDelegate --> LanguageManager : uses
    AppDelegate --> LaunchAtLoginManager : uses
    AppDelegate --> LayoutPresetManager : uses
    CharacterWindow --> UnconstrainedWindow : uses
    CharacterWindow --> FloatingMenuController : uses
    CharacterWindow --> CropEditorPanelController : uses
    CharacterWindow ..|> CropEditorPanelDelegate
    CharacterWindow ..|> FloatingMenuDelegate
    CropEditorPanelController --> CropEditorCanvasView : contains
    CropEditorPanelController --> CropEditorToolbarView : contains
    CropEditorPanelController --> CropEditHistory : uses
    CropEditorToolbarView --> AspectRatioSelectorView : contains
    AppDelegate --> ManagementPanelController : owns
    AppDelegate ..|> ManagementPanelDelegate
    ManagementPanelController --> HotkeyManager : uses
```

`AppDelegate` がアプリケーション全体を統括し、複数の `CharacterWindow` を管理します。各ウィンドウは `DraggableImageView` を内包し、調整パネルを通じて回転・不透明度の操作を受け付けます。シングルトンとして提供される各マネージャーは `AppDelegate` が利用し、それぞれの責務（画像管理・状態保存・アップデート・言語切り替え）を担います。

## ソースファイル一覧

| ファイル | 説明 |
|---|---|
| `main.swift` | エントリポイント。`LanguageManager` を UI ロード前に初期化 |
| `AlertFactory.swift` | アラートダイアログの生成ユーティリティ |
| `AppDelegate.swift` | アプリケーション全体の管理。ウィンドウライフサイクル、Z-order、ホットキー |
| `AppDelegate+LayoutPreset.swift` | レイアウトプリセット操作のAppDelegate拡張 |
| `AppDelegate+ScreenRestoration.swift` | モニター切断・スリープ/復帰時のウィンドウ位置復元 |
| `AppDelegate+Services.swift` | サービス初期化・管理のAppDelegate拡張 |
| `AppDelegate+StatusBarMenu.swift` | ステータスバーメニューの構築 |
| `AppDelegate+TestableLogic.swift` | テスト可能なビジネスロジックのAppDelegate拡張 |
| `AppSupportDirectory.swift` | Application Supportディレクトリ取得ユーティリティ（`AppSupportDirectory.url(baseDirectory:logger:)`） |
| `AspectRatioPreset.swift` | アスペクト比プリセットの定義（フリー・オリジナル・1:1・3:2・4:3・16:9等） |
| `AspectRatioSelectorView.swift` | アスペクト比プリセット選択UI（フリー・オリジナル・1:1・3:2・4:3・16:9等） |
| `AdjustmentPanelController.swift` | 回転ダイアル・不透明度スライダーのパネル |
| `BackgroundRemovalManager.swift` | Vision フレームワークによる背景除去（macOS 14以降、シングルトン） |
| `CharacterWindow.swift` | ボーダーレス透明ウィンドウ。`RotatableContainer`、コンテキストメニュー |
| `CharacterWindow+OtherSubmenu.swift` | 「その他」コンテキストサブメニューのCharacterWindow拡張 |
| `Constants.swift` | `AppConstants`、`GeometryUtils`、`MenuItemTag`、`L()` ヘルパー |
| `CropEditorPanelController.swift` | iPhone写真アプリ風クロップエディタのメインコントローラ。パネル管理、Undo/Redo、状態同期 |
| `CropEditorCanvasView.swift` | クロップエディタのキャンバス。画像描画、クロップ枠のハンドル操作、パン・ズーム |
| `CropEditorToolbarView.swift` | 補正モード切り替え（傾き・垂直パース・水平パース）、ルーラーダイヤル、アスペクト比セレクター |
| `CropEditHistory.swift` | クロップ編集のUndo/Redo履歴管理。線形スタック構造 |
| `CropGeometry.swift` | クロップ関連の幾何学計算ユーティリティ。座標変換、リサイズ制約、アスペクト比計算 |
| `CropImageProcessor.swift` | CropRectを実画像に適用する画像処理パイプライン（回転→反転→パース→傾き→クロップ） |
| `CropRect.swift` | クロップ状態の構造体（正規化0-1座標、回転・傾き・パース・反転・アスペクト比）。Codable対応 |
| `DragDropUtils.swift` | ドラッグ＆ドロップ操作のユーティリティ。ペーストボードから対応画像URLを抽出 |
| `DraggableImageView.swift` | ドラッグ移動、スクロールリサイズ、反転/回転/不透明度 |
| `FloatingMenuController.swift` | ダブルクリックで表示するSFシンボルアイコンのフローティングツールバー（NSPanel） |
| `HotkeyManager.swift` | ホットキーアクション・バインディング・マネージャーの定義。`UserDefaults` に JSON で保存。競合チェック機能を含む |
| `ImageManager.swift` | 画像の登録・読み込み・削除（シングルトン） |
| `ImagePreviewPanel.swift` | 画像プレビューパネル |
| `JSONPersistence.swift` | JSON永続化の共通ユーティリティ（アトミック書き込み、読み込み） |
| `LaunchAtLoginManager.swift` | ログイン時自動起動の管理（`SMAppService`、シングルトン） |
| `LanguageManager.swift` | ランタイム言語切り替え（シングルトン） |
| `LayoutPresetManager.swift` | レイアウトプリセットの保存・読み込み・削除を管理するシングルトン。`layouts/` ディレクトリにプリセットごとのJSONファイルを保存 |
| `ManagementPanelController.swift` | 管理パネルの生命周期・タブ切り替え・イベント監視（Lazy-init） |
| `ManagementPanelController+Setup.swift` | 管理パネルのサイドバー・コンテンツコンテナ・ステータスバー構築 |
| `ManagementPanelWindowListView.swift` | 管理パネルのウィンドウ管理タブ一覧ビュー |
| `ManagementPanelWindowListView+DragDrop.swift` | ウィンドウ一覧のドラッグ＆ドロップ並び替え拡張 |
| `ManagementPanelDetailView.swift` | 管理パネルのウィンドウ管理タブ詳細ビュー |
| `ManagementPanelLayoutView.swift` | 管理パネルのレイアウトタブ（プリセット一覧・操作） |
| `ManagementPanelLayoutView+Setup.swift` | レイアウトビューのUI構築拡張 |
| `ManagementPanelLayoutView+Cells.swift` | レイアウトビューのテーブルセル構築拡張 |
| `ManagementPanelSettingsView.swift` | 管理パネルの設定タブ（一般・ゴーストモード・外観・ホットキー） |
| `MenuStateUtils.swift` | メニュー状態管理のユーティリティ |
| `NSMenu+RegisteredImages.swift` | NSMenu拡張 — 登録画像メニュー項目の構築 |
| `NSPanel+FloatingConfig.swift` | NSPanel拡張 — フローティングパネルの共通設定 |
| `OnboardingManager.swift` | オンボーディング表示状態の管理（シングルトン） |
| `OnboardingWindowController.swift` | 初回起動時のオンボーディングガイド（3ステップ） |
| `PathSanitizer.swift` | パストラバーサル防止ユーティリティ（`safeURL(name:in:)`, `safeName(from:)`） |
| `ScreenRestorationManager.swift` | 復元待ちキューの管理（シングルトンではなく `AppDelegate` が所有）。`PendingRestoration` 構造体も同ファイルに定義 |
| `ScreenRestorationUtils.swift` | 画面復元関連のユーティリティ関数 |
| `SnapUtils.swift` | スナップ（吸着）関連のユーティリティ |
| `StraightenSliderView.swift` | iPhone風ルーラーダイヤル。慣性スクロール・フェードトレイルエフェクト対応 |
| `UnconstrainedWindow.swift` | `NSWindow` サブクラス。`constrainFrameRect` をオーバーライドし画面端制約を無効化。透過PNG画像のメニューバー越え配置を実現 |
| `UpdateManager.swift` | GitHub Releases 経由の自動アップデート（シングルトン） |
| `WakeRestorationContext.swift` | スリープ/復帰時の復元コンテキスト |
| `WindowStateManager.swift` | ウィンドウ状態の永続化（シングルトン） |
| `ZOrderUtils.swift` | Z-order配列操作ユーティリティ（`moveToFront`, `moveForward`, `moveBackward`, `moveToBack`, `nextId`） |

## シングルトン一覧

| シングルトン | 責務 |
|---|---|
| `ImageManager.shared` | ユーザー登録画像の管理（`~/Library/Application Support/Sobani/images/`） |
| `WindowStateManager.shared` | ウィンドウ状態の保存・読み込み（`window_states.json`） |
| `UpdateManager.shared` | GitHub Releases を利用した自動アップデートの確認・適用 |
| `LaunchAtLoginManager.shared` | `SMAppService` を通じたログイン時自動起動の切り替え |
| `LanguageManager.shared` | 日本語・英語・システム言語のランタイム切り替え |
| `LayoutPresetManager.shared` | レイアウトプリセットの保存・読み込み・削除（`layouts/` ディレクトリ） |
| `HotkeyManager.shared` | ホットキーバインディングの保存・読み込み・競合チェック（`UserDefaults` に JSON で保存） |

`ScreenRestorationManager` はシングルトンではなく、`AppDelegate` が所有するインスタンスです。

## プロトコル

### CharacterWindowDelegate

`CharacterWindow` と `AppDelegate` 間の通信を担うプロトコルです。`AppDelegate` が準拠します。

| メソッド | 用途 |
|---|---|
| `characterWindowRequestedNewWindow(_:imageName:)` | 新しいキャラクターウィンドウの生成を要求 |
| `characterWindowRequestedNewWindowWithFileURL(_:fileURL:)` | ファイル URL を指定した新しいウィンドウの生成を要求 |
| `characterWindowDidClose(_:)` | ウィンドウが閉じられたことを通知 |
| `characterWindowDidDeleteImage(named:)` | 画像が削除されたことを通知 |
| `characterWindowDidBecomeActive(_:)` | ウィンドウがアクティブになったことを通知（Z-order 管理） |

### AdjustmentPanelDelegate

`AdjustmentPanelController` と `CharacterWindow` 間の通信を担うプロトコルです。`CharacterWindow` が準拠します。

| メソッド | 用途 |
|---|---|
| `rotationPanel(_:didChangeAngle:)` | 回転ダイアルの角度変更を通知 |
| `rotationPanelDidReset(_:)` | 回転のリセットを通知 |
| `adjustmentPanel(_:didChangeOpacity:)` | 不透明度スライダーの変更を通知 |
| `adjustmentPanelDidResetOpacity(_:)` | 不透明度のリセットを通知 |

### FloatingMenuDelegate

`FloatingMenuController` から `CharacterWindow` へのボタンアクション通知を担うプロトコルです。`CharacterWindow` が準拠します。

| メソッド | 用途 |
|---|---|
| `floatingMenuDidRequestFlip(_:)` | 反転ボタンの押下を通知 |
| `floatingMenuDidRequestRotation(_:)` | 回転調整パネルの表示を要求 |
| `floatingMenuDidRequestCrop(_:)` | クロップエディタの表示を要求 |
| `floatingMenuDidSelectResetDisplay(_:)` | 表示をリセット（回転・反転・不透明度・切り取りを初期状態に戻す） |
| `floatingMenuDidRequestClose(_:)` | ウィンドウの閉じるを要求 |

### CropEditorPanelDelegate

`CropEditorPanelController` から `CharacterWindow` へクロップ編集結果を通知します。`CharacterWindow` が準拠します。

| メソッド | 用途 |
|---|---|
| `cropEditorDidConfirm(_:cropRect:)` | クロップ編集の確定を通知 |
| `cropEditorDidCancel(_:)` | クロップ編集のキャンセルを通知 |

### UpdateManagerDelegate

`UpdateManager` から `AppDelegate` へアップデート状態の変化を通知します。

| メソッド | 用途 |
|---|---|
| `updateManager(_:didChangeState:)` | アップデート状態の変化を通知 |

## アプリのライフサイクル

```mermaid
stateDiagram-v2
    [*] --> 初期化 : main.swift
    初期化 --> 起動完了 : applicationDidFinishLaunching
    起動完了 --> 実行中 : ウィンドウ復元
    実行中 --> スリープ : willSleep
    スリープ --> 実行中 : didWake → 復元処理
    実行中 --> 終了処理 : applicationWillTerminate
    終了処理 --> [*] : 状態保存完了

    state 初期化 {
        [*] --> LanguageManager初期化
        LanguageManager初期化 --> NSApplication作成
        NSApplication作成 --> AppDelegate設定
    }

    state 起動完了 {
        [*] --> ステータスバー作成
        ステータスバー作成 --> ホットキー登録
        ホットキー登録 --> ペンディングキュー読み込み
        ペンディングキュー読み込み --> 保存状態読み込み
        保存状態読み込み --> ウィンドウ生成
        ウィンドウ生成 --> アップデートチェック開始
        アップデートチェック開始 --> オブザーバー登録
    }

    state 終了処理 {
        [*] --> ウィンドウ状態保存
        ウィンドウ状態保存 --> ペンディング保存
        ペンディング保存 --> ホットキーモニター解除
        ホットキーモニター解除 --> オブザーバー解除
    }
```

起動時は `main.swift` で `LanguageManager` を初期化してから `NSApplication` を生成します。`applicationDidFinishLaunching` でステータスバー・ホットキーを設定し、`WindowStateManager` から前回の状態を読み込んでウィンドウを復元します。スリープ/復帰イベントは `AppDelegate+ScreenRestoration.swift` が処理し、モニター構成の変化に対応した三段階の復元を行います。終了時は全ウィンドウの状態を `window_states.json` に保存します。

## ウィンドウの構造

```mermaid
flowchart TD
    CW["CharacterWindow<br/>(NSObject)<br/>NSWindow を保持<br/>ボーダーレス・透明・常に最前面"]
    RC["RotatableContainer<br/>(NSView)<br/>回転時のバウンディングボックス調整"]
    DIV["DraggableImageView<br/>(NSImageView)<br/>ドラッグ・リサイズ・反転・回転・不透明度"]
    AP["AdjustmentPanelController<br/>(NSObject, NSPanel を保持)<br/>回転ダイアル・不透明度スライダー"]
    FM["FloatingMenuController<br/>(NSObject, NSPanel を保持)<br/>ダブルクリックで表示するツールバー"]
    CEP["CropEditorPanelController<br/>(NSObject, NSPanel を保持)<br/>iPhone風クロップエディタ・Undo/Redo"]
    CCV["CropEditorCanvasView<br/>(NSView)<br/>画像プレビュー・クロップ枠・パン/ズーム"]
    CTV["CropEditorToolbarView<br/>(NSView)<br/>補正ダイヤル・アスペクト比セレクター"]

    CW --> |contentView| RC
    RC --> |subview| DIV
    CW -.-> |opens| AP
    AP -.-> |AdjustmentPanelDelegate| CW
    CW -.-> |opens（ダブルクリック）| FM
    FM -.-> |FloatingMenuDelegate| CW
    CW -.-> |opens（切り取り時）| CEP
    CEP --> |contains| CCV
    CEP --> |contains| CTV
    CEP -.-> |CropEditorPanelDelegate| CW
```

`CharacterWindow` は `NSObject` のサブクラスで、`NSWindow` インスタンスをプロパティとして保持します。ウィンドウはボーダーレスかつ透明で、全 Space に表示される常に最前面のウィンドウです。`contentView` として `RotatableContainer` を設定し、その子ビューとして `DraggableImageView` が配置されます。

`RotatableContainer` は `CharacterWindow.swift` 内に定義された `private class` であり、外部からは参照できません。`CharacterWindow` のプロパティとしては保持されず、`init` 内でローカル変数として生成され `window.contentView` に設定されます。回転を適用した際に画像の領域が元の寸法を超えて拡大するため、バウンディングボックスを正しく計算・調整する役割を担います。`DraggableImageView` はマウスドラッグによる移動、スクロールホイールによるリサイズ、そして反転・回転・不透明度の状態を保持します。

`AdjustmentPanelController` は別の `NSPanel` として表示されるフローティングパネルで、`AdjustmentPanelDelegate` を通じて `CharacterWindow` に変更を伝えます。

## 管理パネル（ManagementPanel）

管理パネルは `⌥P`（デフォルト）で呼び出せるフローティングパネルで、ウィンドウ管理・レイアウト・設定の3つのタブを備えます。

### ファイル構成と役割

| ファイル | 説明 |
|---|---|
| `ManagementPanelController.swift` | パネルの生命周期・タブ切り替え・キーイベント監視 |
| `ManagementPanelController+Setup.swift` | サイドバー・コンテンツコンテナ・ステータスバーの構築 |
| `ManagementPanelWindowListView.swift` | ウィンドウ管理タブの一覧ビュー（表示・ゴーストモード・不透明度・並び替え） |
| `ManagementPanelWindowListView+DragDrop.swift` | ウィンドウ一覧のドラッグ＆ドロップによる並び替え拡張 |
| `ManagementPanelDetailView.swift` | ウィンドウ管理タブの詳細ビュー（個別ウィンドウ操作） |
| `ManagementPanelLayoutView.swift` | レイアウトタブ（プリセット一覧・詳細・保存・適用・削除） |
| `ManagementPanelLayoutView+Setup.swift` | レイアウトビューのUI構築拡張 |
| `ManagementPanelLayoutView+Cells.swift` | レイアウトビューのテーブルセル構築拡張 |
| `ManagementPanelSettingsView.swift` | 設定タブ（ログイン時起動・スナップ・ゴーストモードα・言語・テーマ・ホットキー） |

### ManagementPanelController のアーキテクチャ

- **Lazy-init**: `show()` が最初に呼ばれた時点で `setupPanel()` を実行し、`NSPanel` を遅延生成する
- **サイドバーナビ**: 左端のサイドバーにアイコンボタンを3つ配置し、選択中タブをアニメーション付きハイライトで示す
- **3タブ切替**: `switchTab(_:)` がコンテントコンテナの子ビューを入れ替え、各タブのビューを遅延生成する
- **イベント監視**: `NSEvent.addLocalMonitorForEvents` で ESC キーと管理パネルホットキーを監視し、パネルを閉じる
- **出現監視**: `NSApp.observe(\.effectiveAppearance)` でダーク/ライトモード切替時に accent color を更新する

```mermaid
flowchart TD
    MPC["ManagementPanelController<br/>（パネル統括）"]
    SB["サイドバー<br/>（3タブボタン）"]
    CC["コンテンツコンテナ<br/>（タブ切替領域）"]
    WLV["ManagementPanelWindowListView<br/>+ DetailView<br/>（ウィンドウ管理タブ）"]
    LV["ManagementPanelLayoutView<br/>（レイアウトタブ）"]
    SV["ManagementPanelSettingsView<br/>（設定タブ）"]
    DEL["ManagementPanelDelegate<br/>（AppDelegate）"]

    MPC --> SB
    MPC --> CC
    CC --> WLV
    CC --> LV
    CC --> SV
    MPC -.-> |委譲| DEL
```

### HotkeyManager の設計

| 特徴 | 詳細 |
|---|---|
| **キャッシュ** | 初期化時に全アクションのバインディングを `cache` ディクショナリに読み込み、`binding(for:)` はキャッシュから O(1) で返す |
| **Sendable** | `@unchecked Sendable` を宣言し、`UserDefaults`（スレッドセーフ）と `Logger`（Sendable）のみ保持 |
| **DI 対応** | `init(defaults: UserDefaults = .standard)` でテスト時に独立した `UserDefaults` スイートを注入できる |
| **競合チェック** | `hasSystemConflict(_:)` でシステム予約済みショートカット（⌘Space 等）を検出、`hasSobaniConflict(_:excluding:)` でアプリ内重複を検出 |

### ManagementPanelDelegate によるAppDelegateとの通信パターン

`ManagementPanelDelegate` は `@MainActor` プロトコルとして宣言され、`AppDelegate` が準拠します。管理パネルからの操作要求はすべてこの delegate を通じて `AppDelegate` に委譲されます。

| メソッド | 用途 |
|---|---|
| `managementPanel(_:didToggleVisibility:)` | ウィンドウの表示/非表示トグルを要求 |
| `managementPanel(_:didToggleGhostMode:)` | ウィンドウのゴーストモードトグルを要求 |
| `managementPanel(_:didChangeOpacity:for:)` | 不透明度変更を通知 |
| `managementPanel(_:didReorderWindow:to:)` | Z-order 変更を要求 |
| `managementPanelDidRequestShowAll(_:)` | 全ウィンドウの表示を要求 |
| `managementPanelDidRequestHideAll(_:)` | 全ウィンドウの非表示を要求 |
| `managementPanelDidRequestGhostAll(_:)` | 全ウィンドウのゴーストモード有効化を要求 |
| `managementPanelDidRequestUnghostAll(_:)` | 全ウィンドウのゴーストモード解除を要求 |
| `managementPanel(_:didRequestApplyLayout:)` | レイアウトプリセットの適用を要求 |
| `managementPanel(_:didRequestSaveLayoutWithName:)` | レイアウトプリセットの保存を要求 |
| `managementPanelDidRequestCreateNewLayout(_:)` | 新しいレイアウトプリセット作成を要求 |
| `managementPanel(_:didRequestUpdateLayout:)` | レイアウトプリセットの上書き更新を要求 |
| `managementPanel(_:didRequestDeleteLayout:)` | レイアウトプリセットの削除を要求 |
| `managementPanel(_:didRequestRenameLayout:to:)` | レイアウトプリセットのリネームを要求 |
| `managementPanelDidChangeHotkey(_:)` | ホットキー変更後の再登録を要求 |
| `managementPanelDidDismiss(_:)` | パネルが閉じられたことを通知 |

## ゴーストモード

ゴーストモード（`ignoresMouseEvents = true`）はウィンドウをクリックスルーにする機能です。有効時はウィンドウの`imageView`に不透明度（デフォルト0.3）を適用し、ホバー時の枠線は不透明を維持します。

- **状態管理**: `CharacterWindow` が `isGhostMode` と `customGhostAlpha` をプロパティとして保持
- **永続化**: `WindowState` 構造体の `isGhostMode`/`customGhostAlpha` フィールドで `window_states.json` に保存
- **グローバル設定**: `UserDefaults` に `ghostAlpha` キーでグローバルデフォルト不透明度を保存
- **トグル方法**: Option+G グローバルホットキー、右クリックメニュー、フローティングメニュー、ステータスバーメニュー

[← 目次](README.md)
