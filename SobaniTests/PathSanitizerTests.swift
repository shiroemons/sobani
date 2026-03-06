import XCTest
@testable import Sobani

final class PathSanitizerTests: XCTestCase {
    // MARK: - safeURL tests

    func testSafeURLWithValidName() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = PathSanitizer.safeURL(name: "image.png", in: dir)
        XCTAssertEqual(result?.path, "/tmp/test/image.png")
    }

    func testSafeURLRejectsPathTraversal() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = PathSanitizer.safeURL(name: "../etc/passwd", in: dir)
        // Should extract only "passwd" as lastPathComponent and validate prefix
        XCTAssertNotNil(result)
        // swiftlint:disable:next force_unwrapping
        XCTAssertTrue(result!.path.hasPrefix(dir.path + "/"))
    }

    func testSafeURLRejectsEmptyName() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        XCTAssertNil(PathSanitizer.safeURL(name: "", in: dir))
    }

    func testSafeURLRejectsDot() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        XCTAssertNil(PathSanitizer.safeURL(name: ".", in: dir))
    }

    func testSafeURLWithSubdirectoryAttempt() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = PathSanitizer.safeURL(name: "subdir/file.png", in: dir)
        // lastPathComponent extracts "file.png"
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.lastPathComponent, "file.png")
    }

    // MARK: - safeName tests

    func testSafeNameWithValidName() {
        XCTAssertEqual(PathSanitizer.safeName(from: "my layout"), "my layout")
    }

    func testSafeNameReplacesInvalidCharacters() {
        let result = PathSanitizer.safeName(from: "my/layout:test")
        XCTAssertNotNil(result)
        // swiftlint:disable:next force_unwrapping
        XCTAssertFalse(result!.contains("/"))
        // swiftlint:disable:next force_unwrapping
        XCTAssertFalse(result!.contains(":"))
    }

    func testSafeNameRejectsEmpty() {
        XCTAssertNil(PathSanitizer.safeName(from: ""))
    }

    func testSafeNameRejectsDot() {
        XCTAssertNil(PathSanitizer.safeName(from: "."))
    }

    func testSafeNameRejectsDoubleDot() {
        XCTAssertNil(PathSanitizer.safeName(from: ".."))
    }

    func testSafeNameWithPathTraversalAttempt() {
        let result = PathSanitizer.safeName(from: "../../../etc")
        // After replacing / and extracting lastPathComponent
        XCTAssertNotNil(result)
    }

    func testSafeNameWithSpecialCharacters() {
        let result = PathSanitizer.safeName(from: "test*file?name")
        XCTAssertNotNil(result)
        // swiftlint:disable:next force_unwrapping
        XCTAssertFalse(result!.contains("*"))
        // swiftlint:disable:next force_unwrapping
        XCTAssertFalse(result!.contains("?"))
    }
}
