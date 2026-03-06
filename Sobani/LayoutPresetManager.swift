import Cocoa
import os.log

// MARK: - Layout Preset

struct LayoutPreset: Codable, Equatable {
    let name: String
    let createdAt: Date
    let states: [WindowState]
}

// MARK: - Layout Preset Manager

class LayoutPresetManager {
    static let shared = LayoutPresetManager()
    private let logger = Logger(
        subsystem: "com.shiroemons.Sobani",
        category: "LayoutPresetManager"
    )
    private let baseDirectory: URL?

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
    }

    private var appSupportURL: URL? {
        AppSupportDirectory.url(baseDirectory: baseDirectory, logger: logger)
    }

    var layoutsDirectoryURL: URL? {
        guard let appDir = appSupportURL else { return nil }
        let layoutsDir = appDir.appendingPathComponent("layouts")
        let fm = FileManager.default
        if !fm.fileExists(atPath: layoutsDir.path) {
            do {
                try fm.createDirectory(at: layoutsDir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create layouts directory: \(error.localizedDescription)")
            }
        }
        return layoutsDir
    }

    private func sanitizedFileName(for name: String) -> String {
        PathSanitizer.safeName(from: name) ?? "unnamed"
    }

    func savePreset(name: String, states: [WindowState]) {
        guard let layoutsDir = layoutsDirectoryURL else { return }
        let preset = LayoutPreset(name: name, createdAt: Date(), states: states)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(preset)
            let fileName = sanitizedFileName(for: name) + ".json"
            let url = layoutsDir.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to save layout preset: \(error.localizedDescription)")
        }
    }

    func loadPresets() -> [LayoutPreset] {
        guard let layoutsDir = layoutsDirectoryURL else { return [] }
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: layoutsDir.path)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var presets: [LayoutPreset] = []
        for file in files where file.hasSuffix(".json") {
            let url = layoutsDir.appendingPathComponent(file)
            do {
                let data = try Data(contentsOf: url)
                let preset = try decoder.decode(LayoutPreset.self, from: data)
                presets.append(preset)
            } catch {
                logger.warning("Skipping invalid layout file \(file): \(error.localizedDescription)")
            }
        }
        return presets.sorted { $0.createdAt > $1.createdAt }
    }

    func loadPreset(named name: String) -> LayoutPreset? {
        guard let layoutsDir = layoutsDirectoryURL else { return nil }
        let fileName = sanitizedFileName(for: name) + ".json"
        let url = layoutsDir.appendingPathComponent(fileName)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(LayoutPreset.self, from: data)
        } catch {
            logger.error("Failed to load layout preset '\(name)': \(error.localizedDescription)")
            return nil
        }
    }

    func deletePreset(named name: String) {
        guard let layoutsDir = layoutsDirectoryURL else { return }
        let fileName = sanitizedFileName(for: name) + ".json"
        let url = layoutsDir.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("Failed to delete layout preset '\(name)': \(error.localizedDescription)")
        }
    }

    func presetExists(named name: String) -> Bool {
        guard let layoutsDir = layoutsDirectoryURL else { return false }
        let fileName = sanitizedFileName(for: name) + ".json"
        let url = layoutsDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path)
    }
}
