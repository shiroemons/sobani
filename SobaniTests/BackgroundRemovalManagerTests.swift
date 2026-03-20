import AppKit
import Foundation
import Testing

@testable import Sobani

/// 背景除去エラーの説明文と、空画像・有効画像に対するremoveBackgroundの動作を検証するテスト（macOS 14.0以上）
@Suite(.enabled(if: ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 14))
@MainActor struct BackgroundRemovalManagerTests {

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

    /// 全エラーケースの説明文が空でなくローカライズ済みであることを検証
    @Test func errorDescription_AllCasesNonEmptyAndLocalized() throws {
        guard #available(macOS 14.0, *) else { return }
        let allErrors: [BackgroundRemovalError] = [
            .cgImageConversionFailed,
            .noForegroundDetected,
            .maskGenerationFailed,
            .filterOutputFailed,
            .finalImageConversionFailed,
        ]
        for error in allErrors {
            let description = try #require(error.errorDescription)
            #expect(!description.isEmpty)
            #expect(!description.hasPrefix("background_removal.error."),
                    "errorDescription should be a localized string, not the key itself: \(error)")
        }
    }

    // MARK: - removeBackground Tests

    /// 空画像に対してcgImageConversionFailedエラーが返されることを検証
    @Test func removeBackgroundWithEmptyImage() async {
        guard #available(macOS 14.0, *) else { return }
        let emptyImage = NSImage()

        let result: Result<NSImage, BackgroundRemovalError> =
            await withCheckedContinuation { continuation in
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

        let _: Result<NSImage, BackgroundRemovalError> =
            await withCheckedContinuation { continuation in
                BackgroundRemovalManager.shared.removeBackground(from: image) { result in
                    continuation.resume(returning: result)
                }
            }
    }

    /// removeBackgroundの完了コールバックがメインスレッドで呼ばれることを検証
    @Test func removeBackground_CompletionOnMainThread() async {
        guard #available(macOS 14.0, *) else { return }
        let emptyImage = NSImage()

        let isMainThread: Bool = await withCheckedContinuation { continuation in
            BackgroundRemovalManager.shared.removeBackground(from: emptyImage) { _ in
                continuation.resume(returning: Thread.isMainThread)
            }
        }
        #expect(isMainThread, "Completion should be called on main thread")
    }

    /// 1x1ピクセルの最小画像に対してremoveBackgroundがクラッシュせず完了することを検証
    @Test func removeBackgroundWith1x1Image() async {
        guard #available(macOS 14.0, *) else { return }
        let tiny = NSImage(size: NSSize(width: 1, height: 1))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        tiny.addRepresentation(rep)

        let result: Result<NSImage, BackgroundRemovalError> =
            await withCheckedContinuation { continuation in
                BackgroundRemovalManager.shared.removeBackground(from: tiny) { result in
                    continuation.resume(returning: result)
                }
            }
        // 1x1画像は成功または失敗どちらでもクラッシュしないことが重要
        switch result {
        case .success, .failure:
            break // No crash = pass
        }
    }

    /// 全エラーケースの説明文が一意であることを検証
    @Test func errorDescriptions_AreUnique() throws {
        guard #available(macOS 14.0, *) else { return }
        let descriptions = BackgroundRemovalError.allCases.compactMap { $0.errorDescription }
        let uniqueDescriptions = Set(descriptions)
        #expect(descriptions.count == uniqueDescriptions.count,
                "Each error case should have a unique description")
    }

    /// CaseIterable に含まれるエラーケース数が期待通りであることを検証
    @Test func allCases_ContainsExpectedCount() {
        guard #available(macOS 14.0, *) else { return }
        #expect(BackgroundRemovalError.allCases.count == 5)
    }

    /// removeBackgroundを複数回連続で呼び出してもクラッシュせず安定して完了することを検証
    @Test func removeBackground_MultipleCallsStable() async {
        guard #available(macOS 14.0, *) else { return }
        let emptyImage = NSImage()
        for _ in 0..<3 {
            let _: Result<NSImage, BackgroundRemovalError> =
                await withCheckedContinuation { continuation in
                    BackgroundRemovalManager.shared.removeBackground(from: emptyImage) { result in
                        continuation.resume(returning: result)
                    }
                }
        }
    }
}
