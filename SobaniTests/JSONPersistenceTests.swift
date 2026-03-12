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

    private let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "JSONPersistenceTests")

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
