import AppKit
import Foundation
import Testing
@testable import Sobani

/// WindowStateのゴーストモード機能に関するテスト
@Suite @MainActor struct WindowStateGhostModeTests {
    private func fakeScreens() -> [ScreenInfo] {
        [ScreenInfo(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), displayID: 1, isMain: true)]
    }

    // MARK: - Ghost Mode Tests

    /// isGhostModeがJSONラウンドトリップで保持されることを検証
    @Test func encodeDecodeWithGhostMode() throws {
        let state = WindowState(
            imageName: "test.png", originX: 100, originY: 200,
            width: 300, height: 400, isFlippedHorizontally: false,
            isGhostMode: true
        )
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.isGhostMode == true)
    }

    /// isGhostModeフィールドなしの旧JSONでデフォルトfalseが設定されることを検証
    @Test func ghostModeBackwardCompatibility() throws {
        let fields = "\"imageName\":\"test.png\",\"originX\":100,\"originY\":200,"
            + "\"width\":300,\"height\":400,\"isFlippedHorizontally\":false,"
            + "\"rotationAngle\":0,\"opacityLevel\":1.0,\"windowId\":1"
        let json = "[{\(fields)}]"
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.isGhostMode == false)
    }

    /// デフォルトのisGhostModeがfalseであることを検証
    @Test func ghostModeDefaultValue() {
        let state = WindowState(
            imageName: "test.png", originX: 100, originY: 200,
            width: 300, height: 400, isFlippedHorizontally: false
        )
        #expect(state.isGhostMode == false)
    }

    /// 位置調整時にisGhostModeが保持されることを検証
    @Test func adjustToVisibleAreaPreservesGhostMode() {
        let state = WindowState(
            imageName: "test.png", originX: -99999, originY: -99999,
            width: 300, height: 400, isFlippedHorizontally: false,
            isGhostMode: true
        )
        let adjusted = state.adjustedToVisibleArea(on: fakeScreens())
        #expect(adjusted.isGhostMode == true)
    }
}
