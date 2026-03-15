import AppKit
import os.log

// MARK: - HotkeyAction

enum HotkeyAction: String, CaseIterable, Codable, Sendable {
    case toggleVisibility
    case toggleGhostMode
    case managementPanel

    var defaultBinding: HotkeyBinding {
        switch self {
        case .toggleVisibility:
            return HotkeyBinding(
                keyCode: AppConstants.optionHKeyCode,
                modifierMask: NSEvent.ModifierFlags.option.rawValue
            )
        case .toggleGhostMode:
            return HotkeyBinding(
                keyCode: AppConstants.optionGKeyCode,
                modifierMask: NSEvent.ModifierFlags.option.rawValue
            )
        case .managementPanel:
            return HotkeyBinding(
                keyCode: AppConstants.optionPKeyCode,
                modifierMask: NSEvent.ModifierFlags.option.rawValue
            )
        }
    }

    var userDefaultsKey: String { "hotkey_\(rawValue)" }

    var displayName: String {
        switch self {
        case .toggleVisibility: return L("hotkey.toggle_visibility")
        case .toggleGhostMode: return L("hotkey.toggle_ghost_mode")
        case .managementPanel: return L("hotkey.management_panel")
        }
    }
}

// MARK: - HotkeyBinding

struct HotkeyBinding: Codable, Sendable, Equatable {
    let keyCode: UInt16
    let modifierMask: UInt

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierMask)
    }

    var displayString: String {
        var parts: [String] = []
        let flags = modifiers
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        default: return "Key(\(keyCode))"
        }
    }
}

// MARK: - HotkeyManager

/// UserDefaults（スレッドセーフ）と Logger（Sendable）のみ保持。
/// cache は setBinding/resetBinding でのみ変更され、
/// これらは @MainActor コンテキストから呼ばれる想定。
final class HotkeyManager: @unchecked Sendable {
    static let shared = HotkeyManager()

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// ⌘Space, ⌘Tab, ⌘Q などのシステム予約済みキーコード（O(1) 検索）
    private static let reservedCommandKeyCodes: Set<UInt16> = [
        49, // Space (⌘Space: Spotlight)
        48, // Tab   (⌘Tab: App Switcher)
        12, // Q     (⌘Q: Quit)
        13, // W     (⌘W: Close Window)
        14, // E
        1,  // S     (⌘S: Save)
        6,  // Z     (⌘Z: Undo)
    ]

    private let logger = Logger(category: "HotkeyManager")
    private let defaults: UserDefaults
    private var cache: [HotkeyAction: HotkeyBinding] = [:]

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for action in HotkeyAction.allCases {
            cache[action] = loadBinding(for: action)
        }
    }

    // MARK: - Private

    private func loadBinding(for action: HotkeyAction) -> HotkeyBinding {
        guard let data = defaults.data(forKey: action.userDefaultsKey) else {
            return action.defaultBinding
        }
        do {
            return try Self.decoder.decode(HotkeyBinding.self, from: data)
        } catch {
            logger.error("Failed to decode HotkeyBinding for \(action.rawValue): \(error.localizedDescription)")
            return action.defaultBinding
        }
    }

    // MARK: - Public

    func binding(for action: HotkeyAction) -> HotkeyBinding {
        cache[action] ?? action.defaultBinding
    }

    func setBinding(_ binding: HotkeyBinding, for action: HotkeyAction) {
        do {
            let data = try Self.encoder.encode(binding)
            defaults.set(data, forKey: action.userDefaultsKey)
            cache[action] = binding
        } catch {
            logger.error("Failed to encode HotkeyBinding for \(action.rawValue): \(error.localizedDescription)")
        }
    }

    func resetBinding(for action: HotkeyAction) {
        defaults.removeObject(forKey: action.userDefaultsKey)
        cache[action] = action.defaultBinding
    }

    func resetAllBindings() {
        for action in HotkeyAction.allCases {
            defaults.removeObject(forKey: action.userDefaultsKey)
            cache[action] = action.defaultBinding
        }
    }

    func hasSystemConflict(_ binding: HotkeyBinding) -> Bool {
        // ⌘Space, ⌘Tab, ⌘Q などのシステム予約済みショートカットとの競合チェック
        let flags = binding.modifiers
        guard flags.contains(.command) else { return false }
        return Self.reservedCommandKeyCodes.contains(binding.keyCode)
    }

    func hasSobaniConflict(_ binding: HotkeyBinding, excluding action: HotkeyAction) -> Bool {
        HotkeyAction.allCases.contains { $0 != action && self.binding(for: $0) == binding }
    }

    nonisolated func matches(_ event: NSEvent, binding: HotkeyBinding) -> Bool {
        guard event.type == .keyDown else { return false }
        guard event.keyCode == binding.keyCode else { return false }
        let eventFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let bindingFlags = NSEvent.ModifierFlags(rawValue: binding.modifierMask)
            .intersection(.deviceIndependentFlagsMask)
        return eventFlags == bindingFlags
    }

    func matchingAction(for event: NSEvent) -> HotkeyAction? {
        HotkeyAction.allCases.first { matches(event, binding: binding(for: $0)) }
    }
}
