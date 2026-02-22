import XCTest
@testable import Sobani

final class LanguageManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "AppLanguage")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        LanguageManager.shared.updateBundle()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "AppLanguage")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        LanguageManager.shared.updateBundle()
        super.tearDown()
    }

    func testDefaultLanguageIsSystem() {
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .system)
    }

    func testSetLanguageToJapanese() {
        LanguageManager.shared.currentLanguage = .japanese
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .japanese)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "AppLanguage"), "ja")
    }

    func testSetLanguageToEnglish() {
        LanguageManager.shared.currentLanguage = .english
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .english)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "AppLanguage"), "en")
    }

    func testSetLanguageToSystemRemovesDefaults() {
        LanguageManager.shared.currentLanguage = .japanese
        LanguageManager.shared.currentLanguage = .system
        XCTAssertEqual(LanguageManager.shared.currentLanguage, .system)
        XCTAssertNil(UserDefaults.standard.string(forKey: "AppLanguage"))
    }

    func testSystemLanguageBundleIsNil() {
        LanguageManager.shared.currentLanguage = .system
        XCTAssertNil(LanguageManager.shared.currentBundle)
    }

    func testLanguageDisplayNames() {
        XCTAssertEqual(Language.japanese.displayName, "日本語")
        XCTAssertEqual(Language.english.displayName, "English")
    }

    func testAllLanguageCases() {
        XCTAssertEqual(Language.allCases.count, 3)
        XCTAssertTrue(Language.allCases.contains(.system))
        XCTAssertTrue(Language.allCases.contains(.japanese))
        XCTAssertTrue(Language.allCases.contains(.english))
    }
}
