import CoreGraphics
import Foundation
import Testing
@testable import Sobani

@Suite struct CropGeometryTests {

    // MARK: - normalizeQuarterTurns テスト

    @Test func normalizeQuarterTurns_inRange() {
        #expect(CropGeometry.normalizeQuarterTurns(0) == 0)
        #expect(CropGeometry.normalizeQuarterTurns(1) == 1)
        #expect(CropGeometry.normalizeQuarterTurns(2) == 2)
        #expect(CropGeometry.normalizeQuarterTurns(3) == 3)
    }

    @Test func normalizeQuarterTurns_wraps() {
        #expect(CropGeometry.normalizeQuarterTurns(4) == 0)
        #expect(CropGeometry.normalizeQuarterTurns(5) == 1)
        #expect(CropGeometry.normalizeQuarterTurns(-1) == 3)
        #expect(CropGeometry.normalizeQuarterTurns(-4) == 0)
    }

    // MARK: - clampStraightenAngle テスト

    @Test func clampStraightenAngle_withinRange() {
        #expect(abs(CropGeometry.clampStraightenAngle(0) - 0) < AppConstants.floatingPointTolerance)
        let tol = AppConstants.floatingPointTolerance
        #expect(abs(CropGeometry.clampStraightenAngle(30) - 30) < tol)
        #expect(abs(CropGeometry.clampStraightenAngle(-30) - (-30)) < tol)
    }

    @Test func clampStraightenAngle_clampsExtremes() {
        let tol = AppConstants.floatingPointTolerance
        #expect(abs(CropGeometry.clampStraightenAngle(90) - 45) < tol)
        #expect(abs(CropGeometry.clampStraightenAngle(-90) - (-45)) < tol)
    }

    // MARK: - cropRectForAspectRatio テスト

    @Test func cropRectForAspectRatio_square_inSquareBounds() {
        let result = CropGeometry.cropRectForAspectRatio(
            ratio: 1.0, within: CGSize(width: 100, height: 100)
        )
        #expect(abs(result.width - 1.0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 1.0) < AppConstants.floatingPointTolerance)
    }

    @Test func cropRectForAspectRatio_wide_inSquareBounds() {
        let result = CropGeometry.cropRectForAspectRatio(
            ratio: 2.0, within: CGSize(width: 100, height: 100)
        )
        #expect(abs(result.width - 1.0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 0.5) < AppConstants.floatingPointTolerance)
    }

    @Test func cropRectForAspectRatio_centered() {
        let result = CropGeometry.cropRectForAspectRatio(
            ratio: 2.0, within: CGSize(width: 100, height: 100)
        )
        #expect(abs(result.x - 0.0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 0.25) < AppConstants.floatingPointTolerance)
    }

    // MARK: - cropRectAfterQuarterTurn テスト

