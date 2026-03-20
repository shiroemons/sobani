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

    /// キャッシュキーを生成する（画像名 + cropRectの各フィールドをエンコード）
    private static func cacheKey(imageName: String, cropRect: CropRect) -> NSString {
        let x = String(format: "%.6f", cropRect.x)
        let y = String(format: "%.6f", cropRect.y)
        let w = String(format: "%.6f", cropRect.width)
        let h = String(format: "%.6f", cropRect.height)
        let angle = String(format: "%.6f", cropRect.straightenAngle)
        let vPersp = String(format: "%.6f", cropRect.verticalPerspective)
        let hPersp = String(format: "%.6f", cropRect.horizontalPerspective)
        let radiusTopLeft = String(format: "%.6f", cropRect.cornerRadii.topLeft)
        let radiusTopRight = String(format: "%.6f", cropRect.cornerRadii.topRight)
        let radiusBottomLeft = String(format: "%.6f", cropRect.cornerRadii.bottomLeft)
        let radiusBottomRight = String(format: "%.6f", cropRect.cornerRadii.bottomRight)
        let key = "\(imageName)-\(x)-\(y)-\(w)-\(h)"
            + "-\(angle)-\(cropRect.quarterTurns)-\(cropRect.isFlippedInCrop)"
            + "-\(vPersp)-\(hPersp)"
            + "-\(cropRect.shape.rawValue)"
            + "-\(radiusTopLeft)-\(radiusTopRight)-\(radiusBottomLeft)-\(radiusBottomRight)"
        return key as NSString
    }

    /// クロップ済みサムネイル画像を返す。キャッシュがあればキャッシュを返す。
    /// - Parameters:
    ///   - image: 元画像
    ///   - cropRect: 適用するクロップ設定（nil または identity の場合は元画像をそのまま返す）
    ///   - imageName: キャッシュキーに使用する画像名
    static func croppedImage(
        from image: NSImage,
        cropRect: CropRect?,
        imageName: String
    ) -> NSImage {
        // クロップなし、またはフル画像と同等の場合は元画像を返す
        guard let cropRect, !cropRect.isEffectivelyEqual(to: .full) else {
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

        guard let croppedCG = CropImageProcessor.applyFullCrop(
            to: cgImage, cropRect: cropRect
        ) else {
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
