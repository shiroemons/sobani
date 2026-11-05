import Cocoa
import os.log
import UniformTypeIdentifiers

/// Localization helper that supports runtime language switching via LanguageManager.
/// Falls back to NSLocalizedString with the main bundle when no custom bundle is set.
/// スレッドセーフ: 任意のスレッドから呼び出し可能。
func L(_ key: String) -> String {
    if let bundle = sharedLocalizationBundle {
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    return NSLocalizedString(key, comment: "")
}

struct ScreenInfo: Sendable {
    let frame: NSRect
    let displayID: CGDirectDisplayID
    let isMain: Bool
    /// 再起動をまたいでも変わらないディスプレイ識別子（`displayID` は再起動で変わる）。
    let displayUUID: String?

    init(frame: NSRect, displayID: CGDirectDisplayID, isMain: Bool, displayUUID: String? = nil) {
        self.frame = frame
        self.displayID = displayID
        self.isMain = isMain
        self.displayUUID = displayUUID
    }

    @MainActor
    static func current() -> [Self] {
        NSScreen.screens.map { screen in
            Self(
                frame: screen.frame,
                displayID: screen.displayID ?? AppConstants.unknownDisplayID,
                isMain: screen == NSScreen.main,
                displayUUID: screen.displayUUID
            )
        }
    }

    static func mainFrame(from screens: [Self]) -> NSRect {
        screens.first(where: { $0.isMain })?.frame
            ?? screens.first?.frame
            ?? NSRect(origin: .zero, size: AppConstants.fallbackScreenSize)
    }
}

enum AppConstants {
    // App Identity
    static let appName = "Sobani"
    static let loggerSubsystem = "com.shiroemons.Sobani"

    static let defaultImageName = "default"

    // Window
    static let defaultWindowHeight: CGFloat = 600
    static let minImageHeight: CGFloat = 100
    static let maxImageHeight: CGFloat = 6000
    static let windowSpawnRandomOffset: CGFloat = 100
    static let scrollScaleSensitivity: CGFloat = 0.01
    static let dialScrollSensitivity: CGFloat = 0.5

    // Screen Restoration
    static let screenChangeDebounceInterval: TimeInterval = 1.0
    static let wakeDebounceInterval: TimeInterval = 1.5
    static let wakeInitialDelay: TimeInterval = 3.0
    static let wakeDetectDriftThreshold: CGFloat = 1.0
    static let screenMatchTolerance: CGFloat = 100
    static let screenIntersectionThreshold: CGFloat = 50

    // Fallback
    static let fallbackScreenSize = NSSize(width: 1920, height: 1080)
    static let fallbackScreenHeight: CGFloat = 900

    // Floating-point comparison
    static let floatingPointTolerance: CGFloat = 0.01
    /// 0〜1 に正規化された座標（`CropRect` 等）同士の比較に使う許容誤差。
    /// `floatingPointTolerance`（0.01）は正規化座標では画像の 1% に相当し粗すぎるため別に持つ。
    static let normalizedTolerance: CGFloat = 1e-4

    // Hit Test
    /// 透過ピクセル判定のしきい値。alpha 値がこの値未満ならクリックスルーする。
    static let hitTestAlphaThreshold: UInt8 = 16

    // Hotkey
    static let optionHKeyCode: UInt16 = 4
    static let optionMKeyCode: UInt16 = 46    // Option + M (管理パネル切り替え)
    static let escKeyCode: UInt16 = 53
    static let hotkeySignature: FourCharCode = 0x534F424E  // "SOBN"

    // Display ID
    static let unknownDisplayID: CGDirectDisplayID = 0
    static let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

    // Status Bar
    static let statusBarIconSize: CGFloat = 18

    // Menu
    static let menuWindowMinWidth: CGFloat = 10
    static let menuIconPointSize: CGFloat = 14

    // Image Preview Panel
    static let previewMaxDimension: CGFloat = 256
    static let previewGap: CGFloat = 6
    static let previewFallbackMouseOffset: CGFloat = 20
    static let menuTabPadding: CGFloat = 16
    static let layoutDialogFieldWidth: CGFloat = 260
    static let layoutDialogFieldHeight: CGFloat = 24

    // Screen Restoration (追加)
    static let wakeRetryCountThreshold = 2
    static let wakeRetryMaxAttempts = 10
    static let wakeRetryInterval: TimeInterval = 3.0

    // Launch Restoration
    /// 起動後、ディスプレイ構成の変化に追従してアンカー位置を再適用し続ける期間（ログイン直後の
    /// 外部ディスプレイ認識遅延・プライマリ入れ替わりに対応）
    static let launchRestoreWindow: TimeInterval = 120

    // Persistence
    /// ウィンドウ状態変更から `window_states.json` へ保存するまでのデバウンス間隔
    static let statePersistDebounceInterval: TimeInterval = 1.0
    /// 画面構成変更の直後は macOS がウィンドウを一時退避している可能性があるため保存を見送る期間
    static let statePersistScreenSettleInterval: TimeInterval = 10
    /// 登録できる画像の縦横それぞれの最大ピクセル数（巨大画像のデコードでメモリを使い果たさないため）
    static let maxImagePixelDimension = 16_384
    /// 登録できる画像の総ピクセル数の上限（約 1.3 億ピクセル。RGBA で約 512MB）
    static let maxImagePixelCount = 128 * 1_024 * 1_024
    /// サービス（「Sobani で表示」）1 回の呼び出しで開く画像の最大数（大量のウィンドウ生成を防ぐ）
    static let maxServiceImageCount = 20

    // Opacity
    static let opacityMin: CGFloat = 0.1
    static let opacityMax: CGFloat = 1.0

    // Ghost Mode
    static let ghostModeAlphaDefault: CGFloat = 0.3
    static let ghostModeAlphaMin: CGFloat = 0.1
    static let ghostModeAlphaMax: CGFloat = 0.9
    static let ghostModeAlphaKey = "ghostModeAlpha"
    static let ghostModeAnimationDuration: TimeInterval = 0.3
    static let optionGKeyCode: UInt16 = 5
    static let ghostModeSymbol = "face.dashed"
    static let normalModeSymbol = "face.smiling"
    static let hiddenWindowSymbol = "eye.slash"
    static let visibleWindowSymbol = "eye"
    static let opacitySymbol = "circle.lefthalf.filled"
    static let themeSystemSymbol = "circle.lefthalf.filled"
    static let themeLightSymbol = "sun.max"
    static let themeDarkSymbol = "moon"
    static let themeParentSymbol = "paintbrush"
    static let resetSymbol = "arrow.counterclockwise.circle"
    static let closeSymbol = "xmark.circle"
    static let changeImageSymbol = "photo.on.rectangle"

    // Ghost Mode Slider Layout
    static let ghostAlphaSliderContainerWidth: CGFloat = 260
    static let ghostAlphaSliderContainerHeight: CGFloat = 28
    static let ghostAlphaSliderPercentWidth: CGFloat = 45
    static let ghostAlphaSliderHeight: CGFloat = 21
    static let ghostAlphaSliderTrailingMargin: CGFloat = 8

    // Ghost Alpha Slider Checkbox Layout
    static let ghostAlphaCheckboxX: CGFloat = 32
    static let ghostAlphaCheckboxSize: CGFloat = 18
    static let ghostAlphaCheckboxTrailingGap: CGFloat = 22

    // Crop
    static let cropHandleSize: CGFloat = 8
    static let cropMinProportion: CGFloat = 0.1
    static let cropOverlayAlpha: CGFloat = 0.5

    // Crop Editor
    static let cropEditorPanelWidth: CGFloat = 480
    static let cropEditorPanelHeight: CGFloat = 648
    static let cropEditorTopBarHeight: CGFloat = 90
    static let cropEditorToolbarHeight: CGFloat = 130
    static let cropEditorLastToolbarModeKey = "cropEditorLastToolbarMode"
    static let cropEditorCanvasPadding: CGFloat = 20
    static let cropEditorCanvasGap: CGFloat = 4
    static let cropEditorHandleLength: CGFloat = 20
    static let cropEditorHandleThickness: CGFloat = 3
    static let cropEditorGridLineWidth: CGFloat = 0.5
    static let cropEditorOverlayAlpha: CGFloat = 0.6

    // Top bar pill buttons
    static let cropEditorPillButtonSize: CGFloat = 36
    static let cropEditorPillCornerRadius: CGFloat = 18

    // Crop Editor - Apple-style colors
    static let cropEditorToolbarBackgroundLight: CGFloat = 0.98
    static let cropEditorToolbarBackgroundDark: CGFloat = 0.18
    static let cropEditorPillBackgroundDarkAlpha: CGFloat = 0.2
    static let cropEditorModeButtonSelectedDarkAlpha: CGFloat = 0.15

    // Ruler dial
    static let cropEditorRulerHeight: CGFloat = 36
    static let cropEditorRulerTickSpacing: CGFloat = 6

    // Straighten Slider
    static let straightenMinAngle: CGFloat = -45
    static let straightenMaxAngle: CGFloat = 45
    static let straightenMajorTickInterval: CGFloat = 15
    static let straightenMinorTickInterval: CGFloat = 5
    static let straightenZeroSnapThreshold: CGFloat = 1.0
    static let straightenScrollSensitivity: CGFloat = 0.5
    static let straightenInertiaDecayRate: CGFloat = 0.95
    static let straightenInertiaMinVelocity: CGFloat = 0.1
    static let straightenInertiaFrameInterval: TimeInterval = 1.0 / 60.0

    // Straighten Slider - Fade Trail
    static let straightenFadeDuration: CGFloat = 0.5
    static let straightenFadeHighlightHeight: CGFloat = 18
    static let straightenFadeHighlightWidth: CGFloat = 1.5

    // Selector View (shared by AspectRatio and CropShape selectors)
    static let selectorButtonSpacing: CGFloat = 8
    static let selectorCornerRadius: CGFloat = 6
    static let selectorSelectedAlpha: CGFloat = 0.1

    // Crop Shape
    static let cornerRadiusHandleSize: CGFloat = 8
    static let cornerRadiusHandleHitTolerance: CGFloat = 14
    static let cornerRadiusMin: CGFloat = 0.0
    static let cornerRadiusMax: CGFloat = 1.0
    static let cornerRadiusDefault: CGFloat = 0.3
    static let shapeButtonSize: CGFloat = 28

    // UserDefaults Keys
    static let appLanguageKey = "AppLanguage"
    static let appThemeKey = "AppTheme"
    static let appleLanguagesKey = "AppleLanguages"

    // Hotkey Settings
    static let hotkeyEnabledKey = "hotkeyEnabled"
    static let hotkeyToggleVisibilityKeyCodeKey = "hotkeyToggleVisibilityKeyCode"
    static let hotkeyToggleVisibilityModifiersKey = "hotkeyToggleVisibilityModifiers"
    static let hotkeyToggleGhostModeKeyCodeKey = "hotkeyToggleGhostModeKeyCode"
    static let hotkeyToggleGhostModeModifiersKey = "hotkeyToggleGhostModeModifiers"
    static let hotkeyToggleManagementKeyCodeKey = "hotkeyToggleManagementKeyCode"
    static let hotkeyToggleManagementModifiersKey = "hotkeyToggleManagementModifiers"
    static let hotkeyToggleScreenVisKeyCodeKey = "hotkeyToggleScreenVisKeyCode"
    static let hotkeyToggleScreenVisModifiersKey = "hotkeyToggleScreenVisModifiers"
    static let hotkeyToggleScreenGhostKeyCodeKey = "hotkeyToggleScreenGhostKeyCode"
    static let hotkeyToggleScreenGhostModifiersKey = "hotkeyToggleScreenGhostModifiers"

    // Window Snap
    static let snapThreshold: CGFloat = 8
    static let snapEnabledKey = "windowSnapEnabled"

    // Position Log
    static let positionLogEnabledKey = "positionLogEnabled"

    // Floating Menu
    static let floatingMenuButtonSize: CGFloat = 36
    static let floatingMenuColumnWidth: CGFloat = 50
    static let floatingMenuPadding: CGFloat = 8
    static let floatingMenuGap: CGFloat = 4
    static let floatingMenuCornerRadius: CGFloat = 10

    // Floating Menu Opacity Slider
    static let floatingMenuSliderRowHeight: CGFloat = 28
    static let floatingMenuSeparatorHeight: CGFloat = 1

    // Menu Opacity Slider (two-line layout)
    static let opacitySliderContainerHeight: CGFloat = 44
    static let opacitySliderTopRowHeight: CGFloat = 20

    // Onboarding
    enum Onboarding {
        static let width: CGFloat = 520
        static let height: CGFloat = 480
        static let currentVersion = 2
        static let completedVersionKey = "onboardingCompletedVersion"
    }

    // Management Panel
    static let managementPanelWidth: CGFloat = 1200
    static let managementPanelHeight: CGFloat = 800
    static let managementPanelLevelOffset = 2
    static let managementPreviewMaxHeight: CGFloat = 300
    static let managementSplitIdealWidth: CGFloat = 500
    static let managementImagePickerPopoverWidth: CGFloat = 400
    static let managementImagePickerPopoverHeight: CGFloat = 300
    static let managementImagePickerListWidth: CGFloat = 220
    static let managementImagePickerPreviewWidth: CGFloat = 170
    static let layoutUndoTimeoutSeconds: Double = 5
    static let managementMinimapPadding: CGFloat = 16
    static let minimapDragMinimumDistance: CGFloat = 3

    // App Version
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // MARK: - Notifications
    static let imageWindowStateDidChange = Notification.Name(
        "\(loggerSubsystem).imageWindowStateDidChange"
    )
    static let imageWindowListDidChange = Notification.Name(
        "\(loggerSubsystem).imageWindowListDidChange"
    )
    static let hotkeySettingsDidChange = Notification.Name(
        "\(loggerSubsystem).hotkeySettingsDidChange"
    )
    static let registeredImagesDidChange = Notification.Name(
        "\(loggerSubsystem).registeredImagesDidChange"
    )
    /// レイアウトプリセットの保存・削除・リネームで発火する
    static let layoutPresetsDidChange = Notification.Name(
        "\(loggerSubsystem).layoutPresetsDidChange"
    )

    // MARK: - Notification UserInfo Keys
    static let notificationTriggerKey = "trigger"

    /// snapshot.update イベントの発火原因を示すトリガー
    enum SnapshotTrigger: String {
        case launch
        // imageWindowStateDidChange 経由
        case position
        case image
        case size
        case flip
        case opacity
        case rotation
        case reset
        case ghost
        case ghostAlpha
        case hidden
        case crop
        // imageWindowListDidChange 経由
        case windowAdd = "window.add"
        case windowRemove = "window.remove"
        case reorder
        case layout
        case zorder
        case closeAll
    }
}

enum PositionLogSettings {
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppConstants.positionLogEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: AppConstants.positionLogEnabledKey) }
    }
}