    @Test func cropRectAfterQuarterTurn_zeroTurns() {
        let rect = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.3)
        let result = CropGeometry.cropRectAfterQuarterTurn(cropRect: rect, turns: 0)
        #expect(abs(result.x - 0.1) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 0.2) < AppConstants.floatingPointTolerance)
    }

    @Test func cropRectAfterQuarterTurn_fourTurns_identity() {
        let rect = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.3)
        let result = CropGeometry.cropRectAfterQuarterTurn(cropRect: rect, turns: 4)
        #expect(abs(result.x - rect.x) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - rect.y) < AppConstants.floatingPointTolerance)
        #expect(abs(result.width - rect.width) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - rect.height) < AppConstants.floatingPointTolerance)
    }

    // MARK: - constrainCropRect テスト

    @Test func constrainCropRect_alreadyCorrectRatio() {
        let rect = CropRect(x: 0, y: 0, width: 1.0, height: 1.0)
        let result = CropGeometry.constrainCropRect(
            rect, toAspectRatio: 1.0, within: CGSize(width: 100, height: 100)
        )
        #expect(abs(result.width - 1.0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 1.0) < AppConstants.floatingPointTolerance)
    }

    // MARK: - viewRectToNormalizedCrop テスト

    @Test func viewRectToNormalizedCrop_fullImage() {
        let cropFrame = CGRect(x: 100, y: 100, width: 400, height: 300)
        let imageRect = CGRect(x: 100, y: 100, width: 400, height: 300)
        let result = CropGeometry.viewRectToNormalizedCrop(
            cropFrame: cropFrame, imageRect: imageRect
        )
        #expect(abs(result.x - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.width - 1) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 1) < AppConstants.floatingPointTolerance)
    }

    @Test func viewRectToNormalizedCrop_halfCrop() {
        let cropFrame = CGRect(x: 200, y: 175, width: 200, height: 150)
        let imageRect = CGRect(x: 100, y: 100, width: 400, height: 300)
        let result = CropGeometry.viewRectToNormalizedCrop(
            cropFrame: cropFrame, imageRect: imageRect
        )
        #expect(abs(result.x - 0.25) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 0.25) < AppConstants.floatingPointTolerance)
        #expect(abs(result.width - 0.5) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 0.5) < AppConstants.floatingPointTolerance)
    }

    // MARK: - constrainedResize テスト

    private func makeInput(
        start: CropRect, newWidth: CGFloat, newHeight: CGFloat,
        handle: CropGeometry.ResizeHandle, normalizedRatio: CGFloat, minSize: CGFloat = 0.1
    ) -> CropGeometry.ConstrainedResizeInput {
        CropGeometry.ConstrainedResizeInput(
            start: start, newWidth: newWidth, newHeight: newHeight,
            handle: handle, normalizedRatio: normalizedRatio, minSize: minSize
        )
    }

    @Test func constrainedResize_cornerHandle_maintainsRatio() {
        let start = CropRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.6, newHeight: 0.7,
                             handle: .bottomRight, normalizedRatio: 1.0)
        )
        // 正方形比率: width == height
        #expect(abs(result.width - result.height) < AppConstants.floatingPointTolerance)
        // 左端がアンカー（bottomRightドラッグ）
        #expect(abs(result.originX - 0.1) < AppConstants.floatingPointTolerance)
        // 上端がアンカー
        #expect(
            abs(result.originY - (0.1 + 0.5 - result.height)) < AppConstants.floatingPointTolerance
        )
    }

    @Test func constrainedResize_cornerHandle_selectsSmallerArea() {
        let start = CropRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.8, newHeight: 0.3,
                             handle: .topRight, normalizedRatio: 2.0)
        )
        // 比率維持: width / height ≈ 2.0
        #expect(abs(result.width / result.height - 2.0) < 0.01)
    }

    @Test func constrainedResize_topEdge_adjustsWidth() {
        let start = CropRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.4, newHeight: 0.6,
                             handle: .top, normalizedRatio: 1.0)
        )
        // 正方形比率: width == height
        #expect(abs(result.width - result.height) < AppConstants.floatingPointTolerance)
        // 下端固定
        #expect(abs(result.originY - 0.2) < AppConstants.floatingPointTolerance)
        // X中心固定
        let expectedX = 0.2 + 0.4 / 2 - result.width / 2
        #expect(abs(result.originX - expectedX) < AppConstants.floatingPointTolerance)
    }

    @Test func constrainedResize_leftEdge_adjustsHeight() {
        let start = CropRect(x: 0.3, y: 0.2, width: 0.4, height: 0.4)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.3, newHeight: 0.4,
                             handle: .left, normalizedRatio: 1.0)
        )
        // 正方形比率
        #expect(abs(result.width - result.height) < AppConstants.floatingPointTolerance)
        // 右端固定
        let expectedX = 0.3 + 0.4 - result.width
        #expect(abs(result.originX - expectedX) < AppConstants.floatingPointTolerance)
        // Y中心固定
        let expectedY = 0.2 + 0.4 / 2 - result.height / 2
        #expect(abs(result.originY - expectedY) < AppConstants.floatingPointTolerance)
    }

    @Test func constrainedResize_clampsToNormalizedBounds() {
        let start = CropRect(x: 0.8, y: 0.8, width: 0.15, height: 0.15)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.5, newHeight: 0.5,
                             handle: .bottomRight, normalizedRatio: 1.0)
        )
        // x + width <= 1.0, y + height <= 1.0
        #expect(result.originX + result.width <= 1.0 + AppConstants.floatingPointTolerance)
        #expect(result.originY + result.height <= 1.0 + AppConstants.floatingPointTolerance)
    }

    @Test func constrainedResize_minSizeConstraint() {
        let start = CropRect(x: 0.5, y: 0.5, width: 0.3, height: 0.3)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.01, newHeight: 0.01,
                             handle: .topLeft, normalizedRatio: 1.0)
        )
        // 最小サイズ以上
        #expect(result.width >= 0.1)
        #expect(result.height >= 0.1)
    }

    @Test func constrainedResize_bottomHandle_anchorsTop() {
        let start = CropRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.4, newHeight: 0.3,
                             handle: .bottom, normalizedRatio: 1.0)
        )
        // 上端固定: start.y + start.height
        let topEdge = start.y + start.height
        let resultTopEdge = result.originY + result.height
        #expect(abs(resultTopEdge - topEdge) < AppConstants.floatingPointTolerance)
    }

    @Test func constrainedResize_topLeftHandle_anchorsBottomRight() {
        let start = CropRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.3, newHeight: 0.3,
                             handle: .topLeft, normalizedRatio: 1.0)
        )
        // 右端固定
        let rightEdge = start.x + start.width
        let resultRightEdge = result.originX + result.width
        #expect(abs(resultRightEdge - rightEdge) < AppConstants.floatingPointTolerance)
        // 下端固定
        #expect(abs(result.originY - start.y) < AppConstants.floatingPointTolerance)
    }

}

