import Foundation
import Testing
@testable import Sobani

/// safeURLとsafeNameによるパストラバーサル防止、無効文字の置換、エッジケースの処理を検証するテスト
@Suite @MainActor struct PathSanitizerTests {
    // MARK: - safeURL tests

    /// 正常なファイル名で正しいURLが生成されることを検証
    @Test func safeURLWithValidName() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = PathSanitizer.safeURL(name: "image.png", in: dir)
        #expect(result?.path == "/tmp/test/image.png")
    }

    /// パストラバーサルがディレクトリ内に制限されることを検証
    @Test func safeURLRejectsPathTraversal() throws {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = try #require(PathSanitizer.safeURL(name: "../etc/passwd", in: dir))
        // Should extract only "passwd" as lastPathComponent and validate prefix
        #expect(result.path.hasPrefix(dir.path + "/"))
    }

    /// safeURLが無効な名前でnilを返すことを検証
    @Test(arguments: ["", ".", ".."])
    func safeURLRejectsInvalidName(name: String) {
        let dir = URL(fileURLWithPath: "/tmp/test")
        #expect(PathSanitizer.safeURL(name: name, in: dir) == nil)
    }

    /// サブディレクトリ指定でlastPathComponentのみが使用されることを検証
    @Test func safeURLWithSubdirectoryAttempt() {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = PathSanitizer.safeURL(name: "subdir/file.png", in: dir)
        // lastPathComponent extracts "file.png"
        #expect(result != nil)
        #expect(result?.lastPathComponent == "file.png")
    }

    // MARK: - safeName tests

    /// 正常な名前がそのまま返されることを検証
    @Test func safeNameWithValidName() {
        #expect(PathSanitizer.safeName(from: "my layout") == "my layout")
    }

    /// 無効文字(/、:)がアンダースコアに置換されることを検証
    @Test func safeNameReplacesInvalidCharacters() throws {
        let result = try #require(PathSanitizer.safeName(from: "my/layout:test"))
        #expect(!result.contains("/"))
        #expect(!result.contains(":"))
        #expect(result == "my_layout_test")
    }

    /// safeNameが無効な名前でnilを返すことを検証
    @Test(arguments: ["", ".", ".."])
    func safeNameRejectsInvalidName(name: String) {
        #expect(PathSanitizer.safeName(from: name) == nil)
    }

    /// パストラバーサル文字列が無害化されパス区切り文字を含まないことを検証
    @Test func safeNameWithPathTraversalAttempt() throws {
        let result = try #require(PathSanitizer.safeName(from: "../../../etc"))
        // パス区切り文字が除去されていることを確認
        #expect(!result.contains("/"))
        #expect(!result.contains("\\"))
    }

    /// 特殊文字(*, ?)がアンダースコアに置換されることを検証
    @Test func safeNameWithSpecialCharacters() throws {
        let result = try #require(PathSanitizer.safeName(from: "test*file?name"))
        #expect(!result.contains("*"))
        #expect(!result.contains("?"))
        #expect(result == "test_file_name")
    }

    /// 日本語ファイル名が正しく処理されることを検証
    @Test func safeNameWithUnicodeCharacters() {
        let result = PathSanitizer.safeName(from: "テスト画像")
        #expect(result == "テスト画像")
    }

    /// 空白のみの名前が有効な文字として処理されることを検証
    @Test func safeNameWithWhitespaceOnly() {
        let result = PathSanitizer.safeName(from: "   ")
        #expect(result != nil)
    }

    /// 無効文字のみで構成された名前がアンダースコアに置換されることを検証
    @Test func safeNameWithOnlyInvalidCharacters() {
        let result = PathSanitizer.safeName(from: "///:::")
        #expect(result != nil)
        #expect(result == "______")
    }

}
