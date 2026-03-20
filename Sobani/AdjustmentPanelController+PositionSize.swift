import Cocoa

// MARK: - Position & Size Section

extension AdjustmentPanelController {
    func setupPositionSizeSection(in contentView: NSView) {
        setupMonitorControls(in: contentView)
        setupPositionRow(in: contentView)
        setupSizeRow(in: contentView)

        // Reset button
        let resetButton = NSButton(
            title: L("adjust.reset"),
            target: self,
            action: #selector(resetPositionAndSize)
        )
        resetButton.frame = NSRect(
            x: PositionSizeLayout.resetButtonX, y: PositionSizeLayout.resetButtonY,
            width: SectionLayout.resetButtonWidth, height: SectionLayout.resetButtonHeight
        )
        resetButton.bezelStyle = .rounded
        resetButton.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(resetButton)

        updatePositionFields()
        updateSizeFields()
    }

    private func setupMonitorControls(in contentView: NSView) {
        let monitorLabel = NSTextField(labelWithString: L("adjust.monitor"))
        monitorLabel.frame = NSRect(
            x: SectionLayout.labelX, y: PositionSizeLayout.monitorLabelY, width: 60, height: 20
        )
        monitorLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(monitorLabel)

        let popup = NSPopUpButton(frame: NSRect(
            x: PositionSizeLayout.monitorPopupX, y: PositionSizeLayout.monitorPopupY,
            width: PositionSizeLayout.monitorPopupWidth,
            height: PositionSizeLayout.monitorPopupHeight
        ), pullsDown: false)
        popup.font = NSFont.systemFont(ofSize: PositionSizeLayout.monitorPopupFontSize)
        popup.target = self
        popup.action = #selector(monitorPopupChanged(_:))
        contentView.addSubview(popup)
        monitorPopup = popup
        populateMonitorPopup()

        let resLabel = NSTextField(labelWithString: "")
        resLabel.frame = NSRect(
            x: PositionSizeLayout.monitorPopupX, y: PositionSizeLayout.resolutionLabelY,
            width: PositionSizeLayout.monitorPopupWidth,
            height: PositionSizeLayout.resolutionLabelHeight
        )
        resLabel.font = NSFont.systemFont(ofSize: PositionSizeLayout.resolutionLabelFontSize)
        resLabel.textColor = .secondaryLabelColor
        contentView.addSubview(resLabel)
        resolutionLabel = resLabel
        updateResolutionLabel()
    }

    private func setupPositionRow(in contentView: NSView) {
        let posLabel = NSTextField(labelWithString: L("adjust.position"))
        posLabel.frame = NSRect(
            x: SectionLayout.labelX, y: PositionSizeLayout.positionRowY, width: 40, height: 20
        )
        posLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(posLabel)

        let xLabel = NSTextField(labelWithString: "X")
        xLabel.frame = NSRect(
            x: PositionSizeLayout.firstAxisLabelX, y: PositionSizeLayout.positionRowY,
            width: 15, height: 20
        )
        xLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(xLabel)

        let xInput = NSTextField(frame: NSRect(
            x: PositionSizeLayout.firstInputX, y: PositionSizeLayout.positionRowY - 2,
            width: PositionSizeLayout.inputWidth, height: 22
        ))
        xInput.alignment = .right
        xInput.font = NSFont.monospacedDigitSystemFont(
            ofSize: SectionLayout.labelFontSize, weight: .regular)
        xInput.target = self
        xInput.action = #selector(xFieldChanged(_:))
        contentView.addSubview(xInput)
        xField = xInput

        let yLabel = NSTextField(labelWithString: "Y")
        yLabel.frame = NSRect(
            x: PositionSizeLayout.secondAxisLabelX, y: PositionSizeLayout.positionRowY,
            width: 15, height: 20
        )
        yLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(yLabel)

        let yInput = NSTextField(frame: NSRect(
            x: PositionSizeLayout.secondInputX, y: PositionSizeLayout.positionRowY - 2,
            width: PositionSizeLayout.inputWidth, height: 22
        ))
        yInput.alignment = .right
        yInput.font = NSFont.monospacedDigitSystemFont(
            ofSize: SectionLayout.labelFontSize, weight: .regular)
        yInput.target = self
        yInput.action = #selector(yFieldChanged(_:))
        contentView.addSubview(yInput)
        yField = yInput
    }

    private func setupSizeRow(in contentView: NSView) {
        let sizeLabel = NSTextField(labelWithString: L("adjust.size"))
        sizeLabel.frame = NSRect(
            x: SectionLayout.labelX, y: PositionSizeLayout.sizeRowY, width: 40, height: 20
        )
        sizeLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(sizeLabel)

        let wLabel = NSTextField(labelWithString: "W")
        wLabel.frame = NSRect(
            x: PositionSizeLayout.firstAxisLabelX, y: PositionSizeLayout.sizeRowY,
            width: 15, height: 20
        )
        wLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(wLabel)

        let wInput = NSTextField(frame: NSRect(
            x: PositionSizeLayout.firstInputX, y: PositionSizeLayout.sizeRowY - 2,
            width: PositionSizeLayout.inputWidth, height: 22
        ))
        wInput.alignment = .right
        wInput.font = NSFont.monospacedDigitSystemFont(
            ofSize: SectionLayout.labelFontSize, weight: .regular)
        wInput.target = self
        wInput.action = #selector(wFieldChanged(_:))
        contentView.addSubview(wInput)
        wField = wInput

        let hLabel = NSTextField(labelWithString: "H")
        hLabel.frame = NSRect(
            x: PositionSizeLayout.secondAxisLabelX, y: PositionSizeLayout.sizeRowY,
            width: 15, height: 20
        )
        hLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(hLabel)

        let hInput = NSTextField(frame: NSRect(
            x: PositionSizeLayout.secondInputX, y: PositionSizeLayout.sizeRowY - 2,
            width: PositionSizeLayout.inputWidth, height: 22
        ))
        hInput.alignment = .right
        hInput.font = NSFont.monospacedDigitSystemFont(
            ofSize: SectionLayout.labelFontSize, weight: .regular)
        hInput.target = self
        hInput.action = #selector(hFieldChanged(_:))
        contentView.addSubview(hInput)
        hField = hInput
    }

