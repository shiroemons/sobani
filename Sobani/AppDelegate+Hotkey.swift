import Cocoa

// MARK: - Hotkey Monitor Types

extension AppDelegate {
    enum KeyboardAction: Sendable, CaseIterable {
        case toggleVisibility
        case toggleScreenVisibility
        case toggleGhostMode
        case toggleScreenGhostMode
        case toggleManagement

        var label: String {
            switch self {
            case .toggleVisibility: return L("management.hotkey_toggle_visibility")
            case .toggleScreenVisibility: return L("management.hotkey_toggle_screen_visibility")
            case .toggleGhostMode: return L("management.hotkey_toggle_ghost")
            case .toggleScreenGhostMode: return L("management.hotkey_toggle_screen_ghost")
            case .toggleManagement: return L("management.hotkey_toggle_management")
            }
        }
    }

    struct HotkeyBinding: Sendable, Equatable {
        let action: KeyboardAction
        let keyCode: UInt16
        let modifiers: NSEvent.ModifierFlags
    }

    struct HotkeyConfig: Sendable, Equatable {
        let bindings: [HotkeyBinding]
    }
}

// MARK: - Hotkey Setup

extension AppDelegate {
    func performKeyboardAction(_ action: KeyboardAction) {
        switch action {
        case .toggleVisibility: toggleAllWindowsVisibility()
        case .toggleScreenVisibility: toggleCurrentScreenWindowsVisibility()
        case .toggleGhostMode: toggleAllGhostMode()
        case .toggleScreenGhostMode: toggleCurrentScreenGhostMode()
        case .toggleManagement: showManagementPanel()
        }
    }

    func setupHotkeyMonitors() {
        let config = HotkeySettings.buildConfig()
        CarbonHotkeyManager.shared.registerAll(config: config)
    }

    func unregisterHotkeyMonitors() {
        CarbonHotkeyManager.shared.unregisterAll()
    }

    @objc func refreshHotkeyMonitors() {
        unregisterHotkeyMonitors()
        if HotkeySettings.isEnabled {
            setupHotkeyMonitors()
        }
    }
}
