import AppKit
import Foundation
import Testing
@testable import Sobani

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

    // MARK: - applyQuarterTurns

    @Test func quarterTurns_zero_preservesSize() throws {
        let image = try #require(makeTestImage(width: 100, height: 200))
        let result = try #require(CropImageProcessor.applyQuarterTurns(to: image, turns: 0))
        #expect(result.width == 100)
        #expect(result.height == 200)
    }

    @Test func quarterTurns_one_swapsDimensions() throws {
        let image = try #require(makeTestImage(width: 100, height: 200))
        let result = try #require(CropImageProcessor.applyQuarterTurns(to: image, turns: 1))
        #expect(result.width == 200)
        #expect(result.height == 100)
    }

    @Test func quarterTurns_two_preservesDimensions() throws {
        let image = try #require(makeTestImage(width: 100, height: 200))
        let result = try #require(CropImageProcessor.applyQuarterTurns(to: image, turns: 2))
        #expect(result.width == 100)
        #expect(result.height == 200)
    }

    @Test func quarterTurns_four_identity() throws {
        let image = try #require(makeTestImage(width: 100, height: 200))
        let result = try #require(CropImageProcessor.applyQuarterTurns(to: image, turns: 4))
        #expect(result.width == 100)
        #expect(result.height == 200)
    }

    // MARK: - applyHorizontalFlip

    @Test func horizontalFlip_preservesDimensions() throws {
        let image = try #require(makeTestImage(width: 100, height: 200))
        let result = try #require(CropImageProcessor.applyHorizontalFlip(to: image))
        #expect(result.width == 100)
        #expect(result.height == 200)
    }

    // MARK: - applyStraighten

    @Test func straighten_zeroAngle_preservesDimensions() throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        // straighten with 0 should not be called normally, but test edge case
        let result = CropImageProcessor.applyStraighten(to: image, angleDegrees: 0)
        // 0度の場合、zoomScale=1で元サイズ
        if let resultImage = result {
            #expect(resultImage.width == 100)
            #expect(resultImage.height == 100)
        }
    }

    @Test func straighten_nonZeroAngle_preservesDimensions() throws {
        let image = try #require(makeTestImage(width: 100, height: 100))
        let result = try #require(CropImageProcessor.applyStraighten(to: image, angleDegrees: 15))
        // 出力は元画像サイズ（中央切り出し）
        #expect(result.width == 100)
        #expect(result.height == 100)
    }

    // MARK: - applyCropRect

    @Test func cropRect_full_preservesDimensions() throws {
        let image = try #require(makeTestImage(width: 200, height: 100))
        let result = try #require(CropImageProcessor.applyCropRect(to: image, cropRect: .full))
        #expect(result.width == 200)
        #expect(result.height == 100)
    }

    @Test func cropRect_half_halvesDimensions() throws {
        let image = try #require(makeTestImage(width: 200, height: 100))
        let crop = CropRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let result = try #require(CropImageProcessor.applyCropRect(to: image, cropRect: crop))
        #expect(result.width == 100)
        #expect(result.height == 50)
    }

    @Test func cropRect_zeroSize_returnsNil() throws {
        let image = try #require(makeTestImage(width: 200, height: 100))
        let crop = CropRect(x: 0, y: 0, width: 0, height: 0)
        let result = CropImageProcessor.applyCropRect(to: image, cropRect: crop)
        #expect(result == nil)
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
}
