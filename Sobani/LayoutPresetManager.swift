import Cocoa
import os.log

// MARK: - Layout Preset

struct LayoutPreset: Codable, Equatable, Sendable {
    let name: String
    let createdAt: Date
    let states: [WindowState]
}

// MARK: - Layout Preset Manager

@MainActor
final class LayoutPresetManager {
    static let shared = LayoutPresetManager()
    private let logger = Logger(
        subsystem: AppConstants.loggerSubsystem,
        category: "LayoutPresetManager"
    )
    private let baseDirectory: URL?
    private var cachedPresets: [LayoutPreset]?

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
    }

    private var appSupportURL: URL? {
        AppSupportDirectory.url(baseDirectory: baseDirectory, logger: logger)
    }

    var layoutsDirectoryURL: URL? {
        guard let appDir = appSupportURL else { return nil }
        return AppSupportDirectory.ensureSubdirectory("layouts", in: appDir, logger: logger)
    }

    private func sanitizedFileName(for name: String) -> String {
        PathSanitizer.safeName(from: name) ?? "unnamed"
    }

    private func presetFileURL(for name: String) -> URL? {
        guard let layoutsDir = layoutsDirectoryURL else { return nil }
        let fileName = sanitizedFileName(for: name) + ".json"
        return layoutsDir.appendingPathComponent(fileName)
    }

    func savePreset(name: String, states: [WindowState]) {
        guard let url = presetFileURL(for: name) else { return }
        let preset = LayoutPreset(name: name, createdAt: Date(), states: states)
        JSONPersistence.save(preset, to: url, logger: logger, errorMessage: "Failed to save layout preset") {
            $0.dateEncodingStrategy = .iso8601
        }
        cachedPresets = nil
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
            cachedPresets = nil
        } catch {
            logger.error("Failed to delete layout preset '\(name)': \(error.localizedDescription)")
        }
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
        let renamedPreset = LayoutPreset(name: newName, createdAt: oldPreset.createdAt, states: oldPreset.states)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(renamedPreset)
            try data.write(to: newURL, options: .atomic)
            cachedPresets = nil
        } catch {
            logger.error("Failed to save renamed layout preset: \(error.localizedDescription)")
            return false
        }
        // Only delete old file if sanitized file names differ
        let oldFileName = sanitizedFileName(for: oldName)
        let newFileName = sanitizedFileName(for: newName)
        if oldFileName != newFileName {
            deletePreset(named: oldName)
        }
        return true
    }
}
