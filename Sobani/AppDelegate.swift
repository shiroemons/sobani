import Cocoa
import UniformTypeIdentifiers

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, CharacterWindowDelegate, NSMenuDelegate {
    var characterWindows: [CharacterWindow] = []
    var statusItem: NSStatusItem!
    var shouldTerminate = false
    var areWindowsHidden = false
    var globalMonitor: Any?
    var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupHotkeyMonitors()

        let savedStates = WindowStateManager.shared.loadStates()

        if savedStates.isEmpty {
            guard let image = ImageManager.shared.defaultImage() else {
                print("Failed to load character image")
                return
            }
            let charWindow = CharacterWindow(image: image)
            charWindow.delegate = self
            charWindow.window.center()
            characterWindows.append(charWindow)
        } else {
            for state in savedStates {
                let image: NSImage
                let resolvedDisplayName: String

                if state.imageName == "デフォルト" {
                    image = ImageManager.shared.defaultImage() ?? NSImage()
                    resolvedDisplayName = "デフォルト"
                } else if let registered = ImageManager.shared.loadRegisteredImage(named: state.imageName) {
                    image = registered
                    resolvedDisplayName = state.imageName
                } else {
                    image = ImageManager.shared.defaultImage() ?? NSImage()
                    resolvedDisplayName = "デフォルト"
                }

                let charWindow = CharacterWindow(image: image)
                charWindow.delegate = self
                charWindow.displayName = resolvedDisplayName
                charWindow.restore(from: state)
                characterWindows.append(charWindow)
            }
        }

        NSApp.activate(ignoringOtherApps: true)

        UpdateManager.shared.delegate = self
        UpdateManager.shared.startPeriodicChecks()
    }

    @objc func bringAllToFront() {
        areWindowsHidden = false
        NSApp.activate(ignoringOtherApps: true)
        for charWindow in characterWindows {
            charWindow.window.orderFront(nil)
        }
    }

    @objc func toggleAllWindowsVisibility() {
        guard !characterWindows.isEmpty else { return }
        if areWindowsHidden {
            for charWindow in characterWindows {
                charWindow.window.orderFront(nil)
            }
        } else {
            for charWindow in characterWindows {
                charWindow.window.orderOut(nil)
            }
        }
        areWindowsHidden.toggle()
    }

    func setupHotkeyMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 4 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option {
                DispatchQueue.main.async {
                    self?.toggleAllWindowsVisibility()
                }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 4 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .option {
                DispatchQueue.main.async {
                    self?.toggleAllWindowsVisibility()
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

    @objc func closeWindowByIndex(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0 && index < characterWindows.count else { return }
        let charWindow = characterWindows[index]
        charWindow.window.orderOut(nil)
        characterWindows.remove(at: index)
        if characterWindows.isEmpty {
            areWindowsHidden = false
        }
        quitIfNoWindows()
    }

    @objc func closeAllWindows() {
        areWindowsHidden = false
        for charWindow in characterWindows {
            charWindow.window.orderOut(nil)
        }
        characterWindows.removeAll()
        quitIfNoWindows()
    }

    func quitIfNoWindows() {
        if characterWindows.isEmpty {
            shouldTerminate = true
            NSApp.terminate(nil)
        }
    }

    @objc func changeDefaultImageFromMenu() {
        let panel = NSOpenPanel()
        panel.title = "デフォルト画像を選択"
        panel.message = "デフォルトに設定する画像ファイルを選択してください"
        panel.prompt = "選択"
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            ImageManager.shared.setCustomDefault(from: url)
            if let newDefault = ImageManager.shared.defaultImage() {
                for charWindow in characterWindows where charWindow.displayName == "デフォルト" {
                    charWindow.applyImage(newDefault)
                }
            }
        }
    }

    @objc func resetDefaultImage() {
        ImageManager.shared.resetCustomDefault()
        if let newDefault = ImageManager.shared.defaultImage() {
            for charWindow in characterWindows where charWindow.displayName == "デフォルト" {
                charWindow.applyImage(newDefault)
            }
        }
    }

    func confirmQuit() -> Bool {
        let alert = NSAlert()
        alert.messageText = "アプリケーションを終了しますか？"
        alert.informativeText = "すべてのウィンドウが閉じられ、アプリが終了します。"
        alert.addButton(withTitle: "終了")
        alert.addButton(withTitle: "キャンセル")
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc func quitFromMenu() {
        if confirmQuit() {
            shouldTerminate = true
            NSApplication.shared.terminate(nil)
        }
    }

    @objc func quitApp() {
        quitFromMenu()
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
        charWindow.displayName = imageName ?? "デフォルト"
        characterWindows.append(charWindow)
    }

    @objc func addNewWindowWithNewImageFromMenu() {
        let panel = NSOpenPanel()
        panel.title = "画像を選択"
        panel.message = "新しいウィンドウに表示する画像ファイルを選択してください"
        panel.prompt = "選択"
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
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
        if characterWindows.isEmpty {
            areWindowsHidden = false
        }
        quitIfNoWindows()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldTerminate {
            return .terminateNow
        }
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save window states in z-order
        let orderedWindows = NSApplication.shared.orderedWindows
        let orderedCharWindows = orderedWindows.compactMap { nsWindow in
            characterWindows.first { $0.window === nsWindow }
        }

        // Add any windows not found in orderedWindows (e.g. hidden windows)
        let remainingWindows = characterWindows.filter { charWindow in
            !orderedCharWindows.contains { $0 === charWindow }
        }

        // Reverse so first element = backmost, last element = frontmost
        let sortedWindows = orderedCharWindows.reversed() + remainingWindows
        let states = sortedWindows.map { WindowStateManager.captureState(from: $0) }
        WindowStateManager.shared.saveStates(states)

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

}
