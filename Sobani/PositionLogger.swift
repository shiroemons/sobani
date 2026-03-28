import Cocoa
import os.log

/// 画面位置変更のデバッグログを JSONL 形式で記録するマネージャ。
///
/// 管理パネルのログタブでオン/オフを切り替え、有効時のみ記録する。
/// JSONL（1行1JSON）で追記し、最大 1000 エントリを保持する。
@MainActor
final class PositionLogger {
    static let shared = PositionLogger()
    private let logger = Logger(category: "PositionLogger")
    private let appSupportURL: URL?
    private static let maxEntries = 1000
    private static let trimTarget = 900
    private static let logFileName = "position_log.jsonl"
    private static let lineEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private static let lineDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var entryCount = 0

    /// テスト DI 用。プロダクションコードでは `shared` を使用すること。
    init(baseDirectory: URL? = nil) {
        self.appSupportURL = AppSupportDirectory.url(baseDirectory: baseDirectory, logger: logger)
        if let url = appSupportURL?.appendingPathComponent(Self.logFileName),
           let data = try? Data(contentsOf: url) {
            entryCount = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true).count
        }
    }

    var isEnabled: Bool {
        get { PositionLogSettings.isEnabled }
        set { PositionLogSettings.isEnabled = newValue }
    }

    // MARK: - Data Types

    struct LogEntry: Codable, Identifiable, Sendable {
        let id: UUID
        let timestamp: Date
        let event: String
        let screens: [ScreenSnapshot]?
        let windows: [WindowSnapshot]?
        let context: [String: String]?
    }

    struct ScreenSnapshot: Codable, Sendable {
        let displayID: UInt32
        let originX: CGFloat
        let originY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let isMain: Bool
    }

    struct WindowSnapshot: Codable, Sendable {
        let windowId: Int
        let originX: CGFloat
        let originY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let imageWidth: CGFloat
        let imageHeight: CGFloat
        let displayID: UInt32?
    }

    // MARK: - Logging

    func log(
        event: String,
        screens: [ScreenSnapshot]? = nil,
        windows: [WindowSnapshot]? = nil,
        context: [String: String]? = nil
    ) {
        guard isEnabled else { return }
        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            event: event,
            screens: screens,
            windows: windows,
            context: context
        )
        appendEntry(entry)
    }

    // MARK: - Reading

    func loadEntries() -> [LogEntry] {
        guard let url = logFileURL,
              let data = try? Data(contentsOf: url) else { return [] }
        return data
            .split(separator: UInt8(ascii: "\n"))
            .compactMap { line in
                try? Self.lineDecoder.decode(LogEntry.self, from: Data(line))
            }
    }

    // MARK: - Management

    func clearAll() {
        guard let url = logFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        entryCount = 0
        logger.info("Position log cleared")
    }

    // MARK: - Export

    func exportAsJSONL() -> Data {
        guard let url = logFileURL,
              let data = try? Data(contentsOf: url) else { return Data() }
        return data
    }

    func exportAsJSON() -> Data {
        let entries = loadEntries()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(entries)) ?? Data()
    }

    // MARK: - Snapshot Helpers

    /// 現在のスクリーン状態をスナップショットとして返す。
    func currentScreenSnapshots() -> [ScreenSnapshot] {
        NSScreen.screens.map { screen in
            let frame = screen.frame
            let displayID = (screen.deviceDescription[AppConstants.screenNumberKey]
                as? CGDirectDisplayID) ?? 0
            return ScreenSnapshot(
                displayID: displayID,
                originX: frame.origin.x,
                originY: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height,
                isMain: screen == NSScreen.main
            )
        }
    }

    /// WindowState からスナップショットを生成する（復元時・保存時に使用）。
    func windowSnapshot(from state: WindowState) -> WindowSnapshot {
        WindowSnapshot(
            windowId: state.windowId,
            originX: state.originX,
            originY: state.originY,
            width: state.width,
            height: state.height,
            imageWidth: state.width,
            imageHeight: state.height,
            displayID: nil
        )
    }

    /// ImageWindow からスナップショットを生成する（実行時に使用）。
    func windowSnapshot(from imageWindow: ImageWindow) -> WindowSnapshot {
        let frame = imageWindow.window.frame
        let imageFrame = imageWindow.imageView.frame
        let screen = NSScreen.screen(containing: frame)
        return WindowSnapshot(
            windowId: imageWindow.windowId,
            originX: frame.origin.x,
            originY: frame.origin.y,
            width: frame.size.width,
            height: frame.size.height,
            imageWidth: imageFrame.width,
            imageHeight: imageFrame.height,
            displayID: screen?.displayID
        )
    }

    // MARK: - Private

    private var logFileURL: URL? {
        appSupportURL?.appendingPathComponent(Self.logFileName)
    }

    private func appendEntry(_ entry: LogEntry) {
        guard let url = logFileURL else { return }
        guard var lineData = try? Self.lineEncoder.encode(entry) else { return }
        lineData.append(UInt8(ascii: "\n"))

        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            handle.write(lineData)
            handle.closeFile()
        } else {
            try? lineData.write(to: url, options: .atomic)
        }

        entryCount += 1
        trimIfNeeded()
    }

    private func trimIfNeeded() {
        guard entryCount > Self.maxEntries else { return }
        let entries = loadEntries()
        rewriteEntries(Array(entries.suffix(Self.trimTarget)))
        entryCount = Self.trimTarget
    }

    private func rewriteEntries(_ entries: [LogEntry]) {
        guard let url = logFileURL else { return }
        var data = Data()
        for entry in entries {
            guard let lineData = try? Self.lineEncoder.encode(entry) else { continue }
            data.append(lineData)
            data.append(UInt8(ascii: "\n"))
        }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - LogEntry Summary

extension PositionLogger.LogEntry {
    var summary: String {
        var parts: [String] = []
        if let ctx = context {
            parts.append(contentsOf: ctx.map { "\($0.key)=\($0.value)" })
        }
        if let screens = screens {
            parts.append("screens=\(screens.count)")
        }
        return parts.isEmpty ? "-" : parts.joined(separator: " ")
    }
}
