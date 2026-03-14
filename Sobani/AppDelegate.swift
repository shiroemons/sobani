import Cocoa
import ServiceManagement
import os.log

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let logger = Logger(category: "AppDelegate")
    /// Z順（前面→背面）でウィンドウを管理する単一配列。
    var zOrderedWindows: [CharacterWindow] = []
    var statusItem: NSStatusItem?
    private var shouldTerminate = false
    var areWindowsHidden = false
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var nextWindowId: Int = 1
    let screenRestorationManager = ScreenRestorationManager()
    var screenChangeDebounceTimer: Timer?
    var wakeContext = WakeRestorationContext()
    var onboardingController: OnboardingWindowController?
    var isApplyingLayout = false
    weak var lastHighlightedWindow: CharacterWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = AppThemeSettings.currentTheme.nsAppearance
        setupStatusBar()
        setupHotkeyMonitors()
        screenRestorationManager.loadPending()

        let savedStates = WindowStateManager.shared.loadStates()

        if savedStates.isEmpty {
            guard let image = ImageManager.shared.defaultImage() else {
                logger.error("Failed to load character image")
                return
            }
            let charWindow = CharacterWindow(image: image)
            charWindow.delegate = self
            charWindow.windowId = nextWindowId
            nextWindowId += 1
            charWindow.window.center()
            zOrderedWindows.append(charWindow)
        } else {
            var loadedWindows: [CharacterWindow] = []
            for state in savedStates {
                let charWindow = createCharacterWindow(from: state)
                let wasAdjusted = charWindow.restore(from: state)
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
                loadedWindows.append(charWindow)
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

        UpdateManager.shared.delegate = self
        UpdateManager.shared.startPeriodicChecks()

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

        // ペンディングキューが存在する場合、起動直後に画面変化チェックをトリガー
        if screenRestorationManager.hasPending {
            handleScreenChange()
        }
    }

    @objc func bringAllToFront() {
        areWindowsHidden = false
        NSApp.activate(ignoringOtherApps: true)
        for charWindow in zOrderedWindows where charWindow.isHidden {
            charWindow.setHidden(false)
        }
        applyZOrderToWindows()
    }

    @objc func toggleAllWindowsVisibility() {
        guard !zOrderedWindows.isEmpty else { return }
        if areWindowsHidden {
            for charWindow in zOrderedWindows where charWindow.isHidden {
                charWindow.setHidden(false)
            }
            applyZOrderToWindows()
        } else {
            for charWindow in zOrderedWindows {
                charWindow.setHidden(true)
            }
        }
        areWindowsHidden.toggle()
    }

    private nonisolated func isOptionHotkey(_ event: NSEvent, keyCode: UInt16) -> Bool {
        event.keyCode == keyCode
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option
    }

    func setupHotkeyMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { @Sendable [weak self] event in
            guard let self else { return }
            if self.isOptionHotkey(event, keyCode: AppConstants.optionHKeyCode) {
                DispatchQueue.main.async { @Sendable [weak self] in
                    self?.toggleAllWindowsVisibility()
                }
            } else if self.isOptionHotkey(event, keyCode: AppConstants.optionGKeyCode) {
                DispatchQueue.main.async { @Sendable [weak self] in
                    self?.toggleAllGhostMode()
                }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { @Sendable [weak self] event in
            guard let self else { return event }
            if self.isOptionHotkey(event, keyCode: AppConstants.optionHKeyCode) {
                DispatchQueue.main.async { @Sendable [weak self] in
                    self?.toggleAllWindowsVisibility()
                }
                return nil
            } else if self.isOptionHotkey(event, keyCode: AppConstants.optionGKeyCode) {
                DispatchQueue.main.async { @Sendable [weak self] in
                    self?.toggleAllGhostMode()
                }
                return nil
            }
            return event
        }
    }

    @objc func addNewWindowFromMenu() { createNewWindow() }

    @objc func addNewWindowWithImageFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        createNewWindow(imageName: name)
    }

    /// zOrderedWindowsの順序をNSWindowに反映する（最背面から順に重ねる）
    func applyZOrderToWindows() {
        guard !areWindowsHidden else { return }
        var previousWindow: CharacterWindow?
        for charWindow in zOrderedWindows.reversed() {
            guard !charWindow.isHidden else { continue }
            if let prev = previousWindow {
                charWindow.window.order(.above, relativeTo: prev.window.windowNumber)
            } else {
                charWindow.window.orderFront(nil)
            }
            previousWindow = charWindow
        }
    }

    /// windowNumber から CharacterWindow を検索
    func characterWindow(forWindowNumber number: Int) -> CharacterWindow? {
        return zOrderedWindows.first { $0.window.windowNumber == number }
    }

    func moveWindowToFront(_ charWindow: CharacterWindow) {
        zOrderedWindows = ZOrderUtils.moveToFront(charWindow, in: zOrderedWindows)
        applyZOrderToWindows()
    }

    func moveWindowForward(_ charWindow: CharacterWindow) {
        zOrderedWindows = ZOrderUtils.moveForward(charWindow, in: zOrderedWindows)
        applyZOrderToWindows()
    }

    func moveWindowBackward(_ charWindow: CharacterWindow) {
        zOrderedWindows = ZOrderUtils.moveBackward(charWindow, in: zOrderedWindows)
        applyZOrderToWindows()
    }

    func moveWindowToBack(_ charWindow: CharacterWindow) {
        zOrderedWindows = ZOrderUtils.moveToBack(charWindow, in: zOrderedWindows)
        applyZOrderToWindows()
    }

    @objc func closeAllWindows() {
        areWindowsHidden = false
        for charWindow in zOrderedWindows {
            charWindow.window.orderOut(nil)
        }
        zOrderedWindows.removeAll()
        quitIfNoWindows()
    }
    nonisolated static func shouldQuitApp(windowCount: Int, isApplyingLayout: Bool) -> Bool {
        windowCount == 0 && !isApplyingLayout
    }

    func quitIfNoWindows() {
        if Self.shouldQuitApp(windowCount: zOrderedWindows.count, isApplyingLayout: isApplyingLayout) {
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

    func prepareShouldTerminate() {
        shouldTerminate = true
    }

    func createNewWindow(imageName: String? = nil) {
        if areWindowsHidden {
            areWindowsHidden = false
            for charWindow in zOrderedWindows {
                charWindow.window.orderFront(nil)
            }
        }
        let image: NSImage
        if let name = imageName, let registered = ImageManager.shared.loadRegisteredImage(named: name) {
            image = registered
        } else {
            image = ImageManager.shared.defaultImage() ?? NSImage()
        }
        let charWindow = CharacterWindow(image: image)
        charWindow.delegate = self
        charWindow.displayName = imageName ?? AppConstants.defaultImageName
        charWindow.windowId = nextWindowId
        nextWindowId += 1
        addCharacterWindow(charWindow)
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
        if shouldTerminate {
            return .terminateNow
        }
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        let states = captureCurrentWindowStates()
        WindowStateManager.shared.saveStates(states)
        screenRestorationManager.savePending()

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        teardownScreenRestorationObservers()
    }

}

// MARK: - CharacterWindowDelegate

extension AppDelegate: CharacterWindowDelegate {
    var allCharacterWindows: [CharacterWindow] { zOrderedWindows }

    func characterWindowRequestedNewWindow(_ sender: CharacterWindow, imageName: String?) {
        createNewWindow(imageName: imageName)
    }

    func characterWindowRequestedNewWindowWithFileURL(_ sender: CharacterWindow, fileURL: URL) {
        if let savedName = ImageManager.shared.registerImage(from: fileURL) {
            createNewWindow(imageName: savedName)
        }
    }

    func characterWindowDidClose(_ sender: CharacterWindow) {
        removeCharacterWindow(sender)
        if zOrderedWindows.isEmpty {
            areWindowsHidden = false
        }
        quitIfNoWindows()
    }

    func characterWindowDidBecomeActive(_ sender: CharacterWindow) {
        moveWindowToFront(sender)
    }

    func characterWindowDidChangeHidden(_ sender: CharacterWindow) {
        // Intentionally empty: status bar menu rebuilds its content
        // each time it opens (in buildStatusBarMenu), so no immediate
        // update is needed here.
    }

    func characterWindowDidDeleteImage(named name: String) {
        guard let defaultImage = ImageManager.shared.defaultImage() else { return }
        for charWindow in zOrderedWindows where charWindow.displayName == name {
            charWindow.displayName = AppConstants.defaultImageName
            charWindow.applyImage(defaultImage)
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
        let current = UserDefaults.standard.bool(forKey: AppConstants.snapEnabledKey)
        UserDefaults.standard.set(!current, forKey: AppConstants.snapEnabledKey)
        sender.state = !current ? .on : .off
    }
}

// MARK: - Ghost Mode

extension AppDelegate {
    @objc func toggleAllGhostMode() {
        guard !zOrderedWindows.isEmpty else { return }
        let anyGhosted = zOrderedWindows.contains { $0.isGhostMode }
        for charWindow in zOrderedWindows {
            charWindow.setGhostMode(!anyGhosted)
        }
    }

    @objc func disableAllGhostMode() {
        for charWindow in zOrderedWindows {
            charWindow.setGhostMode(false)
        }
    }
}
