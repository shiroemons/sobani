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

    @MainActor
    static func current() -> [Self] {
        NSScreen.screens.map { screen in
            Self(
                frame: screen.frame,
                displayID: (screen.deviceDescription[AppConstants.screenNumberKey]
                    as? CGDirectDisplayID) ?? 0,
                isMain: screen == NSScreen.main
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
    static let screenMatchTolerance: CGFloat = 100
    static let screenIntersectionThreshold: CGFloat = 50

    // Fallback
    static let fallbackScreenSize = NSSize(width: 1920, height: 1080)
    static let fallbackScreenHeight: CGFloat = 900

    // Floating-point comparison
    static let floatingPointTolerance: CGFloat = 0.01

    // Hotkey
    static let optionHKeyCode: UInt16 = 4
    static let escKeyCode: UInt16 = 53

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

    // Window Snap
    static let snapThreshold: CGFloat = 8
    static let snapEnabledKey = "windowSnapEnabled"

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
        static let currentVersion = 1
        static let completedVersionKey = "onboardingCompletedVersion"
    }

    // Management Panel
    static let managementPanelWidth: CGFloat = 820
    static let managementPanelHeight: CGFloat = 560
}

enum GhostModeSettings {
    static var globalAlpha: CGFloat {
        get {
            guard UserDefaults.standard.object(forKey: AppConstants.ghostModeAlphaKey) != nil else {
                return AppConstants.ghostModeAlphaDefault
            }
            let value = UserDefaults.standard.double(forKey: AppConstants.ghostModeAlphaKey)
            return CGFloat(max(AppConstants.ghostModeAlphaMin, min(AppConstants.ghostModeAlphaMax, value)))
        }
        set {
            let clamped = max(AppConstants.ghostModeAlphaMin, min(AppConstants.ghostModeAlphaMax, newValue))
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
}

enum AppSupportDirectory {
    static func url(baseDirectory: URL?, logger: Logger) -> URL? {
        let fm = FileManager.default
        let appDir: URL
        if let base = baseDirectory {
            appDir = base
        } else {
            guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
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

enum PathSanitizer {
    /// Returns a safe URL within the given directory, preventing path traversal.
    /// Returns nil if the name is empty or resolves to a traversal attempt.
    static func safeURL(name: String, in directory: URL) -> URL? {
        let safeName = URL(fileURLWithPath: name).lastPathComponent
        guard !safeName.isEmpty, safeName != "." else { return nil }
        let url = directory.appendingPathComponent(safeName)
        guard url.path.hasPrefix(directory.path + "/") else { return nil }
        return url
    }

    /// Sanitizes a file name by replacing invalid filesystem characters and preventing path traversal.
    /// Returns nil if the result is empty or invalid.
    static func safeName(from name: String) -> String? {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        if sanitized.isEmpty || sanitized == "." || sanitized == ".." {
            return nil
        }
        let resolved = URL(fileURLWithPath: sanitized).lastPathComponent
        if resolved.isEmpty || resolved == "." || resolved == ".." {
            return nil
        }
        return resolved
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
}

// MARK: - SF Symbol Utils

enum SFSymbolUtils {
    static func icon(_ name: String, pointSize: CGFloat = AppConstants.menuIconPointSize,
                     weight: NSFont.Weight = .regular) -> NSImage? {
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
