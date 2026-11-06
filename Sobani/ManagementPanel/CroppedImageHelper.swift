import AppKit
import os

enum CroppedImageHelper {
    /// サムネイルの長辺の上限（ピクセル）。管理パネルのプレビュー（最大 300pt）を Retina で表示できる大きさ
    private static let thumbnailMaxPixelSize: CGFloat = 1024
    private static let cacheCountLimit = 100
    /// キャッシュ全体の上限（バイト）。コストには各サムネイルのビットマップサイズを使う
    private static let cacheTotalCostLimit = 128 * 1024 * 1024

    /// キャッシュキー。画像名・その画像名の世代・クロップ設定の組で引く
    private struct CacheKey: Hashable {
        let imageName: String
        let generation: Int
        let cropRect: CropRect
    }

    /// `NSCache` のキーはオブジェクトである必要があるため、`CacheKey` を値で比較できる箱に入れる
    private final class CacheKeyBox: NSObject {
        let key: CacheKey

        init(_ key: CacheKey) {
            self.key = key
        }

        override var hash: Int { key.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            (object as? CacheKeyBox)?.key == key
        }
    }

    // NSCache is thread-safe internally; nonisolated(unsafe) suppresses Swift 6 Sendable warning.
    // External synchronisation is provided by NSCache's own locking.
    private nonisolated(unsafe) static let cache: NSCache<CacheKeyBox, NSImage> = {
        let cache = NSCache<CacheKeyBox, NSImage>()
        cache.countLimit = cacheCountLimit
        cache.totalCostLimit = cacheTotalCostLimit
        return cache
    }()

    /// 画像名ごとの世代。`invalidateCache(forImageNamed:)` で進めると、その画像名の古いエントリは引かれなくなる。
    /// `NSCache` はキーを列挙できないため個別削除の代わりに使う（古いエントリは上限に応じて自然に破棄される）
    private static let generations = OSAllocatedUnfairLock(initialState: [String: Int]())

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
        let generation = generations.withLock { $0[imageName, default: 0] }
        let key = CacheKeyBox(CacheKey(imageName: imageName, generation: generation, cropRect: cropRect))
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // CGImage に変換してフルパイプラインを適用（サムネイルなので縮小しながら 1 回で描画する）
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        guard let croppedCG = CropImageProcessor.applyFullCrop(
            to: cgImage, cropRect: cropRect, maxOutputPixelSize: thumbnailMaxPixelSize
        ) else {
            return image
        }

        let result = NSImage(
            cgImage: croppedCG,
            size: NSSize(width: croppedCG.width, height: croppedCG.height)
        )

        cache.setObject(result, forKey: key, cost: croppedCG.bytesPerRow * croppedCG.height)

        return result
    }

    /// 指定した画像名のキャッシュだけを無効にする（同じ名前で画像の内容が変わったとき用）
    static func invalidateCache(forImageNamed imageName: String) {
        generations.withLock { $0[imageName, default: 0] += 1 }
    }

    /// キャッシュをすべて破棄する
    static func invalidateCache() {
        cache.removeAllObjects()
    }
}
