import Carbon
import XCTest
@testable import Sobani

final class CarbonHotkeyManagerTests: XCTestCase {

    // MARK: - 単一修飾キーテスト

    func testCarbonModifiersCommand() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: .command)
        XCTAssertEqual(result, UInt32(cmdKey))
    }

    func testCarbonModifiersOption() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: .option)
        XCTAssertEqual(result, UInt32(optionKey))
    }

    func testCarbonModifiersControl() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: .control)
        XCTAssertEqual(result, UInt32(controlKey))
    }

    func testCarbonModifiersShift() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: .shift)
        XCTAssertEqual(result, UInt32(shiftKey))
    }

    // MARK: - 組み合わせ修飾キーテスト

    func testCarbonModifiersCombined() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: [.option, .shift])
        XCTAssertEqual(result, UInt32(optionKey) | UInt32(shiftKey))
    }

    func testCarbonModifiersAllCombined() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: [.command, .option, .control, .shift])
        let expected = UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey)
        XCTAssertEqual(result, expected)
    }

    // MARK: - 空フラグテスト

    func testCarbonModifiersEmpty() throws {
        let result = CarbonHotkeyManager.carbonModifiers(from: [])
        XCTAssertEqual(result, 0)
    }
}
