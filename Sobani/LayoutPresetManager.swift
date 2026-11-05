import Cocoa
import os.log

// MARK: - Layout Preset

struct LayoutPreset: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    let states: [WindowState]

    // Migration: existing files without id get one auto-generated
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.states = try container.decode([WindowState].self, forKey: .states)
    }

    init(id: UUID = UUID(), name: String, createdAt: Date, states: [WindowState]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.states = states
    }
}

// MARK: - Layout Preset Manager

@MainActor
final class LayoutPresetManager {
    static let shared = LayoutPresetManager()
    private let logger = Logger(category: "LayoutPresetManager")
    private var cachedPresets: [LayoutPreset]?
    let layoutsDirectoryURL: URL?

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(baseDirectory: URL? = nil) {
        if let appDir = AppSupportDirectory.url(baseDirectory: baseDirectory, logger: logger) {
            self.layoutsDirectoryURL = AppSupportDirectory.ensureSubdirectory(
                "layouts", in: appDir, logger: logger
            )
        } else {
            self.layoutsDirectoryURL = nil
        }
    }

    private func invalidateCache() {
        cachedPresets = nil
        NotificationCenter.default.post(name: AppConstants.layoutPresetsDidChange, object: nil)
    }

    /// ユーザー入力のプリセット名を正規化する（前後の空白・改行を除去）。空になる場合は nil。
    ///
    /// メニュー・管理パネルなど、プリセット名を受け取るすべての経路でこの関数を通すこと。
    nonisolated static func normalizedName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 2つの URL がファイルシステム上の同一ファイルを指すか。
    ///
    /// 大文字小文字を区別しない APFS や Unicode 正規化の違いでは、文字列が異なっても同じファイルになる。
    nonisolated static func isSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        let key: Set<URLResourceKey> = [.fileResourceIdentifierKey]
        guard let lhsID = try? lhs.resourceValues(forKeys: key).fileResourceIdentifier,
              let rhsID = try? rhs.resourceValues(forKeys: key).fileResourceIdentifier else {
            return false
        }
        return lhsID.isEqual(rhsID)
    }

    private func sanitizedFileName(for name: String) -> String {
        PathSanitizer.safeName(from: name) ?? "unnamed"
    }

    private func presetFileURL(for name: String) -> URL? {
        guard let layoutsDir = layoutsDirectoryURL else { return nil }
        let fileName = sanitizedFileName(for: name) + ".json"
        return layoutsDir.appendingPathComponent(fileName)
    }

    /// - Returns: ファイルへの書き込みに成功したか。
    @discardableResult
    private func persistPreset(_ preset: LayoutPreset) -> Bool {
        guard let url = presetFileURL(for: preset.name) else { return false }
        let sanitized = LayoutPreset(
            id: preset.id, name: preset.name, createdAt: preset.createdAt,
            states: WindowState.sanitizedForPersistence(preset.states, logger: logger)
        )
        let saved = JSONPersistence.save(
            sanitized, to: url, logger: logger,
            errorMessage: "Failed to persist layout preset"
        ) {
            $0.dateEncodingStrategy = .iso8601
        }
        invalidateCache()
        return saved
    }

    func savePreset(name: String, states: [WindowState]) {
        let preset = LayoutPreset(name: name, createdAt: Date(), states: states)
        persistPreset(preset)
    }

    func updatePreset(_ preset: LayoutPreset, states: [WindowState]) {
        let updated = LayoutPreset(
            id: preset.id, name: preset.name, createdAt: preset.createdAt, states: states
        )
        persistPreset(updated)
    }

    func loadPresets() -> [LayoutPreset] {
        if let cached = cachedPresets {
            return cached
        }
        guard let layoutsDir = layoutsDirectoryURL else { return [] }
        let fm = FileManager.default
        let files: [String]
        do {
            files = try fm.contentsOfDirectory(atPath: layoutsDir.path)
        } catch {
            logger.error("Failed to list layouts directory at \(layoutsDir.path): \(error.localizedDescription)")
            return []
        }
        var presets: [LayoutPreset] = []
        for file in files where file.hasSuffix(".json") {
            let url = layoutsDir.appendingPathComponent(file)
            if let preset = JSONPersistence.load(
                LayoutPreset.self,
                from: url,
                logger: logger,
                errorMessage: "Skipping invalid layout file \(file)",
                configure: { $0.dateDecodingStrategy = .iso8601 }
            ) {
                presets.append(preset)
            }
        }
        let result = presets.sorted { $0.createdAt > $1.createdAt }
        cachedPresets = result
        return result
    }

    func loadPreset(named name: String) -> LayoutPreset? {
        guard let url = presetFileURL(for: name) else { return nil }
        return JSONPersistence.load(
            LayoutPreset.self,
            from: url,
            logger: logger,
            errorMessage: "Failed to load layout preset '\(name)'",
            configure: { $0.dateDecodingStrategy = .iso8601 }
        )
    }

    func deletePreset(named name: String) {
        guard let url = presetFileURL(for: name) else { return }
        do {
            try FileManager.default.removeItem(at: url)
            invalidateCache()
        } catch {
            logger.error("Failed to delete layout preset '\(name)': \(error.localizedDescription)")
        }
    }

    func restorePreset(_ preset: LayoutPreset) {
        persistPreset(preset)
    }

    func presetExists(named name: String) -> Bool {
        guard let url = presetFileURL(for: name) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// `name` で保存すると、`excluded` 以外の既存プリセットを上書きしてしまうかを返す。
    ///
    /// リネーム時に自分自身（大文字小文字だけの変更など、同じファイルに解決される名前）を
    /// 「既存」と誤判定しないために使う。
    func presetExists(named name: String, excluding excluded: String?) -> Bool {
        guard presetExists(named: name) else { return false }
        guard let excluded,
              let url = presetFileURL(for: name),
              let excludedURL = presetFileURL(for: excluded) else { return true }
        return !Self.isSameFile(url, excludedURL)
    }

    func renamePreset(from oldName: String, to newName: String) -> Bool {
        guard let oldPreset = loadPreset(named: oldName) else {
            logger.error("Failed to rename layout preset: '\(oldName)' not found")
            return false
        }
        guard let newURL = presetFileURL(for: newName) else { return false }
        let renamedPreset = LayoutPreset(
            id: oldPreset.id, name: newName,
            createdAt: oldPreset.createdAt, states: oldPreset.states
        )
        guard persistPreset(renamedPreset) else { return false }
        // Only delete old file if sanitized file names differ
        let oldFileName = sanitizedFileName(for: oldName)
        let newFileName = sanitizedFileName(for: newName)
        if oldFileName != newFileName {
            guard let oldURL = presetFileURL(for: oldName) else {
                return true
            }
            // 大文字小文字だけの変更などで新旧が同じファイルに解決される場合、削除すると唯一のファイルが消える
            if Self.isSameFile(oldURL, newURL) {
                return true
            }
            do {
                try FileManager.default.removeItem(at: oldURL)
            } catch {
                logger.warning("Failed to remove old preset file at \(oldURL.path): \(error.localizedDescription)")
            }
            invalidateCache()
        }
        return true
    }
}
