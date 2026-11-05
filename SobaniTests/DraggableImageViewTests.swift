import Cocoa
import Foundation
import Testing
@testable import Sobani

@Suite("DraggableImageView Static Methods Tests")
struct DraggableImageViewTests {

    // MARK: - hasMoved Tests

    @Test("原点が変わらなければ移動なし（クリックのみ）")
    func hasMovedSameOrigin() {
        #expect(!DraggableImageView.hasMoved(from: NSPoint(x: 10, y: 20), to: NSPoint(x: 10, y: 20)))
    }

    @Test("x または y が変われば移動あり", arguments: [NSPoint(x: 11, y: 20), NSPoint(x: 10, y: 19)])
    func hasMovedDifferentOrigin(end: NSPoint) {
        #expect(DraggableImageView.hasMoved(from: NSPoint(x: 10, y: 20), to: end))
    }

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

    @Test("同じ量を拡大→縮小すると元の大きさに戻る", arguments: [1.0, 10.0, 37.5, 150.0])
    func scaleFactorRoundTripIsIdentity(delta: Double) {
        let enlarge = DraggableImageView.scaleFactor(fromScrollDelta: CGFloat(delta))
        let shrink = DraggableImageView.scaleFactor(fromScrollDelta: CGFloat(-delta))
        #expect(abs(enlarge * shrink - 1.0) < AppConstants.floatingPointTolerance)
    }

    @Test("大きな負のデルタでも倍率は正（画像が潰れない）", arguments: [-100.0, -250.0, -10_000.0])
    func scaleFactorLargeNegativeDeltaStaysPositive(delta: Double) {
        let result = DraggableImageView.scaleFactor(fromScrollDelta: CGFloat(delta))
        #expect(result > 0)
        #expect(result < 1.0)
    }

    @Test("非精密スクロール（ホイール）のデルタは行単位として点に換算される")
    func scaleFactorNonPreciseUsesLineHeight() {
        let wheel = DraggableImageView.scaleFactor(fromScrollDelta: 1, isPrecise: false)
        let trackpad = DraggableImageView.scaleFactor(fromScrollDelta: 1, isPrecise: true)
        #expect(wheel > trackpad)
        // 1 行 = 10pt
        let tenPoints = DraggableImageView.scaleFactor(fromScrollDelta: 10, isPrecise: true)
        #expect(abs(wheel - tenPoints) < AppConstants.floatingPointTolerance)
    }

    // MARK: - calculateResizedFrames Tests

