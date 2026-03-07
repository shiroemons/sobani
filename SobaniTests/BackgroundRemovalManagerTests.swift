import AppKit
import Foundation
import Testing

@preconcurrency @testable import Sobani

/// 背景除去エラーの説明文と、空画像・有効画像に対するremoveBackgroundの動作を検証するテスト（macOS 14.0以上）
@Suite(.enabled(if: ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 14))
struct BackgroundRemovalManagerTests {

    // MARK: - Helpers

    private func createTestImage() throws -> NSImage {
        let size = NSSize(width: 100, height: 100)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 100,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            Issue.record("Failed to create NSBitmapImageRep")
            return NSImage()
        }
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
    @Test func cgImageConversionFailedErrorDescription() throws {
        guard #available(macOS 14.0, *) else { return }
        let error = BackgroundRemovalError.cgImageConversionFailed
        let description = try #require(error.errorDescription)
        #expect(!description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        #expect(!description.hasPrefix("background_removal.error."),
                "errorDescription should be a localized string, not the key itself")
    }

    /// 前景未検出エラーの説明文が空でなくローカライズ済みであることを検証
    @Test func noForegroundDetectedErrorDescription() throws {
        guard #available(macOS 14.0, *) else { return }
        let error = BackgroundRemovalError.noForegroundDetected
        let description = try #require(error.errorDescription)
        #expect(!description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        #expect(!description.hasPrefix("background_removal.error."),
                "errorDescription should be a localized string, not the key itself")
    }

    /// マスク生成失敗エラーの説明文が空でなくローカライズ済みであることを検証
    @Test func maskGenerationFailedErrorDescription() throws {
        guard #available(macOS 14.0, *) else { return }
        let error = BackgroundRemovalError.maskGenerationFailed
        let description = try #require(error.errorDescription)
        #expect(!description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        #expect(!description.hasPrefix("background_removal.error."),
                "errorDescription should be a localized string, not the key itself")
    }

    /// フィルタ出力失敗エラーの説明文が空でなくローカライズ済みであることを検証
    @Test func filterOutputFailedErrorDescription() throws {
        guard #available(macOS 14.0, *) else { return }
        let error = BackgroundRemovalError.filterOutputFailed
        let description = try #require(error.errorDescription)
        #expect(!description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        #expect(!description.hasPrefix("background_removal.error."),
                "errorDescription should be a localized string, not the key itself")
    }

    /// 最終画像変換失敗エラーの説明文が空でなくローカライズ済みであることを検証
    @Test func finalImageConversionFailedErrorDescription() throws {
        guard #available(macOS 14.0, *) else { return }
        let error = BackgroundRemovalError.finalImageConversionFailed
        let description = try #require(error.errorDescription)
        #expect(!description.isEmpty)
        // ローカライズキーがそのまま返されていないことを確認
        #expect(!description.hasPrefix("background_removal.error."),
                "errorDescription should be a localized string, not the key itself")
    }

    // MARK: - removeBackground Tests

    /// 空画像に対してcgImageConversionFailedエラーが返されることを検証
    @Test func removeBackgroundWithEmptyImage() async {
        guard #available(macOS 14.0, *) else { return }
        let emptyImage = NSImage()

        let result: Result<NSImage, BackgroundRemovalError> = await withCheckedContinuation { continuation in
            BackgroundRemovalManager.shared.removeBackground(from: emptyImage) { result in
                continuation.resume(returning: result)
            }
        }
        switch result {
        case .failure(let error):
            #expect(error == .cgImageConversionFailed)
        case .success:
            Issue.record("Expected failure for empty image")
        }
    }

    /// 有効な画像に対してremoveBackgroundがクラッシュせず完了することを検証
    @Test func removeBackgroundWithValidImageDoesNotCrash() async throws {
        guard #available(macOS 14.0, *) else { return }
        let image = try createTestImage()

        let _: Result<NSImage, BackgroundRemovalError> = await withCheckedContinuation { continuation in
            BackgroundRemovalManager.shared.removeBackground(from: image) { result in
                continuation.resume(returning: result)
            }
        }
    }
}
