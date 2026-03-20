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
    private(set) var layoutsDirectoryURL: URL?

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
    }

    private func sanitizedFileName(for name: String) -> String {
        PathSanitizer.safeName(from: name) ?? "unnamed"
    }

    private func presetFileURL(for name: String) -> URL? {
        guard let layoutsDir = layoutsDirectoryURL else { return nil }
        let fileName = sanitizedFileName(for: name) + ".json"
        return layoutsDir.appendingPathComponent(fileName)
    }

    private func persistPreset(_ preset: LayoutPreset) {
        guard let url = presetFileURL(for: preset.name) else { return }
        JSONPersistence.save(preset, to: url, logger: logger,
                             errorMessage: "Failed to persist layout preset") {
            $0.dateEncodingStrategy = .iso8601
        }
        invalidateCache()
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
        let files = (try? fm.contentsOfDirectory(atPath: layoutsDir.path)) ?? []
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
        persistPreset(renamedPreset)
        guard FileManager.default.fileExists(atPath: newURL.path) else { return false }
        // Only delete old file if sanitized file names differ
        let oldFileName = sanitizedFileName(for: oldName)
        let newFileName = sanitizedFileName(for: newName)
        if oldFileName != newFileName {
            guard let oldURL = presetFileURL(for: oldName) else {
                return true
            }
            try? FileManager.default.removeItem(at: oldURL)
            invalidateCache()
        }
        return true
    }
}