enum SnapSettings {
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppConstants.snapEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: AppConstants.snapEnabledKey) }
    }
}

enum GhostModeSettings {
    static var globalAlpha: CGFloat {
        get {
            guard UserDefaults.standard.object(forKey: AppConstants.ghostModeAlphaKey) != nil else {
                return AppConstants.ghostModeAlphaDefault
            }
            let value = UserDefaults.standard.double(forKey: AppConstants.ghostModeAlphaKey)
            return CGFloat(
                max(AppConstants.ghostModeAlphaMin, min(AppConstants.ghostModeAlphaMax, value))
            )
        }
        set {
            let clamped = max(
                AppConstants.ghostModeAlphaMin,
                min(AppConstants.ghostModeAlphaMax, newValue)
            )
            UserDefaults.standard.set(Double(clamped), forKey: AppConstants.ghostModeAlphaKey)
        }
    }
}

extension NSAppearance {
    /// 現在の外観がダークモードかどうかを判定
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

enum GeometryUtils {
    /// 回転後のバウンディングボックスサイズを計算
    static func rotatedBoundingBox(width: CGFloat, height: CGFloat, angleDegrees: CGFloat) -> NSSize {
        let radians = angleDegrees * .pi / 180
        let bbWidth = abs(width * cos(radians)) + abs(height * sin(radians))
        let bbHeight = abs(width * sin(radians)) + abs(height * cos(radians))
        return NSSize(width: bbWidth, height: bbHeight)
    }