// MARK: - pixelCornerRadius / cornerRadiusHandlePosition / cornerRadiusFromDrag / viewRectToNormalizedCrop ラウンドトリップ

extension CropGeometryTests {

    // MARK: - pixelCornerRadius テスト

    @Test func pixelCornerRadius_zero_returnsZero() {
        let result = CropGeometry.pixelCornerRadius(normalized: 0, shorterSide: 200)
        #expect(abs(result) < AppConstants.floatingPointTolerance)
    }

    @Test func pixelCornerRadius_one_returnsHalfShorterSide() {
        let result = CropGeometry.pixelCornerRadius(normalized: 1.0, shorterSide: 200)
        #expect(abs(result - 100) < AppConstants.floatingPointTolerance)
    }

    @Test func pixelCornerRadius_clampsAboveOne() {
        let result = CropGeometry.pixelCornerRadius(normalized: 1.5, shorterSide: 200)
        #expect(abs(result - 100) < AppConstants.floatingPointTolerance)
    }

    @Test func pixelCornerRadius_clampsBelowZero() {
        let result = CropGeometry.pixelCornerRadius(normalized: -0.5, shorterSide: 200)
        #expect(abs(result) < AppConstants.floatingPointTolerance)
    }

    // MARK: - cornerRadiusHandlePosition テスト

    @Test func cornerRadiusHandlePosition_topLeft() {
        let frame = NSRect(x: 100, y: 100, width: 200, height: 200)
        let pos = CropGeometry.cornerRadiusHandlePosition(
            corner: .topLeft, cropFrame: frame, normalizedRadius: 0.5
        )
        // pixelRadius = 0.5 * 200 / 2 = 50
        #expect(abs(pos.x - 150) < AppConstants.floatingPointTolerance)
        #expect(abs(pos.y - 250) < AppConstants.floatingPointTolerance)
    }

    @Test func cornerRadiusHandlePosition_bottomRight() {
        let frame = NSRect(x: 100, y: 100, width: 200, height: 200)
        let pos = CropGeometry.cornerRadiusHandlePosition(
            corner: .bottomRight, cropFrame: frame, normalizedRadius: 0.5
        )
        #expect(abs(pos.x - 250) < AppConstants.floatingPointTolerance)
        #expect(abs(pos.y - 150) < AppConstants.floatingPointTolerance)
    }

    // MARK: - cornerRadiusFromDrag テスト

    @Test func cornerRadiusFromDrag_atCorner_returnsZero() {
        let frame = NSRect(x: 100, y: 100, width: 200, height: 200)
        let result = CropGeometry.cornerRadiusFromDrag(
            corner: .topLeft, cropFrame: frame, dragPoint: CGPoint(x: 100, y: 300)
        )
        #expect(abs(result) < AppConstants.floatingPointTolerance)
    }

    @Test func cornerRadiusFromDrag_atCenter_returnsOne() {
        let frame = NSRect(x: 100, y: 100, width: 200, height: 200)
        let result = CropGeometry.cornerRadiusFromDrag(
            corner: .topLeft, cropFrame: frame, dragPoint: CGPoint(x: 200, y: 200)
        )
        #expect(abs(result - 1.0) < AppConstants.floatingPointTolerance)
    }

    @Test func cornerRadiusFromDrag_clampsToMax() {
        let frame = NSRect(x: 100, y: 100, width: 200, height: 200)
        let result = CropGeometry.cornerRadiusFromDrag(
            corner: .topLeft, cropFrame: frame, dragPoint: CGPoint(x: 300, y: 100)
        )
        #expect(result <= AppConstants.cornerRadiusMax + AppConstants.floatingPointTolerance)
    }

    // MARK: - viewRectToNormalizedCrop ラウンドトリップテスト

