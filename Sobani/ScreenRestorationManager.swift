import AppKit
import os.log

// MARK: - Pending Restoration

struct PendingRestoration: Codable, Sendable {
    let windowId: Int
    let originalState: WindowState
    let displayID: CGDirectDisplayID
    let adjustedOriginX: CGFloat
    let adjustedOriginY: CGFloat
    let createdAt: Date
    let screenFrameX: CGFloat?
    let screenFrameY: CGFloat?
    let screenFrameWidth: CGFloat?
    let screenFrameHeight: CGFloat?

    var preSleepScreenFrame: NSRect? {
        guard let x = screenFrameX, let y = screenFrameY,
              let w = screenFrameWidth, let h = screenFrameHeight else { return nil }
        return NSRect(x: x, y: y, width: w, height: h)
    }

    init(windowId: Int, originalState: WindowState, displayID: CGDirectDisplayID,
         adjustedOriginX: CGFloat, adjustedOriginY: CGFloat, createdAt: Date,
         preSleepScreenFrame: NSRect? = nil) {
        self.windowId = windowId
        self.originalState = originalState
        self.displayID = displayID
        self.adjustedOriginX = adjustedOriginX
        self.adjustedOriginY = adjustedOriginY
        self.createdAt = createdAt
        self.screenFrameX = preSleepScreenFrame?.origin.x
        self.screenFrameY = preSleepScreenFrame?.origin.y
        self.screenFrameWidth = preSleepScreenFrame?.size.width
        self.screenFrameHeight = preSleepScreenFrame?.size.height
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        windowId = try container.decode(Int.self, forKey: .windowId)
        originalState = try container.decode(WindowState.self, forKey: .originalState)
        displayID = try container.decode(CGDirectDisplayID.self, forKey: .displayID)
        adjustedOriginX = try container.decode(CGFloat.self, forKey: .adjustedOriginX)
        adjustedOriginY = try container.decode(CGFloat.self, forKey: .adjustedOriginY)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        screenFrameX = try container.decodeIfPresent(CGFloat.self, forKey: .screenFrameX)
        screenFrameY = try container.decodeIfPresent(CGFloat.self, forKey: .screenFrameY)
        screenFrameWidth = try container.decodeIfPresent(CGFloat.self, forKey: .screenFrameWidth)
        screenFrameHeight = try container.decodeIfPresent(CGFloat.self, forKey: .screenFrameHeight)
    }
}

// MARK: - Screen Restoration Manager

@MainActor
final class ScreenRestorationManager {
    private let logger = Logger(
        subsystem: AppConstants.loggerSubsystem,
        category: "ScreenRestorationManager"
    )
    private(set) var pendingRestorations: [PendingRestoration] = []
    private let timeout: TimeInterval
    private let baseDirectory: URL?
    var currentDate: @Sendable () -> Date = { Date() }
    var screenProvider: () -> [ScreenInfo] = { ScreenInfo.current() }

    init(timeout: TimeInterval = 300, baseDirectory: URL? = nil) {
        self.timeout = timeout
        self.baseDirectory = baseDirectory
    }

    var pendingFileURL: URL? {
        guard let appDir = AppSupportDirectory.url(baseDirectory: baseDirectory, logger: logger) else { return nil }
        return appDir.appendingPathComponent("pending_restorations.json")
    }

    var hasPending: Bool {
        return !pendingRestorations.isEmpty
    }

    func addPending(windowId: Int, originalState: WindowState, displayID: CGDirectDisplayID,
                    adjustedOriginX: CGFloat, adjustedOriginY: CGFloat,
                    preSleepScreenFrame: NSRect? = nil) {
        pendingRestorations.removeAll { $0.windowId == windowId }
        let entry = PendingRestoration(
            windowId: windowId,
            originalState: originalState,
            displayID: displayID,
            adjustedOriginX: adjustedOriginX,
            adjustedOriginY: adjustedOriginY,
            createdAt: currentDate(),
            preSleepScreenFrame: preSleepScreenFrame
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
        let screens = screenProvider()
        return pendingRestorations.filter { entry in
            if entry.displayID != AppConstants.unknownDisplayID {
                let matchByID = screens.contains { $0.displayID == entry.displayID }
                if matchByID { return true }
                if let savedFrame = entry.preSleepScreenFrame {
                    let tol = AppConstants.screenMatchTolerance
                    return screens.contains { screen in
                        ScreenRestorationUtils.isFrameMatch(screen.frame, savedFrame, tolerance: tol)
                    }
                }
                return false
            } else {
                return entry.originalState.isPositionVisible(on: screens)
            }
        }
    }

    func clearAll() {
        pendingRestorations.removeAll()
    }

    func savePending() {
        guard let url = pendingFileURL else { return }
        JSONPersistence.save(pendingRestorations, to: url, logger: logger, errorMessage: "Failed to save pending restorations")
    }

    func loadPending() {
        guard let url = pendingFileURL else { return }
        guard let loaded = JSONPersistence.load(
            [PendingRestoration].self,
            from: url,
            logger: logger,
            notFoundMessage: "No pending restorations found",
            errorMessage: "Failed to decode pending restorations"
        ) else { return }
        pendingRestorations = loaded
        purgeExpired()
    }
}
