import Cocoa
import os.log

/// Localization helper that supports runtime language switching via LanguageManager.
/// Falls back to NSLocalizedString with the main bundle when no custom bundle is set.
func L(_ key: String) -> String {
    if let bundle = LanguageManager.shared.currentBundle {
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    return NSLocalizedString(key, comment: "")
}

enum AppConstants {
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

    // Display ID
    static let unknownDisplayID: CGDirectDisplayID = 0

    // Status Bar
    static let statusBarIconSize: CGFloat = 18

    // Menu
    static let menuWindowMinWidth: CGFloat = 10
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

    // Onboarding
    enum Onboarding {
        static let width: CGFloat = 520
        static let height: CGFloat = 480
        static let currentVersion = 1
        static let completedVersionKey = "onboardingCompletedVersion"
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
}

enum AppSupportDirectory {
    static func url(baseDirectory: URL?, logger: Logger) -> URL? {
        let fm = FileManager.default
        let appDir: URL
        if let base = baseDirectory {
            appDir = base
        } else {
            guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
            appDir = appSupport.appendingPathComponent("Sobani")
        }
        if !fm.fileExists(atPath: appDir.path) {
            do {
                try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create app support directory: \(error.localizedDescription)")
            }
        }
        return appDir
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

enum MenuItemTag: Int {
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
}
