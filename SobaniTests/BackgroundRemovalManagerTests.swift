import XCTest
@testable import Sobani

/// 背景除去エラーの説明文と、空画像・有効画像に対するremoveBackgroundの動作を検証するテスト（macOS 14.0以上）
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

    /// CGImage変換失敗エラーの説明文が空でなくローカライズ済みであることを検証
    func testCgImageConversionFailedErrorDescription() throws {
        let error = BackgroundRemovalError.cgImageConversionFailed
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        XCTAssertFalse(description.hasPrefix("background_removal.error."),
                       "errorDescription should be a localized string, not the key itself")
    }

    /// 前景未検出エラーの説明文が空でなくローカライズ済みであることを検証
    func testNoForegroundDetectedErrorDescription() throws {
        let error = BackgroundRemovalError.noForegroundDetected
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        XCTAssertFalse(description.hasPrefix("background_removal.error."),
                       "errorDescription should be a localized string, not the key itself")
    }

    /// マスク生成失敗エラーの説明文が空でなくローカライズ済みであることを検証
    func testMaskGenerationFailedErrorDescription() throws {
        let error = BackgroundRemovalError.maskGenerationFailed
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        XCTAssertFalse(description.hasPrefix("background_removal.error."),
                       "errorDescription should be a localized string, not the key itself")
    }

    /// フィルタ出力失敗エラーの説明文が空でなくローカライズ済みであることを検証
    func testFilterOutputFailedErrorDescription() throws {
        let error = BackgroundRemovalError.filterOutputFailed
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        XCTAssertFalse(description.hasPrefix("background_removal.error."),
                       "errorDescription should be a localized string, not the key itself")
    }

    /// 最終画像変換失敗エラーの説明文が空でなくローカライズ済みであることを検証
    func testFinalImageConversionFailedErrorDescription() throws {
        let error = BackgroundRemovalError.finalImageConversionFailed
        let description = try XCTUnwrap(error.errorDescription)
        XCTAssertFalse(description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        XCTAssertFalse(description.hasPrefix("background_removal.error."),
                       "errorDescription should be a localized string, not the key itself")
    }

    // MARK: - removeBackground Tests

    /// 空画像に対してcgImageConversionFailedエラーが返されることを検証
    func testRemoveBackgroundWithEmptyImage() {
        let expectation = expectation(description: "Completion called")
        let emptyImage = NSImage()

        BackgroundRemovalManager.shared.removeBackground(from: emptyImage) { result in
            switch result {
            case .failure(let error):
                XCTAssertEqual(error, .cgImageConversionFailed)
            case .success:
                XCTFail("Expected failure for empty image")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    /// 有効な画像に対してremoveBackgroundがクラッシュせず完了することを検証
    func testRemoveBackgroundWithValidImageDoesNotCrash() throws {
        let expectation = expectation(description: "Completion called")
        let image = try createTestImage()

        BackgroundRemovalManager.shared.removeBackground(from: image) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10)
    }
}
