import XCTest
@testable import Sobani

final class PathSanitizerTests: XCTestCase {
    // MARK: - safeURL tests

    func testSafeURLWithValidName() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = PathSanitizer.safeURL(name: "image.png", in: dir)
        XCTAssertEqual(result?.path, "/tmp/test/image.png")
    }

    func testSafeURLRejectsPathTraversal() throws {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = try XCTUnwrap(PathSanitizer.safeURL(name: "../etc/passwd", in: dir))
        // Should extract only "passwd" as lastPathComponent and validate prefix
        XCTAssertTrue(result.path.hasPrefix(dir.path + "/"))
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

    func testSafeNameReplacesInvalidCharacters() throws {
        let result = try XCTUnwrap(PathSanitizer.safeName(from: "my/layout:test"))
        XCTAssertFalse(result.contains("/"))
        XCTAssertFalse(result.contains(":"))
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

    func testSafeNameWithSpecialCharacters() throws {
        let result = try XCTUnwrap(PathSanitizer.safeName(from: "test*file?name"))
        XCTAssertFalse(result.contains("*"))
        XCTAssertFalse(result.contains("?"))
    }
}
