import AppKit

// swiftlint:disable legacy_objc_type
enum CroppedImageHelper {
    // NSCache is thread-safe internally; nonisolated(unsafe) suppresses Swift 6 Sendable warning.
    // External synchronisation is provided by NSCache's own locking.
    private nonisolated(unsafe) static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 100
        return cache
    }()

    /// フル画像（クロップなし）と同等かどうかを判定する
    private static func isIdentityCrop(_ cropRect: CropRect) -> Bool {
        let tol = AppConstants.floatingPointTolerance
        return abs(cropRect.x) < tol
            && abs(cropRect.y) < tol
            && abs(cropRect.width - 1.0) < tol
            && abs(cropRect.height - 1.0) < tol
            && abs(cropRect.straightenAngle) < tol
            && cropRect.quarterTurns == 0
            && !cropRect.isFlippedInCrop
            && abs(cropRect.verticalPerspective) < tol
            && abs(cropRect.horizontalPerspective) < tol
            && cropRect.shape == .rectangle
    }

    /// キャッシュキーを生成する（画像名 + cropRectの各フィールドをエンコード）
    private static func cacheKey(imageName: String, cropRect: CropRect) -> NSString {
        let key = "\(imageName)-\(cropRect.x)-\(cropRect.y)-\(cropRect.width)-\(cropRect.height)"
            + "-\(cropRect.straightenAngle)-\(cropRect.quarterTurns)-\(cropRect.isFlippedInCrop)"
            + "-\(cropRect.verticalPerspective)-\(cropRect.horizontalPerspective)"
            + "-\(cropRect.shape.rawValue)-\(cropRect.cornerRadii.topLeft)"
            + "-\(cropRect.cornerRadii.topRight)-\(cropRect.cornerRadii.bottomLeft)"
            + "-\(cropRect.cornerRadii.bottomRight)"
        return key as NSString
    }

    /// クロップ済みサムネイル画像を返す。キャッシュがあればキャッシュを返す。
    /// - Parameters:
    ///   - image: 元画像
    ///   - cropRect: 適用するクロップ設定（nil または identity の場合は元画像をそのまま返す）
    ///   - imageName: キャッシュキーに使用する画像名
    static func croppedImage(from image: NSImage, cropRect: CropRect?, imageName: String) -> NSImage {
        // クロップなし、またはフル画像と同等の場合は元画像を返す
        guard let cropRect, !isIdentityCrop(cropRect) else {
            return image
        }

        // キャッシュを確認
        let key = cacheKey(imageName: imageName, cropRect: cropRect)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // CGImage に変換してフルパイプラインを適用
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        guard let croppedCG = CropImageProcessor.applyFullCrop(to: cgImage, cropRect: cropRect) else {
            return image
        }

        let result = NSImage(
            cgImage: croppedCG,
            size: NSSize(width: croppedCG.width, height: croppedCG.height)
        )

        cache.setObject(result, forKey: key)

        return result
    }

    /// キャッシュをすべて破棄する
    static func invalidateCache() {
        cache.removeAllObjects()
    }
}
// swiftlint:enable legacy_objc_type
