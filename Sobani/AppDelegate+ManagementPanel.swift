import Cocoa

// MARK: - Management Panel

extension AppDelegate {
    func setupManagementPanel() {
        let controller = ManagementPanelController()
        controller.delegate = self
        managementPanelController = controller
    }

    func handleHotkeyAction(_ action: HotkeyAction) {
        switch action {
        case .toggleVisibility:
            toggleAllWindowsVisibility()
            managementPanelController?.reloadWindowList()
        case .toggleGhostMode:
            toggleAllGhostMode()
            managementPanelController?.reloadWindowList()
        case .managementPanel:
            managementPanelController?.toggle()
        }
    }
}

// MARK: - ManagementPanelDelegate

extension AppDelegate: ManagementPanelDelegate {
    var managedWindows: [CharacterWindow] {
        zOrderedWindows
    }

    func managementPanel(
        _ panel: ManagementPanelController,
        didToggleVisibility charWindow: CharacterWindow
    ) {
        charWindow.setHidden(!charWindow.isHidden)
        if !charWindow.isHidden {
            applyZOrderToWindows()
        }
    }

    func managementPanel(
        _ panel: ManagementPanelController,
        didToggleGhostMode charWindow: CharacterWindow
    ) {
        charWindow.setGhostMode(!charWindow.isGhostMode)
    }

    func managementPanel(
        _ panel: ManagementPanelController,
        didChangeOpacity opacity: CGFloat,
        for charWindow: CharacterWindow
    ) {
        charWindow.applyOpacity(opacity)
    }

    func managementPanel(
        _ panel: ManagementPanelController,
        didReorderWindow charWindow: CharacterWindow,
        to index: Int
    ) {
        guard let currentIndex = zOrderedWindows.firstIndex(where: { $0 === charWindow })
        else { return }
        zOrderedWindows.remove(at: currentIndex)
        let safeIndex = max(0, min(index, zOrderedWindows.count))
        zOrderedWindows.insert(charWindow, at: safeIndex)
        applyZOrderToWindows()
    }

    func managementPanelDidRequestShowAll(_ panel: ManagementPanelController) {
        areWindowsHidden = false
        for charWindow in zOrderedWindows where charWindow.isHidden {
            charWindow.setHidden(false)
        }
        applyZOrderToWindows()
    }

    func managementPanelDidRequestHideAll(_ panel: ManagementPanelController) {
        for charWindow in zOrderedWindows {
            charWindow.setHidden(true)
            charWindow.window.orderOut(nil)
        }
        areWindowsHidden = true
    }

    func managementPanelDidRequestGhostAll(_ panel: ManagementPanelController) {
        for charWindow in zOrderedWindows {
            charWindow.setGhostMode(true)
        }
    }

    func managementPanelDidRequestUnghostAll(_ panel: ManagementPanelController) {
        disableAllGhostMode()
    }

    func managementPanel(
        _ panel: ManagementPanelController,
        didRequestApplyLayout preset: LayoutPreset
    ) {
        applyLayout(preset)
        panel.reloadWindowList()
    }

    func managementPanel(
        _ panel: ManagementPanelController,
        didRequestSaveLayoutWithName name: String
    ) {
        let states = captureCurrentWindowStates()
        LayoutPresetManager.shared.savePreset(name: name, states: states)
    }

    func managementPanelDidRequestCreateNewLayout(_ panel: ManagementPanelController) {
        createNewLayoutFromMenu()
    }

    func managementPanel(
        _ panel: ManagementPanelController,
        didRequestUpdateLayout preset: LayoutPreset
    ) {
        let states = captureCurrentWindowStates()
        LayoutPresetManager.shared.savePreset(name: preset.name, states: states)
    }

    func managementPanel(
        _ panel: ManagementPanelController,
        didRequestDeleteLayout preset: LayoutPreset
    ) {
        LayoutPresetManager.shared.deletePreset(named: preset.name)
    }

    func managementPanel(
        _ panel: ManagementPanelController,
        didRequestRenameLayout preset: LayoutPreset,
        to newName: String
    ) {
        _ = LayoutPresetManager.shared.renamePreset(from: preset.name, to: newName)
    }

    func managementPanelDidChangeHotkey(_ panel: ManagementPanelController) {
        teardownAndRebuildHotkeyMonitors()
    }

    func managementPanelDidDismiss(_ panel: ManagementPanelController) {
        quitIfNoWindows()
    }
}
