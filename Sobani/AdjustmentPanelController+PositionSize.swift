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
            x: SectionLayout.labelX, y: PositionSizeLayout.monitorLabelY,
            width: PositionSizeLayout.monitorLabelWidth, height: SectionLayout.labelHeight
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

    private static let firstColumn = (labelX: PositionSizeLayout.firstAxisLabelX, inputX: PositionSizeLayout.firstInputX)
    private static let secondColumn = (labelX: PositionSizeLayout.secondAxisLabelX, inputX: PositionSizeLayout.secondInputX)

    private func setupPositionRow(in contentView: NSView) {
        let y = PositionSizeLayout.positionRowY
        addLabel(L("adjust.position"), x: SectionLayout.labelX, y: y, width: SectionLayout.titleLabelWidth, to: contentView)
        xField = addAxisInput("X", column: Self.firstColumn, y: y, action: #selector(xFieldChanged(_:)), to: contentView)
        yField = addAxisInput("Y", column: Self.secondColumn, y: y, action: #selector(yFieldChanged(_:)), to: contentView)
    }

    private func setupSizeRow(in contentView: NSView) {
        let y = PositionSizeLayout.sizeRowY
        addLabel(L("adjust.size"), x: SectionLayout.labelX, y: y, width: SectionLayout.titleLabelWidth, to: contentView)
        wField = addAxisInput("W", column: Self.firstColumn, y: y, action: #selector(wFieldChanged(_:)), to: contentView)
        hField = addAxisInput("H", column: Self.secondColumn, y: y, action: #selector(hFieldChanged(_:)), to: contentView)
    }

    private func addLabel(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, to contentView: NSView) {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: x, y: y, width: width, height: SectionLayout.labelHeight)
        label.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(label)
    }

    /// 軸ラベル（X/Y/W/H）と数値入力欄を置き、入力欄を返す
    private func addAxisInput(
        _ axis: String, column: (labelX: CGFloat, inputX: CGFloat), y: CGFloat,
        action: Selector, to contentView: NSView
    ) -> NSTextField {
        addLabel(axis, x: column.labelX, y: y, width: SectionLayout.unitLabelWidth, to: contentView)
        let input = NSTextField(frame: NSRect(
            x: column.inputX, y: y - SectionLayout.inputYOffset,
            width: PositionSizeLayout.inputWidth, height: SectionLayout.inputHeight
        ))
        input.alignment = .right
        input.font = NSFont.monospacedDigitSystemFont(ofSize: SectionLayout.labelFontSize, weight: .regular)
        input.target = self
        input.action = action
        contentView.addSubview(input)
        return input
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
        guard let value = FormatUtils.parseFiniteNumber(sender.stringValue) else {
            updatePositionFields()
            return
        }
        let currentRelative = Self.globalToMonitorRelative(
            currentPosition, screenOrigin: screen.frame.origin)
        let relative = Self.updatedRelativePosition(
            newAxisValue: value, currentRelative: currentRelative, isXField: isXField
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
        guard let value = FormatUtils.parseFiniteNumber(sender.stringValue) else {
            updateSizeFields()
            return
        }
        guard let newSize = Self.clampedSize(
            newValue: value, aspectRatio: currentAspectRatio, isWidth: isWidth) else {
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

    /// サイズと縦横比を更新する。クロップや画像変更で縦横比が変わるため、W/H 入力の換算にも反映する。
    func updateSize(_ size: CGSize, aspectRatio: CGFloat) {
        currentSize = size
        currentAspectRatio = aspectRatio
        updateSizeFields()
    }

    /// ウィンドウのあるディスプレイに合わせてモニター選択と位置欄を更新する。
    ///
    /// ドラッグ中は移動のたびに呼ばれるため、ポップアップの作り直しは
    /// ディスプレイが変わったとき（または接続数が変わったとき）だけ行う。
    func updateMonitor(_ window: NSWindow) {
        let screen = NSScreen.screen(containing: window.frame)
        if screen != currentScreen || monitorPopup?.numberOfItems != NSScreen.screens.count {
            currentScreen = screen
            populateMonitorPopup()
            updateResolutionLabel()
        }
        updatePositionFields()
    }

    // MARK: Field Update Helpers

    func updatePositionFields() {
        guard let screen = currentScreen else { return }
        let relative = Self.globalToMonitorRelative(
            currentPosition, screenOrigin: screen.frame.origin)
        xField?.stringValue = FormatUtils.integerString(relative.x)
        yField?.stringValue = FormatUtils.integerString(relative.y)
    }

    func updateSizeFields() {
        wField?.stringValue = FormatUtils.integerString(currentSize.width)
        hField?.stringValue = FormatUtils.integerString(currentSize.height)
    }
}
