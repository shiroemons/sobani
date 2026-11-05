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
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        #expect(result.x == 100)
        #expect(result.y == 100)
    }

    @Test("clampOrigin: 左側はみ出し")
    func clampOriginLeftOverflow() {
        let origin = NSPoint(x: -50, y: 100)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        #expect(result.x == 0)
        #expect(result.y == 100)
    }

    @Test("clampOrigin: 右側はみ出し")
    func clampOriginRightOverflow() {
        let origin = NSPoint(x: 1800, y: 100)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        #expect(result.x == 1720)
        #expect(result.y == 100)
    }

    @Test("clampOrigin: 下側はみ出し")
    func clampOriginBottomOverflow() {
        let origin = NSPoint(x: 100, y: -50)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        #expect(result.x == 100)
        #expect(result.y == 0)
    }

    @Test("clampOrigin: 上側はみ出し")
    func clampOriginTopOverflow() {
        let origin = NSPoint(x: 100, y: 950)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        #expect(result.x == 100)
        #expect(result.y == 880)
    }

    @Test("clampOrigin: 四方向はみ出し（左下角にクランプ）")
    func clampOriginAllDirections() {
        let origin = NSPoint(x: -100, y: -100)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        #expect(result.x == 0)
        #expect(result.y == 0)
    }

    @Test("clampOrigin: ウィンドウがスクリーンより大きい場合は画面を覆うようクランプ")
    func clampOriginOversizedWindow() {
        let origin = NSPoint(x: -100, y: -50)
        let windowSize = NSSize(width: 2000, height: 1200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        // X は画面を覆う左端（screen.maxX - windowWidth）にクランプ、Y は範囲内なので変化なし
        #expect(result.x == screenFrame.maxX - windowSize.width)
        #expect(result.y == origin.y)
    }

    @Test("clampOrigin: ウィンドウ幅のみスクリーンより大きい場合は幅方向を覆うようクランプ")
    func clampOriginOversizedWidth() {
        let origin = NSPoint(x: -100, y: -50)
        let windowSize = NSSize(width: 2000, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        // X: 画面幅より大きいので右端揃え、Y: 通常クランプで下端
        #expect(result.x == screenFrame.maxX - windowSize.width)
        #expect(result.y == screenFrame.minY)
    }

    @Test("clampOrigin: 非原点スクリーン（セカンダリモニタ）")
    func clampOriginSecondaryMonitor() {
        let origin = NSPoint(x: 1800, y: 100)
        let windowSize = NSSize(width: 200, height: 200)
        let screenFrame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        #expect(result.x == 1920)
        #expect(result.y == 100)
    }

    @Test("clampOrigin: ウィンドウサイズがスクリーンと同じ場合は origin=0 に固定")
    func clampOriginExactFit() {
        let origin = NSPoint(x: 0, y: 0)
        let windowSize = NSSize(width: 1920, height: 1080)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        #expect(result.x == 0)
        #expect(result.y == 0)
    }

    @Test("clampOrigin: 巨大ウィンドウ + 極端な負origin（#121 リグレッション）")
    func clampOriginOversizedWithExtremeNegativeOrigin() {
        // 実例: #121 が origin=(-2971, -2156), size=1716x3432, displayID=4 の縦モニター
        let origin = NSPoint(x: -2971, y: -2156)
        let windowSize = NSSize(width: 1716, height: 3432)
        let screenFrame = NSRect(x: -1440, y: -674, width: 1440, height: 2560)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        // 極端な負origin は画面を覆う両端（lower bound）にクランプされる
        #expect(result.x == screenFrame.maxX - windowSize.width)
        #expect(result.y == screenFrame.maxY - windowSize.height)
    }

    @Test("clampOrigin: 巨大ウィンドウが画面右側にズレすぎ → 画面を覆うよう左にクランプ")
    func clampOriginOversizedShiftedRight() {
        let origin = NSPoint(x: 500, y: 500)
        let windowSize = NSSize(width: 2000, height: 1500)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.clampOrigin(
            origin, windowSize: windowSize, to: screenFrame
        )
        // 正方向にはみ出した origin は画面 minX/minY（upper bound）にクランプ
        #expect(result.x == screenFrame.minX)
        #expect(result.y == screenFrame.minY)
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

    // MARK: - restoredOrigin / isVisible Tests

    private static let tol = AppConstants.floatingPointTolerance
    private static let screenA = NSRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test("restoredOrigin: 見えている位置は意図的なはみ出しもクランプしない")
    func restoredOriginKeepsVisibleOverhang() {
        let rect = NSRect(x: 1800, y: -100, width: 400, height: 300)  // 右と下へはみ出し
        let result = ScreenRestorationUtils.restoredOrigin(
            of: rect, from: Self.screenA, to: Self.screenA, visibleIn: [Self.screenA]
        )
        #expect(abs(result.x - 1800) < Self.tol)
        #expect(abs(result.y - -100) < Self.tol)
    }

    @Test("restoredOrigin: スクリーンの配置が変わったら相対位置を保って平行移動する")
    func restoredOriginTranslatesWithScreen() {
        let moved = NSRect(x: -1920, y: 200, width: 1920, height: 1080)
        let result = ScreenRestorationUtils.restoredOrigin(
            of: NSRect(x: 100, y: 50, width: 400, height: 300),
            from: Self.screenA, to: moved, visibleIn: [moved]
        )
        #expect(abs(result.x - -1820) < Self.tol)
        #expect(abs(result.y - 250) < Self.tol)
    }

    @Test("restoredOrigin: スクリーンサイズが変わったら中心を正規化座標で写像する（mapOrigin と同じ）")
    func restoredOriginScalesWhenScreenSizeChanged() {
        let oldFrame = NSRect(x: 0, y: 0, width: 1000, height: 1000)
        let newFrame = NSRect(x: 0, y: 0, width: 2000, height: 1000)
        let rect = NSRect(x: 200, y: 450, width: 100, height: 100)  // center (250, 500)
        let result = ScreenRestorationUtils.restoredOrigin(
            of: rect, from: oldFrame, to: newFrame, visibleIn: [newFrame]
        )
        // center' = (0.25 * 2000, 0.5 * 1000) = (500, 500)
        #expect(abs(result.x - 450) < Self.tol)
        #expect(abs(result.y - 450) < Self.tol)
    }

    @Test("restoredOrigin: 写像先がほとんど見えない場合だけ復元先スクリーン内にクランプする")
    func restoredOriginClampsWhenNotVisible() {
        // 右端に 20px だけ重なる（しきい値 50px 未満）
        let rect = NSRect(x: 1900, y: 100, width: 400, height: 300)
        let result = ScreenRestorationUtils.restoredOrigin(
            of: rect, from: Self.screenA, to: Self.screenA, visibleIn: [Self.screenA]
        )
        #expect(abs(result.x - 1520) < Self.tol)
        #expect(abs(result.y - 100) < Self.tol)
    }

    @Test("restoredOrigin: 保存時のスクリーンが不明なら元の原点を使う")
    func restoredOriginWithoutOldScreenUsesOriginalOrigin() {
        let result = ScreenRestorationUtils.restoredOrigin(
            of: NSRect(x: 300, y: 400, width: 100, height: 100),
            from: nil, to: Self.screenA, visibleIn: [Self.screenA]
        )
        #expect(abs(result.x - 300) < Self.tol)
        #expect(abs(result.y - 400) < Self.tol)
    }

    @Test(
        "isVisible: 縦横ともしきい値以上重なるスクリーンがあれば可視",
        arguments: [
            (NSRect(x: 100, y: 100, width: 200, height: 200), true),
            (NSRect(x: 1870, y: 100, width: 200, height: 200), true),   // ちょうど 50px
            (NSRect(x: 1871, y: 100, width: 200, height: 200), false),  // 49px
            (NSRect(x: 100, y: 1031, width: 200, height: 200), false),  // 上へ 49px
            (NSRect(x: 5000, y: 5000, width: 200, height: 200), false),
        ]
    )
    func isVisibleUsesThreshold(rect: NSRect, expected: Bool) {
        #expect(ScreenRestorationUtils.isVisible(rect, in: [Self.screenA]) == expected)
    }
}

// MARK: - findTargetScreen / findTargetScreenForPending Tests

@Suite("ScreenRestorationUtils ScreenSearch Tests")
struct ScreenRestorationUtilsScreenSearchTests {

    private let mainScreen = ScreenInfo(
        frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), displayID: 1, isMain: true
    )
    private let secondaryScreen = ScreenInfo(
        frame: NSRect(x: 1920, y: 0, width: 2560, height: 1440), displayID: 2, isMain: false
    )
    private let unknownID: UInt32 = 0

    // MARK: - findTargetScreen Tests

    @Test("findTargetScreen: displayID一致で見つかる")
    func findTargetScreenByDisplayID() {
        let screens = [mainScreen, secondaryScreen]
        let result = ScreenRestorationUtils.findTargetScreen(
            savedDisplayID: 2, savedScreenFrame: nil, availableScreens: screens, tolerance: 100
        )
        #expect(result != nil)
        #expect(result?.displayID == 2)
        #expect(result?.frame == secondaryScreen.frame)
    }

    @Test("findTargetScreen: displayID不一致でframeで見つかる")
    func findTargetScreenByFrame() {
        let screens = [mainScreen, secondaryScreen]
        let savedFrame = NSRect(x: 1920, y: 0, width: 2560, height: 1440)
        let result = ScreenRestorationUtils.findTargetScreen(
            savedDisplayID: 99, savedScreenFrame: savedFrame,
            availableScreens: screens, tolerance: 100
        )
        #expect(result != nil)
        #expect(result?.displayID == 2)
    }

    @Test("findTargetScreen: 何も見つからない → nil")
    func findTargetScreenNotFound() {
        let screens = [mainScreen, secondaryScreen]
        let savedFrame = NSRect(x: 5000, y: 5000, width: 800, height: 600)
        let result = ScreenRestorationUtils.findTargetScreen(
            savedDisplayID: 99, savedScreenFrame: savedFrame,
            availableScreens: screens, tolerance: 100
        )
        #expect(result == nil)
    }

    @Test("findTargetScreen: 空のavailableScreens → nil")
    func findTargetScreenEmptyScreens() {
        let result = ScreenRestorationUtils.findTargetScreen(
            savedDisplayID: 1,
            savedScreenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            availableScreens: [],
            tolerance: 100
        )
        #expect(result == nil)
    }

    @Test("findTargetScreen: savedScreenFrameがnilの場合")
    func findTargetScreenNilSavedFrame() {
        let screens = [mainScreen, secondaryScreen]
        let result = ScreenRestorationUtils.findTargetScreen(
            savedDisplayID: 99, savedScreenFrame: nil, availableScreens: screens, tolerance: 100
        )
        #expect(result == nil)
    }

    // MARK: - findTargetScreenForPending Tests

    @Test("findTargetScreenForPending: displayID一致で見つかる")
    func findTargetScreenForPendingByDisplayID() {
        let screens = [mainScreen, secondaryScreen]
        let search = ScreenRestorationUtils.PendingScreenSearch(
            displayID: 2, savedScreenFrame: nil,
            originalRect: NSRect(x: 100, y: 100, width: 200, height: 200),
            unknownDisplayID: unknownID
        )
        let result = ScreenRestorationUtils.findTargetScreenForPending(
            search, availableScreens: screens, tolerance: 100
        )
        #expect(result != nil)
        #expect(result?.displayID == 2)
    }

    @Test("findTargetScreenForPending: unknownDisplayIDの場合はPhase1スキップ")
    func findTargetScreenForPendingSkipsPhase1ForUnknown() {
        let screens = [mainScreen, secondaryScreen]
        let search = ScreenRestorationUtils.PendingScreenSearch(
            displayID: unknownID, savedScreenFrame: nil,
            originalRect: NSRect(x: 2000, y: 100, width: 200, height: 200),
            unknownDisplayID: unknownID
        )
        let result = ScreenRestorationUtils.findTargetScreenForPending(
            search, availableScreens: screens, tolerance: 100
        )
        #expect(result != nil)
        #expect(result?.displayID == 2)
    }

    @Test("findTargetScreenForPending: savedScreenFrameで見つかる")
    func findTargetScreenForPendingByFrame() {
        let screens = [mainScreen, secondaryScreen]
        let search = ScreenRestorationUtils.PendingScreenSearch(
            displayID: 99, savedScreenFrame: NSRect(x: 1920, y: 0, width: 2560, height: 1440),
            originalRect: NSRect(x: 100, y: 100, width: 200, height: 200),
            unknownDisplayID: unknownID
        )
        let result = ScreenRestorationUtils.findTargetScreenForPending(
            search, availableScreens: screens, tolerance: 100
        )
        #expect(result != nil)
        #expect(result?.displayID == 2)
    }

    @Test("findTargetScreenForPending: originalRectがスクリーン内で見つかる")
    func findTargetScreenForPendingByOriginalRect() {
        let screens = [mainScreen, secondaryScreen]
        let search = ScreenRestorationUtils.PendingScreenSearch(
            displayID: unknownID, savedScreenFrame: nil,
            originalRect: NSRect(x: 100, y: 100, width: 200, height: 200),
            unknownDisplayID: unknownID
        )
        let result = ScreenRestorationUtils.findTargetScreenForPending(
            search, availableScreens: screens, tolerance: 100
        )
        #expect(result != nil)
        #expect(result?.displayID == 1)
    }

    @Test("findTargetScreenForPending: 何も見つからない → nil")
    func findTargetScreenForPendingNotFound() {
        let screens = [mainScreen, secondaryScreen]
        let search = ScreenRestorationUtils.PendingScreenSearch(
            displayID: 99, savedScreenFrame: NSRect(x: 5000, y: 5000, width: 800, height: 600),
            originalRect: NSRect(x: 100, y: 100, width: 200, height: 200),
            unknownDisplayID: unknownID
        )
        let result = ScreenRestorationUtils.findTargetScreenForPending(
            search, availableScreens: screens, tolerance: 100
        )
        #expect(result == nil)
    }

    @Test("findTargetScreenForPending: displayID不明で元の位置がどのスクリーンとも重ならない → nil（先頭スクリーンにフォールバックしない）")
    func findTargetScreenForPendingNoOverlap() {
        let search = ScreenRestorationUtils.PendingScreenSearch(
            displayID: unknownID, savedScreenFrame: nil,
            originalRect: NSRect(x: -9000, y: -9000, width: 200, height: 200),
            unknownDisplayID: unknownID
        )
        let result = ScreenRestorationUtils.findTargetScreenForPending(
            search, availableScreens: [mainScreen, secondaryScreen], tolerance: 100
        )
        #expect(result == nil)
    }

    @Test("findTargetScreenForPending: displayID不明なら最も大きく重なるスクリーンを選ぶ")
    func findTargetScreenForPendingPicksLargestOverlap() {
        // main と 20px、secondary と 180px 重なる
        let search = ScreenRestorationUtils.PendingScreenSearch(
            displayID: unknownID, savedScreenFrame: nil,
            originalRect: NSRect(x: 1900, y: 100, width: 200, height: 200),
            unknownDisplayID: unknownID
        )
        let result = ScreenRestorationUtils.findTargetScreenForPending(
            search, availableScreens: [mainScreen, secondaryScreen], tolerance: 100
        )
        #expect(result?.displayID == 2)
    }

    // MARK: - indexOfScreen(containingMouseLocation:)

    @Test(
        "indexOfScreen: マウス座標は minY < y ≤ maxY・minX ≤ x < maxX で判定する（最上端も含む）",
        arguments: [
            (NSPoint(x: 100, y: 1080), 0 as Int?),     // メイン最上端（メニューバー上端）
            (NSPoint(x: 0, y: 500), 0),                // メイン左端
            (NSPoint(x: 1920, y: 500), 1),             // 境界はセカンダリ側
            (NSPoint(x: 2000, y: 1440), 1),            // セカンダリ最上端
            (NSPoint(x: 100, y: 0), nil),              // 最下端の外側
            (NSPoint(x: 100, y: 1100), nil),           // スクリーン外
        ]
    )
    func indexOfScreenContainingMouseLocation(point: NSPoint, expected: Int?) {
        let frames = [mainScreen.frame, secondaryScreen.frame]
        #expect(ScreenRestorationUtils.indexOfScreen(containingMouseLocation: point, in: frames) == expected)
    }
}
