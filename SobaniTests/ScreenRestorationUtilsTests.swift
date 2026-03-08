import Cocoa
import Testing
@testable import Sobani

@Suite("ScreenRestorationUtils Tests")
struct ScreenRestorationUtilsTests {

    // MARK: - clampOrigin Tests

    @Test("clampOrigin: スクリーン内の原点はそのまま")
    func clampOriginInsideScreen() {
        let origin = NSPoint(x: 100, y: 100)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == 100)
        #expect(result.y == 100)
    }

    @Test("clampOrigin: 左側はみ出し")
    func clampOriginLeftOverflow() {
        let origin = NSPoint(x: -50, y: 100)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == 0)
        #expect(result.y == 100)
    }

    @Test("clampOrigin: 右側はみ出し")
    func clampOriginRightOverflow() {
        let origin = NSPoint(x: 1800, y: 100)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == 1720)
        #expect(result.y == 100)
    }

    @Test("clampOrigin: 下側はみ出し")
    func clampOriginBottomOverflow() {
        let origin = NSPoint(x: 100, y: -50)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == 100)
        #expect(result.y == 0)
    }

    @Test("clampOrigin: 上側はみ出し")
    func clampOriginTopOverflow() {
        let origin = NSPoint(x: 100, y: 950)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == 100)
        #expect(result.y == 880)
    }

    @Test("clampOrigin: 四方向はみ出し（左下角にクランプ）")
    func clampOriginAllDirections() {
        let origin = NSPoint(x: -100, y: -100)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == 0)
        #expect(result.y == 0)
    }

    @Test("clampOrigin: ウィンドウがスクリーンより大きい場合はクランプしない")
    func clampOriginOversizedWindow() {
        let origin = NSPoint(x: -100, y: -50)
        let windowSize = NSSize(width: 2000, height: 1200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == -100)
        #expect(result.y == -50)
    }

    @Test("clampOrigin: ウィンドウ幅のみスクリーンより大きい")
    func clampOriginOversizedWidth() {
        let origin = NSPoint(x: -100, y: -50)
        let windowSize = NSSize(width: 2000, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == -100)
        #expect(result.y == 0)
    }

    @Test("clampOrigin: 非原点スクリーン（セカンダリモニタ）")
    func clampOriginSecondaryMonitor() {
        let origin = NSPoint(x: 1800, y: 100)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == 1920)
        #expect(result.y == 100)
    }

    @Test("clampOrigin: ウィンドウサイズがスクリーンと同じ")
    func clampOriginExactFit() {
        let origin = NSPoint(x: 0, y: 0)
        let windowSize = NSSize(width: 1920, height: 1080)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
        #expect(result.x == 0)
        #expect(result.y == 0)
    }

    // MARK: - computeRestoredOrigin Tests

    @Test("computeRestoredOrigin: 同じスクリーン位置")
    func computeRestoredOriginSameScreen() {
        let savedOrigin = NSPoint(x: 100, y: 200)
        let oldFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let currentFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.computeRestoredOrigin(
            savedOrigin: savedOrigin, oldScreenFrame: oldFrame, currentScreenFrame: currentFrame
        )
        #expect(result.x == 100)
        #expect(result.y == 200)
    }

    @Test("computeRestoredOrigin: スクリーン移動（右方向）")
    func computeRestoredOriginScreenMoved() {
        let savedOrigin = NSPoint(x: 100, y: 200)
        let oldFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let currentFrame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.computeRestoredOrigin(
            savedOrigin: savedOrigin, oldScreenFrame: oldFrame, currentScreenFrame: currentFrame
        )
        #expect(result.x == 2020)
        #expect(result.y == 200)
    }

    @Test("computeRestoredOrigin: oldScreenFrameがnil")
    func computeRestoredOriginNilOldFrame() {
        let savedOrigin = NSPoint(x: 100, y: 200)
        let currentFrame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.computeRestoredOrigin(
            savedOrigin: savedOrigin, oldScreenFrame: nil, currentScreenFrame: currentFrame
        )
        #expect(result.x == 100)
        #expect(result.y == 200)
    }

    @Test("computeRestoredOrigin: スクリーン移動（左上方向）")
    func computeRestoredOriginScreenMovedUpLeft() {
        let savedOrigin = NSPoint(x: 500, y: 500)
        let oldFrame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        let currentFrame = NSRect(x: 0, y: 500, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.computeRestoredOrigin(
            savedOrigin: savedOrigin, oldScreenFrame: oldFrame, currentScreenFrame: currentFrame
        )
        // relativeX = 500 - 1920 = -1420, relativeY = 500 - 0 = 500
        // newX = 0 + (-1420) = -1420, newY = 500 + 500 = 1000
        #expect(result.x == -1420)
        #expect(result.y == 1000)
    }

    @Test("computeRestoredOrigin: 負座標のスクリーン")
    func computeRestoredOriginNegativeCoordinates() {
        let savedOrigin = NSPoint(x: -1820, y: 100)
        let oldFrame = NSRect(x: -1920, y: 0, width: 1920, height: 1080)
        let currentFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.computeRestoredOrigin(
            savedOrigin: savedOrigin, oldScreenFrame: oldFrame, currentScreenFrame: currentFrame
        )
        // relativeX = -1820 - (-1920) = 100, relativeY = 100 - 0 = 100
        #expect(result.x == 100)
        #expect(result.y == 100)
    }

    // MARK: - isFrameMatch Tests

    @Test("isFrameMatch: 完全一致")
    func isFrameMatchExact() {
        let frameA = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let frameB = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        #expect(ScreenRestorationUtils.isFrameMatch(frameA, frameB, tolerance: 100))
    }

    @Test("isFrameMatch: tolerance以内の差")
    func isFrameMatchWithinTolerance() {
        let frameA = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let frameB = NSRect(x: 50, y: 50, width: 1970, height: 1130)
        #expect(ScreenRestorationUtils.isFrameMatch(frameA, frameB, tolerance: 100))
    }

    @Test("isFrameMatch: tolerance超え")
    func isFrameMatchBeyondTolerance() {
        let frameA = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let frameB = NSRect(x: 200, y: 0, width: 1920, height: 1080)
        #expect(!ScreenRestorationUtils.isFrameMatch(frameA, frameB, tolerance: 100))
    }

    @Test("isFrameMatch: ちょうどtolerance")
    func isFrameMatchExactTolerance() {
        let frameA = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let frameB = NSRect(x: 100, y: 0, width: 1920, height: 1080)
        #expect(ScreenRestorationUtils.isFrameMatch(frameA, frameB, tolerance: 100))
    }

    @Test("isFrameMatch: サイズ不一致")
    func isFrameMatchSizeMismatch() {
        let frameA = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let frameB = NSRect(x: 0, y: 0, width: 2560, height: 1440)
        #expect(!ScreenRestorationUtils.isFrameMatch(frameA, frameB, tolerance: 100))
    }

    @Test("isFrameMatch: tolerance 0 で完全一致")
    func isFrameMatchZeroToleranceExact() {
        let frameA = NSRect(x: 100, y: 200, width: 1920, height: 1080)
        let frameB = NSRect(x: 100, y: 200, width: 1920, height: 1080)
        #expect(ScreenRestorationUtils.isFrameMatch(frameA, frameB, tolerance: 0))
    }

    @Test("isFrameMatch: tolerance 0 でわずかな差")
    func isFrameMatchZeroToleranceTinyDiff() {
        let frameA = NSRect(x: 100, y: 200, width: 1920, height: 1080)
        let frameB = NSRect(x: 100.1, y: 200, width: 1920, height: 1080)
        #expect(!ScreenRestorationUtils.isFrameMatch(frameA, frameB, tolerance: 0))
    }
}
