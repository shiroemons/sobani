import AppKit
import Foundation
import Testing
@testable import Sobani

/// WindowStateの非表示機能に関するテスト
@Suite @MainActor struct WindowStateHiddenTests {
    private func fakeScreens() -> [ScreenInfo] {
        [ScreenInfo(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), displayID: 1, isMain: true)]
    }

    @Test func encodeDecodeWithHidden() throws {
        let state = WindowState(
            imageName: "test.png", originX: 100, originY: 200,
            width: 300, height: 400, isFlippedHorizontally: false,
            isHidden: true
        )
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.isHidden == true)
    }

    @Test func hiddenBackwardCompatibility() throws {
        let fields = "\"imageName\":\"test.png\",\"originX\":100,\"originY\":200,"
            + "\"width\":300,\"height\":400,\"isFlippedHorizontally\":false,"
            + "\"rotationAngle\":0,\"opacityLevel\":1.0,\"windowId\":1"
        let json = "[{\(fields)}]"
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.isHidden == false)
    }

    @Test func hiddenDefaultValue() {
        let state = WindowState(
            imageName: "test.png", originX: 100, originY: 200,
            width: 300, height: 400, isFlippedHorizontally: false
        )
        #expect(state.isHidden == false)
    }

    @Test func adjustToVisibleAreaPreservesHidden() {
        let state = WindowState(
            imageName: "test.png", originX: -99999, originY: -99999,
            width: 300, height: 400, isFlippedHorizontally: false,
            isHidden: true
        )
        let adjusted = state.adjustedToVisibleArea(on: fakeScreens())
        #expect(adjusted.isHidden == true)
    }
}
