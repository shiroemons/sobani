import Cocoa

/// スリープ復帰時のウィンドウ復元に必要な状態を集約する構造体
struct WakeRestorationContext {
    var states: [Int: WindowState] = [:]
    var displayIDs: [Int: CGDirectDisplayID] = [:]
    var screenFrames: [CGDirectDisplayID: NSRect] = [:]
    var windowOrigins: [Int: NSPoint] = [:]
    var isActive: Bool = false
    var retryCount: Int = 0

    mutating func clear() {
        self = Self()
    }
}