    // MARK: Coordinate Conversion

    static func globalToMonitorRelative(_ point: CGPoint, screenOrigin: CGPoint) -> CGPoint {
        return CGPoint(x: point.x - screenOrigin.x, y: point.y - screenOrigin.y)
    }

    static func monitorRelativeToGlobal(_ point: CGPoint, screenOrigin: CGPoint) -> CGPoint {
        return CGPoint(x: point.x + screenOrigin.x, y: point.y + screenOrigin.y)
    }

    // MARK: Monitor Popup

    func populateMonitorPopup() {
        guard let popup = monitorPopup else { return }
        popup.removeAllItems()
        let screens = NSScreen.screens
        let screenSizes = screens.map { (width: Int($0.frame.width), height: Int($0.frame.height)) }
        let titles = Self.generateMonitorPopupTitles(screenSizes: screenSizes)
        for (index, title) in titles.enumerated() {
            popup.addItem(withTitle: title)
            popup.lastItem?.representedObject = screens[index]
        }
        if let current = currentScreen, let idx = screens.firstIndex(of: current) {
            popup.selectItem(at: idx)
        }
    }

    func updateResolutionLabel() {
        guard let screen = currentScreen else {
            resolutionLabel?.stringValue = ""
            return
        }
        resolutionLabel?.stringValue = Self.formatResolutionLabel(
            width: Int(screen.frame.width), height: Int(screen.frame.height)
        )
    }

    @objc func monitorPopupChanged(_ sender: NSPopUpButton) {
        guard let screen = sender.selectedItem?.representedObject as? NSScreen else { return }
        currentScreen = screen
        updateResolutionLabel()
        updatePositionFields()
        delegate?.adjustmentPanel(self, didSelectMonitor: screen)
    }

    // MARK: Position/Size Field Handlers

    private func handlePositionFieldChanged(_ sender: NSTextField, isXField: Bool) {
        guard let screen = currentScreen else { return }
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard let value = Double(text) else {
            updatePositionFields()
            return
        }
        let currentRelative = Self.globalToMonitorRelative(
            currentPosition, screenOrigin: screen.frame.origin)
        let relative = Self.updatedRelativePosition(
            newAxisValue: CGFloat(value), currentRelative: currentRelative, isXField: isXField
        )
        let global = Self.monitorRelativeToGlobal(relative, screenOrigin: screen.frame.origin)
        currentPosition = global
        delegate?.adjustmentPanel(self, didChangePosition: global)
    }

    @objc func xFieldChanged(_ sender: NSTextField) {
        handlePositionFieldChanged(sender, isXField: true)
    }

    @objc func yFieldChanged(_ sender: NSTextField) {
        handlePositionFieldChanged(sender, isXField: false)
    }

    private func handleSizeFieldChanged(_ sender: NSTextField, isWidth: Bool) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard let value = Double(text) else {
            updateSizeFields()
            return
        }
        guard let newSize = Self.clampedSize(
            newValue: CGFloat(value), aspectRatio: currentAspectRatio, isWidth: isWidth) else {
            updateSizeFields()
            return
        }
        currentSize = newSize
        updateSizeFields()
        delegate?.adjustmentPanel(self, didChangeSize: currentSize)
    }

    @objc func wFieldChanged(_ sender: NSTextField) {
        handleSizeFieldChanged(sender, isWidth: true)
    }

    @objc func hFieldChanged(_ sender: NSTextField) {
        handleSizeFieldChanged(sender, isWidth: false)
    }

    @objc func resetPositionAndSize() {
        delegate?.adjustmentPanelDidResetPositionAndSize(self)
    }

    // MARK: Public Update Methods

    func updatePosition(_ position: CGPoint) {
        currentPosition = position
        updatePositionFields()
    }

    func updateSize(_ size: CGSize) {
        currentSize = size
        updateSizeFields()
    }

    func updateMonitor(_ window: NSWindow) {
        currentScreen = NSScreen.screen(containing: window.frame)
        populateMonitorPopup()
        updateResolutionLabel()
        updatePositionFields()
    }

    // MARK: Field Update Helpers

    func updatePositionFields() {
        guard let screen = currentScreen else { return }
        let relative = Self.globalToMonitorRelative(
            currentPosition, screenOrigin: screen.frame.origin)
        xField?.stringValue = "\(Int(round(relative.x)))"
        yField?.stringValue = "\(Int(round(relative.y)))"
    }

    func updateSizeFields() {
        wField?.stringValue = "\(Int(round(currentSize.width)))"
        hField?.stringValue = "\(Int(round(currentSize.height)))"
    }
}
