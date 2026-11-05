import AppKit

// MARK: - ImageWindow + Positioning

extension ImageWindow {
    func centerOnScreen() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        window.setFrameOrigin(
            GeometryUtils.centeredOrigin(size: window.frame.size, in: screen.visibleFrame)
        )
    }

    /// 画像（imageView）基準の原点でウィンドウを配置する。
    ///
    /// `WindowState` の原点は imageView 基準（`WindowStateManager.captureState` と同じ）。
    /// 回転中はウィンドウが回転後のバウンディングボックスになるため、ウィンドウ原点へ変換してから設定する。
    func setImageOrigin(_ imageOrigin: NSPoint) {
        window.setFrameOrigin(Self.windowOrigin(
            forImageOrigin: imageOrigin,
            imageViewSize: imageView.frame.size,
            rotationAngle: imageView.rotationAngle
        ))
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
            imageView.frame.size = newSize
            adjustWindowForRotation()
        }
        setImageOrigin(origin)
        notifyStateDidChange(.position)
        if sizeChanged {
            notifyStateDidChange(.size)
        }
    }
}
