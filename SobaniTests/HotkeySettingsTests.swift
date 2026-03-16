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
