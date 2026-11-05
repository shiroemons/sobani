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
        case .toggleScreenGhostMode:
            return ActionConfig(
                keyCodeKey: AppConstants.hotkeyToggleScreenGhostKeyCodeKey,
                modifiersKey: AppConstants.hotkeyToggleScreenGhostModifiersKey,
                defaultKeyCode: AppConstants.optionGKeyCode,
                defaultModifiers: [.option, .shift]
            )
        }
    }

    // MARK: - Low-level Storage Helpers

    /// ホットキーとして扱う修飾キー。Carbon の `RegisterEventHotKey` が扱えるのはこの 4 つだけで、
    /// CapsLock・fn・テンキー等のビットが混ざると重複判定や `isDefault` が狂う。
    static let supportedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    /// 保存値をキーコードとして解釈する。範囲外・負数（手動編集や破損した設定）は `fallback`。
    static func keyCode(fromStored stored: Any?, default fallback: UInt16) -> UInt16 {
        guard let raw = stored as? Int, let keyCode = UInt16(exactly: raw) else {
            return fallback
        }
        return keyCode
    }

    /// 保存値を修飾キーとして解釈する。負数は `fallback`、未対応の修飾キーのビットは除去する。
    static func modifiers(
        fromStored stored: Any?,
        default fallback: NSEvent.ModifierFlags
    ) -> NSEvent.ModifierFlags {
        guard let raw = stored as? Int, let rawValue = UInt(exactly: raw) else {
            return fallback
        }
        return NSEvent.ModifierFlags(rawValue: rawValue).intersection(supportedModifiers)
    }

    private static func storedKeyCode(forKey key: String, default fallback: UInt16) -> UInt16 {
        keyCode(fromStored: UserDefaults.standard.object(forKey: key), default: fallback)
    }

    private static func saveKeyCode(_ value: UInt16, forKey key: String) {
        UserDefaults.standard.set(Int(value), forKey: key)
    }

    private static func storedModifiers(
        forKey key: String,
        default fallback: NSEvent.ModifierFlags
    ) -> NSEvent.ModifierFlags {
        modifiers(fromStored: UserDefaults.standard.object(forKey: key), default: fallback)
    }

    private static func saveModifiers(_ value: NSEvent.ModifierFlags, forKey key: String) {
        UserDefaults.standard.set(Int(value.intersection(supportedModifiers).rawValue), forKey: key)
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