    /// 角度を 0..<360 の範囲に正規化
    static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var result = angle.truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }

    /// 値が実質的にゼロかどうかを判定
    static func isApproximatelyZero(_ value: CGFloat) -> Bool {
        abs(value) < AppConstants.floatingPointTolerance
    }

    /// 2つの値が実質的に等しいかどうかを判定
    static func isApproximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < AppConstants.floatingPointTolerance
    }

    /// `size` の矩形を `container` の中央に置いたときの原点（container の原点オフセットも考慮する）
    static func centeredOrigin(size: NSSize, in container: NSRect) -> NSPoint {
        NSPoint(
            x: container.midX - size.width / 2,
            y: container.midY - size.height / 2
        )
    }
}

enum AppSupportDirectory {
    static func url(baseDirectory: URL?, logger: Logger) -> URL? {
        let fm = FileManager.default
        let appDir: URL
        if let base = baseDirectory {
            appDir = base
        } else {
            guard let appSupport = fm.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first else { return nil }
            appDir = appSupport.appendingPathComponent(AppConstants.appName)
        }
        do {
            try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create app support directory: \(error.localizedDescription)")
        }
        return appDir
    }

    static func ensureSubdirectory(_ name: String, in baseURL: URL, logger: Logger) -> URL {
        let subdir = baseURL.appendingPathComponent(name)
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: subdir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create \(name) directory: \(error.localizedDescription)")
        }
        return subdir
    }
}

