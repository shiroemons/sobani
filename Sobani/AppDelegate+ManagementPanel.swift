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

extension AppDelegate: ManagementPanelDelegate {}
