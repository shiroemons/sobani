import AppKit

// MARK: - Pending Restoration

struct PendingRestoration {
    let windowId: Int
    let originalState: WindowState
    let displayID: CGDirectDisplayID
    let adjustedOriginX: CGFloat
    let adjustedOriginY: CGFloat
    let createdAt: Date
}

// MARK: - Screen Restoration Manager

class ScreenRestorationManager {
    private(set) var pendingRestorations: [PendingRestoration] = []
    private let timeout: TimeInterval
    var currentDate: () -> Date = { Date() }

    init(timeout: TimeInterval = 300) {
        self.timeout = timeout
    }

    var hasPending: Bool {
        return !pendingRestorations.isEmpty
    }

    func addPending(windowId: Int, originalState: WindowState, displayID: CGDirectDisplayID,
                    adjustedOriginX: CGFloat, adjustedOriginY: CGFloat) {
        pendingRestorations.removeAll { $0.windowId == windowId }
        let entry = PendingRestoration(
            windowId: windowId,
            originalState: originalState,
            displayID: displayID,
            adjustedOriginX: adjustedOriginX,
            adjustedOriginY: adjustedOriginY,
            createdAt: currentDate()
        )
        pendingRestorations.append(entry)
    }

    func removePending(windowId: Int) {
        pendingRestorations.removeAll { $0.windowId == windowId }
    }

    func purgeExpired() {
        let now = currentDate()
        pendingRestorations.removeAll { now.timeIntervalSince($0.createdAt) > timeout }
    }

    func restorableEntries() -> [PendingRestoration] {
        purgeExpired()
        return pendingRestorations.filter { entry in
            if entry.displayID != 0 {
                // displayIDが既知: モニターIDで判定
                return NSScreen.screens.contains { screen in
                    (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                        as? CGDirectDisplayID) == entry.displayID
                }
            } else {
                // displayIDが不明（スリープなし切断）: 元の位置が現在可視かどうかで判定
                return WindowStateManager.isPositionVisible(entry.originalState)
            }
        }
    }

    func clearAll() {
        pendingRestorations.removeAll()
    }
}