/// ファイル名・パスの無害化。カレントディレクトリに依存しないよう、純粋な文字列処理で行う。
enum PathSanitizer {
    /// ファイル名として使えない名前（ディレクトリ自身・親ディレクトリ・ルートを指す）
    private static let reservedNames: Set<String> = ["", ".", "..", "/"]
    private static let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|\0")
    /// ファイル名の UTF-8 バイト数の上限。ファイルシステムの 255 バイト制限から ".json" の分を引いた値。
    /// これより短い名前は従来も保存できていたため、既存のプリセットファイルとの対応が変わらない。
    static let maxNameByteCount = 250
    /// 切り詰め時に残す拡張子の最大バイト数（これより長い「拡張子」は名前の一部として扱う）
    private static let maxPreservedExtensionByteCount = 16

    /// `directory` 直下のファイルを指す安全な URL を返す。パストラバーサルを防ぐ。
    ///
    /// `name` にパス区切りが含まれる場合は最終要素だけを使う（`"subdir/file.png"` → `"file.png"`）。
    /// 最終要素が空・`.`・`..`・`/` になる場合や、NUL 文字を含む場合は nil。
    static func safeURL(name: String, in directory: URL) -> URL? {
        guard !name.contains("\0") else { return nil }
        let component = lastPathComponent(of: name)
        guard !reservedNames.contains(component) else { return nil }
        let url = directory.appendingPathComponent(component)
        // 念のため、正規化後も directory の直下であることを確認する。
        // `standardizedFileURL` は実在するパスだけ `/private` を除去するなどファイルシステムに依存し、
        // 未作成のファイルと比較が食い違うため、字句的に `.` / `..` を解決する `standardized` を使う。
        guard url.standardized.deletingLastPathComponent().path == directory.standardized.path else {
            return nil
        }
        return url
    }

