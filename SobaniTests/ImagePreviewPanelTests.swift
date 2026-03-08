import Foundation
import Testing
@testable import Sobani

/// ImagePreviewPanel の静的メソッドを検証するテスト
@Suite("ImagePreviewPanel Static Methods Tests")
struct ImagePreviewPanelTests {

    // MARK: - scaledSize Tests

    /// 最大寸法以下の画像はそのまま返されることを検証
    @Test("最大寸法以下の画像はそのまま")
    func scaledSizeWithinMax() {
        let result = ImagePreviewPanel.scaledSize(for: NSSize(width: 100, height: 100))
        #expect(abs(result.width - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 100) < AppConstants.floatingPointTolerance)
    }

    /// 最大寸法を超える横長画像が正しく縮小されることを検証
    @Test("最大寸法を超える横長画像は縮小")
    func scaledSizeLandscapeOverMax() {
        let result = ImagePreviewPanel.scaledSize(for: NSSize(width: 512, height: 256), maxDimension: 256)
        #expect(abs(result.width - 256) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 128) < AppConstants.floatingPointTolerance)
    }

    /// 最大寸法を超える縦長画像が正しく縮小されることを検証
    @Test("最大寸法を超える縦長画像は縮小")
    func scaledSizePortraitOverMax() {
        let result = ImagePreviewPanel.scaledSize(for: NSSize(width: 256, height: 512), maxDimension: 256)
        #expect(abs(result.width - 128) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 256) < AppConstants.floatingPointTolerance)
    }

    /// 正方形画像のスケーリングが正しいことを検証
    @Test("正方形画像のスケーリング")
    func scaledSizeSquare() {
        let result = ImagePreviewPanel.scaledSize(for: NSSize(width: 400, height: 400), maxDimension: 200)
        #expect(abs(result.width - 200) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 200) < AppConstants.floatingPointTolerance)
    }

    /// ゼロサイズの画像でフォールバックサイズが返されることを検証
    @Test("ゼロサイズの画像")
    func scaledSizeZero() {
        let result = ImagePreviewPanel.scaledSize(for: NSSize(width: 0, height: 0), maxDimension: 256)
        #expect(abs(result.width - 256) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 256) < AppConstants.floatingPointTolerance)
    }

    /// 幅のみゼロの画像でフォールバックサイズが返されることを検証
    @Test("幅ゼロの画像")
    func scaledSizeZeroWidth() {
        let result = ImagePreviewPanel.scaledSize(for: NSSize(width: 0, height: 100), maxDimension: 256)
        #expect(abs(result.width - 256) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 256) < AppConstants.floatingPointTolerance)
    }

    /// ちょうど最大寸法の画像はそのまま返されることを検証
    @Test("ちょうど最大寸法の画像")
    func scaledSizeExactMax() {
        let result = ImagePreviewPanel.scaledSize(for: NSSize(width: 256, height: 200), maxDimension: 256)
        #expect(abs(result.width - 256) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 200) < AppConstants.floatingPointTolerance)
    }

    // MARK: - calculatePanelPosition Tests

    /// メニュー右側に配置されることを検証
    @Test("メニュー右側に配置")
    func panelPositionRightSide() {
        let screenFrame = NSRect(x: 0, y: 0, width: 2560, height: 1440)
        let result = ImagePreviewPanel.calculatePanelPosition(
            rightmostX: 300, leftmostX: 0,
            mouseY: 700, panelSize: NSSize(width: 200, height: 200),
            screenFrame: screenFrame, visibleFrame: screenFrame, gap: 4
        )
        #expect(abs(result.x - 304) < AppConstants.floatingPointTolerance)
    }

