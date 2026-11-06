import AppKit

extension NSPanel {
    /// Sobaniのフローティングパネル共通設定を適用
    func configureForFloating() {
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    /// 対象ウィンドウの横に付属パネルを置くときの原点を計算する。
    ///
    /// 右側に収まらなければ左側、それでも収まらなければ画面中央に置き、縦方向は可視領域にクランプする。
    static func auxiliaryPanelOrigin(
        near windowFrame: NSRect,
        panelSize: NSSize,
        gap: CGFloat,
        screenFrame: NSRect
    ) -> NSPoint {
        var x = windowFrame.maxX + gap
        var y = windowFrame.midY - panelSize.height / 2

        if x + panelSize.width > screenFrame.maxX {
            x = windowFrame.minX - panelSize.width - gap
        }
        if x < screenFrame.minX {
            x = screenFrame.midX - panelSize.width / 2
        }
        y = max(screenFrame.minY, min(y, screenFrame.maxY - panelSize.height))

        return NSPoint(x: x, y: y)
    }

    /// `window` が表示されている画面（なければメイン画面）の可視領域を基準に付属パネルの原点を計算する。
    @MainActor
    static func auxiliaryPanelOrigin(near window: NSWindow, panelSize: NSSize, gap: CGFloat) -> NSPoint {
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        return auxiliaryPanelOrigin(
            near: window.frame, panelSize: panelSize, gap: gap, screenFrame: screenFrame
        )
    }
}
