import Foundation
import Testing
import os.log
@testable import Sobani

/// JSONPersistenceのsave/loadラウンドトリップ、エラーハンドリング、カスタム設定を検証するテスト
@Suite struct JSONPersistenceTests {
    private struct TestData: Codable, Equatable {
        let name: String
        let value: Int
    }

    private let logger = Logger(category: "JSONPersistenceTests")

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Round trip

    /// saveとloadのラウンドトリップが正しく動作することを検証
    @Test func testSaveAndLoadRoundTrip() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = tempDir.appendingPathComponent("test.json")
        let original = TestData(name: "hello", value: 42)

        JSONPersistence.save(original, to: url, logger: logger)
        let loaded = JSONPersistence.load(TestData.self, from: url, logger: logger)

        #expect(loaded == original)
    }

    // MARK: - Non-existent file

    /// 存在しないファイルからのloadがnilを返すことを検証
    @Test func testLoadNonExistentFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("does_not_exist.json")

        let result = JSONPersistence.load(
            TestData.self,
            from: url,
            logger: logger,
            notFoundMessage: "Expected missing file"
        )

        #expect(result == nil)
    }

    // MARK: - Corrupted data

    /// 不正なJSONデータからのloadがnilを返すことを検証
    @Test func testLoadCorruptedData() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = tempDir.appendingPathComponent("corrupted.json")
        let invalidJSON = Data("not valid json {{{".utf8)
        try invalidJSON.write(to: url, options: .atomic)

        let result = JSONPersistence.load(
            TestData.self,
            from: url,
            logger: logger,
            errorMessage: "Expected decode failure"
        )

        #expect(result == nil)
    }

    // MARK: - Type mismatch

    /// 必須フィールドが欠けた空JSONオブジェクトからのloadがnilを返すことを検証
    @Test func loadEmptyJsonObjectReturnsNil() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("empty.json")
        try Data("{}".utf8).write(to: url, options: .atomic)
        let result = JSONPersistence.load(TestData.self, from: url, logger: logger)
        #expect(result == nil)
    }

    /// オブジェクト型に対してJSON配列が渡された場合、loadがnilを返すことを検証
    @Test func loadArrayInsteadOfObjectReturnsNil() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("array.json")
        try Data("[1,2,3]".utf8).write(to: url, options: .atomic)
        let result = JSONPersistence.load(TestData.self, from: url, logger: logger)
        #expect(result == nil)
    }

    // MARK: - Large array

    /// 大量要素を含む配列のsave/loadラウンドトリップが正しく動作することを検証
    @Test func largeArrayRoundTrip() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("large.json")
        let items = (0..<1000).map { TestData(name: "item\($0)", value: $0) }
        JSONPersistence.save(items, to: url, logger: logger)
        let loaded = JSONPersistence.load([TestData].self, from: url, logger: logger)
        #expect(loaded == items)
    }

    // MARK: - Non-existent directory

    /// 存在しないディレクトリへのsaveがクラッシュせずエラーをログに記録することを検証
    @Test func saveToNonExistentDirectoryDoesNotCrash() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nested")
            .appendingPathComponent("test.json")
        let data = TestData(name: "test", value: 1)
        // クラッシュしないことを確認（エラーはログに記録される）
        JSONPersistence.save(data, to: url, logger: logger)
    }

    // MARK: - Overwrite

    /// 同一ファイルへの上書き保存が正しく動作することを検証
    @Test func overwriteExistingFile() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("overwrite.json")
        let first = TestData(name: "first", value: 1)
        let second = TestData(name: "second", value: 2)
        JSONPersistence.save(first, to: url, logger: logger)
        JSONPersistence.save(second, to: url, logger: logger)
        let loaded = JSONPersistence.load(TestData.self, from: url, logger: logger)
        #expect(loaded == second)
    }

    // MARK: - Empty array

    /// 空配列のsave/loadラウンドトリップが正しく動作することを検証
    @Test func emptyArrayRoundTrip() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("empty_array.json")
        let items: [TestData] = []
        JSONPersistence.save(items, to: url, logger: logger)
        let loaded = JSONPersistence.load([TestData].self, from: url, logger: logger)
        #expect(loaded == items)
    }

    // MARK: - Custom configuration

    /// カスタムのdateEncodingStrategy/dateDecodingStrategyが正しく動作することを検証
    @Test func testSaveAndLoadWithCustomConfiguration() throws {
        struct DatedData: Codable, Equatable {
            let name: String
            let date: Date
        }

        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = tempDir.appendingPathComponent("dated.json")
        let now = Date(timeIntervalSinceReferenceDate: 0) // Fixed date for determinism
        let original = DatedData(name: "test", date: now)

        JSONPersistence.save(original, to: url, logger: logger) {
            $0.dateEncodingStrategy = .iso8601
        }
        let loaded = JSONPersistence.load(DatedData.self, from: url, logger: logger) {
            $0.dateDecodingStrategy = .iso8601
        }

        #expect(loaded == original)
    }
}
