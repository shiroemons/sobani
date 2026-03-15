import Cocoa

// MARK: - ManagementPanelLayoutView + Setup

extension ManagementPanelLayoutView {

    // MARK: - View Setup

    func setupView() {
        setupLeftPane()
        setupDivider()
        setupRightPane()
    }

    func setupLeftPane() {
        let leftWidth = Self.leftPaneWidth
        let buttonBarHeight = Self.buttonBarHeight
        let contentHeight = bounds.height - buttonBarHeight

        let scrollFrame = NSRect(x: 0, y: buttonBarHeight, width: leftWidth, height: contentHeight)
        let scroll = NSScrollView(frame: scrollFrame)
        scroll.autoresizingMask = [.height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        addSubview(scroll)
        presetScrollView = scroll

        let table = NSTableView(frame: scroll.bounds)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = Self.listRowHeight
        table.selectionHighlightStyle = .regular
        table.backgroundColor = .clear
        table.headerView = nil

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("preset"))
        column.width = leftWidth
        table.addTableColumn(column)

        scroll.documentView = table
        presetTableView = table

        setupButtonBar(height: buttonBarHeight, width: leftWidth)
    }

    func setupButtonBar(height: CGFloat, width: CGFloat) {
        let barFrame = NSRect(x: 0, y: 0, width: width, height: height)
        let bar = NSView(frame: barFrame)
        bar.autoresizingMask = [.width]
        addSubview(bar)

        let saveButton = NSButton(frame: NSRect(
            x: Self.saveButtonX,
            y: Self.buttonBarButtonY,
            width: Self.buttonBarButtonWidth,
            height: Self.buttonBarButtonHeight
        ))
        saveButton.bezelStyle = .recessed
        saveButton.controlSize = .small
        saveButton.title = L("management.save_layout")
        saveButton.target = self
        saveButton.action = #selector(saveButtonTapped)
        bar.addSubview(saveButton)

        let newButton = NSButton(frame: NSRect(
            x: Self.newButtonX,
            y: Self.buttonBarButtonY,
            width: Self.buttonBarButtonWidth,
            height: Self.buttonBarButtonHeight
        ))
        newButton.bezelStyle = .recessed
        newButton.controlSize = .small
        newButton.title = L("management.new_layout")
        newButton.target = self
        newButton.action = #selector(newButtonTapped)
        bar.addSubview(newButton)
    }

    func setupDivider() {
        let leftWidth = Self.leftPaneWidth
        let divider = NSBox(frame: NSRect(x: leftWidth, y: 0, width: 1, height: bounds.height))
        divider.boxType = .separator
        addSubview(divider)
    }

    func setupRightPane() {
        let leftWidth = Self.leftPaneWidth
        let rightX = leftWidth + 1
        let rightWidth = bounds.width - rightX
        let rightHeight = bounds.height

        let pane = NSView(frame: NSRect(x: rightX, y: 0, width: rightWidth, height: rightHeight))
        addSubview(pane)

        let label = NSTextField(labelWithString: L("management.select_preset"))
        label.font = .systemFont(ofSize: Self.detailLabelFontSize)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.sizeToFit()
        label.frame = NSRect(
            x: (rightWidth - label.frame.width) / 2,
            y: (rightHeight - label.frame.height) / 2,
            width: label.frame.width,
            height: label.frame.height
        )
        pane.addSubview(label)
        emptyLabel = label

        let container = NSView(frame: NSRect(x: 0, y: 0, width: rightWidth, height: rightHeight))
        container.isHidden = true
        pane.addSubview(container)
        detailContainer = container

        setupDetailContent(in: container, width: rightWidth, height: rightHeight)
    }

    func setupDetailContent(in container: NSView, width: CGFloat, height: CGFloat) {
        let padding = Self.detailPadding
        let contentWidth = width - padding * 2

        let nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = .systemFont(ofSize: Self.presetNameFontSize, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.frame = NSRect(x: padding, y: height - padding - 22, width: contentWidth, height: 22)
        container.addSubview(nameLabel)
        presetNameLabel = nameLabel

        let infoLabel = NSTextField(labelWithString: "")
        infoLabel.font = .systemFont(ofSize: Self.detailSubLabelFontSize)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.frame = NSRect(x: padding, y: height - padding - 22 - 4 - 16, width: contentWidth, height: 16)
        container.addSubview(infoLabel)
        presetInfoLabel = infoLabel

        let countLabel = NSTextField(labelWithString: "")
        countLabel.font = .systemFont(ofSize: Self.detailSubLabelFontSize)
        countLabel.textColor = .secondaryLabelColor
        countLabel.frame = NSRect(x: padding, y: height - padding - 22 - 4 - 16 - 4 - 16, width: contentWidth, height: 16)
        container.addSubview(countLabel)
        windowCountLabel = countLabel

        let listTopY = height - padding - 22 - 4 - 16 - 4 - 16 - 8
        let actionBarHeight: CGFloat = Self.actionButtonHeight + Self.actionButtonY * 2
        let listHeight = listTopY - actionBarHeight - padding
        let listFrame = NSRect(x: padding, y: actionBarHeight + padding, width: contentWidth, height: listHeight)
        setupWindowStateList(in: container, frame: listFrame)

        setupActionButtons(in: container, y: Self.actionButtonY, padding: padding)
    }

    func setupWindowStateList(in container: NSView, frame: NSRect) {
        let scroll = NSScrollView(frame: frame)
        scroll.hasVerticalScroller = true
        scroll.borderType = .lineBorder
        container.addSubview(scroll)

        let table = NSTableView(frame: scroll.bounds)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = Self.detailRowHeight
        table.selectionHighlightStyle = .none
        table.backgroundColor = .clear
        table.headerView = nil
        table.tag = 1

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("windowState"))
        column.width = frame.width - 3
        table.addTableColumn(column)

        scroll.documentView = table
        windowStateTableView = table
    }

