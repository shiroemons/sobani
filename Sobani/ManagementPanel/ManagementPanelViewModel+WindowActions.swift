import AppKit

// MARK: - Window Actions

extension ManagementPanelViewModel {

    func flipWindow(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.toggleFlip()
        triggerRefresh()
    }

    func openCropEditor(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.enterCropMode()
    }

    func openAdjustPanel(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.showAdjustmentPanel()
    }

    func removeBackground(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.removeBackground { [weak self] in
            self?.triggerRefresh()
        }
    }

    func resetDisplay(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.resetDisplay()
        triggerRefresh()
    }

    // MARK: - Ghost Mode Custom Opacity

    func setCustomGhostAlpha(windowId: Int, alpha: CGFloat) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.setCustomGhostAlpha(alpha)
        triggerRefresh()
    }

    func clearCustomGhostAlpha(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.setCustomGhostAlpha(nil)
        triggerRefresh()
    }

    // MARK: - Image Addition

    func addImageFromFile(createWindow: Bool = true) {
        let panel = ImageFileDialog.makeOpenPanel(message: L("file.select_new_image_message"))
        panel.allowsMultipleSelection = true
        Task {
            guard await runDialog(panel) == .OK else { return }
            var failedNames: [String] = []
            for url in panel.urls {
                // 登録・ウィンドウ作成はそれぞれ registeredImagesDidChange / imageWindowListDidChange を発行し、
                // 一覧の更新は通知の監視側で行われる
                let succeeded = createWindow
                    ? appDelegate?.createNewWindow(registeringImageAt: url) ?? false
                    : ImageManager.shared.registerImage(from: url) != nil
                if !succeeded {
                    failedNames.append(url.lastPathComponent)
                }
            }
            ImageFileDialog.showLoadFailedAlert(fileNames: failedNames)
        }
    }

    // MARK: - Registered Images

    func addFromRegisteredImage(name: String) {
        appDelegate?.createNewWindow(imageName: name)
    }

    func registeredImagePreview(name: String) -> NSImage? {
        ImageManager.shared.loadRegisteredImageCached(named: name)
    }

    func previewImage(name: String) -> NSImage? {
        ImageManager.shared.image(named: name)
    }

    func croppedPreviewImage(for state: WindowState) -> NSImage? {
        guard let image = previewImage(name: state.imageName) else { return nil }
        return CroppedImageHelper.croppedImage(
            from: image, cropRect: state.cropRect, imageName: state.imageName
        )
    }

    func removeRegisteredImage(named name: String) {
        ImageManager.shared.removeRegisteredImage(named: name)
        // この画像を表示中のウィンドウをデフォルト画像へ戻す（存在しない画像名を保持させない）。
        // 選択の解除と一覧の更新は registeredImagesDidChange / imageWindowStateDidChange の監視側で行われる
        appDelegate?.imageWindowDidDeleteImage(named: name)
    }

    func windowCountUsingImage(named name: String) -> Int {
        windowCountByImageName[name] ?? 0
    }

    // MARK: - Window Management

    /// 指定ウィンドウを削除すると、すべてのウィンドウがなくなる（＝アプリが終了する）か。
    func deletionRemovesAllWindows(_ windowIds: Set<Int>) -> Bool {
        Self.deletionRemovesAllWindows(
            deleting: windowIds, existingIds: appDelegate?.zOrderedWindows.map(\.windowId) ?? []
        )
    }

    nonisolated static func deletionRemovesAllWindows(deleting windowIds: Set<Int>, existingIds: [Int]) -> Bool {
        !existingIds.isEmpty && existingIds.allSatisfy(windowIds.contains)
    }

    func deleteWindows(windowIds: Set<Int>) {
        guard let appDelegate else { return }
        let windowsToDelete = appDelegate.zOrderedWindows.filter { windowIds.contains($0.windowId) }
        for imageWindow in windowsToDelete {
            removeImageWindow(imageWindow)
        }
        selectedWindowIds.subtract(windowIds)
    }

    func duplicateWindow(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        appDelegate?.createNewWindow(imageName: imageWindow.displayName)
    }

    func centerWindow(windowId: Int) {
        guard let imageWindow = findImageWindow(by: windowId) else { return }
        imageWindow.centerOnScreen()
        triggerRefresh()
    }

    func moveWindows(from source: IndexSet, to destination: Int) {
        appDelegate?.reorderWindows(from: source, to: destination)
        triggerRefresh()
    }

    fileprivate func removeImageWindow(_ imageWindow: ImageWindow) {
        appDelegate?.closeImageWindow(imageWindow)
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

    // MARK: - Layout Preset Methods

    func loadPresets() -> [LayoutPreset] {
        LayoutPresetManager.shared.loadPresets()
    }

    func savePreset(name: String, states: [WindowState]) {
        LayoutPresetManager.shared.savePreset(name: name, states: states)
    }

    func updatePreset(_ preset: LayoutPreset, states: [WindowState]) {
        LayoutPresetManager.shared.updatePreset(preset, states: states)
    }

    @discardableResult
    func renamePreset(from oldName: String, to newName: String) -> Bool {
        LayoutPresetManager.shared.renamePreset(from: oldName, to: newName)
    }

    /// `name` で保存すると `excluded` 以外の既存プリセットを上書きしてしまうか。
    func presetExists(named name: String, excluding excluded: String? = nil) -> Bool {
        LayoutPresetManager.shared.presetExists(named: name, excluding: excluded)
    }
    func deletePreset(named name: String) {
        LayoutPresetManager.shared.deletePreset(named: name)
    }

    func restorePreset(_ preset: LayoutPreset) {
        LayoutPresetManager.shared.restorePreset(preset)
    }
}
