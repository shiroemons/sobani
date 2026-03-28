import Foundation
import Testing
@testable import Sobani

/// PositionLogger の記録・読み込み・クリア・エクスポート動作を検証するテスト
@Suite @MainActor struct PositionLoggerTests {
    let tempDir: URL
    let positionLogger: PositionLogger

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PositionLoggerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        positionLogger = PositionLogger(baseDirectory: tempDir)
        positionLogger.isEnabled = false
    }

    // MARK: - isEnabled

    @Test func logDisabledDoesNotRecord() {
        positionLogger.isEnabled = false
        positionLogger.log(event: "test")
        #expect(positionLogger.loadEntries().isEmpty)
    }

    @Test func logEnabledRecords() {
        positionLogger.isEnabled = true
        positionLogger.log(event: "test.event", context: ["key": "value"])
        let entries = positionLogger.loadEntries()
        #expect(entries.count == 1)
        #expect(entries[0].event == "test.event")
        #expect(entries[0].context?["key"] == "value")
    }

    // MARK: - 複数エントリ

    @Test func appendsMultipleEntries() {
        positionLogger.isEnabled = true
        positionLogger.log(event: "first")
        positionLogger.log(event: "second")
        positionLogger.log(event: "third")
        let entries = positionLogger.loadEntries()
        #expect(entries.count == 3)
        #expect(entries[0].event == "first")
        #expect(entries[2].event == "third")
    }

    // MARK: - clearAll

    @Test func clearRemovesAllEntries() {
        positionLogger.isEnabled = true
        positionLogger.log(event: "test")
        positionLogger.clearAll()
        #expect(positionLogger.loadEntries().isEmpty)
    }

    // MARK: - 件数保持

    @Test func entriesRetainedWithinLimit() {
        positionLogger.isEnabled = true
        for index in 0..<5 {
            positionLogger.log(event: "entry.\(index)")
        }
        #expect(positionLogger.loadEntries().count == 5)
    }

    // MARK: - Export

    @Test func exportAsJSONLReturnsValidData() throws {
        positionLogger.isEnabled = true
        positionLogger.log(event: "export.test")
        let data = positionLogger.exportAsJSONL()
        #expect(!data.isEmpty)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("export.test"))
    }

    @Test func exportAsJSONReturnsValidArray() throws {
        positionLogger.isEnabled = true
        positionLogger.log(event: "json.test")
        let data = positionLogger.exportAsJSON()
        #expect(!data.isEmpty)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([PositionLogger.LogEntry].self, from: data)
        #expect(entries.count == 1)
        #expect(entries[0].event == "json.test")
    }

    // MARK: - スナップショット付きログ

    @Test func logWithScreenSnapshots() throws {
        positionLogger.isEnabled = true
        let screens = [
            PositionLogger.ScreenSnapshot(
                displayID: 1, originX: 0, originY: 0,
                width: 1920, height: 1080, isMain: true
            )
        ]
        positionLogger.log(event: "screen.test", screens: screens)
        let entries = positionLogger.loadEntries()
        #expect(entries.count == 1)
        let savedScreens = try #require(entries[0].screens)
        #expect(savedScreens.count == 1)
        #expect(savedScreens[0].displayID == 1)
        #expect(savedScreens[0].width == 1920)
    }

    @Test func logWithWindowSnapshots() throws {
        positionLogger.isEnabled = true
        let windows = [
            PositionLogger.WindowSnapshot(
                windowId: 1, originX: 100, originY: 200,
                width: 800, height: 600,
                imageWidth: 800, imageHeight: 600, displayID: 1
            )
        ]
        positionLogger.log(event: "window.test", windows: windows)
        let entries = positionLogger.loadEntries()
        let savedWindows = try #require(entries[0].windows)
        #expect(savedWindows[0].windowId == 1)
        #expect(savedWindows[0].originX == 100)
    }

    // MARK: - 空ファイル

    @Test func loadEntriesFromEmptyReturnsEmpty() {
        #expect(positionLogger.loadEntries().isEmpty)
    }
}
