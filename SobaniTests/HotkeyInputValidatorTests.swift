import AppKit
import Carbon.HIToolbox
import Testing
@testable import Sobani

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

    /// 受け付けた修飾キーは HotkeySettings が扱う修飾キーと一致することを検証（判定と保存で同じ集合を使う）
    @Test func acceptedModifiersAreWithinHotkeySettingsSupportedModifiers() throws {
        let allFlags = NSEvent.ModifierFlags.deviceIndependentFlagsMask
        let result = HotkeyInputValidator.evaluate(keyCode: keyH, modifierFlags: allFlags)
        #expect(result == .accept(keyCode: keyH, modifiers: HotkeySettings.supportedModifiers))
    }

    /// HotkeySettings から読んだ修飾キーで重複を判定することを検証
    /// （保存値に Carbon が扱わない修飾キーが混ざっていても読み出し時に除かれ、同じホットキーとして扱われる）
    @Test func duplicatesCompareModifiersReadFromSettings() {
        let pollutedOption = NSEvent.ModifierFlags([.option, .capsLock]).rawValue
        let duplicated: [(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)] = [
            (keyCode: keyH, modifiers: .option),
            (keyCode: keyH, modifiers: HotkeySettings.modifiers(fromStored: Int(pollutedOption), default: [])),
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