    /// ファイル名に使えない文字を `_` に置き換え、長すぎる名前を切り詰める。
    ///
    /// 結果が空・`.`・`..` になる場合は nil。
    static func safeName(from name: String) -> String? {
        let sanitized = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        let truncated = truncatedToByteLimit(sanitized)
        guard !reservedNames.contains(truncated) else { return nil }
        return truncated
    }

    /// パスの最終要素を返す（末尾の `/` は無視する。空文字列は空、`/` のみなら `/`）。
    ///
    /// `URL(fileURLWithPath:)` と違いカレントディレクトリに依存しない。
    static func lastPathComponent(of path: String) -> String {
        guard let last = path.split(separator: "/").last else {
            return path.isEmpty ? "" : "/"
        }
        return String(last)
    }

    /// UTF-8 のバイト数が上限を超える場合、文字境界で切り詰める。短い拡張子は残す。
    private static func truncatedToByteLimit(_ name: String) -> String {
        guard name.utf8.count > maxNameByteCount else { return name }
        // 先頭のドット（隠しファイル）は拡張子の区切りとみなさない
        if let dotIndex = name.lastIndex(of: "."), dotIndex != name.startIndex {
            let suffix = String(name[dotIndex...])
            if suffix.utf8.count > 1, suffix.utf8.count <= maxPreservedExtensionByteCount {
                let base = String(name[..<dotIndex])
                return prefix(of: base, maxByteCount: maxNameByteCount - suffix.utf8.count) + suffix
            }
        }
        return prefix(of: name, maxByteCount: maxNameByteCount)
    }