    @Test("スケールアップ時に高さが増加")
    func calculateResizedFramesScaleUp() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.5, aspectRatio: 1.0,
            rotationAngle: 0, imageCenter: CGPoint(x: 500, y: 500)
        )
        #expect(frames.imageViewFrame.height > 200)
    }

    @Test("スケールダウン時に高さが減少")
    func calculateResizedFramesScaleDown() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 0.5, aspectRatio: 1.0,
            rotationAngle: 0, imageCenter: CGPoint(x: 500, y: 500)
        )
        #expect(frames.imageViewFrame.height < 200)
    }

    @Test("最小高さでクランプ")
    func calculateResizedFramesMinClamp() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 0.01, aspectRatio: 1.0,
            rotationAngle: 0, imageCenter: CGPoint(x: 500, y: 500)
        )
        let minDiff = abs(frames.imageViewFrame.height - AppConstants.minImageHeight)
        #expect(minDiff < AppConstants.floatingPointTolerance)
    }

    @Test("最大高さでクランプ")
    func calculateResizedFramesMaxClamp() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 5000, scaleFactor: 2.0, aspectRatio: 1.0,
            rotationAngle: 0, imageCenter: CGPoint(x: 500, y: 500)
        )
        let maxDiff = abs(frames.imageViewFrame.height - AppConstants.maxImageHeight)
        #expect(maxDiff < AppConstants.floatingPointTolerance)
    }

    @Test("ウィンドウ中心が維持される")
    func calculateResizedFramesCenterMaintained() {
        let center = CGPoint(x: 500, y: 300)
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.5, aspectRatio: 1.0,
            rotationAngle: 0, imageCenter: center
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
            rotationAngle: 0, imageCenter: CGPoint(x: 500, y: 500)
        )
        let resultAspectRatio = frames.imageViewFrame.width / frames.imageViewFrame.height
        #expect(abs(resultAspectRatio - aspectRatio) < AppConstants.floatingPointTolerance)
    }

    @Test("回転時にバウンディングボックスが拡大")
    func calculateResizedFramesWithRotation() {
        let framesNoRotation = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.0, aspectRatio: 2.0,
            rotationAngle: 0, imageCenter: CGPoint(x: 500, y: 500)
        )
        let framesRotated = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.0, aspectRatio: 2.0,
            rotationAngle: 45, imageCenter: CGPoint(x: 500, y: 500)
        )
        #expect(framesRotated.windowFrame.width > framesNoRotation.windowFrame.width)
        #expect(framesRotated.windowFrame.height > framesNoRotation.windowFrame.height)
    }

    @Test("画像ビューがウィンドウフレーム内に中央配置")
    func calculateResizedFramesImageViewCentered() {
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 200, scaleFactor: 1.0, aspectRatio: 1.5,
            rotationAngle: 30, imageCenter: CGPoint(x: 500, y: 500)
        )
        let expectedX = (frames.windowFrame.width - frames.imageViewFrame.width) / 2
        let expectedY = (frames.windowFrame.height - frames.imageViewFrame.height) / 2
        // windowFrame は round() で丸められるため、1.0 の許容誤差を使用
        #expect(abs(frames.imageViewFrame.origin.x - expectedX) <= 1.0)
        #expect(abs(frames.imageViewFrame.origin.y - expectedY) <= 1.0)
    }

    @Test("画像の中心は丸めの影響を受けずアンカーと一致する")
    func calculateResizedFramesKeepsExactImageCenter() {
        let center = CGPoint(x: 500.3, y: 299.8)
        let frames = DraggableImageView.calculateResizedFrames(
            currentHeight: 201, scaleFactor: 1.37, aspectRatio: 0.7,
            rotationAngle: 23, imageCenter: center
        )
        let imageCenterX = frames.windowFrame.minX + frames.imageViewFrame.midX
        let imageCenterY = frames.windowFrame.minY + frames.imageViewFrame.midY
        #expect(abs(imageCenterX - center.x) < AppConstants.floatingPointTolerance)
        #expect(abs(imageCenterY - center.y) < AppConstants.floatingPointTolerance)
    }

    @Test("スクロールで拡大縮小を繰り返しても画像の位置がずれない")
    func calculateResizedFramesRepeatedScrollDoesNotDrift() {
        let start = CGPoint(x: 812.5, y: 433.25)
        var center = start
        var height: CGFloat = 333
        // 拡大・縮小を交互に繰り返す（回転ありで外接矩形の幅の偶奇が頻繁に変わる）
        for step in 0..<200 {
            let delta: CGFloat = step.isMultiple(of: 2) ? 7 : -7
            let frames = DraggableImageView.calculateResizedFrames(
                currentHeight: height,
                scaleFactor: DraggableImageView.scaleFactor(fromScrollDelta: delta),
                aspectRatio: 0.75, rotationAngle: 17, imageCenter: center
            )
            height = frames.imageViewFrame.height
            center = CGPoint(
                x: frames.windowFrame.minX + frames.imageViewFrame.midX,
                y: frames.windowFrame.minY + frames.imageViewFrame.midY
            )
        }
        #expect(abs(center.x - start.x) < AppConstants.floatingPointTolerance)
        #expect(abs(center.y - start.y) < AppConstants.floatingPointTolerance)
        #expect(abs(height - 333) < AppConstants.floatingPointTolerance)
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

    /// 反転の有無にかかわらず、画像の「上方向」は時計回りに rotationDegrees 度傾く（反転→回転の順）
    @Test("反転時も見た目の傾きはダイアルの角度と一致", arguments: [30.0, 45.0, 90.0, 135.0, 300.0])
    func imageTransformFlipKeepsVisibleTilt(degrees: Double) {
        let width: CGFloat = 200
        let height: CGFloat = 100
        let center = CGPoint(x: width / 2, y: height / 2)
        let upPoint = CGPoint(x: center.x, y: center.y + 10)
        let radians = CGFloat(degrees) * .pi / 180
        // 時計回りに θ 回転した上方向ベクトル（y-up 座標系）
        let expected = CGPoint(x: center.x + 10 * sin(radians), y: center.y + 10 * cos(radians))

        for isFlipped in [false, true] {
            let transform = DraggableImageView.imageTransform(
                rotationDegrees: CGFloat(degrees), isFlipped: isFlipped,
                boundsWidth: width, boundsHeight: height
            )
            let mappedCenter = center.applying(transform)
            let mappedUp = upPoint.applying(transform)
            #expect(abs(mappedCenter.x - center.x) < AppConstants.floatingPointTolerance)
            #expect(abs(mappedCenter.y - center.y) < AppConstants.floatingPointTolerance)
            #expect(abs(mappedUp.x - expected.x) < AppConstants.floatingPointTolerance)
            #expect(abs(mappedUp.y - expected.y) < AppConstants.floatingPointTolerance)
        }
    }

    /// 反転時は画像の右方向が回転後の左方向になる（鏡像を回転させる）
    @Test("反転+回転で右方向ベクトルは回転後に左右反転する")
    func imageTransformFlipMirrorsBeforeRotation() {
        let size: CGFloat = 100
        let center = CGPoint(x: size / 2, y: size / 2)
        let rightPoint = CGPoint(x: center.x + 10, y: center.y)
        let transform = DraggableImageView.imageTransform(
            rotationDegrees: 90, isFlipped: true,
            boundsWidth: size, boundsHeight: size
        )
        // 鏡像化で右→左 (-10, 0)、時計回り 90° で (0, +10)（上方向）
        let mapped = rightPoint.applying(transform)
        #expect(abs(mapped.x - center.x) < AppConstants.floatingPointTolerance)
        #expect(abs(mapped.y - (center.y + 10)) < AppConstants.floatingPointTolerance)
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

    @Test("長辺が上限以下ならマスクは元のサイズ")
    func alphaMaskSizeWithinLimit() {
        let size = DraggableImageView.alphaMaskSize(width: 800, height: 600, maxDimension: 2048)
        #expect(size.width == 800)
        #expect(size.height == 600)
    }

    @Test("長辺が上限を超えると縦横比を保って縮小される", arguments: [
        (4096, 100, 2048, 50),
        (100, 8000, 26, 2048),
        (10_000, 1, 2048, 1)
    ])
    func alphaMaskSizeDownsamples(width: Int, height: Int, expectedWidth: Int, expectedHeight: Int) {
        let size = DraggableImageView.alphaMaskSize(width: width, height: height, maxDimension: 2048)
        #expect(size.width == expectedWidth)
        #expect(size.height == expectedHeight)
    }

    @Test("大きな画像のマスクは縮小され、ヒット判定は比率で同じ位置を参照する")
    func buildAlphaMaskDownsampled() throws {
        let cgImage = try #require(makeCGImage(width: 64, height: 16, fill: CGColor(red: 1, green: 0, blue: 0, alpha: 1)))
        let mask = try #require(DraggableImageView.buildAlphaMask(from: cgImage, maxDimension: 8))
        #expect(mask.width == 8)
        #expect(mask.height == 2)
        #expect(mask.bytes.allSatisfy { $0 == 255 })
        // 画像座標の右下端は縮小後のマスクでも最後のピクセルを指す
        let index = try #require(DraggableImageView.alphaMaskPixelIndex(
            imagePoint: CGPoint(x: 63.5, y: 15.5), imageSize: CGSize(width: 64, height: 16), mask: mask
        ))
        #expect(index == 8 * 2 - 1)
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

@Suite("DraggableImageView Image Replacement Tests")
@MainActor
struct DraggableImageViewImageReplacementTests {
    /// 赤で塗った画像を作る。`transparentRight` が true なら右半分を透明にする。
    static func makeImage(width: Int, height: Int, transparentRight: Bool = false) throws -> NSImage {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.red.setFill()
        let fillWidth = transparentRight ? width / 2 : width
        NSRect(x: 0, y: 0, width: fillWidth, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return image
    }

    @Test("画像差し替えで旧画像のクロップと元画像が破棄される")
    func replaceImageClearsCrop() throws {
        let view = DraggableImageView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let oldImage = try Self.makeImage(width: 40, height: 20)
        let newImage = try Self.makeImage(width: 30, height: 30)
        view.image = oldImage
        view.cropRect = CropRect(x: 0, y: 0, width: 0.5, height: 1)
        #expect(view.originalImage === oldImage)

        view.replaceImage(newImage)

        #expect(view.cropRect == nil)
        #expect(view.originalImage == nil)
        #expect(view.image === newImage)

        // 切り取りリセットしても旧画像には戻らない
        view.resetCrop()
        #expect(view.image === newImage)
    }

    @Test("元画像の差し替え（背景除去）ではクロップが維持され新しい元画像に再適用される")
    func setOriginalImageKeepsCrop() throws {
        let view = DraggableImageView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let source = try Self.makeImage(width: 40, height: 20)
        let processed = try Self.makeImage(width: 40, height: 20)
        let crop = CropRect(x: 0, y: 0, width: 0.5, height: 1)
        view.image = source
        view.cropRect = crop

        view.setOriginalImage(processed)

        let currentCrop = try #require(view.cropRect)
        #expect(abs(currentCrop.width - crop.width) < AppConstants.floatingPointTolerance)
        #expect(view.originalImage === processed)
        let displayed = try #require(view.image)
        #expect(displayed !== processed)
        // 40x20 の左半分 → 20x20
        #expect(abs(displayed.size.width - 20) < AppConstants.floatingPointTolerance)
        #expect(abs(displayed.size.height - 20) < AppConstants.floatingPointTolerance)

        // 切り取りリセットで背景除去後の元画像に戻る
        view.resetCrop()
        #expect(view.image === processed)
    }

    @Test("透過の有無は元画像で判定し、画像の差し替えで再判定される")
    func sourceImageHasAlphaFollowsImageChanges() throws {
        let view = DraggableImageView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        view.image = try Self.makeImage(width: 40, height: 40)
        #expect(!view.sourceImageHasAlpha())

        view.replaceImage(try Self.makeImage(width: 40, height: 40, transparentRight: true))
        #expect(view.sourceImageHasAlpha())
    }

    @Test("円形クロップで表示画像に透過ができても元画像が不透明なら透過なしと判定する")
    func sourceImageHasAlphaIgnoresCropShape() throws {
        let view = DraggableImageView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        view.image = try Self.makeImage(width: 40, height: 40)
        #expect(!view.sourceImageHasAlpha())

        view.cropRect = CropRect(x: 0, y: 0, width: 1, height: 1, shape: .circle)

        // 表示画像（円形）には透過がある
        let mask = try #require(view.ensureAlphaMask())
        #expect(mask.bytes.contains { $0 < UInt8.max })
        #expect(!view.sourceImageHasAlpha())
    }

    @Test("切り取りリセットで縦横比が元画像のものに戻る")
    func resetCropRestoresAspectRatio() throws {
        let view = DraggableImageView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        view.image = try Self.makeImage(width: 40, height: 20)
        view.aspectRatio = 2.0
        view.cropRect = CropRect(x: 0, y: 0, width: 0.25, height: 1)
        // 40x20 の左 1/4 → 10x20
        #expect(abs(view.aspectRatio - 0.5) < AppConstants.floatingPointTolerance)

        view.resetCrop()

        #expect(abs(view.aspectRatio - 2.0) < AppConstants.floatingPointTolerance)
    }
}
