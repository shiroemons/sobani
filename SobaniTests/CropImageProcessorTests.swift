import AppKit
import Foundation
import Testing
@testable import Sobani

private struct PixelRGBA {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

@Suite struct CropImageProcessorTests {

    // テスト用に指定サイズのCGImageを生成するヘルパー
    private func makeTestImage(width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // 赤で塗りつぶし
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    // MARK: - applyFullCrop

    @Test func fullCrop_defaultCropRect_preservesDimensions() throws {
        let image = try #require(makeTestImage(width: 200, height: 100))
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: .full))
        #expect(result.width == 200)
        #expect(result.height == 100)
    }

    @Test func fullCrop_withQuarterTurn_swapsDimensions() throws {
        let image = try #require(makeTestImage(width: 200, height: 100))
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: 1)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        // 90°回転後: 200x100 → 100x200、次にfull cropで100x200
        #expect(result.width == 100)
        #expect(result.height == 200)
    }

    @Test func fullCrop_withFlip_preservesDimensions() throws {
        let image = try #require(makeTestImage(width: 200, height: 100))
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, isFlippedInCrop: true)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        #expect(result.width == 200)
        #expect(result.height == 100)
    }

    // MARK: - applyShapeMask

    /// Creates a test image with top half red and bottom half blue
    private func makeTwoToneImage(width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // Bottom half blue (CGContext origin is bottom-left)
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        // Top half red
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
        return context.makeImage()
    }

    /// 指定座標のピクセルのRGBA値を取得するヘルパー
    private func pixelRGBA(of image: CGImage, atX x: Int, y: Int) -> PixelRGBA? {
        guard x >= 0, x < image.width, y >= 0, y < image.height else { return nil }
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        let offset = (y * image.width + x) * 4
        return PixelRGBA(
            red: buffer[offset], green: buffer[offset + 1],
            blue: buffer[offset + 2], alpha: buffer[offset + 3]
        )
    }

    /// 指定座標のピクセルのアルファ値を取得するヘルパー
    private func pixelAlpha(of image: CGImage, atX x: Int, y: Int) -> UInt8? {
        pixelRGBA(of: image, atX: x, y: y)?.alpha
    }

    @Test func shapeMask_rectangle_noChange() throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        let cropRect = CropRect(x: 0, y: 0, width: 1, height: 1) // default rectangle
        let result = CropImageProcessor.applyFullCrop(to: image, cropRect: cropRect)
        // rectangle returns the same image (identity)
        #expect(result?.width == image.width)
        #expect(result?.height == image.height)
    }

    @Test func shapeMask_circle_cornersTransparent() throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        let cropRect = CropRect(
            x: 0, y: 0, width: 1, height: 1,
            shape: .circle
        )
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: cropRect))
        #expect(result.width == 100)
        #expect(result.height == 100)

        // Corners should be transparent (alpha = 0)
        // Top-left corner (0,0 in CGContext is top-left)
        let topLeftAlpha = try #require(pixelAlpha(of: result, atX: 0, y: 0))
        #expect(topLeftAlpha == 0)
        // Top-right corner
        let topRightAlpha = try #require(pixelAlpha(of: result, atX: 99, y: 0))
        #expect(topRightAlpha == 0)
        // Bottom-left corner
        let bottomLeftAlpha = try #require(pixelAlpha(of: result, atX: 0, y: 99))
        #expect(bottomLeftAlpha == 0)
        // Bottom-right corner
        let bottomRightAlpha = try #require(pixelAlpha(of: result, atX: 99, y: 99))
        #expect(bottomRightAlpha == 0)

        // Center should be opaque
        let centerAlpha = try #require(pixelAlpha(of: result, atX: 50, y: 50))
        #expect(centerAlpha == 255)
    }

    @Test func shapeMask_roundedRect_cornersTransparent() throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        let cropRect = CropRect(
            x: 0, y: 0, width: 1, height: 1,
            shape: .roundedRectangle,
            cornerRadii: CornerRadii.defaultLinked
        )
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: cropRect))
        #expect(result.width == 100)
        #expect(result.height == 100)

        // Extreme corners should be transparent
        let topLeftAlpha = try #require(pixelAlpha(of: result, atX: 0, y: 0))
        #expect(topLeftAlpha == 0)

        // Center should be opaque
        let centerAlpha = try #require(pixelAlpha(of: result, atX: 50, y: 50))
        #expect(centerAlpha == 255)
    }

    @Test func fullCrop_withCircleShape_appliesShapeMask() throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        let cropRect = CropRect(
            x: 0, y: 0, width: 1, height: 1,
            shape: .circle
        )
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: cropRect))

        // Corner should be transparent (shape mask applied)
        let cornerAlpha = try #require(pixelAlpha(of: result, atX: 0, y: 0))
        #expect(cornerAlpha == 0)

        // Center should be opaque
        let centerAlpha = try #require(pixelAlpha(of: result, atX: 50, y: 50))
        #expect(centerAlpha == 255)
    }

    @Test func fullCrop_circleShape_cropsCorrectArea() throws {
        // Create 100x200 image: top half red, bottom half blue
        let image = try #require(makeTwoToneImage(width: 100, height: 200))

        // Crop the TOP half with circle shape
        // CropRect y=0 is bottom, so top half = y=0.5, height=0.5
        let cropRect = CropRect(
            x: 0, y: 0.5, width: 1, height: 0.5,
            shape: .circle
        )
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: cropRect))

        // Result should be 100x100 (top half of 100x200)
        #expect(result.width == 100)
        #expect(result.height == 100)

        // Center pixel should be RED (from the top half), not blue
        // In CGContext readback, (0,0) is top-left, so center of 100x100 is (50,50)
        let centerPixel = try #require(pixelRGBA(of: result, atX: 50, y: 50))
        #expect(centerPixel.red > 200)   // should be red
        #expect(centerPixel.blue < 50)   // should NOT be blue
        #expect(centerPixel.alpha > 200) // should be opaque (inside the ellipse)
    }

    /// 下半分(青)をクロップしたとき、中心ピクセルが青であることを確認
    @Test func fullCrop_circleShape_cropsBottomHalfBlue() throws {
        // Create 100x200 image: top half red, bottom half blue
        let image = try #require(makeTwoToneImage(width: 100, height: 200))

        // Crop the BOTTOM half: CropRect y=0 is bottom, so bottom half = y=0.0, height=0.5
        let cropRect = CropRect(
            x: 0, y: 0.0, width: 1, height: 0.5,
            shape: .circle
        )
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: cropRect))

        #expect(result.width == 100)
        #expect(result.height == 100)

        // Center pixel should be BLUE (from the bottom half), not red
        let centerPixel = try #require(pixelRGBA(of: result, atX: 50, y: 50))
        #expect(centerPixel.blue > 200)  // should be blue
        #expect(centerPixel.red < 50)    // should NOT be red
        #expect(centerPixel.alpha > 200) // should be opaque (inside the ellipse)
    }

    /// cropRectのみ（shape=rectangle）で上半分が赤・下半分が青を正確に切り出すことを確認
    @Test func applyCropRect_twoToneImage_cropsTopHalfRed() throws {
        let image = try #require(makeTwoToneImage(width: 100, height: 200))

        // y=0.5, height=0.5 → top half (y=0 is bottom in CropRect)
        let cropRect = CropRect(x: 0, y: 0.5, width: 1, height: 0.5)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: cropRect))

        #expect(result.width == 100)
        #expect(result.height == 100)

        let centerPixel = try #require(pixelRGBA(of: result, atX: 50, y: 50))
        #expect(centerPixel.red > 200)  // top half must be red
        #expect(centerPixel.blue < 50)
    }

    @Test func applyCropRect_twoToneImage_cropsBottomHalfBlue() throws {
        let image = try #require(makeTwoToneImage(width: 100, height: 200))

        // y=0.0, height=0.5 → bottom half
        let cropRect = CropRect(x: 0, y: 0.0, width: 1, height: 0.5)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: cropRect))

        #expect(result.width == 100)
        #expect(result.height == 100)

        let centerPixel = try #require(pixelRGBA(of: result, atX: 50, y: 50))
        #expect(centerPixel.blue > 200)  // bottom half must be blue
        #expect(centerPixel.red < 50)
    }

    /// パン操作後にクロップ領域が画像外にはみ出す場合のY軸処理を検証
    /// スローパス（CGContext描画）でのY軸が正しいことを確認
    @Test func applyCropRect_twoToneImage_cropExtendingBeyondTop() throws {
        let image = try #require(makeTwoToneImage(width: 100, height: 200))

        // y=0.5, height=1.0 → 画像の上半分から画像外まで（スローパスを強制）
        // 表示結果: 上50%が画像の上半分（赤）、下50%が透明
        let cropRect = CropRect(x: 0, y: 0.5, width: 1, height: 1.0)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: cropRect))

        #expect(result.width == 100)
        #expect(result.height == 200)

        // 下半分（CGContextリードバックでy=150）は赤であること（画像の上半分）
        let bottomPixel = try #require(pixelRGBA(of: result, atX: 50, y: 150))
        #expect(
            bottomPixel.red > 200, "下半分のピクセルは赤（画像の上半分）であるべき"
        )
        #expect(bottomPixel.blue < 50, "Y軸が反転している場合、青が表示される")

        // 上半分（CGContextリードバックでy=50）は透明であること（画像外）
        let topPixel = try #require(pixelRGBA(of: result, atX: 50, y: 50))
        #expect(topPixel.alpha == 0, "画像外の領域は透明であるべき")
    }

    // MARK: - extractCGImage

    /// extractCGImage が画像の上下方向を保持することを確認する
    /// CGContext のリードバック座標では y=0 がバッファ上端（視覚的な上）
    @Test func extractCGImage_preservesOrientation() throws {
        // 100x100 の2トーン画像を生成（上半分: 赤, 下半分: 青）
        let cgImage = try #require(makeTwoToneImage(width: 100, height: 100))
        let nsImage = NSImage(
            cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)
        )

        // extractCGImage で取得
        let extracted = try #require(DraggableImageView.extractCGImage(from: nsImage))

        // 上端付近（CGContextリードバックでy=25）は赤であること
        let topPixel = try #require(pixelRGBA(of: extracted, atX: 50, y: 25))
        #expect(
            topPixel.red > 200, "上半分のピクセルは赤であるべき（Y軸が保持されている）"
        )
        #expect(
            topPixel.blue < 50, "上半分のピクセルが青になっている場合はY軸が反転している"
        )

        // 下端付近（CGContextリードバックでy=75）は青であること
        let bottomPixel = try #require(pixelRGBA(of: extracted, atX: 50, y: 75))
        #expect(
            bottomPixel.blue > 200, "下半分のピクセルは青であるべき（Y軸が保持されている）"
        )
        #expect(
            bottomPixel.red < 50, "下半分のピクセルが赤になっている場合はY軸が反転している"
        )
    }

}

