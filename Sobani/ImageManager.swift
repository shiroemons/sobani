import Cocoa
import os.log

// MARK: - Image Manager

/// 画像の登録・読み込み・削除を管理するシングルトン。
///
/// `~/Library/Application Support/Sobani/images/` に画像を格納し、
/// パストラバーサル防止、拡張子チェック、重複ファイル名のリネームを行う。
@MainActor
final class ImageManager {
    private let logger = Logger(category: "ImageManager")
    static let shared = ImageManager()
    nonisolated static let supportedExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "heic"]

    nonisolated static func isSupportedExtension(_ ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }

    private let baseDirectory: URL?
    private var cachedImageNames: [String]?
    private var previewImageCache: [String: (image: NSImage, lastAccess: Date)] = [:]
    private static let previewCacheCountLimit = 20
    private var cachedDefaultImage: NSImage?

    private let appSupportURL: URL?
    private let imagesDirectoryURL: URL?

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
        let appDir = AppSupportDirectory.url(baseDirectory: baseDirectory, logger: logger)
        self.appSupportURL = appDir
        if let appDir {
            self.imagesDirectoryURL = AppSupportDirectory.ensureSubdirectory(
                "images", in: appDir, logger: logger
            )
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

    private func uniqueDestinationURL(for name: String, in directory: URL) -> URL? {
        guard let initialURL = PathSanitizer.safeURL(name: name, in: directory) else { return nil }
        let nameURL = URL(fileURLWithPath: initialURL.lastPathComponent)
        let baseName = nameURL.deletingPathExtension().lastPathComponent
        let ext = nameURL.pathExtension
        var finalURL = initialURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let candidateName = ext.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter).\(ext)"
            finalURL = directory.appendingPathComponent(candidateName)
            counter += 1
        }
        return finalURL
    }

    /// 登録済み画像名をソート済みリストで返す。結果はキャッシュされる。
    func registeredImageNames() -> [String] {
        if let cached = cachedImageNames {
            return cached
        }
        guard let imagesDir = imagesDirectoryURL else { return [] }
        let fm = FileManager.default
        let files: [String]
        do {
            files = try fm.contentsOfDirectory(atPath: imagesDir.path)
        } catch {
            logger.error("Failed to list images directory at \(imagesDir.path): \(error.localizedDescription)")
            return []
        }
        let result = files
            .filter { name in
                let ext = URL(fileURLWithPath: name).pathExtension
                return Self.isSupportedExtension(ext)
            }
            .sorted()
        cachedImageNames = result
        return result
    }

    /// 指定名の登録済み画像を読み込む。パストラバーサル対策済み。
    func loadRegisteredImage(named name: String) -> NSImage? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard let url = PathSanitizer.safeURL(name: name, in: imagesDir) else { return nil }
        return NSImage(contentsOf: url)
    }

    func image(named name: String) -> NSImage? {
        if name == AppConstants.defaultImageName {
            return defaultImage()
        }
        return loadRegisteredImageCached(named: name)
    }

    func loadRegisteredImageCached(named name: String) -> NSImage? {
        if let entry = previewImageCache[name] {
            previewImageCache[name] = (image: entry.image, lastAccess: Date())
            logger.debug("Cache hit: \(name)")
            return entry.image
        }
        guard let image = loadRegisteredImage(named: name) else { return nil }
        if previewImageCache.count >= Self.previewCacheCountLimit {
            if let lruKey = previewImageCache.min(
                by: { $0.value.lastAccess < $1.value.lastAccess }
            )?.key {
                previewImageCache.removeValue(forKey: lruKey)
                logger.debug("Cache eviction: \(lruKey)")
            }
        }
        previewImageCache[name] = (image: image, lastAccess: Date())
        logger.debug("Cache miss: \(name)")
        return image
    }

    /// 外部 URL から画像を `images/` にコピーして登録する。重複名は自動リネームされる。
    @discardableResult
    func registerImage(from url: URL) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard Self.isSupportedExtension(url.pathExtension) else { return nil }
        guard let name = PathSanitizer.safeName(from: url.lastPathComponent) else { return nil }
        guard NSImage(contentsOf: url) != nil else { return nil }
        guard let finalURL = uniqueDestinationURL(for: name, in: imagesDir) else { return nil }
        do {
            try FileManager.default.copyItem(at: url, to: finalURL)
            let finalName = finalURL.lastPathComponent
            insertIntoCache(finalName)
            NotificationCenter.default.post(
                name: AppConstants.registeredImagesDidChange, object: nil
            )
            return finalName
        } catch {
            logger.error("Failed to copy image: \(error.localizedDescription)")
            return nil
        }
    }

    /// NSImage を PNG として `images/` に保存して登録する。重複名は自動リネームされる。
    @discardableResult
    func registerImage(_ image: NSImage, name: String) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
        guard let destURL = uniqueDestinationURL(for: name, in: imagesDir) else { return nil }
        do {
            try pngData.write(to: destURL)
            insertIntoCache(destURL.lastPathComponent)
            NotificationCenter.default.post(
                name: AppConstants.registeredImagesDidChange, object: nil
            )
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
            NotificationCenter.default.post(
                name: AppConstants.registeredImagesDidChange, object: nil
            )
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

    /// デフォルト画像を返す。カスタムデフォルトが存在すればそれを、なければ内蔵アセットを返す。
    func defaultImage() -> NSImage? {
        if let cached = cachedDefaultImage {
            return cached
        }
        let image: NSImage?
        if let url = customDefaultURL, let customImage = NSImage(contentsOf: url) {
            image = customImage
        } else {
            image = NSImage(named: "default_image")
        }
        cachedDefaultImage = image
        return image
    }

    func setCustomDefault(from url: URL) {
        guard let destURL = customDefaultURL else { return }
        let fm = FileManager.default
        let tempURL = destURL.deletingLastPathComponent()
            .appendingPathComponent(".\(destURL.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try fm.copyItem(at: url, to: tempURL)
            if fm.fileExists(atPath: destURL.path) {
                _ = try fm.replaceItemAt(destURL, withItemAt: tempURL)
            } else {
                try fm.moveItem(at: tempURL, to: destURL)
            }
            cachedDefaultImage = nil
        } catch {
            try? fm.removeItem(at: tempURL)
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
