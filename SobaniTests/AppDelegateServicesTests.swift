import Foundation
import Testing
@testable import Sobani

@Suite("AppDelegate+Services テスト")
struct AppDelegateServicesTests {
    @Test("nil の場合はエラーを返す")
    func extractImageURLs_nil() {
        let result = AppDelegate.extractImageURLsFromService(nil)
        #expect(result.imageURLs == nil)
        #expect(result.errorMessage == L("service.error.no_file_urls"))
    }

    @Test("空配列の場合はエラーを返す")
    func extractImageURLs_empty() {
        let result = AppDelegate.extractImageURLsFromService([])
        #expect(result.imageURLs == nil)
        #expect(result.errorMessage == L("service.error.no_supported_images"))
    }

    @Test("非画像ファイルのみの場合はエラーを返す")
    func extractImageURLs_noSupportedImages() {
        let urls = [
            URL(fileURLWithPath: "/tmp/document.pdf"),
            URL(fileURLWithPath: "/tmp/readme.txt")
        ]
        let result = AppDelegate.extractImageURLsFromService(urls)
        #expect(result.imageURLs == nil)
        #expect(result.errorMessage == L("service.error.no_supported_images"))
    }

    @Test("PNG ファイルを正しく抽出する")
    func extractImageURLs_png() {
        let urls = [URL(fileURLWithPath: "/tmp/image.png")]
        let result = AppDelegate.extractImageURLsFromService(urls)
        #expect(result.errorMessage == nil)
        #expect(result.imageURLs?.count == 1)
        #expect(result.imageURLs?[0].lastPathComponent == "image.png")
    }

    @Test("複数の画像フォーマットを正しく抽出する")
    func extractImageURLs_multipleFormats() {
        let urls = [
            URL(fileURLWithPath: "/tmp/photo.jpg"),
            URL(fileURLWithPath: "/tmp/icon.png"),
            URL(fileURLWithPath: "/tmp/anim.gif"),
            URL(fileURLWithPath: "/tmp/doc.pdf")
        ]
        let result = AppDelegate.extractImageURLsFromService(urls)
        #expect(result.errorMessage == nil)
        #expect(result.imageURLs?.count == 3)
    }

    @Test("HEIC フォーマットも対応している")
    func extractImageURLs_heic() {
        let urls = [URL(fileURLWithPath: "/tmp/photo.heic")]
        let result = AppDelegate.extractImageURLsFromService(urls)
        #expect(result.errorMessage == nil)
        #expect(result.imageURLs?.count == 1)
    }

    @Test("TIFF フォーマットも対応している")
    func extractImageURLs_tiff() {
        let urls = [URL(fileURLWithPath: "/tmp/photo.tiff")]
        let result = AppDelegate.extractImageURLsFromService(urls)
        #expect(result.errorMessage == nil)
        #expect(result.imageURLs?.count == 1)
    }

    @Test("上限を超えた画像は除外され、除外数を返す")
    func extractImageURLs_capsCount() {
        let maxCount = AppConstants.maxServiceImageCount
        let urls = (0..<(maxCount + 5)).map { URL(fileURLWithPath: "/tmp/image\($0).png") }
        let result = AppDelegate.extractImageURLsFromService(urls)
        #expect(result.errorMessage == nil)
        #expect(result.imageURLs?.count == maxCount)
        #expect(result.imageURLs?.first?.lastPathComponent == "image0.png")
        #expect(result.skippedCount == 5)
    }

    @Test("上限以内なら除外しない")
    func extractImageURLs_withinLimitSkipsNothing() {
        let urls = [URL(fileURLWithPath: "/tmp/a.png"), URL(fileURLWithPath: "/tmp/b.pdf")]
        let result = AppDelegate.extractImageURLsFromService(urls, maxCount: 1)
        #expect(result.imageURLs?.count == 1)
        #expect(result.skippedCount == 0)
    }

    @Test("エラーメッセージがローカライズされている")
    func errorMessagesAreLocalized() {
        for key in ["service.error.no_file_urls", "service.error.no_supported_images", "service.error.registration_failed"] {
            #expect(L(key) != key)
        }
    }
}
