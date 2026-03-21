import Cocoa

// MARK: - Unconstrained Window

/// NSWindow subclass that completely disables default screen edge constraints.
/// Allows transparent images to be freely positioned beyond screen edges.
/// Safety is ensured by existing mechanisms:
/// - `WindowState.isPositionVisible()` checks visibility on restore
/// - `WindowState.adjustedToVisibleArea()` repositions off-screen windows
/// - `AppDelegate+ScreenRestoration.swift` clamps positions on wake
@MainActor
final class UnconstrainedWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
