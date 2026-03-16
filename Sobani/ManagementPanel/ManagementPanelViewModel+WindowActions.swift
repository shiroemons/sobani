import AppKit

// MARK: - Window Actions

extension ManagementPanelViewModel {

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
        charWindow.removeBackground { [weak self] in
            self?.triggerRefresh()
        }
        triggerRefresh()
    }

    func resetDisplay(windowId: Int) {
        guard let charWindow = findCharacterWindow(by: windowId) else { return }
        charWindow.resetDisplay()
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

    // MARK: - Image Addition

    func addImageFromFile(createWindow: Bool = true) {
        let panel = ImageFileDialog.makeOpenPanel(message: L("file.select_new_image_message"))
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let savedName = ImageManager.shared.registerImage(from: url) {
                    if createWindow {
                        appDelegate?.createNewWindow(imageName: savedName)
                    }
                }
            }
            triggerRefresh()
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

    var windowStates: [WindowState] {
        windows.map { $0.toWindowState() }
    }

    var windowImages: [String: NSImage] {
        var dict: [String: NSImage] = [:]
        for window in windows where dict[window.imageName] == nil {
            dict[window.imageName] = window.originalImage
        }
        return dict
    }
}
