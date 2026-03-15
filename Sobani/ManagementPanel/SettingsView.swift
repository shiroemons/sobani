import SwiftUI

struct SettingsView: View {
    @State private var isLaunchAtLogin = LaunchAtLoginManager.shared.isEnabled
    @State private var isSnapEnabled = UserDefaults.standard.bool(forKey: AppConstants.snapEnabledKey)
    @State private var ghostAlpha = GhostModeSettings.globalAlpha
    @State private var currentTheme = AppThemeSettings.currentTheme
    @State private var currentLanguage = LanguageManager.shared.currentLanguage
    @State private var updateState: UpdateState = .idle
    @State private var isCheckingUpdate = false

    var body: some View {
        Form {
            generalSection
            ghostModeSection
            appearanceSection
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
