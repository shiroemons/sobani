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

    /// 未設定時にtoggleVisibilityKeyCodeがoptionHKeyCodeを返すことを検証
    @Test func defaultToggleVisibilityKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityKeyCodeKey) {
            #expect(HotkeySettings.toggleVisibilityKeyCode == AppConstants.optionHKeyCode)
        }
    }

    /// 未設定時にtoggleVisibilityModifiersが.optionを返すことを検証
    @Test func defaultToggleVisibilityModifiers() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityModifiersKey) {
            #expect(HotkeySettings.toggleVisibilityModifiers == .option)
        }
    }

    /// 未設定時にtoggleGhostModeKeyCodeがoptionGKeyCodeを返すことを検証
    @Test func defaultToggleGhostModeKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeKeyCodeKey) {
            #expect(HotkeySettings.toggleGhostModeKeyCode == AppConstants.optionGKeyCode)
        }
    }

    /// 未設定時にtoggleManagementKeyCodeがoptionMKeyCodeを返すことを検証
    @Test func defaultToggleManagementKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleManagementKeyCodeKey) {
            #expect(HotkeySettings.toggleManagementKeyCode == AppConstants.optionMKeyCode)
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

    /// toggleVisibilityKeyCodeの書き込みと読み出しが正しく動作することを検証
    @Test func setToggleVisibilityKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityKeyCodeKey) {
            HotkeySettings.toggleVisibilityKeyCode = 0  // kVK_ANSI_A
            #expect(HotkeySettings.toggleVisibilityKeyCode == 0)
        }
    }

    /// toggleVisibilityModifiersの書き込みと読み出しが正しく動作することを検証
    @Test func setToggleVisibilityModifiers() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleVisibilityModifiersKey) {
            HotkeySettings.toggleVisibilityModifiers = [.command, .shift]
            #expect(HotkeySettings.toggleVisibilityModifiers == [.command, .shift])
        }
    }

    /// toggleGhostModeKeyCodeの書き込みと読み出しが正しく動作することを検証
    @Test func setToggleGhostModeKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeKeyCodeKey) {
            HotkeySettings.toggleGhostModeKeyCode = 1  // kVK_ANSI_S
            #expect(HotkeySettings.toggleGhostModeKeyCode == 1)
        }
    }

    /// toggleManagementKeyCodeの書き込みと読み出しが正しく動作することを検証
    @Test func setToggleManagementKeyCode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleManagementKeyCodeKey) {
            HotkeySettings.toggleManagementKeyCode = 8  // kVK_ANSI_C
            #expect(HotkeySettings.toggleManagementKeyCode == 8)
        }
    }

    // MARK: - ラウンドトリップテスト

    /// 修飾キーのrawValue保存・復元が正しく動作することを検証
    @Test func modifiersRoundtrip() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeModifiersKey) {
            let original: NSEvent.ModifierFlags = [.control, .option]
            HotkeySettings.toggleGhostModeModifiers = original
            let retrieved = HotkeySettings.toggleGhostModeModifiers
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
            #expect(HotkeySettings.toggleVisibilityKeyCode == 2)
        }
    }

    /// setKeyCode(_:for:)でtoggleGhostModeのキーコードを書き込み・読み出しできることを検証
    @Test func setKeyCodeForToggleGhostMode() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleGhostModeKeyCodeKey) {
            HotkeySettings.setKeyCode(3, for: .toggleGhostMode)
            #expect(HotkeySettings.keyCode(for: .toggleGhostMode) == 3)
            #expect(HotkeySettings.toggleGhostModeKeyCode == 3)
        }
    }

    /// setKeyCode(_:for:)でtoggleManagementのキーコードを書き込み・読み出しできることを検証
    @Test func setKeyCodeForToggleManagement() {
        withCleanHotkeyDefaults(key: AppConstants.hotkeyToggleManagementKeyCodeKey) {
            HotkeySettings.setKeyCode(9, for: .toggleManagement)
            #expect(HotkeySettings.keyCode(for: .toggleManagement) == 9)
            #expect(HotkeySettings.toggleManagementKeyCode == 9)
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
            #expect(HotkeySettings.toggleGhostModeModifiers == [.command, .control])
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