// MARK: - 共通変換による 1 回描画（回転・反転・傾き・サイズ）

extension CropImageProcessorTests {

    /// 1 行の画像を左から指定色で塗り分けて生成するヘルパー（各色 1 ピクセル）
    private func makeRowImage(_ colors: [TestColor]) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: colors.count, height: 1,
            bitsPerComponent: 8, bytesPerRow: colors.count * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        for (index, color) in colors.enumerated() {
            context.setFillColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
            context.fill(CGRect(x: index, y: 0, width: 1, height: 1))
        }
        return context.makeImage()
    }

    private static let red = TestColor(red: 1, green: 0, blue: 0)
    private static let green = TestColor(red: 0, green: 1, blue: 0)
    private static let blue = TestColor(red: 0, green: 0, blue: 1)
    private static let white = TestColor(red: 1, green: 1, blue: 1)

    // MARK: - 90° 回転

    @Test(arguments: [(0, 100, 200), (1, 200, 100), (2, 100, 200), (3, 200, 100), (4, 100, 200)])
    func quarterTurns_outputSize(turns: Int, expectedWidth: Int, expectedHeight: Int) throws {
        let image = try #require(makeTestImage(width: 100, height: 200))
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: turns)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        #expect(result.width == expectedWidth)
        #expect(result.height == expectedHeight)
    }

    /// 90° 回転は時計回り：左端の赤が上に来る
    @Test func quarterTurn_one_isClockwise() throws {
        let image = try #require(makeRowImage([Self.red, Self.blue]))
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: 1)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        #expect(result.width == 1)
        #expect(result.height == 2)
        let top = try #require(pixelRGBA(of: result, atX: 0, y: 0))
        let bottom = try #require(pixelRGBA(of: result, atX: 0, y: 1))
        #expect(top.red > 200 && top.blue < 50)
        #expect(bottom.blue > 200 && bottom.red < 50)
    }

    /// 負の quarterTurns も正規化して適用される（-1 = 時計回り 270°：左端の赤が下に来る）
    @Test func quarterTurn_negative_isNormalized() throws {
        let image = try #require(makeRowImage([Self.red, Self.blue]))
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: -1)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        #expect(result.width == 1)
        #expect(result.height == 2)
        let bottom = try #require(pixelRGBA(of: result, atX: 0, y: 1))
        #expect(bottom.red > 200 && bottom.blue < 50)
    }

    // MARK: - 反転

    @Test func flip_mirrorsPixels() throws {
        let image = try #require(makeRowImage([Self.red, Self.blue]))
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, isFlippedInCrop: true)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        let left = try #require(pixelRGBA(of: result, atX: 0, y: 0))
        let right = try #require(pixelRGBA(of: result, atX: 1, y: 0))
        #expect(left.blue > 200 && left.red < 50)
        #expect(right.red > 200 && right.blue < 50)
    }

    /// エディタの反転操作（cropRectAfterFlip）後の出力は、反転前の出力の鏡像になる
    @Test func flipOperation_outputIsMirrorOfPreviousOutput() throws {
        let image = try #require(makeRowImage([Self.red, Self.green, Self.blue, Self.white]))
        let crop = CropRect(x: 0, y: 0, width: 0.5, height: 1)
        let before = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        let after = try #require(CropImageProcessor.applyFullCrop(
            to: image, cropRect: CropGeometry.cropRectAfterFlip(crop)
        ))
        #expect(after.width == 2)
        for column in 0..<2 {
            let original = try #require(pixelRGBA(of: before, atX: column, y: 0))
            let mirrored = try #require(pixelRGBA(of: after, atX: 1 - column, y: 0))
            #expect(original.red == mirrored.red)
            #expect(original.green == mirrored.green)
            #expect(original.blue == mirrored.blue)
        }
    }

    // MARK: - 傾き補正

    @Test func straighten_preservesCropSizeAndLeavesCornersTransparent() throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, straightenAngle: 30)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        #expect(result.width == 100)
        #expect(result.height == 100)
        #expect(try #require(pixelAlpha(of: result, atX: 0, y: 0)) == 0)
        #expect(try #require(pixelAlpha(of: result, atX: 50, y: 50)) == 255)
    }

    /// 正の傾き角は時計回り：右側は中線より下まで上半分（赤）が下がり、左側は中線より上に下半分（青）が上がる
    @Test func straighten_positiveAngleRotatesClockwise() throws {
        let image = try #require(makeTwoToneImage(width: 100, height: 100))
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, straightenAngle: 30)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        let rightBelowMiddle = try #require(pixelRGBA(of: result, atX: 90, y: 60))
        let leftAboveMiddle = try #require(pixelRGBA(of: result, atX: 10, y: 40))
        #expect(rightBelowMiddle.red > 200 && rightBelowMiddle.blue < 50)
        #expect(leftAboveMiddle.blue > 200 && leftAboveMiddle.red < 50)
    }

    // MARK: - 切り出しサイズ

    @Test func cropRect_full_preservesDimensions() throws {
        let image = try #require(makeTestImage(width: 200, height: 100))
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: .full))
        #expect(result.width == 200)
        #expect(result.height == 100)
    }

    @Test func cropRect_half_halvesDimensions() throws {
        let image = try #require(makeTestImage(width: 200, height: 100))
        let crop = CropRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        #expect(result.width == 100)
        #expect(result.height == 50)
    }

    @Test func cropRect_zeroSize_returnsNil() throws {
        let image = try #require(makeTestImage(width: 200, height: 100))
        let crop = CropRect(x: 0, y: 0, width: 0, height: 0)
        #expect(CropImageProcessor.applyFullCrop(to: image, cropRect: crop) == nil)
    }

    /// 0.55 × 100 = 55.000000000000007 でも 1px 余分な透明の縁が付かない（変換あり・なしの両方）
    @Test(arguments: [false, true])
    func cropRect_floatingPointNoise_doesNotAddPixel(isFlipped: Bool) throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        let crop = CropRect(x: 0.2, y: 0.2, width: 0.55, height: 0.55, isFlippedInCrop: isFlipped)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        #expect(result.width == 55)
        #expect(result.height == 55)
        #expect(try #require(pixelAlpha(of: result, atX: 54, y: 54)) == 255)
    }

    /// 壊れた巨大な CropRect でもクラッシュせず nil を返す
    @Test func cropRect_hugeExtent_returnsNil() throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        let crop = CropRect(x: 0, y: 0, width: 1e303, height: 1e303, straightenAngle: 5)
        #expect(CropImageProcessor.applyFullCrop(to: image, cropRect: crop) == nil)
    }

    /// maxOutputPixelSize を指定すると長辺がその値になるよう縮小して描画する（サムネイル用）
    @Test func maxOutputPixelSize_downscalesOutput() throws {
        let image = try #require(makeTestImage(width: 400, height: 200))
        let crop = CropRect(x: 0, y: 0, width: 0.5, height: 1)
        let result = try #require(
            CropImageProcessor.applyFullCrop(to: image, cropRect: crop, maxOutputPixelSize: 50)
        )
        #expect(result.width == 50)
        #expect(result.height == 50)
        let center = try #require(pixelRGBA(of: result, atX: 25, y: 25))
        #expect(center.red > 200 && center.alpha == 255)
    }

    /// 出力は sRGB（元画像が RGB 色空間ならその色空間）で生成される
    @Test func output_usesRGBColorSpace() throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, isFlippedInCrop: true)
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        #expect(result.colorSpace?.model == .rgb)
    }
}

private struct TestColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}