    private static func prefix(of string: String, maxByteCount: Int) -> String {
        var result = ""
        var byteCount = 0
        for character in string {
            let size = character.utf8.count
            guard byteCount + size <= maxByteCount else { break }
            result.append(character)
            byteCount += size
        }
        return result
    }
}

enum MenuItemTag: Int, CaseIterable, Sendable {
    // Phase 2 で使用
    case resetToDefault = 1001
    case defaultImage = 1002
    case changeDefaultImage = 1003
    case resetDefaultImage = 1004
    case addImage = 1005
    case showCount = 1006
    case flipHorizontal = 1007
    case adjust = 1008
    case moveToFront = 1009
    case moveToBack = 1010
    case close = 1011
    case launchAtLogin = 1012
    case checkForUpdates = 1013
    case quit = 1014
    case changeImageSubmenu = 1015
    case addNewWindowSubmenu = 1016
    case otherSubmenu = 1018
    case showOnboarding = 1019
    case removeBackground = 1020
    case flipContext = 1021
    case adjustPanelContext = 1022
    case layoutSubmenu = 1023
    case saveLayout = 1024
    case deleteLayout = 1025
    case updateLayout = 1026
    case createLayout = 1027
    case settingsSubmenu = 1028
    case bulkResetSubmenu = 1029
    case renameLayout = 1030
    case cropImage = 1031
    case resetCrop = 1032
    case ghostModeToggle = 1033
    case ghostModeAllDisable = 1034
    case ghostModeAlphaSlider = 1035
    case opacitySliderContext = 1036
    case hideWindowToggle = 1037
    case managementPanel = 1038
    case quitWithoutSaving = 1039
}

enum AppTheme: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return L("theme.system")
        case .light: return L("theme.light")
        case .dark: return L("theme.dark")
        }
    }

    var iconName: String {
        switch self {
        case .system: return AppConstants.themeSystemSymbol
        case .light: return AppConstants.themeLightSymbol
        case .dark: return AppConstants.themeDarkSymbol
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
enum AppThemeSettings {
    static var currentTheme: AppTheme {
        get {
            guard let raw = UserDefaults.standard.string(forKey: AppConstants.appThemeKey),
                  let theme = AppTheme(rawValue: raw) else {
                return .system
            }
            return theme
        }
        set {
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: AppConstants.appThemeKey)
            } else {
                UserDefaults.standard.set(newValue.rawValue, forKey: AppConstants.appThemeKey)
            }
            NSApp.appearance = newValue.nsAppearance
        }
    }
}

// MARK: - Format Utils

enum FormatUtils {
    /// 不透明度（0–1）をパーセント文字列に変換（例: 0.75 → "75%"）
    static func formatOpacity(_ opacity: CGFloat) -> String {
        "\(Int(round(opacity * 100)))%"
    }

    /// 幅と高さを "W×H px" 形式の文字列に変換（例: 400×300 px）
    static func formatDimensions(width: CGFloat, height: CGFloat) -> String {
        "\(Int(width))×\(Int(height)) px"
    }
}

// MARK: - SF Symbol Utils

enum SFSymbolUtils {
    static func icon(
        _ name: String,
        pointSize: CGFloat = AppConstants.menuIconPointSize,
        weight: NSFont.Weight = .regular
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
}

@MainActor
enum ImageFileDialog {
    static func makeOpenPanel(
        title: String = L("dialog.select_image"),
        message: String = L("dialog.select_image_message")
    ) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = L("dialog.select")
        panel.message = message
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .floating
        return panel
    }
}

extension NSMenu {
    func item(withMenuTag tag: MenuItemTag) -> NSMenuItem? {
        items.first { $0.tag == tag.rawValue }
    }
}

extension NSScreen {
    /// Returns the main screen frame, or a fallback rect when no screen is available.
    static var mainFrameOrFallback: NSRect {
        main?.frame ?? NSRect(origin: .zero, size: AppConstants.fallbackScreenSize)
    }
}

extension Logger {
    init(category: String) {
        self.init(subsystem: AppConstants.loggerSubsystem, category: category)
    }
}