    /// 右端を超える場合は左側に配置されることを検証
    @Test("右端超え時は左側に配置")
    func panelPositionFallbackToLeft() {
        let screenFrame = NSRect(x: 0, y: 0, width: 400, height: 1440)
        let result = ImagePreviewPanel.calculatePanelPosition(
            rightmostX: 300, leftmostX: 100,
            mouseY: 700, panelSize: NSSize(width: 200, height: 200),
            screenFrame: screenFrame, visibleFrame: screenFrame, gap: 4
        )
        #expect(abs(result.x - (100 - 200 - 4)) < AppConstants.floatingPointTolerance)
    }

    /// 垂直方向の中央配置を検証
    @Test("垂直方向の中央配置")
    func panelPositionVerticalCenter() {
        let screenFrame = NSRect(x: 0, y: 0, width: 2560, height: 1440)
        let result = ImagePreviewPanel.calculatePanelPosition(
            rightmostX: 300, leftmostX: 0,
            mouseY: 700, panelSize: NSSize(width: 200, height: 200),
            screenFrame: screenFrame, visibleFrame: screenFrame, gap: 4
        )
        #expect(abs(result.y - 600) < AppConstants.floatingPointTolerance)
    }

    /// 垂直方向の下端クランプを検証
    @Test("垂直方向のクランプ（下端）")
    func panelPositionVerticalClampBottom() {
        let visibleFrame = NSRect(x: 0, y: 100, width: 2560, height: 1340)
        let result = ImagePreviewPanel.calculatePanelPosition(
            rightmostX: 300, leftmostX: 0,
            mouseY: 50, panelSize: NSSize(width: 200, height: 200),
            screenFrame: NSRect(x: 0, y: 0, width: 2560, height: 1440),
            visibleFrame: visibleFrame, gap: 4
        )
        #expect(result.y >= visibleFrame.minY)
    }

