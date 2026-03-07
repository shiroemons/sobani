import XCTest
@testable import Sobani

/// safeURLとsafeNameによるパストラバーサル防止、無効文字の置換、エッジケースの処理を検証するテスト
final class PathSanitizerTests: XCTestCase {
    // MARK: - safeURL tests

    /// 正常なファイル名で正しいURLが生成されることを検証
    func testSafeURLWithValidName() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = PathSanitizer.safeURL(name: "image.png", in: dir)
        XCTAssertEqual(result?.path, "/tmp/test/image.png")
    }

    /// パストラバーサルがディレクトリ内に制限されることを検証
    func testSafeURLRejectsPathTraversal() throws {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = try XCTUnwrap(PathSanitizer.safeURL(name: "../etc/passwd", in: dir))
        // Should extract only "passwd" as lastPathComponent and validate prefix
        XCTAssertTrue(result.path.hasPrefix(dir.path + "/"))
    }

    /// 空文字列でnilが返されることを検証
    func testSafeURLRejectsEmptyName() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        XCTAssertNil(PathSanitizer.safeURL(name: "", in: dir))
    }

    /// ドット1つでnilが返されることを検証
    func testSafeURLRejectsDot() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        XCTAssertNil(PathSanitizer.safeURL(name: ".", in: dir))
    }

    /// サブディレクトリ指定でlastPathComponentのみが使用されることを検証
    func testSafeURLWithSubdirectoryAttempt() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = PathSanitizer.safeURL(name: "subdir/file.png", in: dir)
        // lastPathComponent extracts "file.png"
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.lastPathComponent, "file.png")
    }

    // MARK: - safeName tests

    /// 正常な名前がそのまま返されることを検証
    func testSafeNameWithValidName() {
        XCTAssertEqual(PathSanitizer.safeName(from: "my layout"), "my layout")
    }

    /// 無効文字(/、:)がアンダースコアに置換されることを検証
    func testSafeNameReplacesInvalidCharacters() throws {
        let result = try XCTUnwrap(PathSanitizer.safeName(from: "my/layout:test"))
        XCTAssertFalse(result.contains("/"))
        XCTAssertFalse(result.contains(":"))
        XCTAssertEqual(result, "my_layout_test")
    }

    /// 空文字列でnilが返されることを検証
    func testSafeNameRejectsEmpty() {
        XCTAssertNil(PathSanitizer.safeName(from: ""))
    }

    /// ドット1つでnilが返されることを検証
    func testSafeNameRejectsDot() {
        XCTAssertNil(PathSanitizer.safeName(from: "."))
    }

    /// ドット2つでnilが返されることを検証
    func testSafeNameRejectsDoubleDot() {
        XCTAssertNil(PathSanitizer.safeName(from: ".."))
    }

    /// パストラバーサル文字列が無害化されパス区切り文字を含まないことを検証
    func testSafeNameWithPathTraversalAttempt() throws {
        let result = try XCTUnwrap(PathSanitizer.safeName(from: "../../../etc"))
        // パス区切り文字が除去されていることを確認
        XCTAssertFalse(result.contains("/"))
        XCTAssertFalse(result.contains("\\"))
    }

    /// 特殊文字(*, ?)がアンダースコアに置換されることを検証
    func testSafeNameWithSpecialCharacters() throws {
        let result = try XCTUnwrap(PathSanitizer.safeName(from: "test*file?name"))
        XCTAssertFalse(result.contains("*"))
        XCTAssertFalse(result.contains("?"))
        XCTAssertEqual(result, "test_file_name")
    }
}
