import Foundation
import Testing
@testable import Sobani

@Suite("DraggableImageView Static Methods Tests")
struct DraggableImageViewTests {

    // MARK: - scaleFactor Tests

    @Test("正のデルタでスケールファクター > 1")
    func scaleFactorPositiveDelta() {
        let result = DraggableImageView.scaleFactor(fromScrollDelta: 5.0)
        #expect(result > 1.0)
    }

    @Test("負のデルタでスケールファクター < 1")
    func scaleFactorNegativeDelta() {
        let result = DraggableImageView.scaleFactor(fromScrollDelta: -5.0)
        #expect(result < 1.0)
        #expect(result > 0.0)
    }

    @Test("ゼロデルタでスケールファクター = 1")
    func scaleFactorZeroDelta() {
        let result = DraggableImageView.scaleFactor(fromScrollDelta: 0.0)
        #expect(abs(result - 1.0) < AppConstants.floatingPointTolerance)
    }

    // MARK: - calculateResizedFrames Tests

    @Test("スケールアップ時に高さが増加")
    func calculateResizedFramesScaleUp() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.5, aspectRatio: 1.0,
            rotationAngle: 0, windowCenter: CGPoint(x: 500, y: 500)
        )
        #expect(frames.imageViewFrame.height > 200)
    }

    @Test("スケールダウン時に高さが減少")
    func calculateResizedFramesScaleDown() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 0.5, aspectRatio: 1.0,
            rotationAngle: 0, windowCenter: CGPoint(x: 500, y: 500)
        )
        #expect(frames.imageViewFrame.height < 200)
    }

    @Test("最小高さでクランプ")
    func calculateResizedFramesMinClamp() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 0.01, aspectRatio: 1.0,
            rotationAngle: 0, windowCenter: CGPoint(x: 500, y: 500)
        )
        let minDiff = abs(frames.imageViewFrame.height - AppConstants.minImageHeight)
        #expect(minDiff < AppConstants.floatingPointTolerance)
    }

    @Test("最大高さでクランプ")
    func calculateResizedFramesMaxClamp() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 5000, scaleFactor: 2.0, aspectRatio: 1.0,
            rotationAngle: 0, windowCenter: CGPoint(x: 500, y: 500)
        )
        let maxDiff = abs(frames.imageViewFrame.height - AppConstants.maxImageHeight)
        #expect(maxDiff < AppConstants.floatingPointTolerance)
    }

    @Test("ウィンドウ中心が維持される")
    func calculateResizedFramesCenterMaintained() {
        let center = CGPoint(x: 500, y: 300)
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.5, aspectRatio: 1.0,
            rotationAngle: 0, windowCenter: center
        )
        let resultCenterX = frames.windowFrame.midX
        let resultCenterY = frames.windowFrame.midY
        #expect(abs(resultCenterX - center.x) <= 1.0)
        #expect(abs(resultCenterY - center.y) <= 1.0)
    }

    @Test("アスペクト比が維持される")
    func calculateResizedFramesAspectRatioMaintained() {
        let aspectRatio: CGFloat = 16.0 / 9.0
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.5, aspectRatio: aspectRatio,
            rotationAngle: 0, windowCenter: CGPoint(x: 500, y: 500)
        )
        let resultAspectRatio = frames.imageViewFrame.width / frames.imageViewFrame.height
        #expect(abs(resultAspectRatio - aspectRatio) < AppConstants.floatingPointTolerance)
    }

    @Test("回転時にバウンディングボックスが拡大")
    func calculateResizedFramesWithRotation() {
        let framesNoRotation = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.0, aspectRatio: 2.0,
            rotationAngle: 0, windowCenter: CGPoint(x: 500, y: 500)
        )
        let framesRotated = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.0, aspectRatio: 2.0,
            rotationAngle: 45, windowCenter: CGPoint(x: 500, y: 500)
        )
        #expect(framesRotated.windowFrame.width > framesNoRotation.windowFrame.width)
        #expect(framesRotated.windowFrame.height > framesNoRotation.windowFrame.height)
    }

    @Test("画像ビューがウィンドウフレーム内に中央配置")
    func calculateResizedFramesImageViewCentered() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.0, aspectRatio: 1.5,
            rotationAngle: 30, windowCenter: CGPoint(x: 500, y: 500)
        )
        let expectedX = (frames.windowFrame.width - frames.imageViewFrame.width) / 2
        let expectedY = (frames.windowFrame.height - frames.imageViewFrame.height) / 2
        // windowFrame は round() で丸められるため、1.0 の許容誤差を使用
        #expect(abs(frames.imageViewFrame.origin.x - expectedX) <= 1.0)
        #expect(abs(frames.imageViewFrame.origin.y - expectedY) <= 1.0)
    }

    // MARK: - imageTransform Tests

    @Test("回転なし・反転なしでidentity")
    func imageTransformIdentity() {
        let transform = DraggableImageView.imageTransform(
            rotationDegrees: 0, isFlipped: false,
            boundsWidth: 100, boundsHeight: 100
        )
        #expect(transform.isIdentity)
    }

    @Test("90度回転")
    func imageTransformRotation90() {
        let transform = DraggableImageView.imageTransform(
            rotationDegrees: 90, isFlipped: false,
            boundsWidth: 100, boundsHeight: 100
        )
        #expect(!transform.isIdentity)
        // 90度回転: a≈0, b≈1, c≈-1, d≈0 (negative angle convention)
        #expect(abs(transform.a) < AppConstants.floatingPointTolerance)
        #expect(abs(transform.d) < AppConstants.floatingPointTolerance)
    }

    @Test("反転のみ")
    func imageTransformFlipOnly() {
        let transform = DraggableImageView.imageTransform(
            rotationDegrees: 0, isFlipped: true,
            boundsWidth: 100, boundsHeight: 100
        )
        #expect(!transform.isIdentity)
        // Flip: a=-1, d=1
        #expect(abs(transform.a - (-1.0)) < AppConstants.floatingPointTolerance)
        #expect(abs(transform.d - 1.0) < AppConstants.floatingPointTolerance)
    }

    @Test("回転+反転の組み合わせ")
    func imageTransformRotationAndFlip() {
        let transform = DraggableImageView.imageTransform(
            rotationDegrees: 45, isFlipped: true,
            boundsWidth: 100, boundsHeight: 100
        )
        #expect(!transform.isIdentity)
    }

    @Test("360度回転はidentityに近い")
    func imageTransformFullRotation() {
        let transform = DraggableImageView.imageTransform(
            rotationDegrees: 360, isFlipped: false,
            boundsWidth: 200, boundsHeight: 150
        )
        #expect(abs(transform.a - 1.0) < AppConstants.floatingPointTolerance)
        #expect(abs(transform.d - 1.0) < AppConstants.floatingPointTolerance)
        #expect(abs(transform.b) < AppConstants.floatingPointTolerance)
        #expect(abs(transform.c) < AppConstants.floatingPointTolerance)
    }
}
