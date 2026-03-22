import AppKit
import Testing
@testable import Sobani

@Suite struct CroppedImageHelperTests {

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
}
