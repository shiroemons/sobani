import AppKit
import Foundation
import Testing
@testable import Sobani

/// HotkeySettingsのデフォルト値・読み書き・ラウンドトリップを検証するテスト
@Suite @MainActor struct HotkeySettingsTests {

    // MARK: - デフォルト値テスト

    /// 未設定時にisEnabledがtrueを返すことを検証
    @Test func defaultIsEnabled() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyEnabledKey) {
            #expect(HotkeySettings.isEnabled == true)
        }
    }

    /// 未設定時にkeyCode(for: .toggleVisibility)がoptionHKeyCodeを返すことを検証
    @Test func defaultToggleVisibilityKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityKeyCodeKey) {
            #expect(HotkeySettings.keyCode(for: .toggleVisibility) == AppConstants.optionHKeyCode)
        }
    }

    /// 未設定時にmodifiers(for: .toggleVisibility)が.optionを返すことを検証
    @Test func defaultToggleVisibilityModifiers() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityModifiersKey) {
            #expect(HotkeySettings.modifiers(for: .toggleVisibility) == .option)
        }
    }

    /// 未設定時にkeyCode(for: .toggleGhostMode)がoptionGKeyCodeを返すことを検証
    @Test func defaultToggleGhostModeKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeKeyCodeKey) {
            #expect(HotkeySettings.keyCode(for: .toggleGhostMode) == AppConstants.optionGKeyCode)
        }
    }

    /// 未設定時にtoggleScreenGhostModeのキーコードがoptionGKeyCodeを返すことを検証
    @Test func defaultToggleScreenGhostModeKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleScreenGhostKeyCodeKey) {
            #expect(HotkeySettings.keyCode(for: .toggleScreenGhostMode) == AppConstants.optionGKeyCode)
        }
    }

    /// 未設定時にtoggleScreenGhostModeの修飾キーが[.option, .shift]を返すことを検証
    @Test func defaultToggleScreenGhostModeModifiers() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleScreenGhostModifiersKey) {
            #expect(HotkeySettings.modifiers(for: .toggleScreenGhostMode) == [.option, .shift])
        }
    }

    /// 未設定時にkeyCode(for: .toggleManagement)がoptionMKeyCodeを返すことを検証
    @Test func defaultToggleManagementKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleManagementKeyCodeKey) {
            #expect(HotkeySettings.keyCode(for: .toggleManagement) == AppConstants.optionMKeyCode)
        }
    }

    // MARK: - 値設定テスト

    /// isEnabledの書き込みと読み出しが正しく動作することを検証
    @Test func setIsEnabled() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyEnabledKey) {
            HotkeySettings.isEnabled = false
            #expect(HotkeySettings.isEnabled == false)
            HotkeySettings.isEnabled = true
            #expect(HotkeySettings.isEnabled == true)
        }
    }

    /// keyCode(for: .toggleVisibility)の書き込みと読み出しが正しく動作することを検証
    @Test func setToggleVisibilityKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityKeyCodeKey) {
            HotkeySettings.setKeyCode(0, for: .toggleVisibility)  // kVK_ANSI_A
            #expect(HotkeySettings.keyCode(for: .toggleVisibility) == 0)
        }
    }

    /// modifiers(for: .toggleVisibility)の書き込みと読み出しが正しく動作することを検証
    @Test func setToggleVisibilityModifiers() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityModifiersKey) {
            HotkeySettings.setModifiers([.command, .shift], for: .toggleVisibility)
            #expect(HotkeySettings.modifiers(for: .toggleVisibility) == [.command, .shift])
        }
    }

    /// keyCode(for: .toggleGhostMode)の書き込みと読み出しが正しく動作することを検証
    @Test func setToggleGhostModeKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeKeyCodeKey) {
            HotkeySettings.setKeyCode(1, for: .toggleGhostMode)  // kVK_ANSI_S
            #expect(HotkeySettings.keyCode(for: .toggleGhostMode) == 1)
        }
    }

    /// keyCode(for: .toggleManagement)の書き込みと読み出しが正しく動作することを検証
    @Test func setToggleManagementKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleManagementKeyCodeKey) {
            HotkeySettings.setKeyCode(8, for: .toggleManagement)  // kVK_ANSI_C
            #expect(HotkeySettings.keyCode(for: .toggleManagement) == 8)
        }
    }

    // MARK: - ラウンドトリップテスト

    /// 修飾キーのrawValue保存・復元が正しく動作することを検証
    @Test func modifiersRoundtrip() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeModifiersKey) {
            let original: NSEvent.ModifierFlags = [.control, .option]
            HotkeySettings.setModifiers(original, for: .toggleGhostMode)
            let retrieved = HotkeySettings.modifiers(for: .toggleGhostMode)
            #expect(retrieved.contains(.control))
            #expect(retrieved.contains(.option))
        }
    }

    // MARK: - Array-based Accessor テスト

    /// keyCode(for:)がtoggleVisibilityのデフォルト値を返すことを検証
    @Test func keyCodeForToggleVisibility() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityKeyCodeKey) {
            #expect(HotkeySettings.keyCode(for: .toggleVisibility) == AppConstants.optionHKeyCode)
        }
    }

    /// keyCode(for:)がtoggleGhostModeのデフォルト値を返すことを検証
    @Test func keyCodeForToggleGhostMode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeKeyCodeKey) {
            #expect(HotkeySettings.keyCode(for: .toggleGhostMode) == AppConstants.optionGKeyCode)
        }
    }

    /// keyCode(for:)がtoggleManagementのデフォルト値を返すことを検証
    @Test func keyCodeForToggleManagement() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleManagementKeyCodeKey) {
            #expect(HotkeySettings.keyCode(for: .toggleManagement) == AppConstants.optionMKeyCode)
        }
    }

    /// setKeyCode(_:for:)でtoggleVisibilityのキーコードを書き込み・読み出しできることを検証
    @Test func setKeyCodeForToggleVisibility() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityKeyCodeKey) {
            HotkeySettings.setKeyCode(2, for: .toggleVisibility)
            #expect(HotkeySettings.keyCode(for: .toggleVisibility) == 2)
            #expect(HotkeySettings.keyCode(for: .toggleVisibility) == 2)
        }
    }

    /// setKeyCode(_:for:)でtoggleGhostModeのキーコードを書き込み・読み出しできることを検証
    @Test func setKeyCodeForToggleGhostMode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeKeyCodeKey) {
            HotkeySettings.setKeyCode(3, for: .toggleGhostMode)
            #expect(HotkeySettings.keyCode(for: .toggleGhostMode) == 3)
            #expect(HotkeySettings.keyCode(for: .toggleGhostMode) == 3)
        }
    }

    /// setKeyCode(_:for:)でtoggleManagementのキーコードを書き込み・読み出しできることを検証
    @Test func setKeyCodeForToggleManagement() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleManagementKeyCodeKey) {
            HotkeySettings.setKeyCode(9, for: .toggleManagement)
            #expect(HotkeySettings.keyCode(for: .toggleManagement) == 9)
            #expect(HotkeySettings.keyCode(for: .toggleManagement) == 9)
        }
    }

    /// modifiers(for:)がtoggleVisibilityのデフォルト修飾キーを返すことを検証
    @Test func modifiersForToggleVisibility() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityModifiersKey) {
            #expect(HotkeySettings.modifiers(for: .toggleVisibility) == .option)
        }
    }

    /// setModifiers(_:for:)でtoggleGhostModeの修飾キーを書き込み・読み出しできることを検証
    @Test func setModifiersForToggleGhostMode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeModifiersKey) {
            HotkeySettings.setModifiers([.command, .control], for: .toggleGhostMode)
            let result = HotkeySettings.modifiers(for: .toggleGhostMode)
            #expect(result.contains(.command))
            #expect(result.contains(.control))
            #expect(HotkeySettings.modifiers(for: .toggleGhostMode) == [.command, .control])
        }
    }

    // MARK: - リセットテスト

    /// toggleVisibilityのみをリセットしたとき、他のアクションはカスタム値を維持することを検証
    @Test func testResetToDefaultRestoresSingleAction() {
        withCleanAllHotkeyDefaults {
            setAllActionsToCustomValues()

            HotkeySettings.resetToDefault(for: .toggleVisibility)

            #expect(HotkeySettings.keyCode(for: .toggleVisibility) == AppConstants.optionHKeyCode)
            #expect(HotkeySettings.modifiers(for: .toggleVisibility) == .option)
            #expect(HotkeySettings.keyCode(for: .toggleGhostMode) == 3)
            #expect(HotkeySettings.modifiers(for: .toggleGhostMode) == [.command, .control])
            #expect(HotkeySettings.keyCode(for: .toggleScreenVisibility) == 12)
            #expect(HotkeySettings.modifiers(for: .toggleScreenVisibility) == [.option, .shift])
            #expect(HotkeySettings.keyCode(for: .toggleScreenGhostMode) == 11)
            #expect(HotkeySettings.modifiers(for: .toggleScreenGhostMode) == [.command, .shift])
            #expect(HotkeySettings.keyCode(for: .toggleManagement) == 9)
            #expect(HotkeySettings.modifiers(for: .toggleManagement) == [.command, .option])
        }
    }

    /// resetAllToDefaults()がすべてのアクションをデフォルトに戻すことを検証
    @Test func testResetAllToDefaultsRestoresAllActions() {
        withCleanAllHotkeyDefaults {
            setAllActionsToCustomValues()

            HotkeySettings.resetAllToDefaults()

            #expect(HotkeySettings.keyCode(for: .toggleVisibility) == AppConstants.optionHKeyCode)
            #expect(HotkeySettings.modifiers(for: .toggleVisibility) == .option)
            #expect(HotkeySettings.keyCode(for: .toggleGhostMode) == AppConstants.optionGKeyCode)
            #expect(HotkeySettings.modifiers(for: .toggleGhostMode) == .option)
            #expect(HotkeySettings.keyCode(for: .toggleScreenVisibility) == AppConstants.optionHKeyCode)
            #expect(HotkeySettings.modifiers(for: .toggleScreenVisibility) == [.option, .shift])
            #expect(HotkeySettings.keyCode(for: .toggleScreenGhostMode) == AppConstants.optionGKeyCode)
            #expect(HotkeySettings.modifiers(for: .toggleScreenGhostMode) == [.option, .shift])
            #expect(HotkeySettings.keyCode(for: .toggleManagement) == AppConstants.optionMKeyCode)
            #expect(HotkeySettings.modifiers(for: .toggleManagement) == .option)
        }
    }

    // MARK: - buildConfig() テスト

    /// buildConfig()がすべてのアクションのバインディングを含むHotkeyConfigを返すことを検証
    @Test func buildConfigContainsAllActions() {
        let config = HotkeySettings.buildConfig()
        #expect(config.bindings.count == AppDelegate.KeyboardAction.allCases.count)
        for action in AppDelegate.KeyboardAction.allCases {
            #expect(config.binding(for: action) != nil)
        }
    }

    /// buildConfig()がHotkeySettingsの現在値を反映することを検証
    @Test func buildConfigReflectsCurrentSettings() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityKeyCodeKey) {
            withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityModifiersKey) {
                HotkeySettings.setKeyCode(10, for: .toggleVisibility)
                HotkeySettings.setModifiers([.command, .shift], for: .toggleVisibility)
                let config = HotkeySettings.buildConfig()
                let binding = config.binding(for: .toggleVisibility)
                #expect(binding?.keyCode == 10)
                #expect(binding?.modifiers == [.command, .shift])
            }
        }
    }

    // MARK: - 不正な保存値

    /// 範囲外・負数のキーコードがクラッシュせずデフォルトに戻ることを検証
    @Test(arguments: [-1, 70_000, Int.max])
    func keyCodeFromOutOfRangeStoredValueFallsBack(stored: Int) {
        #expect(HotkeySettings.keyCode(fromStored: stored, default: 4) == 4)
    }

    /// 有効なキーコードはそのまま読み出され、未設定・型違いはデフォルトに戻ることを検証
    @Test func keyCodeFromStoredValue() {
        #expect(HotkeySettings.keyCode(fromStored: 53, default: 4) == 53)
        #expect(HotkeySettings.keyCode(fromStored: nil, default: 4) == 4)
        #expect(HotkeySettings.keyCode(fromStored: "53", default: 4) == 4)
    }

    /// 負数の修飾キーはデフォルトに戻り、未対応の修飾キーのビットは除去されることを検証
    @Test func modifiersFromStoredValueIsSanitized() {
        #expect(HotkeySettings.modifiers(fromStored: -1, default: .option) == .option)
        let polluted: NSEvent.ModifierFlags = [.option, .shift, .capsLock, .function, .numericPad]
        let result = HotkeySettings.modifiers(fromStored: Int(polluted.rawValue), default: .command)
        #expect(result == [.option, .shift])
    }

    /// UserDefaultsに不正値が保存されていてもアクセサがクラッシュせずデフォルトを返すことを検証
    @Test func accessorsToleratePollutedDefaults() {
        withCleanAllHotkeyDefaults {
            UserDefaults.standard.set(-5, forKey: AppConstants.hotkeyToggleVisibilityKeyCodeKey)
            let polluted = NSEvent.ModifierFlags([.option, .capsLock]).rawValue
            UserDefaults.standard.set(Int(polluted), forKey: AppConstants.hotkeyToggleVisibilityModifiersKey)

            #expect(HotkeySettings.keyCode(for: .toggleVisibility) == AppConstants.optionHKeyCode)
            #expect(HotkeySettings.modifiers(for: .toggleVisibility) == .option)
            #expect(HotkeySettings.isDefault(for: .toggleVisibility))
        }
    }

    /// 保存時にも未対応の修飾キーのビットが除去されることを検証
    @Test func setModifiersDropsUnsupportedFlags() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeModifiersKey) {
            HotkeySettings.setModifiers([.control, .numericPad, .function], for: .toggleGhostMode)
            let stored = UserDefaults.standard.integer(forKey: AppConstants.hotkeyToggleGhostModeModifiersKey)
            #expect(stored == Int(NSEvent.ModifierFlags.control.rawValue))
        }
    }
}

