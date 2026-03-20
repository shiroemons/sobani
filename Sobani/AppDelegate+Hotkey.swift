import Cocoa

// MARK: - Hotkey Monitor Types

extension AppDelegate {
    enum KeyboardAction: Sendable, CaseIterable {
        case toggleVisibility
        case toggleGhostMode
        case toggleManagement

        var label: String {
            switch self {
            case .toggleVisibility: return L("management.hotkey_toggle_visibility")
            case .toggleGhostMode: return L("management.hotkey_toggle_ghost")
            case .toggleManagement: return L("management.hotkey_toggle_management")
            }
        }
    }

    struct HotkeyBinding: Sendable, Equatable {
        let action: KeyboardAction
        let keyCode: UInt16
        let modifiers: NSEvent.ModifierFlags

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.action == rhs.action && lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
        }
    }

    struct HotkeyConfig: Sendable, Equatable {
        let bindings: [HotkeyBinding]

        func binding(for action: KeyboardAction) -> HotkeyBinding? {
            bindings.first { $0.action == action }
        }
    }
}

// MARK: - Hotkey Monitor Setup

extension AppDelegate {
    nonisolated func isHotkey(_ event: NSEvent, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        event.keyCode == keyCode
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifiers
    }

    nonisolated func hotkeyAction(for event: NSEvent, config: HotkeyConfig) -> KeyboardAction? {
        config.bindings.first { isHotkey(event, keyCode: $0.keyCode, modifiers: $0.modifiers) }?.action
    }

    func performKeyboardAction(_ action: KeyboardAction) {
        switch action {
        case .toggleVisibility: toggleAllWindowsVisibility()
        case .toggleGhostMode: toggleAllGhostMode()
        case .toggleManagement: showManagementPanel()
        }
    }

    func setupHotkeyMonitors() {
        let config = HotkeySettings.buildConfig()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { @Sendable [weak self] event in
            guard let self else { return }
            if let action = self.hotkeyAction(for: event, config: config) {
                DispatchQueue.main.async { @Sendable [weak self] in
                    self?.performKeyboardAction(action)
                }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { @Sendable [weak self] event in
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
