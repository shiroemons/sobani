import AppKit
import Observation
import os.log

@MainActor @Observable
final class ManagementPanelViewModel {
    private let logger = Logger(category: "ManagementPanelViewModel")
    weak var appDelegate: AppDelegate?
    var selectedTab: ManagementTab? = .images
    var searchText: String = ""
    var selectedWindowIds: Set<Int> = []
    private(set) var windows: [WindowInfo] = []

    enum ManagementTab: String, CaseIterable, Identifiable {
        case images
        case layouts
        case settings

        var id: String { rawValue }

        var label: String {
            switch self {
            case .images: return L("management.images")
            case .layouts: return L("management.layout")
            case .settings: return L("management.settings")
            }
        }

        var iconName: String {
            switch self {
            case .images: return "photo.on.rectangle"
            case .layouts: return "rectangle.3.group"
            case .settings: return "gearshape"
            }
        }

        /// 設定以外のタブ（サイドバー上部に表示）
        static var topTabs: [Self] {
            [.images, .layouts]
        }
    }

    // MARK: - Window Info (snapshot for SwiftUI)

    struct WindowInfo: Identifiable, Hashable {
        let id: Int
        let windowId: Int
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

        func hash(into hasher: inout Hasher) {
            hasher.combine(windowId)
            hasher.combine(isHidden)
            hasher.combine(isGhostMode)
            hasher.combine(opacityLevel)
            hasher.combine(customGhostAlpha)
            hasher.combine(effectiveGhostAlpha)
            hasher.combine(isRemoveBackgroundEnabled)
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
        }
    }

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        rebuildWindows()
    }

    // MARK: - Window List

    private func rebuildWindows() {
        guard let appDelegate else {
            windows = []
            return
        }
        windows = appDelegate.zOrderedWindows.map { charWindow in
            let imageSize = charWindow.imageView.frame.size
            let screenName = charWindow.window.screen?.localizedName ?? L("image.unknown")
            let subtitle = "\(Int(imageSize.width))×\(Int(imageSize.height)) px ・ \(screenName)"
            let thumbnail = charWindow.imageView.image
            return WindowInfo(
                id: charWindow.windowId,
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
                isRemoveBackgroundEnabled: charWindow.isRemoveBackgroundAvailable
            )
        }
    }

    var filteredWindows: [WindowInfo] {
        if searchText.isEmpty {
            return windows
        }
        return windows.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Window Operations

    func toggleHidden(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.setHidden(!charWindow.isHidden)
        triggerRefresh()
    }

    func toggleGhostMode(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.setGhostMode(!charWindow.isGhostMode)
        triggerRefresh()
    }

    // MARK: - Bulk Operations

    func showAllWindows() {
        guard let appDelegate else { return }
        appDelegate.zOrderedWindows.forEach { $0.setHidden(false) }
        triggerRefresh()
    }

    func hideAllWindows() {
        guard let appDelegate else { return }
        appDelegate.zOrderedWindows.forEach { $0.setHidden(true) }
        triggerRefresh()
    }

    func ghostAllWindows() {
        guard let appDelegate else { return }
        appDelegate.zOrderedWindows.forEach { $0.setGhostMode(true) }
        triggerRefresh()
    }

    func unghostAllWindows() {
        guard let appDelegate else { return }
        appDelegate.zOrderedWindows.forEach { $0.setGhostMode(false) }
        triggerRefresh()
    }

    // MARK: - Image Addition

    func addImageFromFile() {
        let panel = ImageFileDialog.makeOpenPanel(message: L("file.select_new_image_message"))
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let savedName = ImageManager.shared.registerImage(from: url) {
                    appDelegate?.createNewWindow(imageName: savedName)
                }
            }
        }
    }

    // MARK: - Detail View Operations

    func changeOpacity(windowId: Int, opacity: CGFloat) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.applyOpacity(opacity)
        triggerRefresh()
    }

    func changeBulkOpacity(opacity: CGFloat) {
        targetWindows.forEach { $0.applyOpacity(opacity) }
        triggerRefresh()
    }

    func changePositionAndSize(windowId: Int, origin: CGPoint, size: CGSize) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        let newFrame = NSRect(origin: origin, size: size)
        charWindow.window.setFrame(newFrame, display: true)
        triggerRefresh()
    }

    func findWindow(by windowId: Int) -> CharacterWindow? {
        findCharacterWindow(by: windowId)
    }

    // MARK: - Window Management

    func deleteWindows(windowIds: Set<Int>) {
        guard let appDelegate else { return }
        let windowsToDelete = appDelegate.zOrderedWindows.filter { windowIds.contains($0.windowId) }
        for charWindow in windowsToDelete {
            removeCharacterWindow(charWindow)
        }
        selectedWindowIds.subtract(windowIds)
        triggerRefresh()
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
    }

    func moveWindows(from source: IndexSet, to destination: Int) {
        guard let appDelegate else { return }
        var windows = appDelegate.zOrderedWindows
        windows.move(fromOffsets: source, toOffset: destination)
        appDelegate.zOrderedWindows = windows
        appDelegate.applyZOrderToWindows()
        triggerRefresh()
    }

    func moveWindow(fromIndex: Int, toIndex: Int) {
        guard let appDelegate else { return }
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < appDelegate.zOrderedWindows.count,
              toIndex >= 0, toIndex <= appDelegate.zOrderedWindows.count else { return }
        let window = appDelegate.zOrderedWindows.remove(at: fromIndex)
        let adjustedIndex = toIndex > fromIndex ? toIndex - 1 : toIndex
        appDelegate.zOrderedWindows.insert(window, at: adjustedIndex)
        appDelegate.applyZOrderToWindows()
        triggerRefresh()
    }

    // MARK: - Ghost Mode Custom Opacity

    func setCustomGhostAlpha(windowId: Int, alpha: CGFloat) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.setCustomGhostAlpha(alpha)
        triggerRefresh()
    }

    func clearCustomGhostAlpha(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.setCustomGhostAlpha(nil)
        triggerRefresh()
    }

    // MARK: - Window Actions

    func flipWindow(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.toggleFlip()
        triggerRefresh()
    }

    func openCropEditor(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.enterCropMode()
    }

    func openAdjustPanel(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.showAdjustmentPanel()
    }

    func removeBackground(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.removeBackground()
        triggerRefresh()
    }

    func resetDisplay(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.resetDisplay()
        triggerRefresh()
    }

    private func removeCharacterWindow(_ charWindow: CharacterWindow) {
        guard let appDelegate else { return }
        charWindow.window.orderOut(nil)
        appDelegate.zOrderedWindows.removeAll { $0 === charWindow }
        appDelegate.quitIfNoWindows()
    }

    // MARK: - Private Helpers

    private func triggerRefresh() {
        rebuildWindows()
    }

    private func findCharacterWindow(by windowId: Int) -> CharacterWindow? {
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
