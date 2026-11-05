import AppKit
import Carbon.HIToolbox
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
        let result = KeyCodeMapper.shortcutDisplayString(keyCode: 46, modifiers: [.command, .shift])
        #expect(result == "⇧⌘M")
    }
}

// MARK: - HotkeyInputValidator

/// 管理パネルのホットキー録音で受け付けるキー入力の検証を検証するテスト
@Suite struct HotkeyInputValidatorTests {
    private let keyH = UInt16(kVK_ANSI_H)
    private let leftArrow = UInt16(kVK_LeftArrow)

    /// Caps Lock・fn・テンキーなど Carbon が扱わない修飾キーだけでは受け付けないことを検証
    @Test(arguments: [
        NSEvent.ModifierFlags(),
        .capsLock,
        .function,
        .numericPad,
        .help,
        [.capsLock, .function, .numericPad],
    ])
    func unsupportedModifiersOnlyAreIgnored(flags: NSEvent.ModifierFlags) {
        #expect(HotkeyInputValidator.evaluate(keyCode: UInt16(kVK_ANSI_H), modifierFlags: flags) == .ignore)
    }

    /// Shift だけでは受け付けないことを検証（矢印キーには fn・テンキーのフラグが付く）
    @Test func shiftOnlyIsIgnored() {
        #expect(HotkeyInputValidator.evaluate(keyCode: keyH, modifierFlags: .shift) == .ignore)
        let arrowFlags: NSEvent.ModifierFlags = [.shift, .function, .numericPad]
        #expect(HotkeyInputValidator.evaluate(keyCode: leftArrow, modifierFlags: arrowFlags) == .ignore)
    }

    /// 対応する修飾キーを含む場合は、余分なフラグを除いた修飾キーで受け付けることを検証
    @Test func supportedModifiersAreAcceptedAndNormalized() {
        let result = HotkeyInputValidator.evaluate(
            keyCode: keyH, modifierFlags: [.option, .shift, .capsLock, .function]
        )
        #expect(result == .accept(keyCode: keyH, modifiers: [.option, .shift]))
        let arrowResult = HotkeyInputValidator.evaluate(
            keyCode: leftArrow, modifierFlags: [.control, .function, .numericPad]
        )
        #expect(arrowResult == .accept(keyCode: leftArrow, modifiers: .control))
    }

    /// Esc は修飾キーの有無にかかわらず録音の取り消しになることを検証
    @Test func escapeCancels() {
        let escape = UInt16(kVK_Escape)
        #expect(HotkeyInputValidator.evaluate(keyCode: escape, modifierFlags: []) == .cancel)
        #expect(HotkeyInputValidator.evaluate(keyCode: escape, modifierFlags: .option) == .cancel)
    }

    /// 重複判定は Carbon が扱わない修飾キーの違いを無視することを検証
    @Test func duplicatesCompareNormalizedModifiers() {
        let duplicated: [(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)] = [
            (keyCode: keyH, modifiers: .option),
            (keyCode: keyH, modifiers: [.option, .capsLock]),
        ]
        let distinct: [(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)] = [
            (keyCode: keyH, modifiers: .option),
            (keyCode: keyH, modifiers: [.option, .shift]),
            (keyCode: UInt16(kVK_ANSI_G), modifiers: .option),
        ]
        #expect(HotkeyInputValidator.containsDuplicates(duplicated))
        #expect(!HotkeyInputValidator.containsDuplicates(distinct))
    }
}
