import Cocoa
import Testing
@testable import Sobani

@Suite("SnapUtils Tests")
struct SnapUtilsTests {

    private let tolerance = AppConstants.floatingPointTolerance
    private let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
    private let threshold = AppConstants.snapThreshold

    // MARK: - 基本: しきい値内でスナップ発生

    @Test("しきい値内でスナップ発生: X軸左端同士")
    func snapWithinThresholdXMinMin() {
        // ドラッグ中ウィンドウが別ウィンドウの左端から threshold-1 の距離にある
        let dragging = NSRect(x: 201, y: 100, width: 100, height: 100)
        let other = NSRect(x: 207, y: 200, width: 100, height: 100)
        // dist = |201 - 207| = 6 < 8
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX - 6) < tolerance)
    }

    @Test("しきい値外でスナップなし: X軸")
    func noSnapOutsideThresholdX() {
        let dragging = NSRect(x: 200, y: 100, width: 100, height: 100)
        let other = NSRect(x: 300, y: 100, width: 100, height: 100)
        // minX距離=100, maxX-minX距離=200, いずれもthreshold超え
        // 画面端を遠ざけるため screenFrame を遠い位置に
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX) < tolerance)
    }

    @Test("しきい値外でスナップなし: Y軸")
    func noSnapOutsideThresholdY() {
        let dragging = NSRect(x: 100, y: 200, width: 100, height: 100)
        let other = NSRect(x: 100, y: 300, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaY) < tolerance)
    }

    @Test("境界値: threshold-1 でスナップ発生")
    func snapAtThresholdMinusOne() {
        let dist: CGFloat = threshold - 1
        let dragging = NSRect(x: 100, y: 100, width: 100, height: 100)
        let other = NSRect(x: 100 + dist, y: 500, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX - dist) < tolerance)
    }

    @Test("境界値: threshold ちょうどでスナップなし")
    func noSnapAtExactThreshold() {
        let dist: CGFloat = threshold
        let dragging = NSRect(x: 100, y: 100, width: 100, height: 100)
        let other = NSRect(x: 100 + dist, y: 500, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX) < tolerance)
    }

    // MARK: - 画面端スナップ

    @Test("画面端スナップ: 左端")
    func snapToScreenLeftEdge() {
        // minX が画面左端 (0) に近い
        let dragging = NSRect(x: 5, y: 100, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [],
            screenVisibleFrame: screenFrame,
            threshold: threshold
        )
        #expect(abs(result.deltaX - (-5)) < tolerance)
    }

    @Test("画面端スナップ: 右端")
    func snapToScreenRightEdge() {
        // maxX が画面右端 (1920) に近い
        let dragging = NSRect(x: 1814, y: 100, width: 100, height: 100)
        // maxX = 1914, screenFrame.maxX = 1920, dist = 6 < 8
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [],
            screenVisibleFrame: screenFrame,
            threshold: threshold
        )
        #expect(abs(result.deltaX - 6) < tolerance)
    }

    @Test("画面端スナップ: 下端")
    func snapToScreenBottomEdge() {
        // minY が画面下端 (0) に近い
        let dragging = NSRect(x: 100, y: 4, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [],
            screenVisibleFrame: screenFrame,
            threshold: threshold
        )
        #expect(abs(result.deltaY - (-4)) < tolerance)
    }

    @Test("画面端スナップ: 上端")
    func snapToScreenTopEdge() {
        // maxY が画面上端 (1080) に近い
        let dragging = NSRect(x: 100, y: 975, width: 100, height: 100)
        // maxY = 1075, screenFrame.maxY = 1080, dist = 5 < 8
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [],
            screenVisibleFrame: screenFrame,
            threshold: threshold
        )
        #expect(abs(result.deltaY - 5) < tolerance)
    }

    // MARK: - ウィンドウ間スナップ

    @Test("ウィンドウ間: 右に隣接配置（dragging.maxX → other.minX）")
    func snapWindowAdjacentRight() {
        // dragging.maxX = 300, other.minX = 305, dist = 5 < 8
        let dragging = NSRect(x: 200, y: 100, width: 100, height: 100)
        let other = NSRect(x: 305, y: 100, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX - 5) < tolerance)
    }

    @Test("ウィンドウ間: 左に隣接配置（dragging.minX → other.maxX）")
    func snapWindowAdjacentLeft() {
        // dragging.minX = 200, other.maxX = 204, dist = 4 < 8
        let dragging = NSRect(x: 200, y: 100, width: 100, height: 100)
        let other = NSRect(x: 100, y: 100, width: 104, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX - 4) < tolerance)
    }

    @Test("ウィンドウ間: 上に隣接配置（dragging.maxY → other.minY）")
    func snapWindowAdjacentTop() {
        // dragging.maxY = 200, other.minY = 203, dist = 3 < 8
        let dragging = NSRect(x: 100, y: 100, width: 100, height: 100)
        let other = NSRect(x: 100, y: 203, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaY - 3) < tolerance)
    }

    @Test("ウィンドウ間: 下に隣接配置（dragging.minY → other.maxY）")
    func snapWindowAdjacentBottom() {
        // dragging.minY = 100, other.maxY = 106, dist = 6 < 8
        let dragging = NSRect(x: 100, y: 100, width: 100, height: 100)
        let other = NSRect(x: 100, y: 0, width: 100, height: 106)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaY - 6) < tolerance)
    }

    @Test("ウィンドウ間: X軸中心揃え")
    func snapWindowCenterX() {
        // dragging.midX = 250, other.midX = 253, dist = 3 < 8
        let dragging = NSRect(x: 200, y: 100, width: 100, height: 100)
        let other = NSRect(x: 203, y: 300, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX - 3) < tolerance)
    }

    @Test("ウィンドウ間: Y軸中心揃え")
    func snapWindowCenterY() {
        // dragging.midY = 150, other.midY = 155, dist = 5 < 8
        let dragging = NSRect(x: 100, y: 100, width: 100, height: 100)
        let other = NSRect(x: 300, y: 105, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaY - 5) < tolerance)
    }

    // MARK: - X/Y 独立判定

    @Test("X/Y独立: Xのみスナップ")
    func snapXOnly() {
        // X: dist=3 < 8 でスナップ, Y: dist=50 > 8 でスナップなし
        let dragging = NSRect(x: 200, y: 100, width: 100, height: 100)
        let other = NSRect(x: 203, y: 500, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX - 3) < tolerance)
        #expect(abs(result.deltaY) < tolerance)
    }

    @Test("X/Y独立: Yのみスナップ")
    func snapYOnly() {
        // X: dist=50 > 8 でスナップなし, Y: dist=4 < 8 でスナップ
        let dragging = NSRect(x: 100, y: 200, width: 100, height: 100)
        let other = NSRect(x: 500, y: 204, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX) < tolerance)
        #expect(abs(result.deltaY - 4) < tolerance)
    }

    @Test("X/Y独立: 両方スナップ")
    func snapBothAxes() {
        // X: dist=3, Y: dist=5 ともにスナップ
        let dragging = NSRect(x: 200, y: 200, width: 100, height: 100)
        let other = NSRect(x: 203, y: 205, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX - 3) < tolerance)
        #expect(abs(result.deltaY - 5) < tolerance)
    }

    @Test("X/Y独立: どちらもスナップなし")
    func snapNeitherAxis() {
        let dragging = NSRect(x: 100, y: 100, width: 100, height: 100)
        let other = NSRect(x: 500, y: 500, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX) < tolerance)
        #expect(abs(result.deltaY) < tolerance)
    }

    // MARK: - エッジケース

    @Test("エッジケース: 他ウィンドウ0個（画面端のみ評価）")
    func snapNoOtherWindows() {
        // 画面左端に近い
        let dragging = NSRect(x: 3, y: 100, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [],
            screenVisibleFrame: screenFrame,
            threshold: threshold
        )
        #expect(abs(result.deltaX - (-3)) < tolerance)
    }

    @Test("エッジケース: 複数ウィンドウで最近接を選択")
    func snapClosestOfMultipleWindows() {
        let dragging = NSRect(x: 200, y: 100, width: 100, height: 100)
        // otherA: dist=6, otherB: dist=3 → otherBを選択
        let otherA = NSRect(x: 206, y: 500, width: 100, height: 100)
        let otherB = NSRect(x: 203, y: 600, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [otherA, otherB],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX - 3) < tolerance)
    }

    @Test("エッジケース: delta がゼロの場合は移動なし")
    func snapDeltaZeroMeansNoMove() {
        // 完全一致でスナップ（delta = 0）
        let dragging = NSRect(x: 200, y: 200, width: 100, height: 100)
        let other = NSRect(x: 200, y: 500, width: 100, height: 100)
        let result = SnapUtils.calculateSnap(
            draggingFrame: dragging,
            otherFrames: [other],
            screenVisibleFrame: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            threshold: threshold
        )
        #expect(abs(result.deltaX) < tolerance)
    }
}
