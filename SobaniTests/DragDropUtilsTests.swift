import XCTest
@testable import Sobani

/// サポート対象の画像フォーマット判定を検証するテスト
final class DragDropUtilsTests: XCTestCase {
    // MARK: - isSupportedImageURL Tests

    /// PNG形式がサポート対象と判定されることを検証
    func testIsSupportedImageURL_PNG() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    /// JPEG形式がサポート対象と判定されることを検証
    func testIsSupportedImageURL_JPEG() {
        let url = URL(fileURLWithPath: "/tmp/test.jpeg")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    /// JPG形式がサポート対象と判定されることを検証
    func testIsSupportedImageURL_JPG() {
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    /// GIF形式がサポート対象と判定されることを検証
    func testIsSupportedImageURL_GIF() {
        let url = URL(fileURLWithPath: "/tmp/test.gif")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    /// TIFF形式がサポート対象と判定されることを検証
    func testIsSupportedImageURL_TIFF() {
        let url = URL(fileURLWithPath: "/tmp/test.tiff")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    /// HEIC形式がサポート対象と判定されることを検証
    func testIsSupportedImageURL_HEIC() {
        let url = URL(fileURLWithPath: "/tmp/test.heic")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    /// 非サポート形式(txt, pdf, svg, bmp)が拒否されることを検証
    func testIsSupportedImageURL_UnsupportedFormat() {
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.txt")))
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.pdf")))
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.svg")))
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.bmp")))
    }

    /// 拡張子の大文字小文字を区別しないことを検証
    func testIsSupportedImageURL_CaseInsensitive() {
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.PNG")))
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.Jpeg")))
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.HEIC")))
    }

    // MARK: - filterSupportedImages Tests

    /// 全サポート形式のURLが全件返されることを検証
    func testFilterSupportedImages_AllSupported() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.jpeg"),
            URL(fileURLWithPath: "/tmp/c.gif"),
            URL(fileURLWithPath: "/tmp/d.tiff"),
            URL(fileURLWithPath: "/tmp/e.heic"),
            URL(fileURLWithPath: "/tmp/f.jpg")
        ]
        let result = DragDropUtils.filterSupportedImages(urls)
        XCTAssertEqual(result.count, 6)
    }

    /// サポート・非サポート混在時にサポートのみ返されることを検証
    func testFilterSupportedImages_MixedFormats() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.gif"),
            URL(fileURLWithPath: "/tmp/d.pdf")
        ]
        let result = DragDropUtils.filterSupportedImages(urls)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].lastPathComponent, "a.png")
        XCTAssertEqual(result[1].lastPathComponent, "c.gif")
    }

    /// 空配列入力で空配列が返されることを検証
    func testFilterSupportedImages_EmptyArray() {
        let result = DragDropUtils.filterSupportedImages([])
        XCTAssertTrue(result.isEmpty)
    }

    /// 全非サポート形式で空配列が返されることを検証
    func testFilterSupportedImages_AllUnsupported() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.pdf"),
            URL(fileURLWithPath: "/tmp/c.svg")
        ]
        let result = DragDropUtils.filterSupportedImages(urls)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - isSupportedImageURL Edge Cases

    /// 拡張子なしURLがfalseを返すことを検証
    func testIsSupportedImageURL_NoExtension() {
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/imagefile")))
    }

    /// 二重拡張子(test.png.txt)がfalseを返すことを検証
    func testIsSupportedImageURL_DoubleExtension() {
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.png.txt")))
    }

    /// 隠しファイル(.hidden.png)がtrueを返すことを検証
    func testIsSupportedImageURL_HiddenFile() {
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/.hidden.png")))
    }
}