    /// パン操作後のCropRect計算のラウンドトリップを確認する
    /// recalculateImageOffset の計算を手動で再現し、viewRectToNormalizedCrop が元の値を復元できることを検証
    @Test func viewRectToNormalizedCrop_roundTrip_withOffset() throws {
        let originalX: CGFloat = 0.2
        let originalY: CGFloat = 0.3
        let originalW: CGFloat = 0.6
        let originalH: CGFloat = 0.5
        let cropRect = CropRect(x: originalX, y: originalY, width: originalW, height: originalH)

        let cropFrame = NSRect(x: 50, y: 50, width: 200, height: 150)

        // recalculateImageOffset の計算を手動再現（zoom=1 と仮定）
        let baseWidth = cropFrame.width / cropRect.width
        let baseHeight = cropFrame.height / cropRect.height
        let offsetX = baseWidth * (0.5 - cropRect.x) - cropFrame.width / 2
        let offsetY = baseHeight * (0.5 - cropRect.y) - cropFrame.height / 2
        let drawWidth = baseWidth
        let drawHeight = baseHeight
        let centerX = cropFrame.midX + offsetX
        let centerY = cropFrame.midY + offsetY
        let imageRect = NSRect(
            x: centerX - drawWidth / 2,
            y: centerY - drawHeight / 2,
            width: drawWidth,
            height: drawHeight
        )

        let result = CropGeometry.viewRectToNormalizedCrop(
            cropFrame: cropFrame, imageRect: imageRect
        )

        #expect(abs(result.x - originalX) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - originalY) < AppConstants.floatingPointTolerance)
        #expect(abs(result.width - originalW) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - originalH) < AppConstants.floatingPointTolerance)
    }
}

// MARK: - 共通変換（キャンバスと出力処理の一致）

extension CropGeometryTests {

    private static let tol = AppConstants.normalizedTolerance

