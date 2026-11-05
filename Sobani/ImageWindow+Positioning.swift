import AppKit

// MARK: - ImageWindow + Positioning

extension ImageWindow {
    func centerOnScreen() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        window.setFrameOrigin(
            GeometryUtils.centeredOrigin(size: window.frame.size, in: screen.visibleFrame)
        )
    }

    /// imageView のスクリーン座標上のフレーム（`WindowState` の原点・サイズと同じ座標系）。
    ///
    /// 回転中はウィンドウが回転後の外接矩形になり、imageView はその中に置かれる。
    var imageFrameInScreen: NSRect {
        imageView.frame.offsetBy(dx: window.frame.minX, dy: window.frame.minY)
    }

    /// 画像（imageView）基準の原点でウィンドウを配置する。
    ///
    /// `WindowState` の原点は imageView 基準（`WindowStateManager.captureState` と同じ）。
    /// 回転中はウィンドウが回転後のバウンディングボックスになるため、画像の中心を基準に配置する。
    func setImageOrigin(_ imageOrigin: NSPoint) {
        let size = imageView.frame.size
        placeImage(center: CGPoint(x: imageOrigin.x + size.width / 2, y: imageOrigin.y + size.height / 2), size: size)
    }

    /// 画像（imageView）基準の原点とサイズで配置する。
    ///
    /// 座標系は `WindowState` / `WindowStateManager.captureState` と同じ（原点 = imageView の
    /// スクリーン座標上の原点、サイズ = imageView のサイズ）。サイズは現在の縦横比を保ち、
    /// 高さを最小・最大値にクランプする。移動は `.position`、サイズ変更は `.size` で通知する。
    func setPositionAndSize(origin: NSPoint, size: NSSize) {
        // NaN/無限大はフレームを壊し、JSON 保存も失敗させるため無視する
        guard origin.x.isFinite, origin.y.isFinite,
              size.width.isFinite, size.height.isFinite else { return }
        let oldSize = imageView.frame.size
        let newSize = Self.clampedImageSize(height: size.height, aspectRatio: imageView.aspectRatio)
        let sizeChanged = !GeometryUtils.isApproximatelyEqual(newSize.width, oldSize.width)
            || !GeometryUtils.isApproximatelyEqual(newSize.height, oldSize.height)
        if sizeChanged {
            adjustWindowForRotation(imageSize: newSize)
        }
        setImageOrigin(origin)
        notifyStateDidChange(.position)
        if sizeChanged {
            notifyStateDidChange(.size)
        }
    }
}