    func setupActionButtons(in container: NSView, y: CGFloat, padding: CGFloat) {
        struct ButtonSpec {
            let key: String
            let action: Selector
        }
        let specs: [ButtonSpec] = [
            ButtonSpec(key: "management.apply_layout", action: #selector(applyButtonTapped)),
            ButtonSpec(key: "management.update_layout", action: #selector(updateButtonTapped)),
            ButtonSpec(key: "management.rename_layout", action: #selector(renameButtonTapped)),
            ButtonSpec(key: "management.delete_layout", action: #selector(deleteButtonTapped))
        ]
        var buttons: [NSButton] = []
        var currentX = padding
        for spec in specs {
            let button = NSButton(frame: NSRect(
                x: currentX, y: y,
                width: Self.actionButtonWidth,
                height: Self.actionButtonHeight
            ))
            button.bezelStyle = .recessed
            button.controlSize = .small
            button.title = L(spec.key)
            button.target = self
            button.action = spec.action
            container.addSubview(button)
            buttons.append(button)
            currentX += Self.actionButtonWidth + Self.actionButtonSpacing
        }
        if buttons.count >= 4 {
            applyButton = buttons[0]
            updateButton = buttons[1]
            renameButton = buttons[2]
            deleteButton = buttons[3]
        }
    }

    // MARK: - Detail Helpers

    func updateDetailVisibility() {
        let hasSelection = selectedPreset != nil
        emptyLabel?.isHidden = hasSelection
        detailContainer?.isHidden = !hasSelection
    }

    func updateDetailContent() {
        guard let preset = selectedPreset else { return }
        presetNameLabel?.stringValue = preset.name
        let formatter = DateFormatter()
        formatter.dateFormat = Self.shortDateFormat
        let dateString = formatter.string(from: preset.createdAt)
        presetInfoLabel?.stringValue = String(format: L("management.created_at_format"), dateString)
        windowCountLabel?.stringValue = String(format: L("management.window_count_format"), preset.states.count)
        windowStateTableView?.reloadData()
    }

    func shortDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Self.shortDateFormat
        return formatter.string(from: date)
    }

    func selectPresetByName(_ name: String) {
        guard let index = presets.firstIndex(where: { $0.name == name }) else { return }
        presetTableView?.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        selectedPreset = presets[index]
        windowStateTableView?.reloadData()
        updateDetailVisibility()
        updateDetailContent()
    }

    // MARK: - Dialog Helpers

    func promptPresetName(
        messageText: String,
        informativeText: String,
        okTitle: String,
        initialValue: String = "",
        checkOverwrite: Bool = true
    ) -> String? {
        let alert = AlertFactory.make(
            style: .informational,
            messageText: messageText,
            informativeText: informativeText,
            buttonTitles: [okTitle, L("quit.cancel")]
        )
        let textField = NSTextField(frame: NSRect(
            x: 0, y: 0,
            width: AppConstants.layoutDialogFieldWidth,
            height: AppConstants.layoutDialogFieldHeight
        ))
        textField.placeholderString = L("layout.name_placeholder")
        if !initialValue.isEmpty {
            textField.stringValue = initialValue
        }
        alert.accessoryView = textField
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if checkOverwrite {
            guard confirmOverwriteIfNeeded(name: name) else { return nil }
        }
        return name
    }

    func confirmOverwriteIfNeeded(name: String) -> Bool {
        guard LayoutPresetManager.shared.presetExists(named: name) else { return true }
        let alert = AlertFactory.confirmation(
            messageText: L("layout.overwrite_title"),
            informativeText: String(format: L("layout.overwrite_message"), name),
            okTitle: L("layout.overwrite_button"),
            cancelTitle: L("quit.cancel")
        )
        return alert.runModal() == .alertFirstButtonReturn
    }
}
