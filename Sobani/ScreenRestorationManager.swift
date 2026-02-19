import Foundation

// MARK: - Pending Restoration

struct PendingRestoration {
    let windowId: Int
    let originalState: WindowState
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

    func addPending(windowId: Int, originalState: WindowState, adjustedOriginX: CGFloat, adjustedOriginY: CGFloat) {
        pendingRestorations.removeAll { $0.windowId == windowId }
        let entry = PendingRestoration(
            windowId: windowId,
            originalState: originalState,
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

    func restorableEntries(using isVisible: (WindowState) -> Bool) -> [PendingRestoration] {
        purgeExpired()
        return pendingRestorations.filter { isVisible($0.originalState) }
    }

    func clearAll() {
        pendingRestorations.removeAll()
    }
}
