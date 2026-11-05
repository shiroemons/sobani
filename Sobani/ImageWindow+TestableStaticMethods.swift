import Cocoa

// MARK: - Testable Static Methods

extension ImageWindow {
    /// ウィンドウフレームから画像の原点座標を計算
    nonisolated static func imageOrigin(windowFrame: NSRect, imageViewSize: NSSize) -> CGPoint {
        CGPoint(
            x: windowFrame.midX - imageViewSize.width / 2,
            y: windowFrame.midY - imageViewSize.height / 2
        )
    }

    /// 画像原点座標からウィンドウ原点座標を計算（逆変換）
    nonisolated static func windowOrigin(
        forImageOrigin imageOrigin: CGPoint, imageViewSize: NSSize, rotationAngle: CGFloat
    ) -> NSPoint {
        let bbSize = GeometryUtils.rotatedBoundingBox(
            width: imageViewSize.width, height: imageViewSize.height, angleDegrees: rotationAngle
        )
        let centerX = imageOrigin.x + imageViewSize.width / 2
        let centerY = imageOrigin.y + imageViewSize.height / 2
        return NSPoint(x: round(centerX - bbSize.width / 2), y: round(centerY - bbSize.height / 2))
    }

    /// 新規ウィンドウの初期原点（画面中央 + ランダムオフセット）。画面の原点（マルチディスプレイ）も考慮する。
    nonisolated static func spawnOrigin(windowSize: NSSize, screenFrame: NSRect, offset: CGVector) -> NSPoint {
        let centered = GeometryUtils.centeredOrigin(size: windowSize, in: screenFrame)
        return NSPoint(x: centered.x + offset.dx, y: centered.y + offset.dy)
    }

    /// 画像サイズからウィンドウサイズを計算（maxHeight以下にアスペクト比維持で縮小）
    nonisolated static func calculateWindowSize(imageSize: NSSize, maxHeight: CGFloat) -> NSSize {
        let scale = maxHeight / max(imageSize.height, 1)
        return NSSize(width: imageSize.width * scale, height: maxHeight)
    }

    /// baseHeightに基づいてアスペクト比を維持した画像寸法を計算
    nonisolated static func calculateImageDimensions(
        baseHeight: CGFloat, imageSize: NSSize
    ) -> (width: CGFloat, aspectRatio: CGFloat) {
        let baseWidth = imageSize.width * (baseHeight / imageSize.height)
        return (width: baseWidth, aspectRatio: baseWidth / baseHeight)
    }

    /// 高さを min/max にクランプし、縦横比を保った画像サイズを返す。
    nonisolated static func clampedImageSize(
        height: CGFloat, aspectRatio: CGFloat,
        minHeight: CGFloat = AppConstants.minImageHeight,
        maxHeight: CGFloat = AppConstants.maxImageHeight
    ) -> NSSize {
        let clampedHeight = max(minHeight, min(maxHeight, height))
        return NSSize(width: clampedHeight * aspectRatio, height: clampedHeight)
    }

    /// 表示面積を保ったまま新しい縦横比に合わせた画像サイズを返す（高さは min/max にクランプ）。
    ///
    /// クロップの確定・リセットで縦横比が変わったときに使う。縦横比が不正なら nil。
    nonisolated static func areaPreservingImageSize(
        currentSize: NSSize, aspectRatio: CGFloat,
        minHeight: CGFloat = AppConstants.minImageHeight,
        maxHeight: CGFloat = AppConstants.maxImageHeight
    ) -> NSSize? {
        guard aspectRatio > 0, aspectRatio.isFinite else { return nil }
        let area = currentSize.width * currentSize.height
        return clampedImageSize(
            height: sqrt(area / aspectRatio), aspectRatio: aspectRatio,
            minHeight: minHeight, maxHeight: maxHeight
        )
    }

    /// 表示名のローカライズ処理（デフォルト名と一致する場合はローカライズ名を返す）
    nonisolated static func formatLocalizedDisplayName(
        displayName: String, defaultName: String, localizedDefault: String
    ) -> String {
        displayName == defaultName ? localizedDefault : displayName
    }

    /// CGImageAlphaInfoが透明情報を持つかどうかを判定
    nonisolated static func isAlphaInfoTransparent(_ alphaInfo: CGImageAlphaInfo) -> Bool {
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast: return true
        default: return false
        }
    }

}
