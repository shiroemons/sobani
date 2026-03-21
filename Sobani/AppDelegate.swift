import Cocoa
import os.log
import ServiceManagement

// MARK: - App Delegate

/// Sobani アプリケーションのメインデリゲート。
///
/// メニューバー専用アプリ（`LSUIElement`）として動作し、ステータスバーメニュー、
/// ウィンドウのライフサイクル管理、ホットキー監視、画面復元を統括する。
/// ウィンドウの重なり順は `zOrderedWindows` 配列で管理される。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let logger = Logger(category: "AppDelegate")
    /// Z順（前面→背面）でウィンドウを管理する単一配列。
    var zOrderedWindows: [ImageWindow] = []
    var statusItem: NSStatusItem?
    private var shouldTerminate = false
    private var shouldSkipSave = false
    var areWindowsHidden = false
    // internal (not private) because AppDelegate+Hotkey.swift (a separate file) both reads
    // and writes these properties in setupHotkeyMonitors() / unregisterHotkeyMonitors().
    // Same-file extensions could use `private`, but cross-file extensions require at least
    // internal access.
    var globalMonitor: Any?
    var localMonitor: Any?
    var nextWindowId: Int = 1
    let screenRestorationManager = ScreenRestorationManager()
    var screenChangeDebounceTimer: Timer?
    var snapshotDebounceTimer: Timer?
    var wakeContext = WakeRestorationContext()
    /// ディスプレイ切断時の復元用スナップショット。安定状態で定期的に更新される。
    var screenSnapshot = WakeRestorationContext()
    var onboardingController: OnboardingWindowController?
    var isApplyingLayout = false
    weak var lastHighlightedWindow: ImageWindow?
    private var managementPanelController: ManagementPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = AppThemeSettings.currentTheme.nsAppearance
        setupStatusBar()
        SparkleManager.shared.startUpdater()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshHotkeyMonitors),
            name: AppConstants.hotkeySettingsDidChange,
            object: nil
        )
        if HotkeySettings.isEnabled {
            setupHotkeyMonitors()
        }
        screenRestorationManager.loadPending()

        let savedStates = WindowStateManager.shared.loadStates()

        if savedStates.isEmpty {
            guard let image = ImageManager.shared.defaultImage() else {
                logger.error("Failed to load default image")
                return
            }
            let imageWindow = ImageWindow(image: image)
            imageWindow.delegate = self
            imageWindow.windowId = nextWindowId
            nextWindowId += 1
            imageWindow.window.center()
            zOrderedWindows.append(imageWindow)
        } else {
            var loadedWindows: [ImageWindow] = []
            for state in savedStates {
                let imageWindow = createImageWindow(from: state)
                let wasAdjusted = imageWindow.restore(from: state)
                if wasAdjusted {
                    let adjusted = state.adjustedToVisibleArea(on: ScreenInfo.current())
                    screenRestorationManager.addPending(
                        windowId: state.windowId,
                        originalState: state,
                        displayID: AppConstants.unknownDisplayID,
                        adjustedOriginX: adjusted.originX,
                        adjustedOriginY: adjusted.originY
                    )
                }
                loadedWindows.append(imageWindow)
            }

            // Legacy states (windowId == 0) get new IDs assigned
            let migrationResult = Self.migrateWindowIds(
                existingIds: loadedWindows.map(\.windowId),
                legacyId: 0
            )
            for assignment in migrationResult.assignments {
                loadedWindows[assignment.oldIndex].windowId = assignment.newId
            }
            nextWindowId = migrationResult.nextId

            zOrderedWindows = loadedWindows.reversed()
        }

        NSApp.activate(ignoringOtherApps: true)

        if OnboardingManager.shared.shouldShowOnboarding {
            if savedStates.isEmpty {
                let controller = OnboardingWindowController()
                controller.onAddImage = { [weak self] in
                    self?.changeDefaultImageFromMenu()
                }
                controller.onFinish = { [weak self] in
                    self?.statusItem?.button?.performClick(nil)
                }
                controller.show()
                onboardingController = controller
            } else {
                OnboardingManager.shared.markCompleted()
            }
        }

        setupScreenRestorationObservers()
        updateScreenSnapshot()

        // ペンディングキューが存在する場合、起動直後に画面変化チェックをトリガー
        if screenRestorationManager.hasPending {
            handleScreenChange()
        }
    }

    @objc func bringAllToFront() {
        areWindowsHidden = false
        NSApp.activate(ignoringOtherApps: true)
        for imageWindow in zOrderedWindows where imageWindow.isHidden {
            imageWindow.setHidden(false)
        }
        applyZOrderToWindows()
    }

    @objc func toggleAllWindowsVisibility() {
        guard !zOrderedWindows.isEmpty else { return }
        if areWindowsHidden {
            for imageWindow in zOrderedWindows where imageWindow.isHidden {
                imageWindow.setHidden(false)
            }
            applyZOrderToWindows()
        } else {
            for imageWindow in zOrderedWindows {
                imageWindow.setHidden(true)
            }
        }
        areWindowsHidden.toggle()
    }

    @objc func addNewWindowFromMenu() { createNewWindow() }

    @objc func addNewWindowWithImageFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        createNewWindow(imageName: name)
    }

    /// zOrderedWindowsの順序をNSWindowに反映する（最背面から順に重ねる）
    func applyZOrderToWindows() {
        guard !areWindowsHidden else { return }
        var previousWindow: ImageWindow?
        for imageWindow in zOrderedWindows.reversed() {
            guard !imageWindow.isHidden else { continue }
            if let prev = previousWindow {
                imageWindow.window.order(.above, relativeTo: prev.window.windowNumber)
            } else {
                imageWindow.window.orderFront(nil)
            }
            previousWindow = imageWindow
        }
    }

    /// windowNumber から ImageWindow を検索
    func imageWindow(forWindowNumber number: Int) -> ImageWindow? {
        return zOrderedWindows.first { $0.window.windowNumber == number }
    }

    func notifyWindowListDidChange() {
        NotificationCenter.default.post(
            name: AppConstants.imageWindowListDidChange, object: nil)
    }

    func moveWindowToFront(_ imageWindow: ImageWindow) {
        zOrderedWindows = ZOrderUtils.moveToFront(imageWindow, in: zOrderedWindows)
        applyZOrderToWindows()
        notifyWindowListDidChange()
    }

    func moveWindowForward(_ imageWindow: ImageWindow) {
        zOrderedWindows = ZOrderUtils.moveForward(imageWindow, in: zOrderedWindows)
        applyZOrderToWindows()
        notifyWindowListDidChange()
    }

    func moveWindowBackward(_ imageWindow: ImageWindow) {
        zOrderedWindows = ZOrderUtils.moveBackward(imageWindow, in: zOrderedWindows)
        applyZOrderToWindows()
        notifyWindowListDidChange()
    }

    func moveWindowToBack(_ imageWindow: ImageWindow) {
        zOrderedWindows = ZOrderUtils.moveToBack(imageWindow, in: zOrderedWindows)
        applyZOrderToWindows()
        notifyWindowListDidChange()
    }

    @objc func closeAllWindows() {
        areWindowsHidden = false
        for imageWindow in zOrderedWindows {
            imageWindow.window.orderOut(nil)
        }
        zOrderedWindows.removeAll()
        notifyWindowListDidChange()
        quitIfNoWindows()
    }

    nonisolated static func shouldQuitApp(windowCount: Int, isApplyingLayout: Bool) -> Bool {
        windowCount == 0 && !isApplyingLayout
    }

    /// すべてのウィンドウが閉じられた場合にアプリを終了する。
    ///
    /// `applicationShouldTerminate` は常に `.terminateCancel` を返すため、
    /// 終了は `shouldTerminate` フラグを設定してからこのメソッドを呼ぶか、
    /// 明示的な終了アクション経由で行う必要がある。
    func quitIfNoWindows() {
        if Self.shouldQuitApp(
            windowCount: zOrderedWindows.count, isApplyingLayout: isApplyingLayout
        ) {
            shouldTerminate = true
            NSApp.terminate(nil)
        }
    }

    @objc func quitFromMenu() {
        let alert = AlertFactory.confirmation(
            messageText: L("quit.confirm_title"),
            informativeText: L("quit.confirm_message"),
            okTitle: L("quit.button"),
            cancelTitle: L("quit.cancel")
        )
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        shouldTerminate = true
        NSApplication.shared.terminate(nil)
    }

    func requestQuit() { quitFromMenu() }

    @objc func quitWithoutSavingFromMenu() {
        shouldSkipSave = true
        shouldTerminate = true
        NSApplication.shared.terminate(nil)
    }

    func requestQuitWithoutSaving() { quitWithoutSavingFromMenu() }

    func prepareShouldTerminate() {
        shouldTerminate = true
    }

    /// 新しいキャラクターウィンドウを作成して表示する。
    ///
    /// - Parameter imageName: 表示する画像名。`nil` の場合はデフォルト画像を使用する。
    func createNewWindow(imageName: String? = nil) {
        if areWindowsHidden {
            areWindowsHidden = false
            for imageWindow in zOrderedWindows {
                imageWindow.window.orderFront(nil)
            }
        }
        let image: NSImage
        if let name = imageName,
            let registered = ImageManager.shared.loadRegisteredImage(named: name) {
            image = registered
        } else {
            image = ImageManager.shared.defaultImage() ?? NSImage()
        }
        let imageWindow = ImageWindow(image: image)
        imageWindow.delegate = self
        imageWindow.displayName = imageName ?? AppConstants.defaultImageName
        imageWindow.windowId = nextWindowId
        nextWindowId += 1
        addImageWindow(imageWindow)
    }

    @objc func addNewWindowWithNewImageFromMenu() {
        let panel = ImageFileDialog.makeOpenPanel(message: L("file.select_new_image_message"))
        if panel.runModal() == .OK, let url = panel.url {
            if let savedName = ImageManager.shared.registerImage(from: url) {
                createNewWindow(imageName: savedName)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldTerminate || SparkleManager.shared.isInstallingUpdate {
            return .terminateNow
        }
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        if !shouldSkipSave {
            let states = captureCurrentWindowStates()
            WindowStateManager.shared.saveStates(states)
            screenRestorationManager.savePending()
        }
        unregisterHotkeyMonitors()
        teardownScreenRestorationObservers()
    }

}

// MARK: - ImageWindowDelegate

extension AppDelegate: ImageWindowDelegate {
    var allImageWindows: [ImageWindow] { zOrderedWindows }

    func imageWindowRequestedNewWindow(_ sender: ImageWindow, imageName: String?) {
        createNewWindow(imageName: imageName)
    }

    func imageWindowRequestedNewWindowWithFileURL(_ sender: ImageWindow, fileURL: URL) {
        if let savedName = ImageManager.shared.registerImage(from: fileURL) {
            createNewWindow(imageName: savedName)
        }
    }

    func imageWindowDidClose(_ sender: ImageWindow) {
        removeImageWindow(sender)
        if zOrderedWindows.isEmpty {
            areWindowsHidden = false
        }
        quitIfNoWindows()
    }

    func imageWindowDidBecomeActive(_ sender: ImageWindow) {
        moveWindowToFront(sender)
    }

    func imageWindowDidChangeHidden(_ sender: ImageWindow) {
        // Intentionally empty: status bar menu rebuilds its content
        // each time it opens (in buildStatusBarMenu), so no immediate
        // update is needed here.
    }

    func imageWindowDidDeleteImage(named name: String) {
        guard let defaultImage = ImageManager.shared.defaultImage() else { return }
        for imageWindow in zOrderedWindows where imageWindow.displayName == name {
            imageWindow.displayName = AppConstants.defaultImageName
            imageWindow.applyImage(defaultImage)
        }
    }
}

// MARK: - Settings Actions

extension AppDelegate {
    @objc func toggleLaunchAtLogin() {
        do {
            try LaunchAtLoginManager.shared.toggle()
        } catch {
            if LaunchAtLoginManager.shared.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    @objc func toggleWindowSnap(_ sender: NSMenuItem) {
        let current = SnapSettings.isEnabled
        SnapSettings.isEnabled = !current
        sender.state = !current ? .on : .off
    }

    @objc func showManagementPanel() {
        if managementPanelController == nil {
            managementPanelController = ManagementPanelController(appDelegate: self)
        }
        managementPanelController?.toggle()
    }
}

// MARK: - Ghost Mode

extension AppDelegate {
    @objc func toggleAllGhostMode() {
        guard !zOrderedWindows.isEmpty else { return }
        let anyGhosted = zOrderedWindows.contains { $0.isGhostMode }
        for imageWindow in zOrderedWindows {
            imageWindow.setGhostMode(!anyGhosted)
        }
    }

    @objc func disableAllGhostMode() {
        for imageWindow in zOrderedWindows {
            imageWindow.setGhostMode(false)
        }
    }
}
