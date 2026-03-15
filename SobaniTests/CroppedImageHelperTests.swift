import XCTest
@testable import Sobani

final class CroppedImageHelperTests: XCTestCase {

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

    // MARK: - Tests

    func testNilCropRectReturnsOriginal() throws {
        let original = makeTestImage(width: 200, height: 100)
        let result = CroppedImageHelper.croppedImage(from: original, cropRect: nil)
        XCTAssertEqual(result.size.width, 200, accuracy: 0.001)
        XCTAssertEqual(result.size.height, 100, accuracy: 0.001)
    }

    func testFullCropReturnsSameDimensions() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 1, height: 1)
        let result = CroppedImageHelper.croppedImage(from: original, cropRect: crop)

        let cgImage = try XCTUnwrap(result.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let originalCG = try XCTUnwrap(original.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(cgImage.width, originalCG.width)
        XCTAssertEqual(cgImage.height, originalCG.height)
    }

    func testHalfWidthCrop() throws {
        let original = makeTestImage(width: 200, height: 100)
        let crop = makeCropRect(x: 0, y: 0, width: 0.5, height: 1)
        let result = CroppedImageHelper.croppedImage(from: original, cropRect: crop)

        let cgImage = try XCTUnwrap(result.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let originalCG = try XCTUnwrap(original.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(cgImage.width, originalCG.width / 2)
        XCTAssertEqual(cgImage.height, originalCG.height)
    }

    func testQuarterCropFromCenter() throws {
        let original = makeTestImage(width: 200, height: 200)
        let crop = makeCropRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let result = CroppedImageHelper.croppedImage(from: original, cropRect: crop)

        let cgImage = try XCTUnwrap(result.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let originalCG = try XCTUnwrap(original.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(cgImage.width, originalCG.width / 2)
        XCTAssertEqual(cgImage.height, originalCG.height / 2)
    }
}