    /// 垂直方向の上端クランプを検証
    @Test("垂直方向のクランプ（上端）")
    func panelPositionVerticalClampTop() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 2560, height: 1440)
        let result = ImagePreviewPanel.calculatePanelPosition(
            rightmostX: 300, leftmostX: 0,
            mouseY: 1500, panelSize: NSSize(width: 200, height: 200),
            screenFrame: NSRect(x: 0, y: 0, width: 2560, height: 1440),
            visibleFrame: visibleFrame, gap: 4
        )
        #expect(result.y + 200 <= visibleFrame.maxY)
    }

    /// スクリーン情報なしでもクラッシュしないことを検証
    @Test("スクリーン情報なしの場合")
    func panelPositionNoScreen() {
        let result = ImagePreviewPanel.calculatePanelPosition(
            rightmostX: 300, leftmostX: 0,
            mouseY: 700, panelSize: NSSize(width: 200, height: 200),
            screenFrame: nil, visibleFrame: nil, gap: 4
        )
        // screenFrame が nil の場合は右側配置（制限チェックがスキップされる）
        #expect(abs(result.x - 304) < AppConstants.floatingPointTolerance)
    }

    /// デフォルト gap 値が使用されることを検証
    @Test("デフォルト gap 値の使用")
    func panelPositionDefaultGap() {
        let screenFrame = NSRect(x: 0, y: 0, width: 2560, height: 1440)
        let result = ImagePreviewPanel.calculatePanelPosition(
            rightmostX: 300, leftmostX: 0,
            mouseY: 700, panelSize: NSSize(width: 200, height: 200),
            screenFrame: screenFrame, visibleFrame: screenFrame
        )
        // デフォルト gap は 6
        #expect(abs(result.x - 306) < AppConstants.floatingPointTolerance)
    }

    // MARK: - fallbackPosition Tests

    /// フォールバック位置の基本計算を検証
    @Test("フォールバック位置の基本計算")
    func fallbackPositionBasic() {
        let mouse = NSPoint(x: 500, y: 500)
        let panelSize = NSSize(width: 200, height: 200)
        let result = ImagePreviewPanel.fallbackPosition(mouseLocation: mouse, panelSize: panelSize, offset: 20)
        #expect(abs(result.x - 520) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 400) < AppConstants.floatingPointTolerance)
    }

    /// デフォルトオフセットが使用されることを検証
    @Test("デフォルトオフセットの使用")
    func fallbackPositionDefaultOffset() {
        let mouse = NSPoint(x: 100, y: 300)
        let panelSize = NSSize(width: 200, height: 200)
        let result = ImagePreviewPanel.fallbackPosition(mouseLocation: mouse, panelSize: panelSize)
        // デフォルト offset は 20
        #expect(abs(result.x - 120) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 200) < AppConstants.floatingPointTolerance)
    }

    /// ゼロ位置でのフォールバック計算を検証
    @Test("ゼロ位置でのフォールバック計算")
    func fallbackPositionAtOrigin() {
        let mouse = NSPoint(x: 0, y: 0)
        let panelSize = NSSize(width: 100, height: 100)
        let result = ImagePreviewPanel.fallbackPosition(mouseLocation: mouse, panelSize: panelSize, offset: 10)
        #expect(abs(result.x - 10) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - (-50)) < AppConstants.floatingPointTolerance)
    }

    // MARK: - calculatePanelFrames Tests

    /// 正方形画像のパネルフレーム計算を検証
    @Test("正方形画像のパネルフレーム計算")
    func calculatePanelFramesSquare() {
        let result = ImagePreviewPanel.calculatePanelFrames(
            imageSize: NSSize(width: 200, height: 200), maxDimension: 256, padding: 8
        )
        // 200 <= 256 なのでそのまま
        #expect(abs(result.panelSize.width - 216) < AppConstants.floatingPointTolerance)
        #expect(abs(result.panelSize.height - 216) < AppConstants.floatingPointTolerance)
        #expect(abs(result.imageFrame.origin.x - 8) < AppConstants.floatingPointTolerance)
        #expect(abs(result.imageFrame.origin.y - 8) < AppConstants.floatingPointTolerance)
        #expect(abs(result.imageFrame.size.width - 200) < AppConstants.floatingPointTolerance)
        #expect(abs(result.imageFrame.size.height - 200) < AppConstants.floatingPointTolerance)
    }

    /// 横長画像のアスペクト比維持を検証
    @Test("横長画像のアスペクト比維持")
    func calculatePanelFramesLandscape() {
        let result = ImagePreviewPanel.calculatePanelFrames(
            imageSize: NSSize(width: 512, height: 256), maxDimension: 256, padding: 10
        )
        // 512 > 256 → scale = 0.5 → 256x128
        #expect(abs(result.panelSize.width - 276) < AppConstants.floatingPointTolerance)
        #expect(abs(result.panelSize.height - 148) < AppConstants.floatingPointTolerance)
        #expect(abs(result.imageFrame.size.width - 256) < AppConstants.floatingPointTolerance)
        #expect(abs(result.imageFrame.size.height - 128) < AppConstants.floatingPointTolerance)
    }

    /// maxDimension より小さい画像はそのまま使用されることを検証
    @Test("maxDimension より小さい画像")
    func calculatePanelFramesSmallImage() {
        let result = ImagePreviewPanel.calculatePanelFrames(
            imageSize: NSSize(width: 50, height: 30), maxDimension: 256, padding: 5
        )
        // 50 <= 256 なのでそのまま
        #expect(abs(result.panelSize.width - 60) < AppConstants.floatingPointTolerance)
        #expect(abs(result.panelSize.height - 40) < AppConstants.floatingPointTolerance)
        #expect(abs(result.imageFrame.size.width - 50) < AppConstants.floatingPointTolerance)
        #expect(abs(result.imageFrame.size.height - 30) < AppConstants.floatingPointTolerance)
    }

    // MARK: - filterMenuWindowFrames Tests

    /// レベルとサイズでフィルタリングされることを検証
    @Test("レベルとサイズでフィルタリング")
    func filterMenuWindowFramesBasic() {
        let frames: [(frame: NSRect, level: Int)] = [
            (frame: NSRect(x: 0, y: 0, width: 200, height: 300), level: 100),
            (frame: NSRect(x: 100, y: 0, width: 50, height: 300), level: 100),  // 幅不足
            (frame: NSRect(x: 200, y: 0, width: 200, height: 300), level: 50),   // レベル不足
            (frame: NSRect(x: 300, y: 0, width: 200, height: 300), level: 150),
        ]
        let result = ImagePreviewPanel.filterMenuWindowFrames(frames: frames, menuLevel: 100, minWidth: 60)
        #expect(result.count == 2)
        #expect(abs(result[0].origin.x - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(result[1].origin.x - 300) < AppConstants.floatingPointTolerance)
    }

    /// 空配列を渡すと空配列が返されることを検証
    @Test("空配列→空配列")
    func filterMenuWindowFramesEmpty() {
        let result = ImagePreviewPanel.filterMenuWindowFrames(
            frames: [], menuLevel: 100, minWidth: 60
        )
        #expect(result.isEmpty)
    }

    /// すべてフィルタアウトされる場合を検証
    @Test("すべてフィルタアウト")
    func filterMenuWindowFramesAllFiltered() {
        let frames: [(frame: NSRect, level: Int)] = [
            (frame: NSRect(x: 0, y: 0, width: 10, height: 300), level: 100),  // 幅不足
            (frame: NSRect(x: 0, y: 0, width: 200, height: 300), level: 10),  // レベル不足
        ]
        let result = ImagePreviewPanel.filterMenuWindowFrames(frames: frames, menuLevel: 100, minWidth: 60)
        #expect(result.isEmpty)
    }

    // MARK: - menuWindowBounds Tests

    /// 空配列で nil が返されることを検証
    @Test("空配列→nil")
    func menuWindowBoundsEmpty() {
        let result = ImagePreviewPanel.menuWindowBounds(frames: [])
        #expect(result == nil)
    }

    /// 1フレームの境界計算を検証
    @Test("1フレームの境界計算")
    func menuWindowBoundsSingleFrame() throws {
        let frames = [NSRect(x: 100, y: 200, width: 300, height: 400)]
        let result = try #require(ImagePreviewPanel.menuWindowBounds(frames: frames))
        #expect(abs(result.rightmostX - 400) < AppConstants.floatingPointTolerance)
        #expect(abs(result.leftmostX - 100) < AppConstants.floatingPointTolerance)
    }

    /// 複数フレームの最大右端と最小左端を検証
    @Test("複数フレームの境界計算")
    func menuWindowBoundsMultipleFrames() throws {
        let frames = [
            NSRect(x: 50, y: 0, width: 200, height: 100),   // minX=50, maxX=250
            NSRect(x: 100, y: 0, width: 400, height: 100),  // minX=100, maxX=500
            NSRect(x: 30, y: 0, width: 100, height: 100),   // minX=30, maxX=130
        ]
        let result = try #require(ImagePreviewPanel.menuWindowBounds(frames: frames))
        #expect(abs(result.rightmostX - 500) < AppConstants.floatingPointTolerance)
        #expect(abs(result.leftmostX - 30) < AppConstants.floatingPointTolerance)
    }

    /// 重複するフレームの境界計算を検証
    @Test("重複するフレームの境界計算")
    func menuWindowBoundsOverlappingFrames() throws {
        let frames = [
            NSRect(x: 100, y: 0, width: 200, height: 100),  // minX=100, maxX=300
            NSRect(x: 100, y: 0, width: 200, height: 100),  // 同一フレーム
        ]
        let result = try #require(ImagePreviewPanel.menuWindowBounds(frames: frames))
        #expect(abs(result.rightmostX - 300) < AppConstants.floatingPointTolerance)
        #expect(abs(result.leftmostX - 100) < AppConstants.floatingPointTolerance)
    }
}
