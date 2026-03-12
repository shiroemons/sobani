import Foundation
import os.log

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

/// スレッドセーフなバンドル参照。任意のスレッドから読み取り可能。
/// 書き込みは @MainActor (LanguageManager.updateBundle()) からのみ行われる。
/// Bundle は不変オブジェクトであり、参照の代入は64bitでアトミックなため安全。
nonisolated(unsafe) var sharedLocalizationBundle: Bundle?

enum Language: String, CaseIterable, Sendable {
    case system = "system"
    case japanese = "ja"
    case english = "en"

    var displayName: String {
        switch self {
        case .system: return L("language.system")
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }
}

@MainActor
final class LanguageManager {
    private let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: "LanguageManager")
    static let shared = LanguageManager()

    private static let appleLanguagesKey = "AppleLanguages"
    private let defaults: UserDefaults
    private(set) var currentBundle: Bundle?

    var currentLanguage: Language {
        get {
            guard let raw = defaults.string(forKey: AppConstants.appLanguageKey),
                  let lang = Language(rawValue: raw) else {
                return .system
            }
            return lang
        }
        set {
            if newValue == .system {
                defaults.removeObject(forKey: AppConstants.appLanguageKey)
                defaults.removeObject(forKey: Self.appleLanguagesKey)
            } else {
                defaults.set(newValue.rawValue, forKey: AppConstants.appLanguageKey)
                defaults.set([newValue.rawValue], forKey: Self.appleLanguagesKey)
            }
            updateBundle()
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Restore AppleLanguages from saved preference on launch
        // This must happen before any UI is loaded so system strings respect the language
        if let raw = defaults.string(forKey: AppConstants.appLanguageKey),
           let lang = Language(rawValue: raw), lang != .system {
            defaults.set([lang.rawValue], forKey: Self.appleLanguagesKey)
        }
        updateBundle()
    }

    private static let supportedLangCodes: Set<String> = Set(
        Language.allCases.compactMap { $0 == .system ? nil : $0.rawValue }
    )
    private static let defaultLangCode = Language.japanese.rawValue

    func updateBundle() {
        let language = currentLanguage
        let langCode: String
        if language == .system {
            // アプリがサポートする言語とシステム設定を突き合わせて検出
            langCode = Bundle.main.preferredLocalizations
                .first { Self.supportedLangCodes.contains($0) }
                ?? Self.defaultLangCode
        } else {
            langCode = language.rawValue
        }

        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            currentBundle = bundle
            sharedLocalizationBundle = bundle
        } else {
            currentBundle = nil
            sharedLocalizationBundle = nil
        }
    }
}
