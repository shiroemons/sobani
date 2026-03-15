import Cocoa
import ServiceManagement

// MARK: - ManagementPanelSettingsView

@MainActor
final class ManagementPanelSettingsView: NSView {

    // MARK: - Layout Constants

    private static let sectionHeaderFontSize: CGFloat = 11
    private static let labelFontSize: CGFloat = 13
    private static let sectionHeaderX: CGFloat = 24
    private static let checkboxX: CGFloat = 24
    private static let separatorHeight: CGFloat = 1
    private static let separatorInset: CGFloat = 16
    private static let alphaLabelX: CGFloat = 24
    private static let alphaLabelWidth: CGFloat = 30
    private static let sliderX: CGFloat = 60
    private static let sliderWidth: CGFloat = 160
    private static let percentLabelX: CGFloat = 225
    private static let percentLabelWidth: CGFloat = 45
    private static let popupLabelX: CGFloat = 24
    private static let popupLabelWidth: CGFloat = 60
    private static let popupX: CGFloat = 90
    private static let popupWidth: CGFloat = 180
    private static let hotkeyLabelX: CGFloat = 24
    private static let hotkeyLabelWidth: CGFloat = 120
    private static let hotkeyKeyLabelX: CGFloat = 150
    private static let hotkeyKeyLabelWidth: CGFloat = 60
    private static let hotkeyRecordButtonX: CGFloat = 215
    private static let hotkeyResetButtonX: CGFloat = 275
    private static let hotkeyButtonWidth: CGFloat = 56
    private static let hotkeyButtonHeight: CGFloat = 22
    private static let resetAllButtonX: CGFloat = 24
    private static let resetAllButtonWidth: CGFloat = 100
    private static let resetAllButtonHeight: CGFloat = 24
    private static let rowHeight: CGFloat = 26

    // MARK: - Callbacks

    var onHotkeyChanged: ((HotkeyAction, HotkeyBinding) -> Void)?

    // MARK: - Private UI Elements

