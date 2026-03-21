import AppKit
import Observation

@MainActor @Observable
final class ManagementPanelViewModel {
    private(set) weak var appDelegate: AppDelegate?
    var selectedTab: ManagementTab? = .images
    var selectedWindowIds: Set<Int> = []
    var selectedRegisteredImageName: String?
    private(set) var windows: [WindowInfo] = []
    private(set) var registeredImageNames: [String] = []
    private(set) var windowCountByImageName: [String: Int] = [:]
    var windowStates: [WindowState] { windows.map { $0.toWindowState() } }
    private(set) var windowImages: [String: NSImage] = [:]
    var visibleWindowCount: Int { windows.lazy.filter { !$0.isHidden }.count }
    private(set) var languageRefreshId = UUID()
    nonisolated(unsafe) private var stateObserver: Any?
    nonisolated(unsafe) private var listObserver: Any?
    nonisolated(unsafe) private var imageListObserver: Any?
    nonisolated(unsafe) private var languageObserver: Any?
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
        static let topTabs: [Self] = [.images, .layouts, .registeredImages]
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
        if let languageObserver { NotificationCenter.default.removeObserver(languageObserver) }
    }

    // MARK: - Window List

    private func rebuildWindows() {
        guard let appDelegate else {
            windows = []
            windowImages = [:]
            windowCountByImageName = [:]
            return
        }
        let newWindows = appDelegate.zOrderedWindows.map { imageWindow in
            let imageSize = imageWindow.imageView.frame.size
            let screenName = imageWindow.window.screen?.localizedName ?? L("image.unknown")
            let dims = FormatUtils.formatDimensions(
                width: imageSize.width, height: imageSize.height)
            let subtitle = "\(dims) ・ \(screenName)"
            let thumbnail = imageWindow.imageView.image
            let frame = imageWindow.window.frame
            return WindowInfo(
                windowId: imageWindow.windowId,
                displayName: imageWindow.localizedDisplayName,
                subtitle: subtitle,
                isHidden: imageWindow.isHidden,
                isGhostMode: imageWindow.isGhostMode,
                opacityLevel: imageWindow.imageView.opacityLevel,
                thumbnail: thumbnail,
                originalImage: imageWindow.imageView.originalImage,
                cropRect: imageWindow.imageView.cropRect,
                customGhostAlpha: imageWindow.customGhostAlpha,
                effectiveGhostAlpha: imageWindow.effectiveGhostAlpha,
                isRemoveBackgroundEnabled: imageWindow.isRemoveBackgroundAvailable,
                originX: frame.origin.x,
                originY: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height,
                imageName: imageWindow.displayName,
                isFlippedHorizontally: imageWindow.imageView.isFlippedHorizontally,
                rotationAngle: imageWindow.imageView.rotationAngle
            )
        }
        if newWindows != windows {
            windows = newWindows
        }
    }

    private func rebuildImageCaches() {
        windowCountByImageName = Dictionary(grouping: windows, by: \.imageName).mapValues(\.count)
        var imageDict: [String: NSImage] = [:]
        for window in windows where imageDict[window.imageName] == nil {
            imageDict[window.imageName] = window.originalImage ?? window.thumbnail
        }
        windowImages = imageDict
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
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.setHidden(!imageWindow.isHidden)
        // notifyStateDidChange fires via ImageWindow.setHidden
        // → triggerRefresh handled by observer
    }

    func toggleGhostMode(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.setGhostMode(!imageWindow.isGhostMode)
        // notifyStateDidChange fires via ImageWindow.setGhostMode
        // → triggerRefresh handled by observer
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

    private func performBatchUpdate(_ action: (ImageWindow) -> Void) {
        guard let appDelegate else { return }
        isBatchUpdating = true
        defer { isBatchUpdating = false }
        appDelegate.zOrderedWindows.forEach(action)
        triggerRefresh()
    }

    // MARK: - Detail View Operations

    func changeOpacity(windowId: Int, opacity: CGFloat) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.applyOpacity(opacity)
        // applyOpacity fires notifyStateDidChange → triggerRefresh handled by observer
    }

    func changeBulkOpacity(opacity: CGFloat) {
        isBatchUpdating = true
        defer { isBatchUpdating = false }
        targetWindows.forEach { $0.applyOpacity(opacity) }
        triggerRefresh()
    }

    func changePositionAndSize(windowId: Int, origin: CGPoint, size: CGSize) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.setPositionAndSize(origin: origin, size: size)
        triggerRefresh()
    }

    /// ドラッグ中: setFrame のみ（軽量、triggerRefresh なし）
    func moveWindowWithoutRefresh(windowId: Int, origin: CGPoint) {
        applyWindowPosition(windowId: windowId, origin: origin)
    }

    /// ドラッグ完了: setFrame + triggerRefresh で状態同期
    func moveWindowAndRefresh(windowId: Int, origin: CGPoint) {
        applyWindowPosition(windowId: windowId, origin: origin)
        triggerRefresh()
    }

    private func applyWindowPosition(windowId: Int, origin: CGPoint) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.setPositionAndSize(origin: origin, size: imageWindow.window.frame.size)
    }

    // MARK: - Private Helpers

    private func setupNotificationObservers() {
        stateObserver = NotificationCenter.default.addObserver(
            forName: AppConstants.imageWindowStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.triggerRefresh()
            }
        }
        listObserver = NotificationCenter.default.addObserver(
            forName: AppConstants.imageWindowListDidChange,
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
                CroppedImageHelper.invalidateCache()
                if !(self?.windows.isEmpty ?? true) { self?.rebuildImageCaches() }
            }
        }
        languageObserver = NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.languageRefreshId = UUID()
            }
        }
    }

    /// Rebuilds window state from the current `zOrderedWindows` snapshot.
    /// Intentionally calls only `rebuildWindows()` — not `rebuildImageCaches()` — because
    /// image identity does not change during state-only updates
    /// (position, opacity, ghost mode, etc.).
    /// Image caches are rebuilt via `rebuildAll()`,
    /// which is triggered by `imageWindowListDidChange`.
    func triggerRefresh() {
        guard !isBatchUpdating else { return }
        rebuildWindows()
    }

    func findImageWindow(by windowId: Int) -> ImageWindow? {
        appDelegate?.zOrderedWindows.first { $0.windowId == windowId }
    }

    /// Returns the target windows for bulk operations.
    /// If windows are selected, returns only the selected ones.
    /// If no windows are selected, returns all windows.
    private var targetWindows: [ImageWindow] {
        guard let appDelegate else { return [] }
        if selectedWindowIds.isEmpty {
            return appDelegate.zOrderedWindows
        }
        return appDelegate.zOrderedWindows.filter { selectedWindowIds.contains($0.windowId) }
    }

}
