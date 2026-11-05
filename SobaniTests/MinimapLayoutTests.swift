import CoreGraphics
import Foundation
import Testing
@testable import Sobani

@Suite struct MinimapLayoutTests {

    // MARK: - Basic Window Positioning

    @Test func testWindowAtOriginMapsCorrectly() throws {
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
        #expect(abs(rect.origin.x - 10) < 0.001)
        #expect(abs(rect.origin.y - 450) < 0.001)
        #expect(abs(rect.width - 50) < 0.001)
        #expect(abs(rect.height - 100) < 0.001)
    }

    @Test func testWindowAtTopRightMapsToSwiftUITopRight() throws {
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
        #expect(abs(rect.origin.x - 920) < 0.001)
        #expect(abs(rect.origin.y - 10) < 0.001)
    }

    @Test func testScaleAppliedToSize() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.25,
            offset: .zero,
            rawTotalBounds: CGRect(x: 0, y: 0, width: 3840, height: 2160)
        )

        let rect = layout.windowRect(for: 0, originY: 0, width: 400, height: 300)

        #expect(abs(rect.width - 100) < 0.001)
        #expect(abs(rect.height - 75) < 0.001)
    }

    // MARK: - Multi-Screen with Negative Origin

    @Test func testNegativeOriginScreen() throws {
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
        #expect(abs(rect.origin.x - 112) < 0.001)
        #expect(abs(rect.origin.y - 48) < 0.001)
        #expect(abs(rect.width - 20) < 0.001)
        #expect(abs(rect.height - 30) < 0.001)
    }

    @Test func testWindowOnMainScreenWithNegativeOriginBounds() throws {
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
        #expect(abs(rect.origin.x - 222) < 0.001)
        #expect(abs(rect.origin.y - 98) < 0.001)
    }

    // MARK: - macOSDelta

    @Test func testMacOSDeltaBasicConversion() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: .zero,
            rawTotalBounds: .zero
        )

        // Positive width → positive X, positive height → negative Y (SwiftUI→macOS Y flip)
        let delta = layout.macOSDelta(from: CGSize(width: 50, height: 30))
        #expect(abs(delta.x - 100) < 0.001)
        #expect(abs(delta.y - (-60)) < 0.001)
    }

    @Test func testMacOSDeltaScaleFactor() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.1,
            offset: .zero,
            rawTotalBounds: .zero
        )

        let delta = layout.macOSDelta(from: CGSize(width: 10, height: 20))
        #expect(abs(delta.x - 100) < 0.001)
        #expect(abs(delta.y - (-200)) < 0.001)
    }

    @Test func testMacOSDeltaZero() throws {
        let layout = MinimapLayout(
            screens: [],
            scale: 0.5,
            offset: .zero,
            rawTotalBounds: .zero
        )

        let delta = layout.macOSDelta(from: .zero)
        #expect(abs(delta.x - 0) < 0.001)
        #expect(abs(delta.y - 0) < 0.001)
    }

    /// 倍率が 0 の（描画できない）レイアウトではドラッグ量が無限大にならないことを検証
    @Test func testMacOSDeltaWithZeroScaleIsZero() throws {
        let layout = MinimapLayout(screens: [], scale: 0, offset: .zero, rawTotalBounds: .zero)
        let delta = layout.macOSDelta(from: CGSize(width: 10, height: 20))
        #expect(delta.x.isFinite && delta.y.isFinite)
        #expect(abs(delta.x) < AppConstants.floatingPointTolerance)
        #expect(abs(delta.y) < AppConstants.floatingPointTolerance)
    }

    // MARK: - calculate

    private let mainScreen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    /// 範囲が空（.zero・.null）の場合は空のレイアウトになり、NaN・無限大を生まないことを検証
    @Test(arguments: [CGRect.zero, CGRect.null, CGRect(x: 0, y: 0, width: 100, height: 0)])
    @MainActor func testCalculateWithEmptyBoundsIsEmpty(bounds: CGRect) throws {
        let layout = MinimapLayout.calculate(
            in: CGSize(width: 400, height: 300), precomputedBounds: bounds, screenFrames: [mainScreen]
        )
        #expect(layout.isEmpty)
        #expect(layout.scale.isFinite)
        #expect(layout.offset.x.isFinite && layout.offset.y.isFinite)
    }

    /// 表示領域が余白（両側）より小さい場合は空のレイアウトになり、負の倍率で反転しないことを検証
    @Test(arguments: [CGSize.zero, CGSize(width: 20, height: 300), CGSize(width: 400, height: 30)])
    @MainActor func testCalculateWithTooSmallAreaIsEmpty(size: CGSize) throws {
        let layout = MinimapLayout.calculate(in: size, screenFrames: [mainScreen])
        #expect(layout.isEmpty)
        #expect(layout.scale > 0)
    }

    /// スクリーンがない場合は空のレイアウトになることを検証
    @Test @MainActor func testCalculateWithoutScreensIsEmpty() throws {
        let layout = MinimapLayout.calculate(in: CGSize(width: 400, height: 300), screenFrames: [])
        #expect(layout.isEmpty)
    }

    /// 通常の範囲では正の倍率で中央に配置されることを検証
    @Test @MainActor func testCalculateCentersContent() throws {
        let size = CGSize(width: 400, height: 300)
        let padding = AppConstants.managementMinimapPadding
        let layout = MinimapLayout.calculate(in: size, screenFrames: [mainScreen])
        let screen = try #require(layout.screens.first)
        let expectedScale = min((size.width - padding * 2) / 1920, (size.height - padding * 2) / 1080)
        #expect(!layout.isEmpty)
        #expect(abs(layout.scale - expectedScale) < AppConstants.floatingPointTolerance)
        #expect(abs(screen.midX - size.width / 2) < AppConstants.floatingPointTolerance)
        #expect(abs(screen.midY - size.height / 2) < AppConstants.floatingPointTolerance)
    }

    // MARK: - totalBounds

    /// 画面外のウィンドウも範囲に含めることを検証
    @Test func testTotalBoundsIncludesOffscreenWindows() throws {
        let offscreen = CGRect(x: -500, y: 2000, width: 200, height: 100)
        let bounds = MinimapLayout.totalBounds(screenFrames: [mainScreen], windowFrames: [offscreen])
        #expect(bounds.contains(mainScreen))
        #expect(bounds.contains(offscreen))
    }

    /// スクリーンもウィンドウもない場合は .null になることを検証
    @Test func testTotalBoundsOfNothingIsNull() throws {
        #expect(MinimapLayout.totalBounds(screenFrames: [], windowFrames: []).isNull)
    }
}
