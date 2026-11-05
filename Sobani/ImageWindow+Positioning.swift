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

    func setPositionAndSize(origin: NSPoint, size: NSSize) {
        // NaN/無限大はフレームを壊し、JSON 保存も失敗させるため無視する
        guard origin.x.isFinite, origin.y.isFinite,
              size.width.isFinite, size.height.isFinite else { return }
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
