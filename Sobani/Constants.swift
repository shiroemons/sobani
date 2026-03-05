import Cocoa

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

    // Floating-point comparison
    static let floatingPointTolerance: CGFloat = 0.01

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
}
