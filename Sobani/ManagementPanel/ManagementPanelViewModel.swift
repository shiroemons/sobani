import AppKit
import Observation

@MainActor @Observable
final class ManagementPanelViewModel {
    weak var appDelegate: AppDelegate?
    var selectedTab: ManagementTab? = .images
    var selectedWindowIds: Set<Int> = []
    var selectedRegisteredImageName: String?
    private(set) var windows: [WindowInfo] = []
    private(set) var registeredImageNames: [String] = []
    private(set) var windowCountByImageName: [String: Int] = [:]
    private(set) var cachedWindowStates: [WindowState] = []
    private(set) var cachedWindowImages: [String: NSImage] = [:]
    private(set) var visibleWindowCount: Int = 0
    nonisolated(unsafe) private var stateObserver: Any?
    nonisolated(unsafe) private var listObserver: Any?
    nonisolated(unsafe) private var imageListObserver: Any?
    private var isBatchUpdating = false

    enum ManagementTab: String, CaseIterable, Identifiable {
        case images
        case layouts
        case registeredImages
        case settings

        var id: String { rawValue }

        var label: String {
            switch self {
            case .images: return L("management.images")
            case .layouts: return L("management.layout")
            case .registeredImages: return L("management.registered_images")
            case .settings: return L("management.settings")
            }
        }

        var iconName: String {
            switch self {
            case .images: return "photo.on.rectangle"
            case .layouts: return "rectangle.3.group"
            case .registeredImages: return "photo.stack"
            case .settings: return "gearshape"
            }
        }

        /// 設定以外のタブ（サイドバー上部に表示）
        static var topTabs: [Self] {
            [.images, .layouts, .registeredImages]
        }
    }

    // MARK: - Window Info (snapshot for SwiftUI)

    struct WindowInfo: Identifiable, Hashable {
        let windowId: Int
        var id: Int { windowId }
        let displayName: String
        let subtitle: String
        let isHidden: Bool
        let isGhostMode: Bool
        let opacityLevel: CGFloat
        let thumbnail: NSImage?
        let originalImage: NSImage?
        let cropRect: CropRect?
        let customGhostAlpha: CGFloat?
        let effectiveGhostAlpha: CGFloat
        let isRemoveBackgroundEnabled: Bool
        let originX: CGFloat
        let originY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let imageName: String
        let isFlippedHorizontally: Bool

        func hash(into hasher: inout Hasher) {
            hasher.combine(windowId)
            hasher.combine(isHidden)
            hasher.combine(isGhostMode)
            hasher.combine(opacityLevel)
            hasher.combine(customGhostAlpha)
            hasher.combine(effectiveGhostAlpha)
            hasher.combine(isRemoveBackgroundEnabled)
            hasher.combine(originX)
            hasher.combine(originY)
            hasher.combine(width)
            hasher.combine(height)
            hasher.combine(imageName)
            hasher.combine(isFlippedHorizontally)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.windowId == rhs.windowId
                && lhs.isHidden == rhs.isHidden
                && lhs.isGhostMode == rhs.isGhostMode
                && lhs.opacityLevel == rhs.opacityLevel
                && lhs.displayName == rhs.displayName
                && lhs.customGhostAlpha == rhs.customGhostAlpha
                && lhs.effectiveGhostAlpha == rhs.effectiveGhostAlpha
                && lhs.cropRect == rhs.cropRect
                && lhs.isRemoveBackgroundEnabled == rhs.isRemoveBackgroundEnabled
                && lhs.originX == rhs.originX
                && lhs.originY == rhs.originY
                && lhs.width == rhs.width
                && lhs.height == rhs.height
                && lhs.imageName == rhs.imageName
                && lhs.isFlippedHorizontally == rhs.isFlippedHorizontally
        }

