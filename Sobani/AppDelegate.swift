import Cocoa
import ServiceManagement
import os.log

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, CharacterWindowDelegate, NSMenuDelegate {
    private let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "AppDelegate")
    var characterWindows: [CharacterWindow] = []
    var statusItem: NSStatusItem?
    private var shouldTerminate = false
    var areWindowsHidden = false
    var zOrderedWindows: [CharacterWindow] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var nextWindowId: Int = 1
    let screenRestorationManager = ScreenRestorationManager()
    var screenChangeDebounceTimer: Timer?
    var wakeContext = WakeRestorationContext()
    var onboardingController: OnboardingWindowController?
    var isApplyingLayout = false

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            charWindow.setWindowId(nextWindowId)
            nextWindowId += 1
            charWindow.window.center()
            characterWindows.append(charWindow)
        } else {
            for state in savedStates {
                let image: NSImage
                let resolvedDisplayName: String

                if state.imageName == AppConstants.defaultImageName {
                    image = ImageManager.shared.defaultImage() ?? NSImage()
                    resolvedDisplayName = AppConstants.defaultImageName
                } else if let registered = ImageManager.shared.loadRegisteredImage(named: state.imageName) {
                    image = registered
                    resolvedDisplayName = state.imageName
                } else {
                    image = ImageManager.shared.defaultImage() ?? NSImage()
                    resolvedDisplayName = AppConstants.defaultImageName
                }

                let charWindow = CharacterWindow(image: image)
                charWindow.delegate = self
                charWindow.setDisplayName(resolvedDisplayName)
                charWindow.setWindowId(state.windowId)
                let wasAdjusted = charWindow.restore(from: state)
                if wasAdjusted {
                    let adjusted = state.adjustedToVisibleArea()
                    screenRestorationManager.addPending(
                        windowId: state.windowId,
                        originalState: state,
                        displayID: AppConstants.unknownDisplayID,
                        adjustedOriginX: adjusted.originX,
                        adjustedOriginY: adjusted.originY
                    )
                }
                characterWindows.append(charWindow)
            }

            // Legacy states (windowId == 0) get new IDs assigned
            let maxExistingId = characterWindows.map(\.windowId).max() ?? 0
            nextWindowId = maxExistingId + 1
            for charWindow in characterWindows where charWindow.windowId == 0 {
                charWindow.setWindowId(nextWindowId)
                nextWindowId += 1
            }
            // Ensure nextWindowId is always beyond the max assigned ID
            let finalMaxId = characterWindows.map(\.windowId).max() ?? 0
            nextWindowId = finalMaxId + 1
        }

        zOrderedWindows = characterWindows.reversed()

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
        for charWindow in characterWindows {
            charWindow.window.orderFront(nil)
        }
        applyZOrderToWindows()
    }

    @objc func toggleAllWindowsVisibility() {
        guard !characterWindows.isEmpty else { return }
        if areWindowsHidden {
            for charWindow in characterWindows {
                charWindow.window.orderFront(nil)
            }
            applyZOrderToWindows()
        } else {
            for charWindow in characterWindows {
                charWindow.window.orderOut(nil)
            }
        }
        areWindowsHidden.toggle()
    }

    func setupHotkeyMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { @Sendable [weak self] event in
            if event.keyCode == AppConstants.optionHKeyCode && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option {
                let weakSelf = self
                DispatchQueue.main.async { @Sendable in
                    weakSelf?.toggleAllWindowsVisibility()
                }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { @Sendable [weak self] event in
            if event.keyCode == AppConstants.optionHKeyCode && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option {
                let weakSelf = self
                DispatchQueue.main.async { @Sendable in
                    weakSelf?.toggleAllWindowsVisibility()
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

    /// Z-order順（前面が先頭）でCharacterWindow配列を返す
    func getZOrderedCharacterWindows() -> [CharacterWindow] {
        return zOrderedWindows
    }

    /// zOrderedWindowsの順序をNSWindowに反映する（最背面から順に重ねる）
    func applyZOrderToWindows() {
        guard !areWindowsHidden else { return }
        let backToFront = Array(zOrderedWindows.reversed())
        for (idx, charWindow) in backToFront.enumerated() {
            if idx == 0 {
                charWindow.window.orderFront(nil)
            } else {
                let windowBelow = backToFront[idx - 1]
                charWindow.window.order(.above, relativeTo: windowBelow.window.windowNumber)
            }
        }
    }

    /// windowNumber から CharacterWindow を検索
    func characterWindow(forWindowNumber number: Int) -> CharacterWindow? {
        return characterWindows.first { $0.window.windowNumber == number }
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
        for charWindow in characterWindows {
            charWindow.window.orderOut(nil)
        }
        characterWindows.removeAll()
        zOrderedWindows.removeAll()
        quitIfNoWindows()
    }
    nonisolated static func shouldQuitApp(windowCount: Int, isApplyingLayout: Bool) -> Bool {
        windowCount == 0 && !isApplyingLayout
    }

    func quitIfNoWindows() {
        if Self.shouldQuitApp(windowCount: characterWindows.count, isApplyingLayout: isApplyingLayout) {
            shouldTerminate = true
            NSApp.terminate(nil)
        }
    }

    @objc func quitFromMenu() {
        let alert = NSAlert()
        alert.messageText = L("quit.confirm_title")
        alert.informativeText = L("quit.confirm_message")
        alert.addButton(withTitle: L("quit.button"))
        alert.addButton(withTitle: L("quit.cancel"))
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        shouldTerminate = true
        NSApplication.shared.terminate(nil)
    }

    @objc func quitApp() { quitFromMenu() }

    func prepareShouldTerminate() {
        shouldTerminate = true
    }

    @objc func toggleLaunchAtLogin() {
        do {
            try LaunchAtLoginManager.shared.toggle()
        } catch {
            if LaunchAtLoginManager.shared.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    func createNewWindow(imageName: String? = nil) {
        if areWindowsHidden {
            areWindowsHidden = false
            for charWindow in characterWindows {
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
        charWindow.setDisplayName(imageName ?? AppConstants.defaultImageName)
        charWindow.setWindowId(nextWindowId)
        nextWindowId += 1
        characterWindows.append(charWindow)
        zOrderedWindows.insert(charWindow, at: 0)
    }

    @objc func addNewWindowWithNewImageFromMenu() {
        let panel = ImageFileDialog.makeOpenPanel(message: L("file.select_new_image_message"))
        if panel.runModal() == .OK, let url = panel.url {
            if let savedName = ImageManager.shared.registerImage(from: url) {
                createNewWindow(imageName: savedName)
            }
        }
    }

    // MARK: CharacterWindowDelegate

    func characterWindowRequestedNewWindow(_ sender: CharacterWindow, imageName: String?) {
        createNewWindow(imageName: imageName)
    }

    func characterWindowRequestedNewWindowWithFileURL(_ sender: CharacterWindow, fileURL: URL) {
        if let savedName = ImageManager.shared.registerImage(from: fileURL) {
            createNewWindow(imageName: savedName)
        }
    }

    func characterWindowDidClose(_ sender: CharacterWindow) {
        characterWindows.removeAll { $0 === sender }
        zOrderedWindows.removeAll { $0 === sender }
        if characterWindows.isEmpty {
            areWindowsHidden = false
        }
        quitIfNoWindows()
    }

    func characterWindowDidBecomeActive(_ sender: CharacterWindow) {
        moveWindowToFront(sender)
    }

    func characterWindowDidDeleteImage(named name: String) {
        guard let defaultImage = ImageManager.shared.defaultImage() else { return }
        for charWindow in characterWindows where charWindow.displayName == name {
            charWindow.setDisplayName(AppConstants.defaultImageName)
            charWindow.applyImage(defaultImage)
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
        let sortedWindows = Array(getZOrderedCharacterWindows().reversed())
        let states = sortedWindows.map { WindowStateManager.captureState(from: $0) }
        WindowStateManager.shared.saveStates(states)
        screenRestorationManager.savePending()

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }

        teardownScreenRestorationObservers()
    }

}
