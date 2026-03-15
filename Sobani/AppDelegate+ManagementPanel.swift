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
        case .toggleGhostMode:
            toggleAllGhostMode()
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

    func managementPanel(_ panel: ManagementPanelController, didToggleVisibility charWindow: CharacterWindow) {
        charWindow.setHidden(!charWindow.isHidden)
        if !charWindow.isHidden {
            applyZOrderToWindows()
        }
    }

    func managementPanel(_ panel: ManagementPanelController, didToggleGhostMode charWindow: CharacterWindow) {
        charWindow.setGhostMode(!charWindow.isGhostMode)
    }

    func managementPanel(_ panel: ManagementPanelController, didChangeOpacity opacity: CGFloat, for charWindow: CharacterWindow) {
        charWindow.applyOpacity(opacity)
    }
}
