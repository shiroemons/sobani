import XCTest
@testable import Sobani

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

    func testDefaultLanguageIsSystem() {
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .system)
    }

    func testSetLanguageToJapanese() {
        LanguageManager.shared.currentLanguage = .japanese
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .japanese)
        XCTAssertEqual(UserDefaults.standard.string(forKey: Self.appLanguageKey), "ja")
    }

    func testSetLanguageToEnglish() {
        LanguageManager.shared.currentLanguage = .english
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .english)
        XCTAssertEqual(UserDefaults.standard.string(forKey: Self.appLanguageKey), "en")
    }

    func testSetLanguageToSystemRemovesDefaults() {
        LanguageManager.shared.currentLanguage = .japanese
        LanguageManager.shared.currentLanguage = .system
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .system)
        XCTAssertNil(UserDefaults.standard.string(forKey: Self.appLanguageKey))
    }

    func testAllLanguageCases() {
        XCTAssertEqual(Language.allCases.count, 3)
        XCTAssertTrue(Language.allCases.contains(.system))
        XCTAssertTrue(Language.allCases.contains(.japanese))
        XCTAssertTrue(Language.allCases.contains(.english))
    }

    func testLanguageDisplayNames() {
        XCTAssertEqual(Language.japanese.displayName, "日本語")
        XCTAssertEqual(Language.english.displayName, "English")
    }

    // MARK: - Bundle

    func testSystemLanguageBundleIsNotNil() {
        LanguageManager.shared.currentLanguage = .system
        // .system でもシステム言語に基づくバンドルが設定される
        XCTAssertNotNil(LanguageManager.shared.currentBundle)
    }

    func testSwitchFromEnglishToSystemRestoresBundle() {
        LanguageManager.shared.currentLanguage = .english
        XCTAssertNotNil(LanguageManager.shared.currentBundle)

        LanguageManager.shared.currentLanguage = .system
        // システム言語に戻してもバンドルが設定されている（nil にならない）
        XCTAssertNotNil(LanguageManager.shared.currentBundle)
        XCTAssertNil(UserDefaults.standard.string(forKey: Self.appLanguageKey))
    }

    // MARK: - Notification

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
