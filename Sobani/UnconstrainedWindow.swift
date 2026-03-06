import Cocoa

// MARK: - Unconstrained Window

/// NSWindow subclass that completely disables default screen edge constraints.
/// Allows transparent character images to be freely positioned beyond screen edges.
/// Safety is ensured by existing mechanisms:
/// - `WindowStateManager.isPositionVisible()` checks visibility on restore
/// - `WindowStateManager.adjustToVisibleArea()` repositions off-screen windows
/// - `AppDelegate+ScreenRestoration.swift` clamps positions on wake
class UnconstrainedWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
