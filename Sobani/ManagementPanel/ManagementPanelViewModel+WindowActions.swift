import AppKit

// MARK: - Window Actions

extension ManagementPanelViewModel {

    func flipWindow(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.toggleFlip()
        // toggleFlip fires notifyStateDidChange → triggerRefresh handled by observer
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
        charWindow.removeBackground { [weak self] in
            self?.triggerRefresh()
        }
    }

    func resetDisplay(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.resetDisplay()
        // resetDisplay fires notifyStateDidChange → triggerRefresh handled by observer
    }

    // MARK: - Ghost Mode Custom Opacity

    func setCustomGhostAlpha(windowId: Int, alpha: CGFloat) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.setCustomGhostAlpha(alpha)
        // setCustomGhostAlpha fires notifyStateDidChange → triggerRefresh handled by observer
    }

    func clearCustomGhostAlpha(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.setCustomGhostAlpha(nil)
        // setCustomGhostAlpha fires notifyStateDidChange → triggerRefresh handled by observer
    }

    // MARK: - Image Addition

    func addImageFromFile(createWindow: Bool = true) {
        let panel = ImageFileDialog.makeOpenPanel(message: L("file.select_new_image_message"))
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let savedName = ImageManager.shared.registerImage(from: url) {
                    if createWindow {
                        appDelegate?.createNewWindow(imageName: savedName)
                        // createNewWindow fires characterWindowListDidChange → triggerRefresh handled by observer
                    }
                    // registerImage fires registeredImagesDidChange → refreshRegisteredImageNames handled by observer
                }
            }
        }
    }

    // MARK: - Registered Images

    func addFromRegisteredImage(name: String) {
        appDelegate?.createNewWindow(imageName: name)
    }

    func registeredImagePreview(name: String) -> NSImage? {
        ImageManager.shared.loadRegisteredImageCached(named: name)
    }

    func removeRegisteredImage(named name: String) {
        ImageManager.shared.removeRegisteredImage(named: name)
        if selectedRegisteredImageName == name {
            selectedRegisteredImageName = nil
        }
        triggerRefresh()
    }

    func windowCountUsingImage(named name: String) -> Int {
        windowCountByImageName[name] ?? 0
    }

    // MARK: - Derived State for Views

    var windowStates: [WindowState] { cachedWindowStates }

    var windowImages: [String: NSImage] { cachedWindowImages }

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

    fileprivate func removeCharacterWindow(_ charWindow: CharacterWindow) {
        guard let appDelegate else { return }
        charWindow.window.orderOut(nil)
        appDelegate.removeCharacterWindow(charWindow)
        appDelegate.quitIfNoWindows()
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
