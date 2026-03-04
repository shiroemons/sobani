import XCTest
@testable import Sobani

@available(macOS 14.0, *)
final class BackgroundRemovalManagerTests: XCTestCase {

    // MARK: - Helpers

    private func createTestImage() -> NSImage {
        let size = NSSize(width: 100, height: 100)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 100,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: - Error Description Tests

    func testCgImageConversionFailedErrorDescription() {
        let error = BackgroundRemovalError.cgImageConversionFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testNoForegroundDetectedErrorDescription() {
        let error = BackgroundRemovalError.noForegroundDetected
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testMaskGenerationFailedErrorDescription() {
        let error = BackgroundRemovalError.maskGenerationFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testFilterOutputFailedErrorDescription() {
        let error = BackgroundRemovalError.filterOutputFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testFinalImageConversionFailedErrorDescription() {
        let error = BackgroundRemovalError.finalImageConversionFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    // MARK: - removeBackground Tests

    func testRemoveBackgroundWithEmptyImage() {
        let expectation = expectation(description: "Completion called")
        let emptyImage = NSImage()

        BackgroundRemovalManager.shared.removeBackground(from: emptyImage) { result in
            if case .failure = result {
                // Expected
            } else {
                XCTFail("Expected failure for empty image")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func testRemoveBackgroundWithValidImageDoesNotCrash() {
        let expectation = expectation(description: "Completion called")
        let image = createTestImage()

        BackgroundRemovalManager.shared.removeBackground(from: image) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10)
    }
}