    /// 変換の組み合わせを網羅したテスト用 CropRect（回転・反転・傾き・パース・はみ出し）
    static let transformCases: [CropRect] = [
        CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.4),
        CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.4, quarterTurns: 1),
        CropRect(x: 0.2, y: 0.1, width: 0.6, height: 0.7, quarterTurns: 3, isFlippedInCrop: true),
        CropRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0, straightenAngle: 20, isFlippedInCrop: true),
        CropRect(
            x: -0.1, y: 0.3, width: 0.8, height: 0.5, straightenAngle: -12, quarterTurns: 2,
            verticalPerspective: 15, horizontalPerspective: -25
        ),
        CropRect(
            x: 0.25, y: 0.25, width: 0.5, height: 0.5, straightenAngle: 7, quarterTurns: 1,
            isFlippedInCrop: true, verticalPerspective: 30
        ),
    ]

    private func normalized(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: (point.x - rect.minX) / rect.width, y: (point.y - rect.minY) / rect.height)
    }

    @Test func effectiveSize_swapsOnlyForOddTurns() {
        let size = CGSize(width: 300, height: 200)
        #expect(isClose(CropGeometry.effectiveSize(size, quarterTurns: 0), size))
        #expect(isClose(CropGeometry.effectiveSize(size, quarterTurns: 1), CGSize(width: 200, height: 300)))
        #expect(isClose(CropGeometry.effectiveSize(size, quarterTurns: 2), size))
        #expect(isClose(CropGeometry.effectiveSize(size, quarterTurns: -1), CGSize(width: 200, height: 300)))
    }

    /// 90° 回転は時計回り：画像の左端（中心から見て -x 方向）が上（+y、y 軸上向き）へ移る
    @Test func contentTransform_quarterTurnIsClockwise() {
        let left = CGPoint(x: -1, y: 0).applying(
            CropGeometry.contentTransform(for: CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: 1))
        )
        #expect(abs(left.x) < Self.tol)
        #expect(abs(left.y - 1) < Self.tol)
    }

    /// 負の quarterTurns も正規化して適用される（-1 は時計回り 270°）
    @Test func contentTransform_negativeQuarterTurnsAreNormalized() {
        let negative = CropGeometry.contentTransform(for: CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: -1))
        let positive = CropGeometry.contentTransform(for: CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: 3))
        let probe = CGPoint(x: 1, y: 2)
        #expect(isClose(probe.applying(negative), probe.applying(positive)))
        // 時計回り 270° = 反時計回り 90°: (x, y) → (−y, x)
        #expect(isClose(probe.applying(negative), CGPoint(x: -2, y: 1)))
    }

    /// 傾き補正は反転より外側で適用される：反転していても正の角度は時計回り（旧キャンバスでは逆向きで 40° ずれていた）
    @Test func contentTransform_straightenIsClockwiseEvenWhenFlipped() {
        let degrees: CGFloat = 20
        for isFlipped in [false, true] {
            let crop = CropRect(x: 0, y: 0, width: 1, height: 1, straightenAngle: degrees, isFlippedInCrop: isFlipped)
            let upVector = CGPoint(x: 0, y: 1).applying(CropGeometry.contentTransform(for: crop))
            #expect(abs(upVector.x - sin(degrees * .pi / 180)) < Self.tol)
            #expect(abs(upVector.y - cos(degrees * .pi / 180)) < Self.tol)
        }
    }

    /// パース補正は奥行きを持たない cos スケール（縦 = y、横 = x）
    @Test func contentTransform_perspectiveIsCosineScale() {
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, verticalPerspective: 60, horizontalPerspective: 45)
        let transform = CropGeometry.contentTransform(for: crop)
        let unit = CGPoint(x: 1, y: 1).applying(transform)
        #expect(abs(unit.x - cos(45 * CGFloat.pi / 180)) < Self.tol)
        #expect(abs(unit.y - 0.5) < Self.tol)
    }

    /// キャンバスの変換でも、90° 回転で画像の左端中央がクロップ枠の上端中央へ移る（出力処理と同じ向き）
    @Test func imageTransform_canvasQuarterTurnMovesLeftEdgeToTop() {
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: 1)
        let sourceSize = CGSize(width: 200, height: 100)
        let imageRect = CGRect(x: 50, y: 20, width: 100, height: 200)  // 回転後（縦長）の表示矩形
        let transform = CropGeometry.imageTransform(for: crop, sourceSize: sourceSize, imageRect: imageRect)
        let leftMiddle = CGPoint(x: 0, y: 50).applying(transform)
        #expect(abs(leftMiddle.x - imageRect.midX) < AppConstants.floatingPointTolerance)
        #expect(abs(leftMiddle.y - imageRect.maxY) < AppConstants.floatingPointTolerance)
    }

    /// キャンバス（ポイント、任意位置のクロップ枠）と出力処理（ピクセル）で、元画像の各点がクロップ枠内の同じ位置に来る
    @Test(arguments: transformCases)
    func imageTransform_canvasMatchesProcessorOutput(crop: CropRect) {
        let pixelSize = CGSize(width: 400, height: 300)
        let pointSize = CGSize(width: 200, height: 150)

        // 出力処理: 原点 = クロップ領域の左下
        let effectivePixels = CropGeometry.effectiveSize(pixelSize, quarterTurns: crop.quarterTurns)
        let outputRect = CGRect(
            x: 0, y: 0, width: crop.width * effectivePixels.width, height: crop.height * effectivePixels.height
        )
        let processor = CropGeometry.imageTransform(
            for: crop, sourceSize: pixelSize,
            imageRect: CropGeometry.outputImageRect(for: crop, effectiveSize: effectivePixels)
        )

        // キャンバス: zoom = 1 のときの calculateImageDrawRect と同じ配置
        let effectivePoints = CropGeometry.effectiveSize(pointSize, quarterTurns: crop.quarterTurns)
        let frameWidth: CGFloat = 320
        let frameHeight = frameWidth * (crop.height * effectivePoints.height) / (crop.width * effectivePoints.width)
        let cropFrame = CGRect(x: 37, y: 52, width: frameWidth, height: frameHeight)
        let imageWidth = cropFrame.width / crop.width
        let imageHeight = cropFrame.height / crop.height
        let imageDrawRect = CGRect(
            x: cropFrame.minX - crop.x * imageWidth, y: cropFrame.minY - crop.y * imageHeight,
            width: imageWidth, height: imageHeight
        )
        let canvas = CropGeometry.imageTransform(for: crop, sourceSize: pointSize, imageRect: imageDrawRect)

        let samples = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0.3, y: 0.8), CGPoint(x: 1, y: 1)]
        for sample in samples {
            let pixel = CGPoint(x: sample.x * pixelSize.width, y: sample.y * pixelSize.height)
            let pointInSource = CGPoint(x: sample.x * pointSize.width, y: sample.y * pointSize.height)
            let fromProcessor = normalized(pixel.applying(processor), in: outputRect)
            let fromCanvas = normalized(pointInSource.applying(canvas), in: cropFrame)
            #expect(abs(fromProcessor.x - fromCanvas.x) < Self.tol)
            #expect(abs(fromProcessor.y - fromCanvas.y) < Self.tol)
        }
    }

    // MARK: - 90° 回転・反転の表示方向

    /// 反転の有無にかかわらず、90° 回転後の表示は回転前の表示を時計回りに 90° 回したものになる
    /// （反転中に quarterTurns を +1 すると表示が反時計回りに回るため、-1 で進める必要がある）
    @Test(arguments: transformCases)
    func quarterTurn_rotatesDisplayClockwise(crop: CropRect) {
        let sourceSize = CGSize(width: 400, height: 300)
        let rotated = CropGeometry.cropRectAfterQuarterTurn(cropRect: crop, turns: 1)
        let before = displayTransform(crop, sourceSize: sourceSize)
        let after = displayTransform(rotated, sourceSize: sourceSize)
        let displayWidth = CropGeometry.effectiveSize(sourceSize, quarterTurns: crop.quarterTurns).width

        for sample in [CGPoint(x: 0, y: 0), CGPoint(x: 400, y: 0), CGPoint(x: 120, y: 260)] {
            let old = sample.applying(before)
            let new = sample.applying(after)
            // 時計回り 90°: (X, Y) → (Y, 旧表示幅 - X)
            #expect(abs(new.x - old.y) < AppConstants.floatingPointTolerance)
            #expect(abs(new.y - (displayWidth - old.x)) < AppConstants.floatingPointTolerance)
        }
    }

    @Test func quarterTurn_flippedStepsQuarterTurnsBackward() {
        let flipped = CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: 1, isFlippedInCrop: true)
        #expect(CropGeometry.cropRectAfterQuarterTurn(cropRect: flipped, turns: 1).quarterTurns == 0)
        let normal = CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: 1)
        #expect(CropGeometry.cropRectAfterQuarterTurn(cropRect: normal, turns: 1).quarterTurns == 2)
    }

    @Test func quarterTurn_movesCropRectClockwise() {
        // 左下の領域は時計回りに回すと左上へ移る
        let crop = CropRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let rotated = CropGeometry.cropRectAfterQuarterTurn(cropRect: crop, turns: 1)
        #expect(abs(rotated.x - 0.2) < Self.tol)
        #expect(abs(rotated.y - 0.6) < Self.tol)
        #expect(abs(rotated.width - 0.4) < Self.tol)
        #expect(abs(rotated.height - 0.3) < Self.tol)
    }

    /// 反転後のクロップ結果は、反転前のクロップ結果をちょうど左右反転したものになる
    @Test(arguments: transformCases)
    func flip_mirrorsCropOutput(crop: CropRect) {
        let sourceSize = CGSize(width: 400, height: 300)
        let flipped = CropGeometry.cropRectAfterFlip(crop)
        let effective = CropGeometry.effectiveSize(sourceSize, quarterTurns: crop.quarterTurns)
        let outputWidth = crop.width * effective.width
        let before = CropGeometry.imageTransform(
            for: crop, sourceSize: sourceSize,
            imageRect: CropGeometry.outputImageRect(for: crop, effectiveSize: effective)
        )
        let after = CropGeometry.imageTransform(
            for: flipped, sourceSize: sourceSize,
            imageRect: CropGeometry.outputImageRect(for: flipped, effectiveSize: effective)
        )
        for sample in [CGPoint(x: 0, y: 0), CGPoint(x: 400, y: 0), CGPoint(x: 120, y: 260)] {
            let old = sample.applying(before)
            let new = sample.applying(after)
            #expect(abs(new.x - (outputWidth - old.x)) < AppConstants.floatingPointTolerance)
            #expect(abs(new.y - old.y) < AppConstants.floatingPointTolerance)
        }
        #expect(flipped.isFlippedInCrop != crop.isFlippedInCrop)
    }

    @Test func flip_swapsLeftAndRightCornerRadii() {
        let crop = CropRect(
            x: 0, y: 0, width: 1, height: 1, shape: .roundedRectangle,
            cornerRadii: CornerRadii(topLeft: 0.1, topRight: 0.2, bottomLeft: 0.3, bottomRight: 0.4)
        )
        let radii = CropGeometry.cropRectAfterFlip(crop).cornerRadii
        #expect(abs(radii.topLeft - 0.2) < Self.tol)
        #expect(abs(radii.topRight - 0.1) < Self.tol)
        #expect(abs(radii.bottomLeft - 0.4) < Self.tol)
        #expect(abs(radii.bottomRight - 0.3) < Self.tol)
    }

    /// 元画像の座標を、クロップ前の表示全体（左下原点）の座標へ写す変換
    private func displayTransform(_ crop: CropRect, sourceSize: CGSize) -> CGAffineTransform {
        let effective = CropGeometry.effectiveSize(sourceSize, quarterTurns: crop.quarterTurns)
        return CropGeometry.imageTransform(
            for: crop, sourceSize: sourceSize, imageRect: CGRect(origin: .zero, size: effective)
        )
    }

    // MARK: - pixelExtent

    @Test func pixelExtent_absorbsFloatingPointNoise() {
        // 0.55 * 100 = 55.000000000000007 → ceil すると 56 になっていた
        #expect(CropGeometry.pixelExtent(0.55 * 100, limit: 1000) == 55)
        #expect(CropGeometry.pixelExtent(54.5, limit: 1000) == 55)
        #expect(CropGeometry.pixelExtent(0.2, limit: 1000) == 1)
    }

    @Test func pixelExtent_rejectsInvalidValues() {
        #expect(CropGeometry.pixelExtent(0, limit: 1000) == nil)
        #expect(CropGeometry.pixelExtent(-3, limit: 1000) == nil)
        #expect(CropGeometry.pixelExtent(.infinity, limit: 1000) == nil)
        #expect(CropGeometry.pixelExtent(.nan, limit: 1000) == nil)
        #expect(CropGeometry.pixelExtent(1e303, limit: 1000) == nil)
    }
}

