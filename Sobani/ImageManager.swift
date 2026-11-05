import Cocoa
import ImageIO
import os.log
import UniformTypeIdentifiers

// MARK: - Image Manager

/// 画像の登録・読み込み・削除を管理するシングルトン。
///
/// `~/Library/Application Support/Sobani/images/` に画像を格納し、
/// パストラバーサル防止、拡張子・内容のチェック、重複ファイル名のリネームを行う。
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
    /// 登録画像のキャッシュ（ウィンドウ表示・プレビューで共用）。キーはサニタイズ後のファイル名。
    private var imageCache: [String: (image: NSImage, lastAccess: Date)] = [:]
    private static let imageCacheCountLimit = 20
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
        let baseName = initialURL.deletingPathExtension().lastPathComponent
        let ext = initialURL.pathExtension
        var finalURL = initialURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let candidateName = ext.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter).\(ext)"
            finalURL = directory.appendingPathComponent(candidateName)
            counter += 1
        }
        return finalURL
    }

    /// 登録画像名に対応する `images/` 直下の URL。パストラバーサル対策済み。
    private func registeredImageURL(named name: String) -> URL? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        return PathSanitizer.safeURL(name: name, in: imagesDir)
    }

    // MARK: - Validation

    /// 画像ファイルとして読み込め、寸法が上限内かを検証する。
    ///
    /// `NSImage(contentsOf:)` と違い画像全体をデコードしないため、巨大な画像や細工されたファイルでも
    /// メモリを使い果たさない。拡張子ではなく内容から形式を判定する。
    nonisolated static func isValidImageFile(at url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let typeIdentifier = CGImageSourceGetType(source) as String?,
              UTType(typeIdentifier)?.conforms(to: .image) == true,
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return false
        }
        return isAcceptableImageSize(width: width, height: height)
    }

    /// 画像の寸法が登録できる範囲内か。
    nonisolated static func isAcceptableImageSize(width: Int, height: Int) -> Bool {
        width > 0 && height > 0
            && width <= AppConstants.maxImagePixelDimension
            && height <= AppConstants.maxImagePixelDimension
            && width * height <= AppConstants.maxImagePixelCount
    }

    /// `registerImage(_:name:)` の保存名。PNG データを別の拡張子で保存しないよう拡張子を `.png` に揃える。
    nonisolated static func pngFileName(for name: String) -> String? {
        let baseName = PathSanitizer.splitExtension(PathSanitizer.lastPathComponent(of: name)).base
        guard let safeBaseName = PathSanitizer.safeName(from: baseName) else { return nil }
        return safeBaseName + ".png"
    }

    // MARK: - Loading

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
        guard let url = registeredImageURL(named: name) else { return nil }
        return NSImage(contentsOf: url)
    }

    func image(named name: String) -> NSImage? {
        if name == AppConstants.defaultImageName {
            return defaultImage()
        }
        return loadRegisteredImageCached(named: name)
    }

    func loadRegisteredImageCached(named name: String) -> NSImage? {
        guard let url = registeredImageURL(named: name) else { return nil }
        let key = url.lastPathComponent
        if let entry = imageCache[key] {
            imageCache[key] = (image: entry.image, lastAccess: Date())
            logger.debug("Cache hit: \(key)")
            return entry.image
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        if imageCache.count >= Self.imageCacheCountLimit {
            if let lruKey = imageCache.min(
                by: { $0.value.lastAccess < $1.value.lastAccess }
            )?.key {
                imageCache.removeValue(forKey: lruKey)
                logger.debug("Cache eviction: \(lruKey)")
            }
        }
        imageCache[key] = (image: image, lastAccess: Date())
        logger.debug("Cache miss: \(key)")
        return image
    }

    // MARK: - Registration

    /// 外部 URL から画像を `images/` にコピーして登録する。重複名は自動リネームされる。
    ///
    /// シンボリックリンクはリンク先の実体をコピーする。内容が画像でない・寸法が上限を超える場合は登録しない。
    @discardableResult
    func registerImage(from url: URL) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard Self.isSupportedExtension(url.pathExtension) else { return nil }
        guard let name = PathSanitizer.safeName(from: url.lastPathComponent) else { return nil }
        // copyItem はシンボリックリンクをリンクのままコピーするため、実体を解決してから検証・コピーする
        let sourceURL = url.resolvingSymlinksInPath()
        guard Self.isValidImageFile(at: sourceURL) else {
            logger.error("Rejected invalid or oversized image: \(url.lastPathComponent)")
            return nil
        }
        guard let finalURL = uniqueDestinationURL(for: name, in: imagesDir) else { return nil }
        do {
            try FileManager.default.copyItem(at: sourceURL, to: finalURL)
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
    ///
    /// 保存名の拡張子は常に `.png` になる。実際に保存された名前を返すため、呼び出し側はこの戻り値を使うこと。
    @discardableResult
    func registerImage(_ image: NSImage, name: String) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard let fileName = Self.pngFileName(for: name) else { return nil }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let pngData = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            logger.error("Failed to encode image as PNG")
            return nil
        }
        guard let destURL = uniqueDestinationURL(for: fileName, in: imagesDir) else { return nil }
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
        guard let url = registeredImageURL(named: name) else { return }
        let key = url.lastPathComponent
        do {
            try FileManager.default.removeItem(at: url)
            removeFromCache(key)
            imageCache.removeValue(forKey: key)
            NotificationCenter.default.post(
                name: AppConstants.registeredImagesDidChange, object: nil
            )
        } catch {
            logger.error("Failed to remove image: \(error.localizedDescription)")
        }
    }

    // MARK: - Custom Default

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

    /// 外部 URL の画像をカスタムデフォルト画像として設定する。
    ///
    /// `registerImage(from:)` と同じく拡張子・内容・寸法を検証し、シンボリックリンクは実体をコピーする。
    /// - Returns: 設定できたか。失敗時は既存のカスタムデフォルトを保持する。
    @discardableResult
    func setCustomDefault(from url: URL) -> Bool {
        guard let destURL = customDefaultURL else { return false }
        guard Self.isSupportedExtension(url.pathExtension) else { return false }
        let sourceURL = url.resolvingSymlinksInPath()
        guard Self.isValidImageFile(at: sourceURL) else {
            logger.error("Rejected invalid or oversized default image: \(url.lastPathComponent)")
            return false
        }
        let fm = FileManager.default
        let tempURL = destURL.deletingLastPathComponent()
            .appendingPathComponent(".\(destURL.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try fm.copyItem(at: sourceURL, to: tempURL)
            if fm.fileExists(atPath: destURL.path) {
                _ = try fm.replaceItemAt(destURL, withItemAt: tempURL)
            } else {
                try fm.moveItem(at: tempURL, to: destURL)
            }
            cachedDefaultImage = nil
            return true
        } catch {
            try? fm.removeItem(at: tempURL)
            logger.error("Failed to set custom default: \(error.localizedDescription)")
            return false
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
