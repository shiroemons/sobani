import XCTest
@testable import Sobani

final class DragDropUtilsTests: XCTestCase {
    // MARK: - isSupportedImageURL Tests

    func testIsSupportedImageURL_PNG() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    func testIsSupportedImageURL_JPEG() {
        let url = URL(fileURLWithPath: "/tmp/test.jpeg")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    func testIsSupportedImageURL_JPG() {
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    func testIsSupportedImageURL_GIF() {
        let url = URL(fileURLWithPath: "/tmp/test.gif")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    func testIsSupportedImageURL_TIFF() {
        let url = URL(fileURLWithPath: "/tmp/test.tiff")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    func testIsSupportedImageURL_HEIC() {
        let url = URL(fileURLWithPath: "/tmp/test.heic")
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(url))
    }

    func testIsSupportedImageURL_UnsupportedFormat() {
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.txt")))
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.pdf")))
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.svg")))
        XCTAssertFalse(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.bmp")))
    }

    func testIsSupportedImageURL_CaseInsensitive() {
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.PNG")))
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.Jpeg")))
        XCTAssertTrue(DragDropUtils.isSupportedImageURL(URL(fileURLWithPath: "/tmp/test.HEIC")))
    }
}
