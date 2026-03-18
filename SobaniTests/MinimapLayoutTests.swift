import XCTest
@testable import Sobani

final class MinimapLayoutTests: XCTestCase {

    // MARK: - Basic Window Positioning

    func testWindowAtOriginMapsCorrectly() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: CGPoint(x: 10, y: 10),
            rawTotalBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        // Window at bottom-left corner, 100x200
        let rect = layout.windowRect(for: 0, originY: 0, width: 100, height: 200)

        // scaledX = (0 - 0) * 0.5 + 10 = 10
        // scaledY = (1080 - (0 - 0 + 200)) * 0.5 + 10 = 880 * 0.5 + 10 = 450
        // scaledW = 100 * 0.5 = 50
        // scaledH = 200 * 0.5 = 100
        XCTAssertEqual(rect.origin.x, 10, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 450, accuracy: 0.001)
        XCTAssertEqual(rect.width, 50, accuracy: 0.001)
        XCTAssertEqual(rect.height, 100, accuracy: 0.001)
    }

    func testWindowAtTopRightMapsToSwiftUITopRight() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: CGPoint(x: 10, y: 10),
            rawTotalBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        // Window at top-right in macOS coords (origin at bottom-left)
        let rect = layout.windowRect(for: 1820, originY: 980, width: 100, height: 100)

        // scaledX = (1820 - 0) * 0.5 + 10 = 920
        // scaledY = (1080 - (980 - 0 + 100)) * 0.5 + 10 = 0 * 0.5 + 10 = 10
        XCTAssertEqual(rect.origin.x, 920, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 10, accuracy: 0.001)
    }

    func testScaleAppliedToSize() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.25,
            offset: .zero,
            rawTotalBounds: CGRect(x: 0, y: 0, width: 3840, height: 2160)
        )

        let rect = layout.windowRect(for: 0, originY: 0, width: 400, height: 300)

        XCTAssertEqual(rect.width, 100, accuracy: 0.001)
        XCTAssertEqual(rect.height, 75, accuracy: 0.001)
    }

    // MARK: - Multi-Screen with Negative Origin

    func testNegativeOriginScreen() throws {
        // Two screens: main at (0,0) 1920x1080, left at (-1920,0) 1920x1080
        // totalBounds = (-1920, 0, 3840, 1080)
        let layout = MinimapLayout(
            screens: [],
            scale: 0.1,
            offset: CGPoint(x: 20, y: 20),
            rawTotalBounds: CGRect(x: -1920, y: 0, width: 3840, height: 1080)
        )

        // Window on left screen at (-1000, 500) size 200x300
        let rect = layout.windowRect(for: -1000, originY: 500, width: 200, height: 300)

        // scaledX = (-1000 - (-1920)) * 0.1 + 20 = 920 * 0.1 + 20 = 112
        // scaledY = (1080 - (500 - 0 + 300)) * 0.1 + 20 = 280 * 0.1 + 20 = 48
        XCTAssertEqual(rect.origin.x, 112, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 48, accuracy: 0.001)
        XCTAssertEqual(rect.width, 20, accuracy: 0.001)
        XCTAssertEqual(rect.height, 30, accuracy: 0.001)
    }

    func testWindowOnMainScreenWithNegativeOriginBounds() throws {
        // totalBounds = (-1920, 0, 3840, 1080)
        let layout = MinimapLayout(
            screens: [],
            scale: 0.1,
            offset: CGPoint(x: 20, y: 20),
            rawTotalBounds: CGRect(x: -1920, y: 0, width: 3840, height: 1080)
        )

        // Window on main screen at (100, 100) size 200x200
        let rect = layout.windowRect(for: 100, originY: 100, width: 200, height: 200)

        // scaledX = (100 - (-1920)) * 0.1 + 20 = 2020 * 0.1 + 20 = 222
        // scaledY = (1080 - (100 - 0 + 200)) * 0.1 + 20 = 780 * 0.1 + 20 = 98
        XCTAssertEqual(rect.origin.x, 222, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 98, accuracy: 0.001)
    }

    // MARK: - macOSDelta

    func testMacOSDeltaBasicConversion() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: .zero,
            rawTotalBounds: .zero
        )

        // Positive width → positive X, positive height → negative Y (SwiftUI→macOS Y flip)
        let delta = layout.macOSDelta(from: CGSize(width: 50, height: 30))
        XCTAssertEqual(delta.x, 100, accuracy: 0.001)
        XCTAssertEqual(delta.y, -60, accuracy: 0.001)
    }

    func testMacOSDeltaScaleFactor() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.1,
            offset: .zero,
            rawTotalBounds: .zero
        )

        let delta = layout.macOSDelta(from: CGSize(width: 10, height: 20))
        XCTAssertEqual(delta.x, 100, accuracy: 0.001)
        XCTAssertEqual(delta.y, -200, accuracy: 0.001)
    }

    func testMacOSDeltaZero() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: .zero,
            rawTotalBounds: .zero
        )

        let delta = layout.macOSDelta(from: .zero)
        XCTAssertEqual(delta.x, 0, accuracy: 0.001)
        XCTAssertEqual(delta.y, 0, accuracy: 0.001)
    }
}
