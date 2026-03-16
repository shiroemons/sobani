import AppKit
import Testing
@testable import Sobani

/// KeyCodeMapperのキーコード・修飾キー変換ロジックを検証するテスト
@Suite @MainActor struct KeyCodeMapperTests {

    // MARK: - displayName テスト

    /// アルファベットキーコードが正しい表示名に変換されることを検証
    @Test func displayName_letterKeys() {
        #expect(KeyCodeMapper.displayName(for: 0) == "A")   // kVK_ANSI_A = 0
        #expect(KeyCodeMapper.displayName(for: 4) == "H")   // kVK_ANSI_H = 4
        #expect(KeyCodeMapper.displayName(for: 5) == "G")   // kVK_ANSI_G = 5
        #expect(KeyCodeMapper.displayName(for: 46) == "M")  // kVK_ANSI_M = 46
    }

    /// 数字キーコードが正しい表示名に変換されることを検証
    @Test func displayName_numberKeys() {
        #expect(KeyCodeMapper.displayName(for: 29) == "0")  // kVK_ANSI_0 = 29
        #expect(KeyCodeMapper.displayName(for: 18) == "1")  // kVK_ANSI_1 = 18
    }

    /// ファンクションキーコードが正しい表示名に変換されることを検証
    @Test func displayName_functionKeys() {
        #expect(KeyCodeMapper.displayName(for: 122) == "F1")   // kVK_F1 = 122
        #expect(KeyCodeMapper.displayName(for: 111) == "F12")  // kVK_F12 = 111
    }

    /// 特殊キーコードが正しい表示名に変換されることを検証
    @Test func displayName_specialKeys() {
        #expect(KeyCodeMapper.displayName(for: 49) == "Space")   // kVK_Space = 49
        #expect(KeyCodeMapper.displayName(for: 53) == "ESC")     // kVK_Escape = 53
        #expect(KeyCodeMapper.displayName(for: 36) == "Return")  // kVK_Return = 36
    }

    /// 未知のキーコードがKey(n)形式で返されることを検証
    @Test func displayName_unknownKey() {
        #expect(KeyCodeMapper.displayName(for: 999) == "Key(999)")
    }

    // MARK: - modifierDisplayName テスト

    /// Optionキーが⌥記号に変換されることを検証
    @Test func modifierDisplayName_option() {
        #expect(KeyCodeMapper.modifierDisplayName(.option) == "⌥")
    }

    /// Commandキーが⌘記号に変換されることを検証
    @Test func modifierDisplayName_command() {
        #expect(KeyCodeMapper.modifierDisplayName(.command) == "⌘")
    }

    /// 複数の修飾キーが全て含まれることを検証
    @Test func modifierDisplayName_multiple() {
        let mods: NSEvent.ModifierFlags = [.command, .shift]
        let result = KeyCodeMapper.modifierDisplayName(mods)
        #expect(result.contains("⇧"))
        #expect(result.contains("⌘"))
    }

    /// 修飾キーの表示順が⌃⌥⇧⌘になることを検証
    @Test func modifierDisplayName_order() {
        let mods: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        #expect(KeyCodeMapper.modifierDisplayName(mods) == "⌃⌥⇧⌘")
    }

    // MARK: - shortcutDisplayString テスト

    /// Option+HキーのショートカットがVK_ANSIに正しく変換されることを検証
    @Test func shortcutDisplayString_optionH() {
        #expect(KeyCodeMapper.shortcutDisplayString(keyCode: 4, modifiers: .option) == "⌥H")
    }

    /// Command+Shift+MキーのショートカットがVK_ANSIに正しく変換されることを検証
    @Test func shortcutDisplayString_commandShiftM() {
        #expect(
            KeyCodeMapper.shortcutDisplayString(keyCode: 46, modifiers: [.command, .shift]) == "⇧⌘M"
        )
    }
}