// MARK: - アスペクト比固定リサイズの境界処理

extension CropGeometryTests {

    /// 境界付近でも、固定側の辺（辺ハンドルは中心線）を動かさず、比率を保ったまま範囲内に収める
    @Test(arguments: CropGeometry.ResizeHandle.allCases)
    func constrainedResize_atBoundary_keepsAnchorAndRatio(handle: CropGeometry.ResizeHandle) {
        let tol = AppConstants.normalizedTolerance
        let start = CropRect(x: 0.1, y: 0.5, width: 0.4, height: 0.4)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.9, newHeight: 0.9, handle: handle, normalizedRatio: 1.0)
        )

        #expect(abs(result.width - result.height) < tol)
        #expect(result.width >= start.width - tol)
        #expect(result.originX >= -tol)
        #expect(result.originY >= -tol)
        #expect(result.originX + result.width <= 1 + tol)
        #expect(result.originY + result.height <= 1 + tol)

        switch handle {
        case .topLeft, .left, .bottomLeft:
            #expect(abs(result.originX + result.width - (start.x + start.width)) < tol)
        case .topRight, .right, .bottomRight:
            #expect(abs(result.originX - start.x) < tol)
        case .top, .bottom:
            #expect(abs(result.originX + result.width / 2 - (start.x + start.width / 2)) < tol)
        }
        switch handle {
        case .bottomLeft, .bottom, .bottomRight:
            #expect(abs(result.originY + result.height - (start.y + start.height)) < tol)
        case .topLeft, .top, .topRight:
            #expect(abs(result.originY - start.y) < tol)
        case .left, .right:
            #expect(abs(result.originY + result.height / 2 - (start.y + start.height / 2)) < tol)
        }
    }

    /// 左下ハンドルで範囲を超えて広げても、上端（固定側）は 0.9 のまま
    @Test func constrainedResize_bottomLeftBeyondBounds_keepsTopEdge() {
        let tol = AppConstants.normalizedTolerance
        let start = CropRect(x: 0.1, y: 0.5, width: 0.4, height: 0.4)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.7, newHeight: 0.7, handle: .bottomLeft, normalizedRatio: 1.0)
        )
        #expect(abs(result.originX - 0) < tol)
        #expect(abs(result.originY - 0.4) < tol)
        #expect(abs(result.width - 0.5) < tol)
        #expect(abs(result.height - 0.5) < tol)
    }

    /// 最小サイズを適用しても比率は崩れない
    @Test func constrainedResize_minSizeKeepsRatio() {
        let tol = AppConstants.normalizedTolerance
        let start = CropRect(x: 0.2, y: 0.2, width: 0.4, height: 0.1)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.01, newHeight: 0.01, handle: .bottomRight, normalizedRatio: 4.0)
        )
        #expect(abs(result.width / result.height - 4.0) < tol)
        #expect(result.width >= 0.1 - tol)
        #expect(result.height >= 0.1 - tol)
    }

    /// 開始時点で画像外にはみ出しているクロップは、はみ出し分を保ったまま縮められずに済む
    @Test func constrainedResize_startOutsideBounds_doesNotJump() {
        let tol = AppConstants.normalizedTolerance
        let start = CropRect(x: -0.2, y: 0.2, width: 0.5, height: 0.5)
        let result = CropGeometry.constrainedResize(
            input: makeInput(start: start, newWidth: 0.6, newHeight: 0.6, handle: .right, normalizedRatio: 1.0)
        )
        #expect(abs(result.originX - start.x) < tol)
        #expect(abs(result.width - 0.6) < tol)
    }

    /// bounds（キャンバスの可視範囲）を指定するとその内側に収める
    @Test func constrainedResize_respectsCustomBounds() {
        let tol = AppConstants.normalizedTolerance
        let start = CropRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2)
        let input = CropGeometry.ConstrainedResizeInput(
            start: start, newWidth: 0.8, newHeight: 0.8, handle: .topRight,
            normalizedRatio: 1.0, minSize: 0.1, bounds: CGRect(x: 0, y: 0, width: 0.7, height: 1)
        )
        let result = CropGeometry.constrainedResize(input: input)
        #expect(abs(result.originX + result.width - 0.7) < tol)
        #expect(abs(result.width - result.height) < tol)
    }

    // MARK: - freeResizedFrame

    @Test func freeResizedFrame_clampsMovedEdgeToLimit() {
        let start = CGRect(x: 100, y: 100, width: 200, height: 100)
        let limit = CGRect(x: 0, y: 0, width: 400, height: 400)
        let minSize = CGSize(width: 20, height: 20)

        let right = CropGeometry.freeResizedFrame(
            start: start, handle: .right, delta: CGVector(dx: 500, dy: 0), minSize: minSize, limit: limit
        )
        #expect(isClose(right, CGRect(x: 100, y: 100, width: 300, height: 100)))

        let topLeft = CropGeometry.freeResizedFrame(
            start: start, handle: .topLeft, delta: CGVector(dx: -200, dy: 400), minSize: minSize, limit: limit
        )
        #expect(isClose(topLeft, CGRect(x: 0, y: 100, width: 300, height: 300)))
    }

    @Test func freeResizedFrame_keepsMinimumSize() {
        let start = CGRect(x: 100, y: 100, width: 200, height: 100)
        let result = CropGeometry.freeResizedFrame(
            start: start, handle: .left, delta: CGVector(dx: 500, dy: 0),
            minSize: CGSize(width: 20, height: 20), limit: CGRect(x: 0, y: 0, width: 400, height: 400)
        )
        #expect(abs(result.width - 20) < AppConstants.floatingPointTolerance)
        #expect(abs(result.maxX - 300) < AppConstants.floatingPointTolerance)
    }

    // MARK: - ハンドルのヒット判定

    @Test func prefersCornerRadiusHandle_nearerHandleWins() {
        #expect(CropGeometry.prefersCornerRadiusHandle(
            radiusHandleDistance: 2, resizeHandleDistance: 8, isInsideCropFrame: false
        ))
        #expect(!CropGeometry.prefersCornerRadiusHandle(
            radiusHandleDistance: 8, resizeHandleDistance: 2, isInsideCropFrame: true
        ))
    }

    /// 半径 0 で両ハンドルが角に重なる場合、外側からはリサイズ、内側からは角丸を操作できる
    @Test func prefersCornerRadiusHandle_tieDependsOnSide() {
        #expect(!CropGeometry.prefersCornerRadiusHandle(
            radiusHandleDistance: 5, resizeHandleDistance: 5, isInsideCropFrame: false
        ))
        #expect(CropGeometry.prefersCornerRadiusHandle(
            radiusHandleDistance: 5, resizeHandleDistance: 5, isInsideCropFrame: true
        ))
    }

    // MARK: - shapePath

    @Test func shapePath_rectangleCoversRect() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
        let path = CropGeometry.shapePath(.rectangle, in: rect, radii: .zero)
        #expect(isClose(path.boundingBox, rect))
        #expect(path.contains(CGPoint(x: 11, y: 21)))
    }

    @Test func shapePath_roundedRectangleUsesPerCornerRadii() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        // 左上だけ最大の丸み、他は角
        let radii = CornerRadii(topLeft: 1, topRight: 0, bottomLeft: 0, bottomRight: 0)
        let path = CropGeometry.shapePath(.roundedRectangle, in: rect, radii: radii)
        #expect(!path.contains(CGPoint(x: 2, y: 98)))   // 左上（y 軸上向き）は丸められて外側
        #expect(path.contains(CGPoint(x: 98, y: 98)))   // 右上は角のまま
        #expect(path.contains(CGPoint(x: 2, y: 2)))     // 左下も角のまま
    }
}

// MARK: - 許容誤差付き比較ヘルパー

private func isClose(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
    abs(lhs.x - rhs.x) < AppConstants.floatingPointTolerance
        && abs(lhs.y - rhs.y) < AppConstants.floatingPointTolerance
}

private func isClose(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
    abs(lhs.width - rhs.width) < AppConstants.floatingPointTolerance
        && abs(lhs.height - rhs.height) < AppConstants.floatingPointTolerance
}

private func isClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    isClose(lhs.origin, rhs.origin) && isClose(lhs.size, rhs.size)
}