// MARK: - ヘルパー

/// 指定キーの既存値を退避・復元しながらテストを実行するヘルパー
private func withCleanHotkeyDefaults(key: String, body: () -> Void) {
    let hadValue = UserDefaults.standard.object(forKey: key) != nil
    let savedObject = UserDefaults.standard.object(forKey: key)
    UserDefaults.standard.removeObject(forKey: key)
    defer {
        if hadValue {
            UserDefaults.standard.set(savedObject, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    body()
}

/// テスト用：全アクションにカスタム値を設定する
private func setAllActionsToCustomValues() {
    HotkeySettings.setKeyCode(2, for: .toggleVisibility)
    HotkeySettings.setModifiers([.command, .shift], for: .toggleVisibility)
    HotkeySettings.setKeyCode(3, for: .toggleGhostMode)
    HotkeySettings.setModifiers([.command, .control], for: .toggleGhostMode)
    HotkeySettings.setKeyCode(12, for: .toggleScreenVisibility)
    HotkeySettings.setModifiers([.option, .shift], for: .toggleScreenVisibility)
    HotkeySettings.setKeyCode(11, for: .toggleScreenGhostMode)
    HotkeySettings.setModifiers([.command, .shift], for: .toggleScreenGhostMode)
    HotkeySettings.setKeyCode(9, for: .toggleManagement)
    HotkeySettings.setModifiers([.command, .option], for: .toggleManagement)
}

/// 全ホットキー関連キーの既存値を退避・復元しながらテストを実行するヘルパー
private func withCleanAllHotkeyDefaults(body: () throws -> Void) rethrows {
    let keys = [
        AppConstants.hotkeyToggleVisibilityKeyCodeKey,
        AppConstants.hotkeyToggleVisibilityModifiersKey,
        AppConstants.hotkeyToggleGhostModeKeyCodeKey,
        AppConstants.hotkeyToggleGhostModeModifiersKey,
        AppConstants.hotkeyToggleScreenVisKeyCodeKey,
        AppConstants.hotkeyToggleScreenVisModifiersKey,
        AppConstants.hotkeyToggleScreenGhostKeyCodeKey,
        AppConstants.hotkeyToggleScreenGhostModifiersKey,
        AppConstants.hotkeyToggleManagementKeyCodeKey,
        AppConstants.hotkeyToggleManagementModifiersKey
    ]
    let saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
    defer {
        for (key, value) in saved {
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    for key in keys {
        UserDefaults.standard.removeObject(forKey: key)
    }
    try body()
}
