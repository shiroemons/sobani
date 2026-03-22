import Cocoa

enum HotkeySettings {

    // MARK: - Table-driven Config

    private struct ActionConfig {
        let keyCodeKey: String
        let modifiersKey: String
        let defaultKeyCode: UInt16
        let defaultModifiers: NSEvent.ModifierFlags
    }

    private static func actionConfig(for action: AppDelegate.KeyboardAction) -> ActionConfig {
        switch action {
        case .toggleVisibility:
            return ActionConfig(
                keyCodeKey: AppConstants.hotkeyToggleVisibilityKeyCodeKey,
                modifiersKey: AppConstants.hotkeyToggleVisibilityModifiersKey,
                defaultKeyCode: AppConstants.optionHKeyCode,
                defaultModifiers: .option
            )
        case .toggleGhostMode:
            return ActionConfig(
                keyCodeKey: AppConstants.hotkeyToggleGhostModeKeyCodeKey,
                modifiersKey: AppConstants.hotkeyToggleGhostModeModifiersKey,
                defaultKeyCode: AppConstants.optionGKeyCode,
                defaultModifiers: .option
            )
        case .toggleManagement:
            return ActionConfig(
                keyCodeKey: AppConstants.hotkeyToggleManagementKeyCodeKey,
                modifiersKey: AppConstants.hotkeyToggleManagementModifiersKey,
                defaultKeyCode: AppConstants.optionMKeyCode,
                defaultModifiers: .option
            )
        case .toggleScreenVisibility:
            return ActionConfig(
                keyCodeKey: AppConstants.hotkeyToggleScreenVisKeyCodeKey,
                modifiersKey: AppConstants.hotkeyToggleScreenVisModifiersKey,
                defaultKeyCode: AppConstants.optionHKeyCode,
                defaultModifiers: [.option, .shift]
            )
        }
    }

    // MARK: - Low-level Storage Helpers

    private static func storedKeyCode(forKey key: String, default fallback: UInt16) -> UInt16 {
        guard let stored = UserDefaults.standard.object(forKey: key) as? Int else {
            return fallback
        }
        return UInt16(stored)
    }

    private static func saveKeyCode(_ value: UInt16, forKey key: String) {
        UserDefaults.standard.set(Int(value), forKey: key)
    }

    private static func storedModifiers(
        forKey key: String,
        default fallback: NSEvent.ModifierFlags
    ) -> NSEvent.ModifierFlags {
        guard let raw = UserDefaults.standard.object(forKey: key) as? Int else {
            return fallback
        }
        return NSEvent.ModifierFlags(rawValue: UInt(raw))
    }

    private static func saveModifiers(_ value: NSEvent.ModifierFlags, forKey key: String) {
        UserDefaults.standard.set(Int(value.rawValue), forKey: key)
    }

    // MARK: - Global Enable/Disable

    static var isEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: AppConstants.hotkeyEnabledKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppConstants.hotkeyEnabledKey)
        }
    }

    // MARK: - Named Computed Properties (for backwards compatibility)

    static var toggleVisibilityKeyCode: UInt16 {
        get { keyCode(for: .toggleVisibility) }
        set { setKeyCode(newValue, for: .toggleVisibility) }
    }

    static var toggleVisibilityModifiers: NSEvent.ModifierFlags {
        get { modifiers(for: .toggleVisibility) }
        set { setModifiers(newValue, for: .toggleVisibility) }
    }

    static var toggleGhostModeKeyCode: UInt16 {
        get { keyCode(for: .toggleGhostMode) }
        set { setKeyCode(newValue, for: .toggleGhostMode) }
    }

    static var toggleGhostModeModifiers: NSEvent.ModifierFlags {
        get { modifiers(for: .toggleGhostMode) }
        set { setModifiers(newValue, for: .toggleGhostMode) }
    }

    static var toggleManagementKeyCode: UInt16 {
        get { keyCode(for: .toggleManagement) }
        set { setKeyCode(newValue, for: .toggleManagement) }
    }

    static var toggleManagementModifiers: NSEvent.ModifierFlags {
        get { modifiers(for: .toggleManagement) }
        set { setModifiers(newValue, for: .toggleManagement) }
    }

    // MARK: - Action-based Accessors

    static func keyCode(for action: AppDelegate.KeyboardAction) -> UInt16 {
        let cfg = actionConfig(for: action)
        return storedKeyCode(forKey: cfg.keyCodeKey, default: cfg.defaultKeyCode)
    }

    static func modifiers(for action: AppDelegate.KeyboardAction) -> NSEvent.ModifierFlags {
        let cfg = actionConfig(for: action)
        return storedModifiers(forKey: cfg.modifiersKey, default: cfg.defaultModifiers)
    }

    static func setKeyCode(_ keyCode: UInt16, for action: AppDelegate.KeyboardAction) {
        saveKeyCode(keyCode, forKey: actionConfig(for: action).keyCodeKey)
    }

    static func setModifiers(
        _ modifiers: NSEvent.ModifierFlags,
        for action: AppDelegate.KeyboardAction
    ) {
        saveModifiers(modifiers, forKey: actionConfig(for: action).modifiersKey)
    }

    static func buildConfig() -> AppDelegate.HotkeyConfig {
        AppDelegate.HotkeyConfig(
            bindings: AppDelegate.KeyboardAction.allCases.map { action in
                AppDelegate.HotkeyBinding(
                    action: action,
                    keyCode: keyCode(for: action),
                    modifiers: modifiers(for: action)
                )
            }
        )
    }

    // MARK: - Defaults

    /// 指定アクションのデフォルトキーコードを返す
    static func defaultKeyCode(for action: AppDelegate.KeyboardAction) -> UInt16 {
        actionConfig(for: action).defaultKeyCode
    }

    /// 指定アクションのデフォルト修飾キーを返す
    static func defaultModifiers(for action: AppDelegate.KeyboardAction) -> NSEvent.ModifierFlags {
        actionConfig(for: action).defaultModifiers
    }

    /// 指定アクションのホットキーがデフォルト値かどうかを返す
    static func isDefault(for action: AppDelegate.KeyboardAction) -> Bool {
        keyCode(for: action) == defaultKeyCode(for: action)
            && modifiers(for: action) == defaultModifiers(for: action)
    }

    // MARK: - Reset

    /// 指定アクションのホットキーをデフォルトに戻す
    static func resetToDefault(for action: AppDelegate.KeyboardAction) {
        let cfg = actionConfig(for: action)
        saveKeyCode(cfg.defaultKeyCode, forKey: cfg.keyCodeKey)
        saveModifiers(cfg.defaultModifiers, forKey: cfg.modifiersKey)
    }

    /// すべてのホットキーをデフォルトに戻す
    static func resetAllToDefaults() {
        for action in AppDelegate.KeyboardAction.allCases {
            resetToDefault(for: action)
        }
    }
}
