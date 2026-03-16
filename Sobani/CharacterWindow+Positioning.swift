import AppKit

// MARK: - CharacterWindow + Positioning

extension CharacterWindow {
    func centerOnScreen() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let newOrigin = NSPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
        window.setFrameOrigin(newOrigin)
    }

    func setPositionAndSize(origin: NSPoint, size: NSSize) {
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
