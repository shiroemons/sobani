import Foundation
import os.log

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

enum Language: String, CaseIterable {
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

final class LanguageManager {
    private let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "LanguageManager")
    static let shared = LanguageManager()

    private static let userDefaultsKey = "AppLanguage"
    private static let appleLanguagesKey = "AppleLanguages"
    private(set) var currentBundle: Bundle?

    var currentLanguage: Language {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
                  let lang = Language(rawValue: raw) else {
                return .system
            }
            return lang
        }
        set {
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
                UserDefaults.standard.removeObject(forKey: Self.appleLanguagesKey)
            } else {
                UserDefaults.standard.set(newValue.rawValue, forKey: Self.userDefaultsKey)
                UserDefaults.standard.set([newValue.rawValue], forKey: Self.appleLanguagesKey)
            }
            updateBundle()
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init() {
        // Restore AppleLanguages from saved preference on launch
        // This must happen before any UI is loaded so system strings respect the language
        if let raw = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let lang = Language(rawValue: raw), lang != .system {
            UserDefaults.standard.set([lang.rawValue], forKey: Self.appleLanguagesKey)
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
        } else {
            currentBundle = nil
        }
    }
}
