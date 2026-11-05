import AppKit

// MARK: - ImageWindow + Positioning

extension ImageWindow {
    /// 画像を今いる画面（なければメイン画面）の可視領域の中央に置く。
    ///
    /// UI 操作のため `.position` を通知する（通知しないと起動時・スリープ復帰の復元で元の位置に戻される）。
    func centerOnScreen() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        placeImage(center: CGPoint(x: visibleFrame.midX, y: visibleFrame.midY), size: imageView.frame.size)
        notifyStateDidChange(.position)
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
    ///
    /// 状態変更を通知しない、復元処理向けの低レベルな配置。ユーザー操作による移動は
    /// `setPositionAndSize(origin:size:)` を使うこと（`.position` を通知しないと復元処理に位置を戻される）。
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
        // サイズが変わらないときは現在のサイズのまま置く（縦横比から計算し直した幅の誤差で大きさを変えない）
        let placedSize = sizeChanged ? newSize : oldSize
        placeImage(
            center: CGPoint(x: origin.x + placedSize.width / 2, y: origin.y + placedSize.height / 2),
            size: placedSize
        )
        notifyStateDidChange(.position)
        if sizeChanged {
            notifyStateDidChange(.size)
        }
    }
}
