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
}
