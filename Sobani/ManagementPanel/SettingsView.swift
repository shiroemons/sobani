import SwiftUI

struct SettingsView: View {
    @State private var isLaunchAtLogin = LaunchAtLoginManager.shared.isEnabled
    @State private var isSnapEnabled = UserDefaults.standard.bool(forKey: AppConstants.snapEnabledKey)
    @State private var ghostAlpha = GhostModeSettings.globalAlpha
    @State private var currentTheme = AppThemeSettings.currentTheme
    @State private var currentLanguage = LanguageManager.shared.currentLanguage
    @State private var updateState: UpdateState = .idle
    @State private var isCheckingUpdate = false
    @State private var isHotkeyEnabled = HotkeySettings.isEnabled
    @State private var toggleVisibilityKeyCode = HotkeySettings.toggleVisibilityKeyCode
    @State private var toggleVisibilityModifiers = HotkeySettings.toggleVisibilityModifiers
    @State private var toggleGhostKeyCode = HotkeySettings.toggleGhostModeKeyCode
    @State private var toggleGhostModifiers = HotkeySettings.toggleGhostModeModifiers
    @State private var toggleManagementKeyCode = HotkeySettings.toggleManagementKeyCode
    @State private var toggleManagementModifiers = HotkeySettings.toggleManagementModifiers
    @State private var isAccessibilityGranted = AXIsProcessTrusted()
    @State private var accessibilityTimer: Timer?

