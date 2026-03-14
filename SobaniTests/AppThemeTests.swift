import AppKit
import Foundation
import Testing
@testable import Sobani

/// AppTheme enum と AppThemeSettings の動作を検証するテスト
@Suite(.serialized)
@MainActor struct AppThemeTests {

    private let themeKey = AppConstants.appThemeKey

    init() {
        UserDefaults.standard.removeObject(forKey: AppConstants.appThemeKey)
    }

    // MARK: - AppTheme enum テスト

    /// AppThemeが3ケースあることを検証
    @Test func testAllCasesCount() {
        #expect(AppTheme.allCases.count == 3)
    }

    /// 各ケースのrawValueが正しいことを検証
    @Test func testRawValues() {
        #expect(AppTheme.system.rawValue == "system")
        #expect(AppTheme.light.rawValue == "light")
        #expect(AppTheme.dark.rawValue == "dark")
    }

    /// 各ケースのiconNameが正しいことを検証
    @Test func testIconNames() {
        #expect(AppTheme.system.iconName == AppConstants.themeSystemSymbol)
        #expect(AppTheme.light.iconName == AppConstants.themeLightSymbol)
        #expect(AppTheme.dark.iconName == AppConstants.themeDarkSymbol)
    }

    /// systemテーマのnsAppearanceがnilであることを検証
    @Test func testNsAppearanceSystem() {
        #expect(AppTheme.system.nsAppearance == nil)
    }

    /// lightテーマのnsAppearanceが.aquaであることを検証
    @Test func testNsAppearanceLight() {
        let appearance = AppTheme.light.nsAppearance
        #expect(appearance?.name == NSAppearance.Name.aqua)
    }

    /// darkテーマのnsAppearanceが.darkAquaであることを検証
    @Test func testNsAppearanceDark() {
        let appearance = AppTheme.dark.nsAppearance
        #expect(appearance?.name == NSAppearance.Name.darkAqua)
    }

    // MARK: - AppThemeSettings テスト

    /// UserDefaultsにキーがない場合はデフォルトで.systemが返されることを検証
    @Test func testDefaultThemeIsSystem() {
        UserDefaults.standard.removeObject(forKey: themeKey)
        #expect(AppThemeSettings.currentTheme == .system)
    }

    /// .darkを設定して読み取れることを検証
    @Test func testSetAndGetTheme() {
        let hadValue = UserDefaults.standard.object(forKey: themeKey) != nil
        let saved = UserDefaults.standard.string(forKey: themeKey)
        defer {
            if hadValue, let saved {
                UserDefaults.standard.set(saved, forKey: themeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: themeKey)
            }
        }

        AppThemeSettings.currentTheme = .dark
        #expect(AppThemeSettings.currentTheme == .dark)
    }

    /// .systemを設定するとUserDefaultsからキーが削除されることを検証
    @Test func testSetSystemRemovesKey() {
        let hadValue = UserDefaults.standard.object(forKey: themeKey) != nil
        let saved = UserDefaults.standard.string(forKey: themeKey)
        defer {
            if hadValue, let saved {
                UserDefaults.standard.set(saved, forKey: themeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: themeKey)
            }
        }

        AppThemeSettings.currentTheme = .dark
        #expect(UserDefaults.standard.string(forKey: themeKey) != nil)

        AppThemeSettings.currentTheme = .system
        #expect(UserDefaults.standard.object(forKey: themeKey) == nil)
        #expect(AppThemeSettings.currentTheme == .system)
    }
}
