import Foundation
import Testing
@testable import Sobani

@Suite("AppDelegate+Services テスト")
struct AppDelegateServicesTests {
    @Test("nil の場合はエラーを返す")
    func extractImageURLs_nil() {
        let result = AppDelegate.extractImageURLsFromService(nil)
        #expect(result.imageURLs == nil)
        #expect(result.errorMessage == "No file URLs found")
    }

    @Test("空配列の場合はエラーを返す")
    func extractImageURLs_empty() {
        let result = AppDelegate.extractImageURLsFromService([])
        #expect(result.imageURLs == nil)
        #expect(result.errorMessage == "No supported image files")
    }

    @Test("非画像ファイルのみの場合はエラーを返す")
    func extractImageURLs_noSupportedImages() {
        let urls = [
            URL(fileURLWithPath: "/tmp/document.pdf"),
            URL(fileURLWithPath: "/tmp/readme.txt")
        ]
        let result = AppDelegate.extractImageURLsFromService(urls)
        #expect(result.imageURLs == nil)
        #expect(result.errorMessage == "No supported image files")
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
}
