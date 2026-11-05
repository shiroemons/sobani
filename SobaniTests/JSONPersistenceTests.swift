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

    // MARK: - Save result

    /// saveが成功時にtrue、書き込めない場合にfalseを返すことを検証
    @Test func saveReturnsWhetherWriteSucceeded() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let data = TestData(name: "test", value: 1)

        #expect(JSONPersistence.save(data, to: tempDir.appendingPathComponent("ok.json"), logger: logger))
        let missingDirURL = tempDir.appendingPathComponent("missing").appendingPathComponent("ng.json")
        #expect(!JSONPersistence.save(data, to: missingDirURL, logger: logger))
    }

    // MARK: - Corrupt file backup

    private func backupFiles(in dir: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains(".corrupt-") }
    }

    /// backupOnDecodeFailure指定時、デコード失敗したファイルが同じ内容で退避されることを検証
    @Test func loadBacksUpUndecodableFileWhenRequested() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("states.json")
        let invalid = Data("not valid json {{{".utf8)
        try invalid.write(to: url)

        let result = JSONPersistence.load(TestData.self, from: url, logger: logger, backupOnDecodeFailure: true)

        #expect(result == nil)
        let backups = try backupFiles(in: tempDir)
        #expect(backups.count == 1)
        let backupName = try #require(backups.first)
        #expect(backupName.hasPrefix("states.corrupt-"))
        #expect(backupName.hasSuffix(".json"))
        #expect(try Data(contentsOf: tempDir.appendingPathComponent(backupName)) == invalid)
        // 元ファイルはそのまま残る
        #expect(try Data(contentsOf: url) == invalid)
    }

    /// backupOnDecodeFailure未指定時はバックアップを作らないことを検証
    @Test func loadDoesNotBackUpByDefault() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("states.json")
        try Data("{".utf8).write(to: url)

        #expect(JSONPersistence.load(TestData.self, from: url, logger: logger) == nil)
        #expect(try backupFiles(in: tempDir).isEmpty)
    }

    /// ファイルが存在しない場合はbackupOnDecodeFailure指定時もバックアップしないことを検証
    @Test func loadMissingFileDoesNotBackUp() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("missing.json")

        #expect(JSONPersistence.load(TestData.self, from: url, logger: logger, backupOnDecodeFailure: true) == nil)
        #expect(try backupFiles(in: tempDir).isEmpty)
    }

    /// バックアップ先のファイル名が `<basename>.corrupt-<yyyyMMdd-HHmmss>.<ext>` 形式であることを検証
    @Test func corruptBackupURLFormat() throws {
        let url = URL(fileURLWithPath: "/tmp/dir/window_states.json")
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 2
        components.hour = 3
        components.minute = 4
        components.second = 5
        let date = try #require(Calendar(identifier: .gregorian).date(from: components))

        let backup = JSONPersistence.corruptBackupURL(for: url, date: date)

        #expect(backup.path == "/tmp/dir/window_states.corrupt-20260102-030405.json")
    }

    // MARK: - Lossy array

    /// LossyDecodableArrayが壊れた要素だけを読み飛ばし件数を返すことを検証
    @Test func lossyArraySkipsInvalidElements() throws {
        let json = """
        [{"name":"a","value":1},{"name":"b"},42,{"name":"c","value":3}]
        """
        let decoded = try JSONDecoder().decode(LossyDecodableArray<TestData>.self, from: Data(json.utf8))
        #expect(decoded.elements == [TestData(name: "a", value: 1), TestData(name: "c", value: 3)])
        #expect(decoded.skippedCount == 2)
    }

    /// LossyDecodableArrayは配列でないJSONではデコードに失敗することを検証
    @Test func lossyArrayRejectsNonArray() {
        let json = #"{"name":"a","value":1}"#
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(LossyDecodableArray<TestData>.self, from: Data(json.utf8))
        }
    }
}
