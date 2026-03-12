import Foundation
import Testing
@testable import Sobani

/// 言語設定の変更・永続化、バンドル切り替え、言語変更通知の発行を検証するテスト
@Suite(.serialized)
@MainActor struct LanguageManagerTests {
    // LanguageManager 内部の UserDefaults キーと同一値。
    // LanguageManager 側のキーが変更された場合にテストが失敗して気づける。
    private static let appLanguageKey = "AppLanguage"
    private static let appleLanguagesKey = "AppleLanguages"

    private let testDefaults: UserDefaults
    private let manager: LanguageManager

    init() throws {
        let testDefaults = try #require(UserDefaults(suiteName: "test-language-\(UUID().uuidString)"))
        self.testDefaults = testDefaults
        self.manager = LanguageManager(defaults: testDefaults)
    }

    // MARK: - Language Setting

    /// デフォルト言語がsystemであることを検証
    @Test func defaultLanguageIsSystem() {
        #expect(manager.currentLanguage == .system)
    }

    /// 日本語への切り替えとUserDefaults永続化を検証
    @Test func setLanguageToJapanese() {
        manager.currentLanguage = .japanese
        #expect(manager.currentLanguage == .japanese)
        #expect(testDefaults.string(forKey: Self.appLanguageKey) == "ja")
    }

    /// 英語への切り替えとUserDefaults永続化を検証
    @Test func setLanguageToEnglish() {
        manager.currentLanguage = .english
        #expect(manager.currentLanguage == .english)
        #expect(testDefaults.string(forKey: Self.appLanguageKey) == "en")
    }

    /// システム言語への切り替えでUserDefaultsがクリアされることを検証
    @Test func setLanguageToSystemRemovesDefaults() {
        manager.currentLanguage = .japanese
        manager.currentLanguage = .system
        #expect(manager.currentLanguage == .system)
        #expect(testDefaults.string(forKey: Self.appLanguageKey) == nil)
    }

    /// Language enumが3つのケースを持つことを検証
    @Test func allLanguageCases() {
        #expect(Language.allCases.count == 3)
        #expect(Language.allCases.contains(.system))
        #expect(Language.allCases.contains(.japanese))
        #expect(Language.allCases.contains(.english))
    }

    /// 各言語の表示名が正しいことを検証
    @Test func languageDisplayNames() {
        #expect(Language.japanese.displayName == "日本語")
        #expect(Language.english.displayName == "English")
    }

    // MARK: - Bundle

    /// システム言語でもバンドルが設定されることを検証
    @Test func systemLanguageBundleIsNotNil() {
        manager.currentLanguage = .system
        // .system でもシステム言語に基づくバンドルが設定される
        #expect(manager.currentBundle != nil)
    }

    /// 英語からシステム言語に戻した際にバンドルが復元されUserDefaultsがクリアされることを検証
    @Test func switchFromEnglishToSystemRestoresBundle() {
        manager.currentLanguage = .english
        #expect(manager.currentBundle != nil)

        manager.currentLanguage = .system
        // システム言語に戻してもバンドルが設定されている（nil にならない）
        #expect(manager.currentBundle != nil)
        #expect(testDefaults.string(forKey: Self.appLanguageKey) == nil)
    }

    // MARK: - Notification

    /// 言語変更時にlanguageDidChange通知が発行されることを検証
    @Test func languageChangePostsNotification() async {
        await confirmation("Language change notification posted") { confirm in
            let observer = NotificationCenter.default.addObserver(
                forName: .languageDidChange,
                object: nil,
                queue: nil
            ) { _ in
                confirm()
            }
            manager.currentLanguage = .english
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// システム言語への切り替え時にlanguageDidChange通知が発行されることを検証
    @Test func switchToSystemPostsNotification() async {
        manager.currentLanguage = .english

        await confirmation("Language change notification posted on system switch") { confirm in
            let observer = NotificationCenter.default.addObserver(
                forName: .languageDidChange,
                object: nil,
                queue: nil
            ) { _ in
                confirm()
            }
            manager.currentLanguage = .system
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