        func toWindowState() -> WindowState {
            WindowState(
                imageName: imageName,
                originX: originX,
                originY: originY,
                width: width,
                height: height,
                isFlippedHorizontally: isFlippedHorizontally,
                opacityLevel: opacityLevel,
                windowId: windowId,
                cropRect: cropRect,
                isGhostMode: isGhostMode,
                customGhostAlpha: customGhostAlpha,
                isHidden: isHidden
            )
        }
    }

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        rebuildWindows()
        refreshRegisteredImageNames()
        setupNotificationObservers()
    }

    deinit {
        if let stateObserver { NotificationCenter.default.removeObserver(stateObserver) }
        if let listObserver { NotificationCenter.default.removeObserver(listObserver) }
        if let imageListObserver { NotificationCenter.default.removeObserver(imageListObserver) }
    }

    // MARK: - Window List

    private func rebuildWindows() {
        guard let appDelegate else {
            windows = []
            cachedWindowStates = []
            cachedWindowImages = [:]
            visibleWindowCount = 0
            return
        }
        windows = appDelegate.zOrderedWindows.map { charWindow in
            let imageSize = charWindow.imageView.frame.size
            let screenName = charWindow.window.screen?.localizedName ?? L("image.unknown")
            let subtitle = "\(Int(imageSize.width))×\(Int(imageSize.height)) px ・ \(screenName)"
            let thumbnail = charWindow.imageView.image
            let frame = charWindow.window.frame
            return WindowInfo(
                windowId: charWindow.windowId,
                displayName: charWindow.localizedDisplayName,
                subtitle: subtitle,
                isHidden: charWindow.isHidden,
                isGhostMode: charWindow.isGhostMode,
                opacityLevel: charWindow.imageView.opacityLevel,
                thumbnail: thumbnail,
                originalImage: charWindow.imageView.originalImage,
                cropRect: charWindow.imageView.cropRect,
                customGhostAlpha: charWindow.customGhostAlpha,
                effectiveGhostAlpha: charWindow.effectiveGhostAlpha,
                isRemoveBackgroundEnabled: charWindow.isRemoveBackgroundAvailable,
                originX: frame.origin.x,
                originY: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height,
                imageName: charWindow.displayName,
                isFlippedHorizontally: charWindow.imageView.isFlippedHorizontally
            )
        }
        windowCountByImageName = Dictionary(grouping: windows, by: \.imageName).mapValues(\.count)
        cachedWindowStates = windows.map { $0.toWindowState() }
        var imageDict: [String: NSImage] = [:]
        for window in windows where imageDict[window.imageName] == nil {
            imageDict[window.imageName] = window.originalImage
        }
        cachedWindowImages = imageDict
        visibleWindowCount = windows.filter { !$0.isHidden }.count
    }

    private func refreshRegisteredImageNames() {
        let newNames = ImageManager.shared.registeredImageNames()
        if newNames != registeredImageNames {
            registeredImageNames = newNames
        }
    }

    // MARK: - Window Operations

    func toggleHidden(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.setHidden(!charWindow.isHidden)
        // notifyStateDidChange fires via CharacterWindow.setHidden → triggerRefresh handled by observer
    }

    func toggleGhostMode(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.setGhostMode(!charWindow.isGhostMode)
        // notifyStateDidChange fires via CharacterWindow.setGhostMode → triggerRefresh handled by observer
    }

    // MARK: - Bulk Operations

    func showAllWindows() {
        performBatchUpdate { $0.setHidden(false) }
    }

    func hideAllWindows() {
        performBatchUpdate { $0.setHidden(true) }
    }

    func ghostAllWindows() {
        performBatchUpdate { $0.setGhostMode(true) }
    }

    func unghostAllWindows() {
        performBatchUpdate { $0.setGhostMode(false) }
    }

    private func performBatchUpdate(_ action: (CharacterWindow) -> Void) {
        guard let appDelegate else { return }
        isBatchUpdating = true
        defer { isBatchUpdating = false }
        appDelegate.zOrderedWindows.forEach(action)
        triggerRefresh()
    }

    // MARK: - Detail View Operations

    func changeOpacity(windowId: Int, opacity: CGFloat) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.applyOpacity(opacity)
        // applyOpacity fires notifyStateDidChange → triggerRefresh handled by observer
    }

    func changeBulkOpacity(opacity: CGFloat) {
        targetWindows.forEach { $0.applyOpacity(opacity) }
        // Each applyOpacity fires notifyStateDidChange → triggerRefresh handled by observer
    }

    func changePositionAndSize(windowId: Int, origin: CGPoint, size: CGSize) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        let newFrame = NSRect(origin: origin, size: size)
        charWindow.window.setFrame(newFrame, display: true)
        triggerRefresh()
    }

    // MARK: - Window Management

    func deleteWindows(windowIds: Set<Int>) {
        guard let appDelegate else { return }
        let windowsToDelete = appDelegate.zOrderedWindows.filter { windowIds.contains($0.windowId) }
        for charWindow in windowsToDelete {
            removeCharacterWindow(charWindow)
        }
        selectedWindowIds.subtract(windowIds)
    }

    func duplicateWindow(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        appDelegate?.createNewWindow(imageName: charWindow.displayName)
    }

    func centerWindow(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        guard let screen = charWindow.window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = charWindow.window.frame.size
        let newOrigin = CGPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
        charWindow.window.setFrameOrigin(newOrigin)
        triggerRefresh()
    }

    func moveWindows(from source: IndexSet, to destination: Int) {
        guard let appDelegate else { return }
        var windows = appDelegate.zOrderedWindows
        windows.move(fromOffsets: source, toOffset: destination)
        appDelegate.zOrderedWindows = windows
        appDelegate.applyZOrderToWindows()
        triggerRefresh()
    }

    private func removeCharacterWindow(_ charWindow: CharacterWindow) {
        guard let appDelegate else { return }
        charWindow.window.orderOut(nil)
        appDelegate.removeCharacterWindow(charWindow)
        appDelegate.quitIfNoWindows()
    }

    // MARK: - Private Helpers

    private func setupNotificationObservers() {
        stateObserver = NotificationCenter.default.addObserver(
            forName: AppConstants.characterWindowStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.triggerRefresh()
            }
        }
        listObserver = NotificationCenter.default.addObserver(
            forName: AppConstants.characterWindowListDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.triggerRefresh()
            }
        }
        imageListObserver = NotificationCenter.default.addObserver(
            forName: AppConstants.registeredImagesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshRegisteredImageNames()
            }
        }
    }

    func triggerRefresh() {
        guard !isBatchUpdating else { return }
        rebuildWindows()
    }

    func findCharacterWindow(by windowId: Int) -> CharacterWindow? {
        appDelegate?.zOrderedWindows.first { $0.windowId == windowId }
    }

    /// Returns the target windows for bulk operations.
    /// If windows are selected, returns only the selected ones.
    /// If no windows are selected, returns all windows.
    private var targetWindows: [CharacterWindow] {
        guard let appDelegate else { return [] }
        if selectedWindowIds.isEmpty {
            return appDelegate.zOrderedWindows
        }
        return appDelegate.zOrderedWindows.filter { selectedWindowIds.contains($0.windowId) }
    }

    // MARK: - Layout Delegate Methods

    func captureCurrentWindowStates() -> [WindowState]? {
        appDelegate?.captureCurrentWindowStates()
    }

    func applyLayout(_ preset: LayoutPreset) {
        appDelegate?.applyLayout(preset)
    }

    func createNewLayout(name: String) {
        appDelegate?.createNewLayout(name: name)
    }
}