    var body: some View {
        Form {
            generalSection
            ghostModeSection
            appearanceSection
            hotkeySection
            updateSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - General

    @ViewBuilder
    private var generalSection: some View {
        Section(L("management.general")) {
            Toggle(L("management.launch_at_login"), isOn: $isLaunchAtLogin)
                .onChange(of: isLaunchAtLogin) {
                    do {
                        try LaunchAtLoginManager.shared.toggle()
                    } catch {
                        isLaunchAtLogin = LaunchAtLoginManager.shared.isEnabled
                    }
                }

            Toggle(L("management.snap_enabled"), isOn: $isSnapEnabled)
                .onChange(of: isSnapEnabled) {
                    UserDefaults.standard.set(isSnapEnabled, forKey: AppConstants.snapEnabledKey)
                }
        }
    }

    // MARK: - Ghost Mode

    @ViewBuilder
    private var ghostModeSection: some View {
        Section(L("management.ghost_mode_section")) {
            HStack {
                Text(L("management.ghost_alpha"))
                Slider(
                    value: $ghostAlpha,
                    in: AppConstants.ghostModeAlphaMin...AppConstants.ghostModeAlphaMax
                )
                .onChange(of: ghostAlpha) {
                    GhostModeSettings.globalAlpha = ghostAlpha
                }
                Text(FormatUtils.formatOpacity(ghostAlpha))
                    .font(.body.monospaced())
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    // MARK: - Appearance

    @ViewBuilder
    private var appearanceSection: some View {
        Section(L("management.appearance")) {
            Picker(L("management.language"), selection: $currentLanguage) {
                ForEach(Language.allCases, id: \.rawValue) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: currentLanguage) {
                LanguageManager.shared.currentLanguage = currentLanguage
            }

            Picker(L("management.theme"), selection: $currentTheme) {
                ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                    Label {
                        Text(theme.displayName)
                    } icon: {
                        Image(systemName: theme.iconName)
                    }
                    .tag(theme)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: currentTheme) {
                AppThemeSettings.currentTheme = currentTheme
            }
        }
    }

    // MARK: - Hotkey

    @ViewBuilder
    private var hotkeySection: some View {
        Section(L("management.hotkey_section")) {
            Toggle(L("management.hotkey_enabled"), isOn: $isHotkeyEnabled)
                .onChange(of: isHotkeyEnabled) {
                    HotkeySettings.isEnabled = isHotkeyEnabled
                    NotificationCenter.default.post(name: AppConstants.hotkeySettingsDidChange, object: nil)
                }

            if isHotkeyEnabled {
                if isAccessibilityGranted {
                    Label(L("management.hotkey_accessibility_granted"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L("management.hotkey_accessibility_warning"), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Button(L("management.hotkey_open_settings")) {
                            if let url = URL(string: AppConstants.accessibilitySettingsURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }

                hotkeyRow(
                    label: L("management.hotkey_toggle_visibility"),
                    keyCode: $toggleVisibilityKeyCode,
                    modifiers: $toggleVisibilityModifiers
                )
                hotkeyRow(
                    label: L("management.hotkey_toggle_ghost"),
                    keyCode: $toggleGhostKeyCode,
                    modifiers: $toggleGhostModifiers
                )
                hotkeyRow(
                    label: L("management.hotkey_toggle_management"),
                    keyCode: $toggleManagementKeyCode,
                    modifiers: $toggleManagementModifiers
                )

                if hasDuplicateHotkeys {
                    Label(L("management.hotkey_duplicate_warning"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            startAccessibilityPolling()
        }
        .onDisappear {
            stopAccessibilityPolling()
        }
    }

    private func hotkeyRow(label: String, keyCode: Binding<UInt16>, modifiers: Binding<NSEvent.ModifierFlags>) -> some View {
        HStack {
            Text(label)
            Spacer()
            HotkeyRecorderButton(keyCode: keyCode, modifiers: modifiers)
                .onChange(of: keyCode.wrappedValue) { saveHotkeySettings() }
                .onChange(of: modifiers.wrappedValue) { saveHotkeySettings() }
        }
    }

    private var hasDuplicateHotkeys: Bool {
        let hotkeys = [
            (toggleVisibilityKeyCode, toggleVisibilityModifiers),
            (toggleGhostKeyCode, toggleGhostModifiers),
            (toggleManagementKeyCode, toggleManagementModifiers)
        ]
        for outer in 0..<hotkeys.count {
            for inner in (outer + 1)..<hotkeys.count {
                if hotkeys[outer].0 == hotkeys[inner].0 && hotkeys[outer].1 == hotkeys[inner].1 {
                    return true
                }
            }
        }
        return false
    }

    private func saveHotkeySettings() {
        HotkeySettings.toggleVisibilityKeyCode = toggleVisibilityKeyCode
        HotkeySettings.toggleVisibilityModifiers = toggleVisibilityModifiers
        HotkeySettings.toggleGhostModeKeyCode = toggleGhostKeyCode
        HotkeySettings.toggleGhostModeModifiers = toggleGhostModifiers
        HotkeySettings.toggleManagementKeyCode = toggleManagementKeyCode
        HotkeySettings.toggleManagementModifiers = toggleManagementModifiers
        NotificationCenter.default.post(name: AppConstants.hotkeySettingsDidChange, object: nil)
    }

    private func startAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        guard !isAccessibilityGranted else { return }
        accessibilityTimer = Timer.scheduledTimer(
            withTimeInterval: AppConstants.accessibilityPollingInterval,
            repeats: true
        ) { _ in
            MainActor.assumeIsolated {
                let granted = AXIsProcessTrusted()
                isAccessibilityGranted = granted
                if granted {
                    stopAccessibilityPolling()
                }
            }
        }
    }

    private func stopAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
    }

    // MARK: - Update

    @ViewBuilder
    private var updateSection: some View {
        Section(L("management.update_section")) {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            HStack {
                Text(L("management.current_version"))
                Spacer()
                Text("v\(version)")
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }

            if isCheckingUpdate {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(L("management.checking_update"))
                        .foregroundStyle(.secondary)
                }
            } else {
                switch UpdateManager.shared.state {
                case .upToDate:
                    Label(L("management.up_to_date"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .available(let version, _, _, _):
                    Label(
                        String(format: L("management.update_available_format"), version),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                default:
                    EmptyView()
                }
            }

            Button(L("management.check_update")) {
                isCheckingUpdate = true
                UpdateManager.shared.checkForUpdate(trigger: .manual)
                // Simple delay to update UI
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isCheckingUpdate = false
                }
            }
            .disabled(isCheckingUpdate)
        }
    }
}
