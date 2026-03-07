import XCTest
@testable import Sobani

/// 言語設定の変更・永続化、バンドル切り替え、言語変更通知の発行を検証するテスト
final class LanguageManagerTests: XCTestCase {
    // LanguageManager 内部の UserDefaults キーと同一値。
    // LanguageManager 側のキーが変更された場合にテストが失敗して気づける。
    private static let appLanguageKey = "AppLanguage"
    private static let appleLanguagesKey = "AppleLanguages"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: Self.appLanguageKey)
        UserDefaults.standard.removeObject(forKey: Self.appleLanguagesKey)
        LanguageManager.shared.updateBundle()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Self.appLanguageKey)
        UserDefaults.standard.removeObject(forKey: Self.appleLanguagesKey)
        LanguageManager.shared.updateBundle()
        super.tearDown()
    }

    // MARK: - Language Setting

    /// デフォルト言語がsystemであることを検証
    func testDefaultLanguageIsSystem() {
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .system)
    }

    /// 日本語への切り替えとUserDefaults永続化を検証
    func testSetLanguageToJapanese() {
        LanguageManager.shared.currentLanguage = .japanese
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .japanese)
        XCTAssertEqual(UserDefaults.standard.string(forKey: Self.appLanguageKey), "ja")
    }

    /// 英語への切り替えとUserDefaults永続化を検証
    func testSetLanguageToEnglish() {
        LanguageManager.shared.currentLanguage = .english
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .english)
        XCTAssertEqual(UserDefaults.standard.string(forKey: Self.appLanguageKey), "en")
    }

    /// システム言語への切り替えでUserDefaultsがクリアされることを検証
    func testSetLanguageToSystemRemovesDefaults() {
        LanguageManager.shared.currentLanguage = .japanese
        LanguageManager.shared.currentLanguage = .system
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .system)
        XCTAssertNil(UserDefaults.standard.string(forKey: Self.appLanguageKey))
    }

    /// Language enumが3つのケースを持つことを検証
    func testAllLanguageCases() {
        XCTAssertEqual(Language.allCases.count, 3)
        XCTAssertTrue(Language.allCases.contains(.system))
        XCTAssertTrue(Language.allCases.contains(.japanese))
        XCTAssertTrue(Language.allCases.contains(.english))
    }

    /// 各言語の表示名が正しいことを検証
    func testLanguageDisplayNames() {
        XCTAssertEqual(Language.japanese.displayName, "日本語")
        XCTAssertEqual(Language.english.displayName, "English")
    }

    // MARK: - Bundle

    /// システム言語でもバンドルが設定されることを検証
    func testSystemLanguageBundleIsNotNil() {
        LanguageManager.shared.currentLanguage = .system
        // .system でもシステム言語に基づくバンドルが設定される
        XCTAssertNotNil(LanguageManager.shared.currentBundle)
    }

    /// 英語からシステム言語に戻した際にバンドルが復元されUserDefaultsがクリアされることを検証
    func testSwitchFromEnglishToSystemRestoresBundle() {
        LanguageManager.shared.currentLanguage = .english
        XCTAssertNotNil(LanguageManager.shared.currentBundle)

        LanguageManager.shared.currentLanguage = .system
        // システム言語に戻してもバンドルが設定されている（nil にならない）
        XCTAssertNotNil(LanguageManager.shared.currentBundle)
        XCTAssertNil(UserDefaults.standard.string(forKey: Self.appLanguageKey))
    }

    // MARK: - Notification

    /// 言語変更時にlanguageDidChange通知が発行されることを検証
    func testLanguageChangePostsNotification() {
        let expectation = XCTestExpectation(description: "Language change notification posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        LanguageManager.shared.currentLanguage = .english
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    /// システム言語への切り替え時にlanguageDidChange通知が発行されることを検証
    func testSwitchToSystemPostsNotification() {
        LanguageManager.shared.currentLanguage = .english

        let expectation = XCTestExpectation(description: "Language change notification posted on system switch")
        let observer = NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        LanguageManager.shared.currentLanguage = .system
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
