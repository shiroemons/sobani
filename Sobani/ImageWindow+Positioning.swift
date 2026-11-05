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
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
