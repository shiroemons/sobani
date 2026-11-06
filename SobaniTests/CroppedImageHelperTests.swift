import AppKit
import Testing
@testable import Sobani

/// キャッシュは全体で共有されるため、各テストの init による全破棄が他のテストの途中に挟まらないよう直列に実行する
@Suite(.serialized) struct CroppedImageHelperTests {

    // MARK: - Helpers

    private func makeTestImage(width: Int, height: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    private func makeCropRect(
        x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
    ) -> CropRect {
        CropRect(x: x, y: y, width: width, height: height)
    }

    init() {
        CroppedImageHelper.invalidateCache()
    }

    // MARK: - Tests

    @Test func testNilCropRectReturnsOriginal() throws {
        let original = makeTestImage(width: 200, height: 100)
        let result = CroppedImageHelper.croppedImage(
            from: original, cropRect: nil, imageName: "test"
        )
        #expect(abs(result.size.width - 200) < 0.001)
        #expect(abs(result.size.height - 100) < 0.001)
    }

    @Test func testIdentityCropReturnsOriginal() throws {
        let original = makeTestImage(width: 200, height: 100)
        // x:0 y:0 width:1 height:1 with no transforms is identity — should return original directly
        let crop = makeCropRect(x: 0, y: 0, width: 1, height: 1)
        let result = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "test"
        )
        #expect(result === original)
    }

    @Test func testFullCropReturnsSameDimensions() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 1, height: 1)
        let result = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "test"
        )

        let cgImage = try #require(result.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let originalCG = try #require(
            original.cgImage(forProposedRect: nil, context: nil, hints: nil)
        )
        #expect(cgImage.width == originalCG.width)
        #expect(cgImage.height == originalCG.height)
    }

    @Test func testHalfWidthCrop() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 0.5, height: 1)
        let result = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "test"
        )

        let cgImage = try #require(result.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let originalCG = try #require(
            original.cgImage(forProposedRect: nil, context: nil, hints: nil)
        )
        #expect(cgImage.width == originalCG.width / 2)
        #expect(cgImage.height == originalCG.height)
    }

    @Test func testQuarterCropFromCenter() throws {
        let original = makeTestImage(width: 200, height: 200)
        let crop = makeCropRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let result = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "test"
        )

        let cgImage = try #require(result.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let originalCG = try #require(
            original.cgImage(forProposedRect: nil, context: nil, hints: nil)
        )
        #expect(cgImage.width == originalCG.width / 2)
        #expect(cgImage.height == originalCG.height / 2)
    }

    @Test func testCachedResultReturnedOnSecondCall() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 0.5, height: 1)

        let first = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "cached-test"
        )
        let second = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "cached-test"
        )

        // Both calls should return the same NSImage instance (from cache)
        #expect(first === second)
    }

    @Test func testDifferentImageNamesProduceSeparateCacheEntries() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 0.5, height: 1)

        let resultA = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "imageA"
        )
        let resultB = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "imageB"
        )

        // Separate cache entries — different instances
        #expect(!(resultA === resultB))
    }

    @Test func testCacheInvalidationClearsCache() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 0.5, height: 1)

        let before = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "inv-test"
        )
        CroppedImageHelper.invalidateCache()
        let after = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "inv-test"
        )

        // After invalidation, cache is empty — a new image is produced
        #expect(!(before === after))
    }

    /// 画像名を指定した無効化は、その画像名のエントリだけを作り直す
    @Test func testInvalidateCacheForImageNameOnlyAffectsThatName() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 0.5, height: 1)

        let targetBefore = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "per-name-target"
        )
        let otherBefore = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "per-name-other"
        )
        CroppedImageHelper.invalidateCache(forImageNamed: "per-name-target")
        let targetAfter = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "per-name-target"
        )
        let otherAfter = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "per-name-other"
        )

        #expect(!(targetBefore === targetAfter))
        #expect(otherBefore === otherAfter)
        // 無効化後に作り直したエントリは再びキャッシュから返る
        let targetCached = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "per-name-target"
        )
        #expect(targetAfter === targetCached)
    }

    /// 変換・形状が異なるクロップは別のエントリになる
    @Test func testDifferentTransformsProduceSeparateCacheEntries() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 0.5, height: 1)

        let plain = CroppedImageHelper.croppedImage(from: original, cropRect: crop, imageName: "transform-test")
        let flipped = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop.with(isFlippedInCrop: true), imageName: "transform-test"
        )
        let circle = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop.with(shape: .circle), imageName: "transform-test"
        )

        #expect(!(plain === flipped))
        #expect(!(plain === circle))
        #expect(!(flipped === circle))
    }

    /// 全体に近いが 1% 未満だけ小さいクロップも、そのまま元画像を返さずに切り出す
    @Test func testNearFullCropIsNotTreatedAsIdentity() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 0.995, height: 1)
        let result = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "near-full"
        )
        #expect(!(result === original))
    }

    /// 大きな画像のサムネイルは縮小して生成する（長辺が上限を超えない）
    @Test func testLargeImageThumbnailIsDownscaled() throws {
        let original = makeTestImage(width: 4000, height: 2000)
        let crop = makeCropRect(x: 0, y: 0, width: 1, height: 1)
            .with(isFlippedInCrop: true)
        let result = CroppedImageHelper.croppedImage(
            from: original, cropRect: crop, imageName: "large"
        )
        let cgImage = try #require(result.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(max(cgImage.width, cgImage.height) <= 1024)
        #expect(abs(CGFloat(cgImage.width) / CGFloat(cgImage.height) - 2) < AppConstants.floatingPointTolerance)
    }
}
