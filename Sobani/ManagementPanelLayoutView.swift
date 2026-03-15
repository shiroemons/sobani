import Cocoa
import os.log

// MARK: - ManagementPanelLayoutView

@MainActor
final class ManagementPanelLayoutView: NSView, NSTableViewDataSource, NSTableViewDelegate {

    // MARK: - Layout Constants

    static let leftPaneWidth: CGFloat = AppConstants.managementPanelListWidth
    static let buttonBarHeight: CGFloat = AppConstants.managementPanelBulkBarHeight
    static let listRowHeight: CGFloat = AppConstants.managementPanelLayoutRowHeight
    static let detailRowHeight: CGFloat = 28
    static let saveButtonX: CGFloat = 8
    static let newButtonX: CGFloat = 122
    static let buttonBarButtonWidth: CGFloat = 110
    static let buttonBarButtonHeight: CGFloat = 28
    static let buttonBarButtonY: CGFloat = 6
    static let detailLabelFontSize: CGFloat = 12
    static let detailSubLabelFontSize: CGFloat = 10
    static let actionButtonWidth: CGFloat = 72
    static let actionButtonHeight: CGFloat = 26
    static let actionButtonSpacing: CGFloat = 4
    static let actionButtonY: CGFloat = 8
    static let detailPadding: CGFloat = 12
    static let presetNameFontSize: CGFloat = 14
    static let shortDateFormat: String = "M/dd HH:mm"

    // MARK: - Callbacks

    var onApplyLayout: ((LayoutPreset) -> Void)?
    var onSaveLayout: ((String) -> Void)?
    var onCreateNewLayout: (() -> Void)?
    var onUpdateLayout: ((LayoutPreset) -> Void)?
    var onDeleteLayout: ((LayoutPreset) -> Void)?
    var onRenameLayout: ((LayoutPreset, String) -> Void)?

    // MARK: - Internal State

    let logger = Logger(category: "ManagementPanelLayoutView")
    var presets: [LayoutPreset] = []
    var selectedPreset: LayoutPreset?

    // Left pane
    var presetTableView: NSTableView?
    var presetScrollView: NSScrollView?

    // Right pane
    var emptyLabel: NSTextField?
    var detailContainer: NSView?
    var presetNameLabel: NSTextField?
    var presetInfoLabel: NSTextField?
    var windowCountLabel: NSTextField?
    var windowStateTableView: NSTableView?
    var applyButton: NSButton?
    var updateButton: NSButton?
    var renameButton: NSButton?
    var deleteButton: NSButton?

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Public API

    func reloadPresets() {
        presets = LayoutPresetManager.shared.loadPresets()

        if let selected = selectedPreset,
           let updated = presets.first(where: { $0.name == selected.name }) {
            selectedPreset = updated
        } else {
            selectedPreset = nil
        }

        presetTableView?.reloadData()
        windowStateTableView?.reloadData()
        updateDetailVisibility()
        updateDetailContent()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView.tag == 1 {
            return selectedPreset?.states.count ?? 0
        }
        return presets.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView.tag == 1 {
            return buildWindowStateCell(for: row)
        }
        return buildPresetCell(for: row)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView,
              table !== windowStateTableView else { return }
        let row = table.selectedRow
        if row >= 0, row < presets.count {
            selectedPreset = presets[row]
        } else {
            selectedPreset = nil
        }
        windowStateTableView?.reloadData()
        updateDetailVisibility()
        updateDetailContent()
    }

    // MARK: - Actions

    @objc func saveButtonTapped() {
        guard let name = promptPresetName(
            messageText: L("layout.save_title"),
            informativeText: L("layout.save_message"),
            okTitle: L("layout.save_button")
        ) else { return }
        onSaveLayout?(name)
        reloadPresets()
        selectPresetByName(name)
    }

    @objc func newButtonTapped() {
        onCreateNewLayout?()
    }

    @objc func applyButtonTapped() {
        guard let preset = selectedPreset else { return }
        onApplyLayout?(preset)
    }

    @objc func updateButtonTapped() {
        guard let preset = selectedPreset else { return }
        let alert = AlertFactory.confirmation(
            messageText: L("layout.overwrite_title"),
            informativeText: String(format: L("layout.update_confirm_message"), preset.name),
            okTitle: L("layout.overwrite_button"),
            cancelTitle: L("quit.cancel")
        )
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        onUpdateLayout?(preset)
        reloadPresets()
        selectPresetByName(preset.name)
    }

    @objc func renameButtonTapped() {
        guard let preset = selectedPreset else { return }
        guard let newName = promptPresetName(
            messageText: L("layout.rename_title"),
            informativeText: L("layout.rename_message"),
            okTitle: L("layout.rename_button"),
            initialValue: preset.name,
            checkOverwrite: false
        ) else { return }
        guard newName != preset.name else { return }
        guard confirmOverwriteIfNeeded(name: newName) else { return }
        onRenameLayout?(preset, newName)
        reloadPresets()
        selectPresetByName(newName)
    }

    @objc func deleteButtonTapped() {
        guard let preset = selectedPreset else { return }
        let alert = AlertFactory.confirmation(
            messageText: L("layout.delete_confirm_title"),
            informativeText: String(format: L("layout.delete_confirm_message"), preset.name),
            okTitle: L("layout.delete_button"),
            cancelTitle: L("quit.cancel")
        )
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        onDeleteLayout?(preset)
        selectedPreset = nil
        reloadPresets()
    }
}
