import Cocoa
import os.log

// MARK: - Image Manager

@MainActor
final class ImageManager {
    private let logger = Logger(
        subsystem: AppConstants.loggerSubsystem,
        category: "ImageManager"
    )
    static let shared = ImageManager()
    nonisolated static let supportedExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "heic"]
    private let baseDirectory: URL?
    private var cachedImageNames: [String]?
    private var previewImageCache: [String: (image: NSImage, lastAccess: Date)] = [:]
    private static let previewCacheCountLimit = 20
    private var cachedDefaultImage: NSImage?

    let appSupportURL: URL?
    let imagesDirectoryURL: URL?

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
        let initLogger = Logger(subsystem: AppConstants.loggerSubsystem, category: "ImageManager")
        let appDir = AppSupportDirectory.url(baseDirectory: baseDirectory, logger: initLogger)
        self.appSupportURL = appDir
        if let appDir {
            self.imagesDirectoryURL = AppSupportDirectory.ensureSubdirectory("images", in: appDir, logger: initLogger)
        } else {
            self.imagesDirectoryURL = nil
        }
    }

    private func insertIntoCache(_ name: String) {
        guard var names = cachedImageNames else { return }
        let index = names.firstIndex(where: { $0 >= name }) ?? names.count
        names.insert(name, at: index)
        cachedImageNames = names
    }

    private func removeFromCache(_ name: String) {
        cachedImageNames?.removeAll { $0 == name }
    }

    func registeredImageNames() -> [String] {
        if let cached = cachedImageNames {
            return cached
        }
        guard let imagesDir = imagesDirectoryURL else { return [] }
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: imagesDir.path)) ?? []
        let imageExtensions = Self.supportedExtensions
        let result = files
            .filter { name in
                let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
                return imageExtensions.contains(ext)
            }
            .sorted()
        cachedImageNames = result
        return result
    }

    func loadRegisteredImage(named name: String) -> NSImage? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard let url = PathSanitizer.safeURL(name: name, in: imagesDir) else { return nil }
        return NSImage(contentsOf: url)
    }

    func loadRegisteredImageCached(named name: String) -> NSImage? {
        if let entry = previewImageCache[name] {
            previewImageCache[name] = (image: entry.image, lastAccess: Date())
            return entry.image
        }
        guard let image = loadRegisteredImage(named: name) else { return nil }
        if previewImageCache.count >= Self.previewCacheCountLimit {
            if let lruKey = previewImageCache.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key {
                previewImageCache.removeValue(forKey: lruKey)
            }
        }
        previewImageCache[name] = (image: image, lastAccess: Date())
        return image
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
            insertIntoCache(finalName)
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
            insertIntoCache(destURL.lastPathComponent)
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
            removeFromCache(name)
            previewImageCache.removeValue(forKey: name)
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
        if let cached = cachedDefaultImage {
            return cached
        }
        let image: NSImage?
        if let url = customDefaultURL, let customImage = NSImage(contentsOf: url) {
            image = customImage
        } else {
            image = NSImage(named: "character")
        }
        cachedDefaultImage = image
        return image
    }

    func setCustomDefault(from url: URL) {
        guard let destURL = customDefaultURL else { return }
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: url, to: destURL)
            cachedDefaultImage = nil
        } catch {
            logger.error("Failed to set custom default: \(error.localizedDescription)")
        }
    }

    func resetCustomDefault() {
        guard let url = customDefaultURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
            cachedDefaultImage = nil
        } catch {
            logger.error("Failed to reset custom default: \(error.localizedDescription)")
        }
    }
}