    private var launchAtLoginCheckbox: NSButton?
    private var snapEnabledCheckbox: NSButton?
    private var ghostAlphaSlider: NSSlider?
    private var ghostAlphaPercentLabel: NSTextField?
    private var languagePopup: NSPopUpButton?
    private var themePopup: NSPopUpButton?
    private var hotkeyKeyLabels: [HotkeyAction: NSTextField] = [:]

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        let totalHeight = bounds.height
        setupGeneralSection(totalHeight: totalHeight)
        setupGhostModeSection(totalHeight: totalHeight)
        setupAppearanceSection(totalHeight: totalHeight)
        setupHotkeySection(totalHeight: totalHeight)
    }

    private func setupGeneralSection(totalHeight: CGFloat) {
        // "一般" ヘッダ (上から16)
        let headerY = totalHeight - 16 - Self.rowHeight
        addSectionHeader(title: L("management.general"), x: Self.sectionHeaderX, y: headerY)

        // ログイン時起動チェックボックス (上から42)
        let loginCheckboxY = totalHeight - 42 - Self.rowHeight
        let loginCheckbox = makeCheckbox(
            title: L("management.launch_at_login"),
            x: Self.checkboxX,
            y: loginCheckboxY,
            action: #selector(launchAtLoginChanged(_:))
        )
        addSubview(loginCheckbox)
        launchAtLoginCheckbox = loginCheckbox

        // スナップ配置チェックボックス (上から68)
        let snapCheckboxY = totalHeight - 68 - Self.rowHeight
        let snapCheckbox = makeCheckbox(
            title: L("management.snap_enabled"),
            x: Self.checkboxX,
            y: snapCheckboxY,
            action: #selector(snapEnabledChanged(_:))
        )
        addSubview(snapCheckbox)
        snapEnabledCheckbox = snapCheckbox
    }

    private func setupGhostModeSection(totalHeight: CGFloat) {
        // セパレータ (上から98)
        let sep1Y = totalHeight - 98 - Self.separatorHeight
        addSeparator(y: sep1Y)

        // "ゴーストモード" ヘッダ (上から112)
        let headerY = totalHeight - 112 - Self.rowHeight
        addSectionHeader(title: L("management.ghost_mode_section"), x: Self.sectionHeaderX, y: headerY)

        // α値スライダー行 (上から140)
        let sliderRowY = totalHeight - 140 - Self.rowHeight
        setupAlphaSliderRow(y: sliderRowY)
    }

    private func setupAlphaSliderRow(y: CGFloat) {
        // "α値" ラベル
        let alphaLabel = NSTextField(labelWithString: L("management.ghost_alpha"))
        alphaLabel.frame = NSRect(x: Self.alphaLabelX, y: y, width: Self.alphaLabelWidth, height: Self.rowHeight)
        alphaLabel.font = .systemFont(ofSize: Self.labelFontSize)
        addSubview(alphaLabel)

        // スライダー
        let slider = NSSlider(frame: NSRect(x: Self.sliderX, y: y + 2, width: Self.sliderWidth, height: 21))
        slider.minValue = Double(AppConstants.ghostModeAlphaMin)
        slider.maxValue = Double(AppConstants.ghostModeAlphaMax)
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(ghostAlphaChanged(_:))
        addSubview(slider)
        ghostAlphaSlider = slider

        // パーセント表示
        let percentLabel = NSTextField(labelWithString: "")
        percentLabel.frame = NSRect(x: Self.percentLabelX, y: y, width: Self.percentLabelWidth, height: Self.rowHeight)
        percentLabel.font = .systemFont(ofSize: Self.labelFontSize)
        percentLabel.alignment = .right
        addSubview(percentLabel)
        ghostAlphaPercentLabel = percentLabel
    }

    private func setupAppearanceSection(totalHeight: CGFloat) {
        // セパレータ (上から168)
        let sep2Y = totalHeight - 168 - Self.separatorHeight
        addSeparator(y: sep2Y)

        // "外観" ヘッダ (上から182)
        let headerY = totalHeight - 182 - Self.rowHeight
        addSectionHeader(title: L("management.appearance"), x: Self.sectionHeaderX, y: headerY)

        // 言語行 (上から210)
        let langRowY = totalHeight - 210 - Self.rowHeight
        setupLanguageRow(y: langRowY)

        // テーマ行 (上から238)
        let themeRowY = totalHeight - 238 - Self.rowHeight
        setupThemeRow(y: themeRowY)
    }

    private func setupLanguageRow(y: CGFloat) {
        let label = NSTextField(labelWithString: L("management.language"))
        label.frame = NSRect(x: Self.popupLabelX, y: y, width: Self.popupLabelWidth, height: Self.rowHeight)
        label.font = .systemFont(ofSize: Self.labelFontSize)
        addSubview(label)

        let popup = NSPopUpButton(frame: NSRect(x: Self.popupX, y: y - 2, width: Self.popupWidth, height: Self.rowHeight + 4))
        for lang in Language.allCases {
            popup.addItem(withTitle: lang.displayName)
            popup.lastItem?.tag = Language.allCases.firstIndex(of: lang) ?? 0
        }
        popup.target = self
        popup.action = #selector(languageChanged(_:))
        addSubview(popup)
        languagePopup = popup
    }

    private func setupThemeRow(y: CGFloat) {
        let label = NSTextField(labelWithString: L("management.theme"))
        label.frame = NSRect(x: Self.popupLabelX, y: y, width: Self.popupLabelWidth, height: Self.rowHeight)
        label.font = .systemFont(ofSize: Self.labelFontSize)
        addSubview(label)

        let popup = NSPopUpButton(frame: NSRect(x: Self.popupX, y: y - 2, width: Self.popupWidth, height: Self.rowHeight + 4))
        for theme in AppTheme.allCases {
            popup.addItem(withTitle: theme.displayName)
            popup.lastItem?.tag = AppTheme.allCases.firstIndex(of: theme) ?? 0
        }
        popup.target = self
        popup.action = #selector(themeChanged(_:))
        addSubview(popup)
        themePopup = popup
    }

    private func setupHotkeySection(totalHeight: CGFloat) {
        // セパレータ (上から270)
        let sep3Y = totalHeight - 270 - Self.separatorHeight
        addSeparator(y: sep3Y)

        // "ホットキー" ヘッダ (上から284)
        let headerY = totalHeight - 284 - Self.rowHeight
        addSectionHeader(title: L("management.hotkey_section"), x: Self.sectionHeaderX, y: headerY)

        // ホットキー行 (上から312, 338, 364)
        let hotkeys: [(HotkeyAction, CGFloat)] = [
            (.toggleVisibility, 312),
            (.toggleGhostMode, 338),
            (.managementPanel, 364)
        ]
        for (action, topOffset) in hotkeys {
            let rowY = totalHeight - topOffset - Self.rowHeight
            setupHotkeyRow(action: action, y: rowY)
        }

        // [すべてリセット] ボタン (上から400)
        let resetAllY = totalHeight - 400 - Self.resetAllButtonHeight
        let resetAllButton = NSButton(frame: NSRect(
            x: Self.resetAllButtonX,
            y: resetAllY,
            width: Self.resetAllButtonWidth,
            height: Self.resetAllButtonHeight
        ))
        resetAllButton.bezelStyle = .rounded
        resetAllButton.title = L("management.reset_all_hotkeys")
        resetAllButton.isEnabled = false
        addSubview(resetAllButton)
    }

    private func setupHotkeyRow(action: HotkeyAction, y: CGFloat) {
        // アクション名ラベル
        let nameLabel = NSTextField(labelWithString: action.displayName)
        nameLabel.frame = NSRect(x: Self.hotkeyLabelX, y: y, width: Self.hotkeyLabelWidth, height: Self.rowHeight)
        nameLabel.font = .systemFont(ofSize: Self.labelFontSize)
        addSubview(nameLabel)

        // キー表示ラベル
        let keyLabel = NSTextField(labelWithString: HotkeyManager.shared.binding(for: action).displayString)
        keyLabel.frame = NSRect(x: Self.hotkeyKeyLabelX, y: y, width: Self.hotkeyKeyLabelWidth, height: Self.rowHeight)
        keyLabel.font = .monospacedSystemFont(ofSize: Self.labelFontSize, weight: .regular)
        keyLabel.alignment = .center
        keyLabel.wantsLayer = true
        keyLabel.layer?.cornerRadius = 4
        keyLabel.layer?.borderWidth = 1
        keyLabel.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(keyLabel)
        hotkeyKeyLabels[action] = keyLabel

        // [記録] ボタン (Phase 9で有効化)
        let recordButton = NSButton(frame: NSRect(
            x: Self.hotkeyRecordButtonX,
            y: y + 2,
            width: Self.hotkeyButtonWidth,
            height: Self.hotkeyButtonHeight
        ))
        recordButton.bezelStyle = .rounded
        recordButton.title = L("management.record")
        recordButton.isEnabled = false
        addSubview(recordButton)

        // [リセット] ボタン (Phase 9で有効化)
        let resetButton = NSButton(frame: NSRect(
            x: Self.hotkeyResetButtonX,
            y: y + 2,
            width: Self.hotkeyButtonWidth,
            height: Self.hotkeyButtonHeight
        ))
        resetButton.bezelStyle = .rounded
        resetButton.title = L("management.reset")
        resetButton.isEnabled = false
        addSubview(resetButton)
    }

    // MARK: - Helper Factories

    private func addSectionHeader(title: String, x: CGFloat, y: CGFloat) {
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: x, y: y, width: 200, height: Self.rowHeight)
        label.font = .systemFont(ofSize: Self.sectionHeaderFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        addSubview(label)
    }

    private func addSeparator(y: CGFloat) {
        let sep = NSBox(frame: NSRect(
            x: Self.separatorInset,
            y: y,
            width: bounds.width - Self.separatorInset * 2,
            height: Self.separatorHeight
        ))
        sep.boxType = .separator
        addSubview(sep)
    }

    private func makeCheckbox(title: String, x: CGFloat, y: CGFloat, action: Selector) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: action)
        checkbox.frame = NSRect(x: x, y: y, width: 300, height: Self.rowHeight)
        return checkbox
    }

    // MARK: - Public API

    func syncWithCurrentSettings() {
        // ログイン時起動
        let isLoginEnabled = LaunchAtLoginManager.shared.isEnabled
        launchAtLoginCheckbox?.state = isLoginEnabled ? .on : .off

        // スナップ配置
        let isSnapEnabled = UserDefaults.standard.bool(forKey: AppConstants.snapEnabledKey)
        snapEnabledCheckbox?.state = isSnapEnabled ? .on : .off

        // ゴーストモードα値
        let alpha = GhostModeSettings.globalAlpha
        ghostAlphaSlider?.doubleValue = Double(alpha)
        ghostAlphaPercentLabel?.stringValue = FormatUtils.formatOpacity(alpha)

        // 言語
        let currentLang = LanguageManager.shared.currentLanguage
        if let idx = Language.allCases.firstIndex(of: currentLang) {
            languagePopup?.selectItem(at: idx)
        }

        // テーマ
        let currentTheme = AppThemeSettings.currentTheme
        if let idx = AppTheme.allCases.firstIndex(of: currentTheme) {
            themePopup?.selectItem(at: idx)
        }

        // ホットキー表示の更新
        for action in HotkeyAction.allCases {
            hotkeyKeyLabels[action]?.stringValue = HotkeyManager.shared.binding(for: action).displayString
        }
    }

    // MARK: - Actions

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        do {
            try LaunchAtLoginManager.shared.toggle()
        } catch {
            // エラー時はシステム設定のログイン項目画面を開く
            SMAppService.openSystemSettingsLoginItems()
            // UIを現在の実際の状態に戻す
            sender.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        }
    }

    @objc private func snapEnabledChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: AppConstants.snapEnabledKey)
    }

    @objc private func ghostAlphaChanged(_ sender: NSSlider) {
        let newValue = CGFloat(sender.doubleValue)
        GhostModeSettings.globalAlpha = newValue
        ghostAlphaPercentLabel?.stringValue = FormatUtils.formatOpacity(newValue)
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0, idx < Language.allCases.count else { return }
        let lang = Language.allCases[idx]
        LanguageManager.shared.currentLanguage = lang
    }

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0, idx < AppTheme.allCases.count else { return }
        let theme = AppTheme.allCases[idx]
        AppThemeSettings.currentTheme = theme
    }
}
