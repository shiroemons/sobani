import AppKit
import Foundation
import Testing
@testable import Sobani

/// HotkeyManager・HotkeyAction・HotkeyBinding の動作を検証するテスト
@Suite struct HotkeyManagerTests {

    // MARK: - Helper

    private func freshManager() throws -> (manager: HotkeyManager, cleanup: () -> Void) {
        let suiteName = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let manager = HotkeyManager(defaults: defaults)
        let cleanup = { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        return (manager, cleanup)
    }

    // MARK: - HotkeyAction デフォルトバインディング

    /// toggleVisibility のデフォルトバインディングが正しいことを検証
    @Test func hotkeyAction_DefaultBinding_ToggleVisibility() {
        let binding = HotkeyAction.toggleVisibility.defaultBinding
        #expect(binding.keyCode == AppConstants.optionHKeyCode)
        #expect(binding.modifierMask == NSEvent.ModifierFlags.option.rawValue)
    }

    /// toggleGhostMode のデフォルトバインディングが正しいことを検証
    @Test func hotkeyAction_DefaultBinding_ToggleGhostMode() {
        let binding = HotkeyAction.toggleGhostMode.defaultBinding
        #expect(binding.keyCode == AppConstants.optionGKeyCode)
        #expect(binding.modifierMask == NSEvent.ModifierFlags.option.rawValue)
    }

    /// managementPanel のデフォルトバインディングが正しいことを検証
    @Test func hotkeyAction_DefaultBinding_ManagementPanel() {
        let binding = HotkeyAction.managementPanel.defaultBinding
        #expect(binding.keyCode == AppConstants.optionPKeyCode)
        #expect(binding.modifierMask == NSEvent.ModifierFlags.option.rawValue)
    }

    /// userDefaultsKey が "hotkey_" + rawValue であることを検証
    @Test func hotkeyAction_UserDefaultsKey() {
        for action in HotkeyAction.allCases {
            #expect(action.userDefaultsKey == "hotkey_\(action.rawValue)")
        }
    }

    /// displayName が空でないことを検証
    @Test func hotkeyAction_DisplayName_NonEmpty() {
        for action in HotkeyAction.allCases {
            #expect(!action.displayName.isEmpty)
        }
    }

    // MARK: - HotkeyBinding displayString

    /// ⌥P のdisplayStringが "⌥P" であることを検証
    @Test func hotkeyBinding_DisplayString_OptionP() {
        let binding = HotkeyBinding(
            keyCode: 35,
            modifierMask: NSEvent.ModifierFlags.option.rawValue
        )
        #expect(binding.displayString == "⌥P")
    }

    /// ⌘⌥S のdisplayStringに修飾キーと文字が含まれることを検証
    @Test func hotkeyBinding_DisplayString_CommandOption() {
        let flags = NSEvent.ModifierFlags([.command, .option])
        let binding = HotkeyBinding(keyCode: 1, modifierMask: flags.rawValue)
        let str = binding.displayString
        #expect(str.contains("⌘"))
        #expect(str.contains("⌥"))
        #expect(str.contains("S"))
    }

    /// 不明なキーコードで "Key(N)" 形式になることを検証
    @Test func hotkeyBinding_KeyName_Unknown() {
        let name = HotkeyBinding.keyName(for: 200)
        #expect(name == "Key(200)")
    }

    /// Tab キーコード(48)が "Tab" になることを検証
    @Test func hotkeyBinding_KeyName_Tab() {
        #expect(HotkeyBinding.keyName(for: 48) == "Tab")
    }

    /// Space キーコード(49)が "Space" になることを検証
    @Test func hotkeyBinding_KeyName_Space() {
        #expect(HotkeyBinding.keyName(for: 49) == "Space")
    }

    // MARK: - HotkeyBinding.keyName 主要キーコードマッピング

    /// A キーコード(0)が "A" になることを検証
    @Test func hotkeyBinding_KeyName_A() {
        #expect(HotkeyBinding.keyName(for: 0) == "A")
    }

    /// H キーコード(4)が "H" になることを検証
    @Test func hotkeyBinding_KeyName_H() {
        #expect(HotkeyBinding.keyName(for: 4) == "H")
    }

    /// G キーコード(5)が "G" になることを検証
    @Test func hotkeyBinding_KeyName_G() {
        #expect(HotkeyBinding.keyName(for: 5) == "G")
    }

    /// P キーコード(35)が "P" になることを検証
    @Test func hotkeyBinding_KeyName_P() {
        #expect(HotkeyBinding.keyName(for: 35) == "P")
    }

    /// Return キーコード(36)が "Return" になることを検証
    @Test func hotkeyBinding_KeyName_Return() {
        #expect(HotkeyBinding.keyName(for: 36) == "Return")
    }

    /// Delete キーコード(51)が "Delete" になることを検証
    @Test func hotkeyBinding_KeyName_Delete() {
        #expect(HotkeyBinding.keyName(for: 51) == "Delete")
    }

    // MARK: - HotkeyManager バインディング保存・読み出し

    /// カスタムバインディングを保存して読み出せることを検証
    @Test func hotkeyManager_SetAndGetBinding() throws {
        let (manager, cleanup) = try freshManager()
        defer { cleanup() }
        let custom = HotkeyBinding(
            keyCode: 12,
            modifierMask: NSEvent.ModifierFlags([.option, .shift]).rawValue
        )
        manager.setBinding(custom, for: .toggleVisibility)
        let retrieved = manager.binding(for: .toggleVisibility)
        #expect(retrieved == custom)
    }

    /// 未設定時にデフォルトバインディングが返されることを検証
    @Test func hotkeyManager_DefaultWhenNotSet() throws {
        let (manager, cleanup) = try freshManager()
        defer { cleanup() }
        let binding = manager.binding(for: .managementPanel)
        #expect(binding == HotkeyAction.managementPanel.defaultBinding)
    }

    /// resetBinding でデフォルトに戻ることを検証
    @Test func hotkeyManager_ResetBinding() throws {
        let (manager, cleanup) = try freshManager()
        defer { cleanup() }
        let custom = HotkeyBinding(keyCode: 12, modifierMask: NSEvent.ModifierFlags.command.rawValue)
        manager.setBinding(custom, for: .toggleGhostMode)
        manager.resetBinding(for: .toggleGhostMode)
        let binding = manager.binding(for: .toggleGhostMode)
        #expect(binding == HotkeyAction.toggleGhostMode.defaultBinding)
    }

    /// resetAllBindings で全アクションがデフォルトに戻ることを検証
    @Test func hotkeyManager_ResetAllBindings() throws {
        let (manager, cleanup) = try freshManager()
        defer { cleanup() }
        for action in HotkeyAction.allCases {
            let custom = HotkeyBinding(keyCode: 12, modifierMask: NSEvent.ModifierFlags.command.rawValue)
            manager.setBinding(custom, for: action)
        }
        manager.resetAllBindings()
        for action in HotkeyAction.allCases {
            #expect(manager.binding(for: action) == action.defaultBinding)
        }
    }

    // MARK: - 競合チェック

    /// ⌘Spaceがシステム競合として検出されることを検証
    @Test func hotkeyManager_HasSystemConflict_CommandSpace() throws {
        let (manager, cleanup) = try freshManager()
        defer { cleanup() }
        let binding = HotkeyBinding(
            keyCode: 49,
            modifierMask: NSEvent.ModifierFlags.command.rawValue
        )
        #expect(manager.hasSystemConflict(binding))
    }

    /// ⌥Pはシステム競合なしであることを検証
    @Test func hotkeyManager_NoSystemConflict_OptionP() throws {
        let (manager, cleanup) = try freshManager()
        defer { cleanup() }
        let binding = HotkeyBinding(
            keyCode: 35,
            modifierMask: NSEvent.ModifierFlags.option.rawValue
        )
        #expect(!manager.hasSystemConflict(binding))
    }

    /// 同じバインディングを別アクションに設定するとSobani競合が検出されることを検証
    @Test func hotkeyManager_HasSobaniConflict() throws {
        let (manager, cleanup) = try freshManager()
        defer { cleanup() }
        let conflicting = HotkeyBinding(
            keyCode: 12,
            modifierMask: NSEvent.ModifierFlags.option.rawValue
        )
        manager.setBinding(conflicting, for: .toggleVisibility)
        #expect(manager.hasSobaniConflict(conflicting, excluding: .toggleGhostMode))
    }

    /// 自分自身を除外した場合は競合なしとなることを検証
    @Test func hotkeyManager_NoSobaniConflict_ExcludingSelf() throws {
        let (manager, cleanup) = try freshManager()
        defer { cleanup() }
        let binding = manager.binding(for: .toggleVisibility)
        #expect(!manager.hasSobaniConflict(binding, excluding: .toggleVisibility))
    }
}
