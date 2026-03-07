import Foundation
import Testing
@preconcurrency @testable import Sobani

/// サポート対象の画像フォーマット判定を検証するテスト
@Suite struct DragDropUtilsTests {
    // MARK: - isSupportedImageURL Parameterized Tests

    /// サポート対象の各拡張子がtrueを返すことを検証
    @Test(arguments: ["png", "jpg", "jpeg", "gif", "tiff", "heic"])
    func isSupportedImageURL_SupportedFormats(ext: String) {
        #expect(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.\(ext)")))
    }

    /// 非サポート形式がfalseを返すことを検証
    @Test(arguments: ["txt", "pdf", "svg", "bmp"])
    func isSupportedImageURL_UnsupportedFormats(ext: String) {
        #expect(!DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.\(ext)")))
    }

    /// 拡張子の大文字小文字を区別しないことを検証
    @Test(arguments: ["PNG", "Jpeg", "HEIC"])
    func isSupportedImageURL_CaseInsensitive(ext: String) {
        #expect(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.\(ext)")))
    }

    // MARK: - filterSupportedImages Tests

    /// 全サポート形式のURLが全件返されることを検証
    @Test func filterSupportedImages_AllSupported() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.jpeg"),
            URL(fileURLWithPath: "/tmp/c.gif"),
            URL(fileURLWithPath: "/tmp/d.tiff"),
            URL(fileURLWithPath: "/tmp/e.heic"),
            URL(fileURLWithPath: "/tmp/f.jpg")
        ]
        let result = DragDropUtils.filterSupportedImages(urls)
        #expect(result.count == 6)
    }

    /// サポート・非サポート混在時にサポートのみ返されることを検証
    @Test func filterSupportedImages_MixedFormats() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.gif"),
            URL(fileURLWithPath: "/tmp/d.pdf")
        ]
        let result = DragDropUtils.filterSupportedImages(urls)
        #expect(result.count == 2)
        #expect(result[0].lastPathComponent == "a.png")
        #expect(result[1].lastPathComponent == "c.gif")
    }

    /// 空配列入力で空配列が返されることを検証
    @Test func filterSupportedImages_EmptyArray() {
        let result = DragDropUtils.filterSupportedImages([])
        #expect(result.isEmpty)
    }

    /// 全非サポート形式で空配列が返されることを検証
    @Test func filterSupportedImages_AllUnsupported() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.pdf"),
            URL(fileURLWithPath: "/tmp/c.svg")
        ]
        let result = DragDropUtils.filterSupportedImages(urls)
        #expect(result.isEmpty)
    }

    // MARK: - isSupportedImageURL Edge Cases

    /// 拡張子なしURLがfalseを返すことを検証
    @Test func isSupportedImageURL_NoExtension() {
        #expect(!DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/imagefile")))
    }

    /// 二重拡張子(test.png.txt)がfalseを返すことを検証
    @Test func isSupportedImageURL_DoubleExtension() {
        #expect(!DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.png.txt")))
    }

    /// 隠しファイル(.hidden.png)がtrueを返すことを検証
    @Test func isSupportedImageURL_HiddenFile() {
        #expect(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/.hidden.png")))
    }
}
