import Cocoa

// MARK: - ManagementPanelLayoutView + Cell Building

extension ManagementPanelLayoutView {

    func buildPresetCell(for row: Int) -> NSView? {
        guard row < presets.count else { return nil }
        let preset = presets[row]

        let identifier = NSUserInterfaceItemIdentifier("PresetCell")
        let cellView: NSView
        if let reused = presetTableView?.makeView(withIdentifier: identifier, owner: self) {
            cellView = reused
            cellView.subviews.forEach { $0.removeFromSuperview() }
        } else {
            cellView = NSView()
            cellView.identifier = identifier
        }

        let nameLabel = NSTextField(labelWithString: preset.name)
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.frame = NSRect(x: 8, y: 26, width: Self.leftPaneWidth - 16, height: 16)
        cellView.addSubview(nameLabel)

        let windowCount = preset.states.count
        let dateStr = shortDateString(from: preset.createdAt)
        let infoText = "\(windowCount)件 • \(dateStr)"
        let infoLabel = NSTextField(labelWithString: infoText)
        infoLabel.font = .systemFont(ofSize: 10)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.lineBreakMode = .byTruncatingTail
        infoLabel.frame = NSRect(x: 8, y: 8, width: Self.leftPaneWidth - 16, height: 14)
        cellView.addSubview(infoLabel)

        return cellView
    }

    func buildWindowStateCell(for row: Int) -> NSView? {
        guard let states = selectedPreset?.states, row < states.count else { return nil }
        let state = states[row]

        let identifier = NSUserInterfaceItemIdentifier("WindowStateCell")
        let cellView: NSView
        if let reused = windowStateTableView?.makeView(withIdentifier: identifier, owner: self) {
            cellView = reused
            cellView.subviews.forEach { $0.removeFromSuperview() }
        } else {
            cellView = NSView()
            cellView.identifier = identifier
        }

        let indexLabel = NSTextField(labelWithString: "\(row + 1).")
        indexLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        indexLabel.textColor = .secondaryLabelColor
        indexLabel.frame = NSRect(x: 4, y: 7, width: 20, height: 14)
        cellView.addSubview(indexLabel)

        let nameLabel = NSTextField(labelWithString: state.imageName)
        nameLabel.font = .systemFont(ofSize: 11)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.frame = NSRect(x: 28, y: 7, width: 160, height: 14)
        cellView.addSubview(nameLabel)

        let posText = String(format: "(%.0f, %.0f)", state.originX, state.originY)
        let posLabel = NSTextField(labelWithString: posText)
        posLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        posLabel.textColor = .secondaryLabelColor
        posLabel.alignment = .right
        posLabel.frame = NSRect(x: 192, y: 7, width: 100, height: 14)
        cellView.addSubview(posLabel)

        return cellView
    }
}
