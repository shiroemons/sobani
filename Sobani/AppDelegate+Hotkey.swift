import Cocoa

// MARK: - Hotkey Monitor Types

extension AppDelegate {
    enum KeyboardAction: Sendable {
        case toggleVisibility
        case toggleGhostMode
        case toggleManagement
    }

    struct HotkeyConfig: Sendable {
        let visibilityKeyCode: UInt16
        let visibilityModifiers: NSEvent.ModifierFlags
        let ghostKeyCode: UInt16
        let ghostModifiers: NSEvent.ModifierFlags
        let managementKeyCode: UInt16
        let managementModifiers: NSEvent.ModifierFlags
    }
}

// MARK: - Hotkey Monitor Setup

extension AppDelegate {
    nonisolated func isHotkey(_ event: NSEvent, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        event.keyCode == keyCode
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifiers
    }

    nonisolated func hotkeyAction(for event: NSEvent, config: HotkeyConfig) -> KeyboardAction? {
        if isHotkey(event, keyCode: config.visibilityKeyCode, modifiers: config.visibilityModifiers) {
            return .toggleVisibility
        } else if isHotkey(event, keyCode: config.ghostKeyCode, modifiers: config.ghostModifiers) {
            return .toggleGhostMode
        } else if isHotkey(event, keyCode: config.managementKeyCode, modifiers: config.managementModifiers) {
            return .toggleManagement
        }
        return nil
    }

    func performKeyboardAction(_ action: KeyboardAction) {
        switch action {
        case .toggleVisibility: toggleAllWindowsVisibility()
        case .toggleGhostMode: toggleAllGhostMode()
        case .toggleManagement: showManagementPanel()
        }
    }

    func setupHotkeyMonitors() {
        let config = HotkeyConfig(
            visibilityKeyCode: HotkeySettings.toggleVisibilityKeyCode,
            visibilityModifiers: HotkeySettings.toggleVisibilityModifiers,
            ghostKeyCode: HotkeySettings.toggleGhostModeKeyCode,
            ghostModifiers: HotkeySettings.toggleGhostModeModifiers,
            managementKeyCode: HotkeySettings.toggleManagementKeyCode,
            managementModifiers: HotkeySettings.toggleManagementModifiers
        )

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { @Sendable [weak self] event in
            guard let self else { return }
            if let action = self.hotkeyAction(for: event, config: config) {
                DispatchQueue.main.async { @Sendable [weak self] in
                    self?.performKeyboardAction(action)
                }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { @Sendable [weak self] event in
            guard let self else { return event }
            if let action = self.hotkeyAction(for: event, config: config) {
                DispatchQueue.main.async { @Sendable [weak self] in
                    self?.performKeyboardAction(action)
                }
                return nil
            }
            return event
        }
    }

    func unregisterHotkeyMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    @objc func refreshHotkeyMonitors() {
        unregisterHotkeyMonitors()
        if HotkeySettings.isEnabled {
            setupHotkeyMonitors()
        }
    }
}
