import Foundation
import Testing
@testable import Sobani

@Suite struct CropGeometryTests {

    // MARK: - zoomScaleForStraighten テスト

    @Test func zoomScale_zeroAngle_returnsOne() {
        let scale = CropGeometry.zoomScaleForStraighten(angleDegrees: 0, aspectRatio: 1.0)
        #expect(abs(scale - 1.0) < AppConstants.floatingPointTolerance)
    }

    @Test func zoomScale_nonZeroAngle_greaterThanOne() {
        let scale = CropGeometry.zoomScaleForStraighten(angleDegrees: 15, aspectRatio: 1.0)
        #expect(scale > 1.0)
    }

    @Test func zoomScale_negativeAngle_sameAsPositive() {
        let scalePos = CropGeometry.zoomScaleForStraighten(angleDegrees: 20, aspectRatio: 4.0 / 3.0)
        let scaleNeg = CropGeometry.zoomScaleForStraighten(angleDegrees: -20, aspectRatio: 4.0 / 3.0)
        #expect(abs(scalePos - scaleNeg) < AppConstants.floatingPointTolerance)
    }

    @Test func zoomScale_45degrees_maxZoom() {
        let scale15 = CropGeometry.zoomScaleForStraighten(angleDegrees: 15, aspectRatio: 1.0)
        let scale45 = CropGeometry.zoomScaleForStraighten(angleDegrees: 45, aspectRatio: 1.0)
        #expect(scale45 > scale15)
    }

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
        #expect(abs(CropGeometry.clampStraightenAngle(30) - 30) < AppConstants.floatingPointTolerance)
        #expect(abs(CropGeometry.clampStraightenAngle(-30) - (-30)) < AppConstants.floatingPointTolerance)
    }

    @Test func clampStraightenAngle_clampsExtremes() {
        #expect(abs(CropGeometry.clampStraightenAngle(90) - 45) < AppConstants.floatingPointTolerance)
        #expect(abs(CropGeometry.clampStraightenAngle(-90) - (-45)) < AppConstants.floatingPointTolerance)
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
        let result = CropGeometry.viewRectToNormalizedCrop(cropFrame: cropFrame, imageRect: imageRect)
        #expect(abs(result.x - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.width - 1) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 1) < AppConstants.floatingPointTolerance)
    }

    @Test func viewRectToNormalizedCrop_halfCrop() {
        let cropFrame = CGRect(x: 200, y: 175, width: 200, height: 150)
        let imageRect = CGRect(x: 100, y: 100, width: 400, height: 300)
        let result = CropGeometry.viewRectToNormalizedCrop(cropFrame: cropFrame, imageRect: imageRect)
        #expect(abs(result.x - 0.25) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 0.25) < AppConstants.floatingPointTolerance)
        #expect(abs(result.width - 0.5) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 0.5) < AppConstants.floatingPointTolerance)
    }

    // MARK: - initialStateFromCropRect テスト

    @Test func initialStateFromCropRect_fullCrop() {
        let cropRect = CropRect.full
        let result = CropGeometry.initialStateFromCropRect(
            cropRect: cropRect,
            canvasSize: CGSize(width: 480, height: 476),
            imageSize: CGSize(width: 800, height: 600)
        )
        // full crop (width=1, height=1) → zoom = 1/max(1,1) = 1.0
        #expect(abs(result.zoom - 1.0) < AppConstants.floatingPointTolerance)
        // 中心が一致するためオフセットは0
        #expect(abs(result.offset.x - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.offset.y - 0) < AppConstants.floatingPointTolerance)
    }

    @Test func initialStateFromCropRect_zoomedCrop() {
        let cropRect = CropRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let result = CropGeometry.initialStateFromCropRect(
            cropRect: cropRect,
            canvasSize: CGSize(width: 480, height: 476),
            imageSize: CGSize(width: 800, height: 600)
        )
        // クロップ領域が縮小されているため zoom > 1.0
        #expect(result.zoom > 1.0)
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
        #expect(abs(result.originY - (0.1 + 0.5 - result.height)) < AppConstants.floatingPointTolerance)
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

// MARK: - clampOffset / pixelCornerRadius / cornerRadiusHandlePosition / cornerRadiusFromDrag / viewRectToNormalizedCrop ラウンドトリップ

extension CropGeometryTests {

    // MARK: - clampOffset テスト

    @Test func clampOffset_withinBounds() {
        let offset = CGPoint(x: 10, y: 10)
        let result = CropGeometry.clampOffset(
            offset: offset,
            imageSize: CGSize(width: 400, height: 300),
            cropFrameSize: CGSize(width: 200, height: 150)
        )
        #expect(abs(result.x - 10) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 10) < AppConstants.floatingPointTolerance)
    }

    @Test func clampOffset_exceedsBounds() {
        let offset = CGPoint(x: 200, y: 200)
        let result = CropGeometry.clampOffset(
            offset: offset,
            imageSize: CGSize(width: 400, height: 300),
            cropFrameSize: CGSize(width: 200, height: 150)
        )
        // maxOffsetX = (400-200)/2 = 100, maxOffsetY = (300-150)/2 = 75
        #expect(abs(result.x - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 75) < AppConstants.floatingPointTolerance)
    }

    @Test func clampOffset_imageSmallerThanCrop() {
        let offset = CGPoint(x: 50, y: 50)
        let result = CropGeometry.clampOffset(
            offset: offset,
            imageSize: CGSize(width: 100, height: 100),
            cropFrameSize: CGSize(width: 200, height: 200)
        )
        // imageSize < cropFrameSize → maxOffset = 0
        #expect(abs(result.x - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 0) < AppConstants.floatingPointTolerance)
    }

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

        let result = CropGeometry.viewRectToNormalizedCrop(cropFrame: cropFrame, imageRect: imageRect)

        #expect(abs(result.x - originalX) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - originalY) < AppConstants.floatingPointTolerance)
        #expect(abs(result.width - originalW) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - originalH) < AppConstants.floatingPointTolerance)
    }
}
