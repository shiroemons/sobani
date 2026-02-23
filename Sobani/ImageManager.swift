import Cocoa
import os.log

// MARK: - Image Manager

class ImageManager {
    private let logger = Logger(
        subsystem: "com.shiroemons.Sobani",
        category: "ImageManager"
    )
    static let shared = ImageManager()
    private let baseDirectory: URL?

    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
    }

    private var appSupportURL: URL? {
        let fm = FileManager.default
        let appDir: URL
        if let base = baseDirectory {
            appDir = base
        } else {
            guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
            appDir = appSupport.appendingPathComponent("Sobani")
        }
        if !fm.fileExists(atPath: appDir.path) {
            do {
                try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create app support directory: \(error.localizedDescription)")
            }
        }
        return appDir
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
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "heic"]
        return files
            .filter { name in
                let ext = (name as NSString).pathExtension.lowercased()
                return imageExtensions.contains(ext)
            }
            .sorted()
    }

    func loadRegisteredImage(named name: String) -> NSImage? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        // パストラバーサル防止: ファイル名のみを使用し、imagesDir の外へのアクセスを禁止
        let safeName = URL(fileURLWithPath: name).lastPathComponent
        guard !safeName.isEmpty, safeName != "." else { return nil }
        let url = imagesDir.appendingPathComponent(safeName)
        guard url.path.hasPrefix(imagesDir.path + "/") else { return nil }
        return NSImage(contentsOf: url)
    }

    @discardableResult
    func registerImage(from url: URL) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        let ext = url.pathExtension.lowercased()
        let supportedExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "heic"]
        guard supportedExtensions.contains(ext) else { return nil }
        let name = url.lastPathComponent
        let destURL = imagesDir.appendingPathComponent(name)
        let fm = FileManager.default
        var finalURL = destURL
        var finalName = name
        var counter = 1
        while fm.fileExists(atPath: finalURL.path) {
            let baseName = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
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
        let destURL = imagesDir.appendingPathComponent(name)
        do {
            try pngData.write(to: destURL)
        } catch {
            logger.error("Failed to write image data: \(error.localizedDescription)")
            return nil
        }
        return name
    }

    func removeRegisteredImage(named name: String) {
        guard let imagesDir = imagesDirectoryURL else { return }
        // パストラバーサル防止: ファイル名のみを使用し、imagesDir の外の削除を禁止
        let safeName = URL(fileURLWithPath: name).lastPathComponent
        guard !safeName.isEmpty, safeName != "." else { return }
        let url = imagesDir.appendingPathComponent(safeName)
        guard url.path.hasPrefix(imagesDir.path + "/") else { return }
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
