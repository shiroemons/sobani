import Carbon
import Cocoa
import os.log

// MARK: - CarbonHotkeyManager

@MainActor
final class CarbonHotkeyManager {
    static let shared = CarbonHotkeyManager()
    private let logger = Logger(category: "CarbonHotkeyManager")

    private var registeredHotkeys: [UInt32: (ref: EventHotKeyRef, action: AppDelegate.KeyboardAction)] = [:]
    private var eventHandlerRef: EventHandlerRef?

    init() {
        installCarbonEventHandler()
    }

    // MARK: - Setup

    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        if status != noErr {
            logger.error("Failed to install Carbon event handler: \(status)")
        }
    }

    // MARK: - Registration

    func registerAll(config: AppDelegate.HotkeyConfig) {
        unregisterAll()

        for (index, binding) in config.bindings.enumerated() {
            let hotkeyID = EventHotKeyID(
                signature: AppConstants.hotkeySignature,
                id: UInt32(index)
            )
            let carbonMods = Self.carbonModifiers(from: binding.modifiers)

            var hotkeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(binding.keyCode),
                carbonMods,
                hotkeyID,
                GetApplicationEventTarget(),
                0,
                &hotkeyRef
            )

            if status == noErr, let ref = hotkeyRef {
                registeredHotkeys[UInt32(index)] = (ref: ref, action: binding.action)
                logger.debug("Registered hotkey: \(String(describing: binding.action)) (keyCode: \(binding.keyCode))")
            } else {
                logger.error("Failed to register hotkey \(String(describing: binding.action)): \(status)")
            }
        }
    }

    func unregisterAll() {
        for entry in registeredHotkeys.values {
            UnregisterEventHotKey(entry.ref)
        }
        registeredHotkeys.removeAll()
    }

    // MARK: - Event Handling

    func handleHotkeyEvent(id: UInt32) {
        guard let entry = registeredHotkeys[id] else { return }
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.performKeyboardAction(entry.action)
    }

    // MARK: - Modifier Conversion

    nonisolated static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        return carbonMods
    }
}

// MARK: - Carbon Event Callback

private func carbonHotkeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    guard status == noErr else { return status }

    guard let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<CarbonHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    let capturedID = hotkeyID.id

    DispatchQueue.main.async {
        manager.handleHotkeyEvent(id: capturedID)
    }

    return noErr
}
