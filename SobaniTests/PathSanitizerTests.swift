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

    // MARK: - CWD-independent traversal tests

    /// 最終要素が親・自身・ルートを指す名前やNULを含む名前をsafeURLが拒否することを検証（CWDに依存しない）
    @Test(arguments: ["a/..", "foo/../..", "./..", "/", "//", "a/.", "image\0.png", "\0"])
    func safeURLRejectsTraversalAndNUL(name: String) {
        let dir = URL(fileURLWithPath: "/tmp/test")
        #expect(PathSanitizer.safeURL(name: name, in: dir) == nil)
    }

    /// パス区切りを含む名前で最終要素だけがディレクトリ直下に使われることを検証
    @Test(arguments: [("../etc/passwd", "passwd"), ("a/b/c.png", "c.png"), ("dir/", "dir"), ("/abs/file.png", "file.png")])
    func safeURLUsesLastComponentDirectlyUnderDirectory(name: String, expected: String) throws {
        let dir = URL(fileURLWithPath: "/tmp/test")
        let result = try #require(PathSanitizer.safeURL(name: name, in: dir))
        #expect(result.path == "/tmp/test/\(expected)")
    }

    /// 実在しない /private 配下のディレクトリでも直下判定が食い違わないことを検証
    @Test func safeURLWorksForNonexistentPrivatePath() throws {
        let dir = URL(fileURLWithPath: "/private/tmp/\(UUID().uuidString)")
        let result = try #require(PathSanitizer.safeURL(name: "file.png", in: dir))
        #expect(result.deletingLastPathComponent().path == dir.path)
    }

    /// safeNameがパス区切りを置換しトラバーサル文字列を無害化することを検証
    @Test(arguments: [("a/..", "a_.."), ("foo/../..", "foo_.._.."), ("a\0b", "a_b")])
    func safeNameNeutralizesTraversalAndNUL(name: String, expected: String) {
        #expect(PathSanitizer.safeName(from: name) == expected)
    }

    /// 長すぎる名前が上限バイト数以内に切り詰められ、拡張子が保持されることを検証
    @Test func safeNameTruncatesLongNameKeepingExtension() throws {
        let name = String(repeating: "x", count: 300) + ".png"
        let result = try #require(PathSanitizer.safeName(from: name))
        #expect(result.utf8.count == PathSanitizer.maxNameByteCount)
        #expect(result.hasSuffix(".png"))
        #expect(result.hasPrefix("xxx"))
    }

    /// マルチバイト文字の名前が文字境界で切り詰められることを検証
    @Test func safeNameTruncatesAtCharacterBoundary() throws {
        let character = "あ"  // UTF-8 で 3 バイト
        let name = String(repeating: character, count: 100)
        let result = try #require(PathSanitizer.safeName(from: name))
        let expectedCount = PathSanitizer.maxNameByteCount / character.utf8.count
        #expect(result == String(repeating: character, count: expectedCount))
    }

    /// 上限以内の名前は切り詰められないことを検証（従来から保存できていた名前の互換性）
    @Test func safeNameKeepsNameWithinLimit() {
        let name = String(repeating: "y", count: PathSanitizer.maxNameByteCount)
        #expect(PathSanitizer.safeName(from: name) == name)
        let presetFileName = name + ".json"
        #expect(presetFileName.utf8.count <= Int(NAME_MAX))
    }
}
