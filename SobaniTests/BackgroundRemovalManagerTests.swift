import XCTest
@testable import Sobani

@available(macOS 14.0, *)
final class BackgroundRemovalManagerTests: XCTestCase {

    // MARK: - Helpers

    private func createTestImage() throws -> NSImage {
        let size = NSSize(width: 100, height: 100)
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 100,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ))
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

    func testCgImageConversionFailedErrorDescription() throws {
        let error = BackgroundRemovalError.cgImageConversionFailed
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
    }

    func testNoForegroundDetectedErrorDescription() throws {
        let error = BackgroundRemovalError.noForegroundDetected
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
    }

    func testMaskGenerationFailedErrorDescription() throws {
        let error = BackgroundRemovalError.maskGenerationFailed
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
    }

    func testFilterOutputFailedErrorDescription() throws {
        let error = BackgroundRemovalError.filterOutputFailed
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
    }

    func testFinalImageConversionFailedErrorDescription() throws {
        let error = BackgroundRemovalError.finalImageConversionFailed
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
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

    func testRemoveBackgroundWithValidImageDoesNotCrash() throws {
        let expectation = expectation(description: "Completion called")
        let image = try createTestImage()

        BackgroundRemovalManager.shared.removeBackground(from: image) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10)
    }
}
