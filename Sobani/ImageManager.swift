import Cocoa
import os.log

// MARK: - Image Manager

@MainActor
final class ImageManager {
    private let logger = Logger(
        subsystem: "com.shiroemons.Sobani",
        category: "ImageManager"
    )
    static let shared = ImageManager()
    static let supportedExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "heic"]
    private let baseDirectory: URL?

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
    }

    private var appSupportURL: URL? {
        AppSupportDirectory.url(baseDirectory: baseDirectory, logger: logger)
    }

    var imagesDirectoryURL: URL? {
        guard let appDir = appSupportURL else { return nil }
        let imagesDir = appDir.appendingPathComponent("images")
        let fm = FileManager.default
        if !fm.fileExists(atPath: imagesDir.path) {
            do {
                try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create images directory: \(error.localizedDescription)")
            }
        }
        return imagesDir
    }

    func registeredImageNames() -> [String] {
        guard let imagesDir = imagesDirectoryURL else { return [] }
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: imagesDir.path)) ?? []
        let imageExtensions = Self.supportedExtensions
        return files
            .filter { name in
                let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
                return imageExtensions.contains(ext)
            }
            .sorted()
    }

    func loadRegisteredImage(named name: String) -> NSImage? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard let url = PathSanitizer.safeURL(name: name, in: imagesDir) else { return nil }
        return NSImage(contentsOf: url)
    }

    @discardableResult
    func registerImage(from url: URL) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        let ext = url.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else { return nil }
        guard let name = PathSanitizer.safeName(from: url.lastPathComponent) else { return nil }
        let destURL = imagesDir.appendingPathComponent(name)
        let fm = FileManager.default
        var finalURL = destURL
        var finalName = name
        var counter = 1
        while fm.fileExists(atPath: finalURL.path) {
            let nameURL = URL(fileURLWithPath: name)
            let baseName = nameURL.deletingPathExtension().lastPathComponent
            let ext = nameURL.pathExtension
            finalName = "\(baseName)_\(counter).\(ext)"
            finalURL = imagesDir.appendingPathComponent(finalName)
            counter += 1
        }
        do {
            try fm.copyItem(at: url, to: finalURL)
            return finalName
        } catch {
            logger.error("Failed to copy image: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func registerImage(_ image: NSImage, name: String) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
        guard let destURL = PathSanitizer.safeURL(name: name, in: imagesDir) else { return nil }
        do {
            try pngData.write(to: destURL)
        } catch {
            logger.error("Failed to write image data: \(error.localizedDescription)")
            return nil
        }
        return destURL.lastPathComponent
    }

    func removeRegisteredImage(named name: String) {
        guard let imagesDir = imagesDirectoryURL else { return }
        guard let url = PathSanitizer.safeURL(name: name, in: imagesDir) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("Failed to remove image: \(error.localizedDescription)")
        }
    }

    var customDefaultURL: URL? {
        appSupportURL?.appendingPathComponent("default.png")
    }

    var hasCustomDefault: Bool {
        guard let url = customDefaultURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func defaultImage() -> NSImage? {
        if let url = customDefaultURL, let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(named: "character")
    }

    func originalDefaultImage() -> NSImage? {
        return NSImage(named: "character")
    }

    func setCustomDefault(from url: URL) {
        guard let destURL = customDefaultURL else { return }
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: url, to: destURL)
        } catch {
            logger.error("Failed to set custom default: \(error.localizedDescription)")
        }
    }

    func resetCustomDefault() {
        guard let url = customDefaultURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("Failed to reset custom default: \(error.localizedDescription)")
        }
    }
}
