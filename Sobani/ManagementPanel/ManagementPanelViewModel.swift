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

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        rebuildAll()
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
            windowCountByImageName = [:]
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
        cachedWindowStates = windows.map { $0.toWindowState() }
        visibleWindowCount = windows.filter { !$0.isHidden }.count
    }

    private func rebuildImageCaches() {
        windowCountByImageName = Dictionary(grouping: windows, by: \.imageName).mapValues(\.count)
        var imageDict: [String: NSImage] = [:]
        for window in windows where imageDict[window.imageName] == nil {
            imageDict[window.imageName] = window.originalImage
        }
        cachedWindowImages = imageDict
    }

    private func rebuildAll() {
        rebuildWindows()
        rebuildImageCaches()
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
                self?.rebuildAll()
            }
        }
        imageListObserver = NotificationCenter.default.addObserver(
            forName: AppConstants.registeredImagesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshRegisteredImageNames()
                self?.rebuildImageCaches()
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

}
