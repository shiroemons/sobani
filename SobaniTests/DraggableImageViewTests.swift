import Cocoa
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

@Suite("DraggableImageView Hit Test Helper Tests")
struct DraggableImageViewHitTestTests {

    // MARK: - displayRect Tests

    @Test("正方形 view + 正方形 image → view 全体")
    func displayRectSquareViewSquareImage() {
        let rect = DraggableImageView.displayRect(
            viewSize: CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100)
        )
        #expect(abs(rect.origin.x) < AppConstants.floatingPointTolerance)
        #expect(abs(rect.origin.y) < AppConstants.floatingPointTolerance)
        #expect(abs(rect.width - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(rect.height - 100) < AppConstants.floatingPointTolerance)
    }

    @Test("横長 view + 正方形 image → 垂直 letterbox")
    func displayRectWideViewSquareImage() {
        let rect = DraggableImageView.displayRect(
            viewSize: CGSize(width: 200, height: 100),
            imageSize: CGSize(width: 100, height: 100)
        )
        // scale = min(200/100, 100/100) = 1.0 → 100×100、左右に50ずつ余白
        #expect(abs(rect.width - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(rect.height - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(rect.origin.x - 50) < AppConstants.floatingPointTolerance)
        #expect(abs(rect.origin.y) < AppConstants.floatingPointTolerance)
    }

    @Test("縦長 view + 正方形 image → 水平 letterbox")
    func displayRectTallViewSquareImage() {
        let rect = DraggableImageView.displayRect(
            viewSize: CGSize(width: 100, height: 200),
            imageSize: CGSize(width: 100, height: 100)
        )
        // scale = min(100/100, 200/100) = 1.0 → 100×100、上下に50ずつ余白
        #expect(abs(rect.width - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(rect.height - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(rect.origin.x) < AppConstants.floatingPointTolerance)
        #expect(abs(rect.origin.y - 50) < AppConstants.floatingPointTolerance)
    }

    @Test("ゼロサイズ画像 → .zero を返す")
    func displayRectZeroImageSize() {
        let rect = DraggableImageView.displayRect(
            viewSize: CGSize(width: 100, height: 100),
            imageSize: .zero
        )
        #expect(rect == .zero)
    }

    // MARK: - imagePointFromViewPoint Tests

    struct ImagePointTestCase: Sendable {
        let rotation: CGFloat
        let isFlipped: Bool
    }

    @Test("view 中心は image 中心にマップされる", arguments: [
        ImagePointTestCase(rotation: 0, isFlipped: false),
        ImagePointTestCase(rotation: 0, isFlipped: true),
        ImagePointTestCase(rotation: 90, isFlipped: false),
        ImagePointTestCase(rotation: 90, isFlipped: true),
        ImagePointTestCase(rotation: 180, isFlipped: false),
        ImagePointTestCase(rotation: 180, isFlipped: true),
        ImagePointTestCase(rotation: 270, isFlipped: false),
        ImagePointTestCase(rotation: 270, isFlipped: true)
    ])
    func viewCenterMapsToImageCenter(_ testCase: ImagePointTestCase) throws {
        let viewSize = CGSize(width: 100, height: 100)
        let imageSize = CGSize(width: 100, height: 100)
        let center = CGPoint(x: 50, y: 50)
        let result = DraggableImageView.imagePointFromViewPoint(
            viewPoint: center,
            viewSize: viewSize,
            imageSize: imageSize,
            rotationDegrees: testCase.rotation,
            isFlipped: testCase.isFlipped
        )
        let imagePoint = try #require(result)
        #expect(abs(imagePoint.x - 50) < 1.0)
        #expect(abs(imagePoint.y - 50) < 1.0)
    }

    @Test("letterbox 外の点は nil を返す")
    func imagePointFromViewPointLetterboxReturnsNil() {
        // 横長 view + 正方形 image → 左右に letterbox
        let viewSize = CGSize(width: 200, height: 100)
        let imageSize = CGSize(width: 100, height: 100)
        // x=10 は letterbox 領域（displayRect.origin.x = 50）
        let result = DraggableImageView.imagePointFromViewPoint(
            viewPoint: CGPoint(x: 10, y: 50),
            viewSize: viewSize,
            imageSize: imageSize,
            rotationDegrees: 0,
            isFlipped: false
        )
        #expect(result == nil)
    }

    @Test("view 範囲外の点は nil を返す")
    func imagePointFromViewPointOutOfBoundsReturnsNil() {
        let viewSize = CGSize(width: 100, height: 100)
        let imageSize = CGSize(width: 100, height: 100)
        let result = DraggableImageView.imagePointFromViewPoint(
            viewPoint: CGPoint(x: 150, y: 50),
            viewSize: viewSize,
            imageSize: imageSize,
            rotationDegrees: 0,
            isFlipped: false
        )
        #expect(result == nil)
    }

    @Test("y軸反転: view 上端は image 上端（CGImage y-down）")
    func imagePointYAxisFlipped() throws {
        let viewSize = CGSize(width: 100, height: 100)
        let imageSize = CGSize(width: 100, height: 100)
        // view 上端 (y=100) → image top (y near imageSize.height)
        let topResult = DraggableImageView.imagePointFromViewPoint(
            viewPoint: CGPoint(x: 50, y: 99),
            viewSize: viewSize,
            imageSize: imageSize,
            rotationDegrees: 0,
            isFlipped: false
        )
        let topPt = try #require(topResult)
        // view y-up の上端は CGImage y-down では y ≈ 1
        #expect(topPt.y < 5)

        // view 下端 (y=1) → image bottom (y near 0 の反対)
        let bottomResult = DraggableImageView.imagePointFromViewPoint(
            viewPoint: CGPoint(x: 50, y: 1),
            viewSize: viewSize,
            imageSize: imageSize,
            rotationDegrees: 0,
            isFlipped: false
        )
        let bottomPt = try #require(bottomResult)
        #expect(bottomPt.y > 95)
    }

    // MARK: - alphaMaskPixelIndex Tests

    private let mask10x10 = AlphaMask(
        width: 10, height: 10,
        bytes: [UInt8](repeating: 0, count: 100)
    )

    @Test("(0, 0) → インデックス 0")
    func alphaMaskPixelIndexOrigin() throws {
        let result = DraggableImageView.alphaMaskPixelIndex(
            imagePoint: CGPoint(x: 0, y: 0),
            imageSize: CGSize(width: 10, height: 10),
            mask: mask10x10
        )
        let idx = try #require(result)
        #expect(idx == 0)
    }

    @Test("右下端 → 最後のインデックス")
    func alphaMaskPixelIndexBottomRight() throws {
        let result = DraggableImageView.alphaMaskPixelIndex(
            imagePoint: CGPoint(x: 9.5, y: 9.5),
            imageSize: CGSize(width: 10, height: 10),
            mask: mask10x10
        )
        let idx = try #require(result)
        #expect(idx == 10 * 10 - 1)
    }

    @Test("負のx座標 → nil")
    func alphaMaskPixelIndexNegativeX() {
        let result = DraggableImageView.alphaMaskPixelIndex(
            imagePoint: CGPoint(x: -1, y: 5),
            imageSize: CGSize(width: 10, height: 10),
            mask: mask10x10
        )
        #expect(result == nil)
    }

    @Test("範囲外 → nil")
    func alphaMaskPixelIndexOutOfBounds() {
        let result = DraggableImageView.alphaMaskPixelIndex(
            imagePoint: CGPoint(x: 15, y: 5),
            imageSize: CGSize(width: 10, height: 10),
            mask: mask10x10
        )
        #expect(result == nil)
    }

    @Test("小数座標の floor 挙動")
    func alphaMaskPixelIndexFractional() throws {
        let result = DraggableImageView.alphaMaskPixelIndex(
            imagePoint: CGPoint(x: 2.9, y: 1.9),
            imageSize: CGSize(width: 10, height: 10),
            mask: mask10x10
        )
        let idx = try #require(result)
        // pixelX = Int(2.9) = 2, pixelY = Int(1.9) = 1 → 1*10 + 2 = 12
        #expect(idx == 12)
    }

    // MARK: - buildAlphaMask Tests

    private func makeCGImage(width: Int, height: Int, fill: CGColor?) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        if let fill {
            ctx.setFillColor(fill)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return ctx.makeImage()
    }

    @Test("全不透明 CGImage → 全バイト 255")
    func buildAlphaMaskFullOpaque() throws {
        let cgImage = try #require(makeCGImage(width: 4, height: 4, fill: CGColor(red: 1, green: 0, blue: 0, alpha: 1)))
        let mask = try #require(DraggableImageView.buildAlphaMask(from: cgImage))
        #expect(mask.width == 4)
        #expect(mask.height == 4)
        #expect(mask.bytes.allSatisfy { $0 == 255 })
    }

    @Test("全透明 CGImage → 全バイト 0")
    func buildAlphaMaskFullTransparent() throws {
        let cgImage = try #require(makeCGImage(width: 4, height: 4, fill: nil))
        let mask = try #require(DraggableImageView.buildAlphaMask(from: cgImage))
        #expect(mask.bytes.allSatisfy { $0 == 0 })
    }

    @Test("半透明 → 中間値")
    func buildAlphaMaskSemiTransparent() throws {
        let image = try #require(makeCGImage(width: 4, height: 4, fill: CGColor(red: 1, green: 0, blue: 0, alpha: 0.5)))
        let mask = try #require(DraggableImageView.buildAlphaMask(from: image))
        // 半透明なので全バイトが 0 でも 255 でもない
        #expect(mask.bytes.allSatisfy { $0 > 0 && $0 < 255 })
    }

    @Test("width/height が正しく記録される")
    func buildAlphaMaskDimensions() throws {
        let cgImage = try #require(makeCGImage(width: 8, height: 6, fill: CGColor(red: 1, green: 0, blue: 0, alpha: 1)))
        let mask = try #require(DraggableImageView.buildAlphaMask(from: cgImage))
        #expect(mask.width == 8)
        #expect(mask.height == 6)
        #expect(mask.bytes.count == 8 * 6)
    }

    // MARK: - Integration Scenario

    @Test("中心ピクセルはヒット、角の透過ピクセルは miss")
    func integrationHitTestCenterHitCornerMiss() throws {
        // 4×4 AlphaMask: 中央(1,1)〜(2,2)のみ不透明、それ以外透明
        var bytes = [UInt8](repeating: 0, count: 4 * 4)
        bytes[1 * 4 + 1] = 255
        bytes[1 * 4 + 2] = 255
        bytes[2 * 4 + 1] = 255
        bytes[2 * 4 + 2] = 255
        let mask = AlphaMask(width: 4, height: 4, bytes: bytes)

        let viewSize = CGSize(width: 100, height: 100)
        let imageSize = CGSize(width: 4, height: 4)

        // 中心 (50, 50) → imagePoint ≈ (2, 2) → マスク内で不透明
        let centerPoint = DraggableImageView.imagePointFromViewPoint(
            viewPoint: CGPoint(x: 50, y: 50),
            viewSize: viewSize,
            imageSize: imageSize,
            rotationDegrees: 0,
            isFlipped: false
        )
        let centerImagePt = try #require(centerPoint)
        let centerIdx = try #require(DraggableImageView.alphaMaskPixelIndex(
            imagePoint: centerImagePt,
            imageSize: imageSize,
            mask: mask
        ))
        #expect(mask.bytes[centerIdx] >= AppConstants.hitTestAlphaThreshold)

        // 左上角 (2, 98) → imagePoint ≈ (0, 0) → マスク内で透明
        let cornerPoint = DraggableImageView.imagePointFromViewPoint(
            viewPoint: CGPoint(x: 2, y: 98),
            viewSize: viewSize,
            imageSize: imageSize,
            rotationDegrees: 0,
            isFlipped: false
        )
        let cornerImagePt = try #require(cornerPoint)
        let cornerIdx = try #require(DraggableImageView.alphaMaskPixelIndex(
            imagePoint: cornerImagePt,
            imageSize: imageSize,
            mask: mask
        ))
        #expect(mask.bytes[cornerIdx] < AppConstants.hitTestAlphaThreshold)
    }
}
