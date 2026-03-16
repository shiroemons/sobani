import SwiftUI

struct SettingsView: View {
    private let appVersion = AppConstants.appVersion
    @State private var isLaunchAtLogin = LaunchAtLoginManager.shared.isEnabled
    @State private var isSnapEnabled = SnapSettings.isEnabled
    @State private var ghostAlpha = GhostModeSettings.globalAlpha
    @State private var currentTheme = AppThemeSettings.currentTheme
    @State private var currentLanguage = LanguageManager.shared.currentLanguage
    @State private var isAccessibilityGranted = AXIsProcessTrusted()
    @State private var accessibilityTimer: Timer?
    @State private var hotkeySettingsVersion = 0
    @State private var hasDuplicateHotkeys = false
    @State private var hasNonDefaultHotkeys = false
    @State private var hotkeyDebounceTask: Task<Void, Never>?

    var body: some View {
        Form {
            generalSection
            ghostModeSection
            appearanceSection
            hotkeySection
                .id(hotkeySettingsVersion)
            updateSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAccessibilityPolling()
            updateHotkeyState()
        }
        .onDisappear {
            stopAccessibilityPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppConstants.managementPanelWillClose)) { _ in
            stopAccessibilityPolling()
        }
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
                    SnapSettings.isEnabled = isSnapEnabled
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
            Toggle(L("management.hotkey_enabled"), isOn: hotkeyEnabledBinding())

            if HotkeySettings.isEnabled {
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

                ForEach(AppDelegate.KeyboardAction.allCases, id: \.self) { action in
                    hotkeyRow(
                        action: action,
                        keyCode: keyCodeBinding(for: action),
                        modifiers: modifiersBinding(for: action)
                    )
                }

                if hasDuplicateHotkeys {
                    Label(L("management.hotkey_duplicate_warning"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }

                if hasNonDefaultHotkeys {
                    HStack {
                        Spacer()
                        Button {
                            HotkeySettings.resetAllToDefaults()
                            notifyHotkeySettingsChanged()
                        } label: {
                            Label(L("management.hotkey_reset_all"), systemImage: "arrow.counterclockwise")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private func hotkeyRow(
        action: AppDelegate.KeyboardAction,
        keyCode: Binding<UInt16>,
        modifiers: Binding<NSEvent.ModifierFlags>
    ) -> some View {
        HStack {
            Text(action.label)
            Spacer()
            if !HotkeySettings.isDefault(for: action) {
                Button {
                    HotkeySettings.resetToDefault(for: action)
                    notifyHotkeySettingsChanged()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(L("management.hotkey_reset_default"))
            }
            HotkeyRecorderButton(keyCode: keyCode, modifiers: modifiers)
        }
    }

    private func updateHotkeyState() {
        let pairs = AppDelegate.KeyboardAction.allCases.map { action in
            (keyCode: HotkeySettings.keyCode(for: action), modifiers: HotkeySettings.modifiers(for: action))
        }
        let unique = Set(pairs.map { UInt64($0.keyCode) << 32 | UInt64($0.modifiers.rawValue) })
        hasDuplicateHotkeys = unique.count < pairs.count
        hasNonDefaultHotkeys = AppDelegate.KeyboardAction.allCases.contains { !HotkeySettings.isDefault(for: $0) }
    }

    // MARK: - Hotkey Bindings

    private func hotkeyEnabledBinding() -> Binding<Bool> {
        Binding(
            get: { HotkeySettings.isEnabled },
            set: { newValue in
                HotkeySettings.isEnabled = newValue
                notifyHotkeySettingsChanged()
            }
        )
    }

    private func keyCodeBinding(for action: AppDelegate.KeyboardAction) -> Binding<UInt16> {
        Binding(
            get: { HotkeySettings.keyCode(for: action) },
            set: { newValue in
                HotkeySettings.setKeyCode(newValue, for: action)
                notifyHotkeySettingsChanged()
            }
        )
    }

    private func modifiersBinding(for action: AppDelegate.KeyboardAction) -> Binding<NSEvent.ModifierFlags> {
        Binding(
            get: { HotkeySettings.modifiers(for: action) },
            set: { newValue in
                HotkeySettings.setModifiers(newValue, for: action)
                notifyHotkeySettingsChanged()
            }
        )
    }

    private func notifyHotkeySettingsChanged() {
        hotkeySettingsVersion += 1
        updateHotkeyState()
        hotkeyDebounceTask?.cancel()
        hotkeyDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            NotificationCenter.default.post(name: AppConstants.hotkeySettingsDidChange, object: nil)
        }
    }

    // MARK: - Accessibility Polling

    private func startAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        guard HotkeySettings.isEnabled else { return }
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

    private var isCheckingUpdate: Bool {
        if case .checking = UpdateManager.shared.state { return true }
        return false
    }

    @ViewBuilder
    private var updateSection: some View {
        Section(L("management.update_section")) {
            HStack {
                Text(L("management.current_version"))
                Spacer()
                Text("v\(appVersion)")
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }

            switch UpdateManager.shared.state {
            case .checking:
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(L("management.checking_update"))
                        .foregroundStyle(.secondary)
                }
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

            Button(L("management.check_update")) {
                UpdateManager.shared.checkForUpdate(trigger: .manual)
            }
            .disabled(isCheckingUpdate)
        }
    }
}
