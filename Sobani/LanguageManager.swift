import Foundation

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

class LanguageManager {
    static let shared = LanguageManager()

    private let userDefaultsKey = "AppLanguage"
    private(set) var currentBundle: Bundle?

    var currentLanguage: Language {
        get {
            guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
                  let lang = Language(rawValue: raw) else {
                return .system
            }
            return lang
        }
        set {
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
                UserDefaults.standard.set([newValue.rawValue], forKey: "AppleLanguages")
            }
            updateBundle()
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    private init() {
        // Restore AppleLanguages from saved preference on launch
        // This must happen before any UI is loaded so system strings respect the language
        if let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
           let lang = Language(rawValue: raw), lang != .system {
            UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
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
