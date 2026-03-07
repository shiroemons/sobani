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
}
