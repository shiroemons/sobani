import Carbon
import Testing
@testable import Sobani

@Suite struct CarbonHotkeyManagerTests {

    // MARK: - 単一修飾キーテスト

    @Test func testCarbonModifiersCommand() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: .command)
        #expect(result == UInt32(cmdKey))
    }

    @Test func testCarbonModifiersOption() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: .option)
        #expect(result == UInt32(optionKey))
    }

    @Test func testCarbonModifiersControl() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: .control)
        #expect(result == UInt32(controlKey))
    }

    @Test func testCarbonModifiersShift() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: .shift)
        #expect(result == UInt32(shiftKey))
    }

    // MARK: - 組み合わせ修飾キーテスト

    @Test func testCarbonModifiersCombined() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: [.option, .shift])
        #expect(result == UInt32(optionKey) | UInt32(shiftKey))
    }

    @Test func testCarbonModifiersAllCombined() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: [.command, .option, .control, .shift])
        let expected = UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey)
        #expect(result == expected)
    }

    // MARK: - 空フラグテスト

    @Test func testCarbonModifiersEmpty() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: [])
        #expect(result == 0)
    }
}
