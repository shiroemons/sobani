import Cocoa

// MARK: - Adjustment Panel Delegate

/// 調整パネルでの変更を CharacterWindow に通知するプロトコル
protocol AdjustmentPanelDelegate: AnyObject {
    /// 回転角度が変更された
    func rotationPanel(_ panel: AdjustmentPanelController, didChangeAngle angle: CGFloat)
    /// 回転角度がリセットされた
    func rotationPanelDidReset(_ panel: AdjustmentPanelController)
    /// 不透明度が変更された
    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangeOpacity opacity: CGFloat)
    /// 不透明度がリセットされた
    func adjustmentPanelDidResetOpacity(_ panel: AdjustmentPanelController)
}

// MARK: - Rotation Dial View

class RotationDialView: NSView {
    private let scrollSensitivity: CGFloat = AppConstants.dialScrollSensitivity
    var angle: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    var onAngleChanged: ((CGFloat) -> Void)?
    private var isTracking = false

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 4

        // Outer circle
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(1.5)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.strokePath()

        // Tick marks every 45 degrees
        context.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
        context.setLineWidth(1)
        for tick in 0..<8 {
            let tickAngle = CGFloat(tick) * .pi / 4
            let innerRadius = radius - 6
            let outerRadius = radius - 1
            let startPoint = CGPoint(
                x: center.x + innerRadius * cos(tickAngle),
                y: center.y + innerRadius * sin(tickAngle)
            )
            let endPoint = CGPoint(
                x: center.x + outerRadius * cos(tickAngle),
                y: center.y + outerRadius * sin(tickAngle)
            )
            context.move(to: startPoint)
            context.addLine(to: endPoint)
        }
        context.strokePath()

        // Indicator line (0° = top, clockwise)
        let drawRadians = (90 - angle) * .pi / 180
        let indicatorEnd = CGPoint(
            x: center.x + (radius - 8) * cos(drawRadians),
            y: center.y + (radius - 8) * sin(drawRadians)
        )
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(2)
        context.move(to: center)
        context.addLine(to: indicatorEnd)
        context.strokePath()

        // Center dot
        let dotSize: CGFloat = 4
        context.setFillColor(NSColor.controlAccentColor.cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - dotSize / 2,
            y: center.y - dotSize / 2,
            width: dotSize,
            height: dotSize
        ))
    }

    override func mouseDown(with event: NSEvent) {
        isTracking = true
        updateAngle(from: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isTracking else { return }
        updateAngle(from: event)
    }

    override func mouseUp(with event: NSEvent) {
        isTracking = false
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        if delta == 0 { return }
        let newAngle = GeometryUtils.normalizeAngle(angle + delta * scrollSensitivity)
        angle = newAngle
        onAngleChanged?(angle)
    }

    private func updateAngle(from event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y
        let mathDegrees = atan2(deltaY, deltaX) * 180 / .pi
        // Convert: 0° = top, clockwise
        var degrees = 90 - mathDegrees
        // Snap to 5-degree increments
        degrees = (degrees / 5).rounded() * 5
        degrees = GeometryUtils.normalizeAngle(degrees)
        angle = degrees
        onAngleChanged?(angle)
    }
}

// MARK: - Adjustment Panel Controller

class AdjustmentPanelController: NSObject, NSWindowDelegate {
    weak var delegate: AdjustmentPanelDelegate?
    var onClose: (() -> Void)?
    private var panel: NSPanel?
    private var dialView: RotationDialView?
    private var textField: NSTextField?
    private var currentAngle: CGFloat = 0
    private var currentOpacity: CGFloat = 1.0
    private var opacitySlider: NSSlider?
    private var opacityLabel: NSTextField?

    func show(near window: NSWindow, currentAngle angle: CGFloat, currentOpacity opacity: CGFloat) {
        currentAngle = angle
        currentOpacity = opacity
        close()

        let panelWidth: CGFloat = 220
        let panelHeight: CGFloat = 280
        let panelRect = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        let newPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.title = L("adjust.panel_title")
        newPanel.level = .modalPanel
        newPanel.isFloatingPanel = true
        newPanel.delegate = self
        newPanel.becomesKeyOnlyIfNeeded = true
        newPanel.hidesOnDeactivate = false
        newPanel.isReleasedWhenClosed = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position near the target window
        let windowFrame = window.frame
        let panelOrigin = NSPoint(
            x: windowFrame.maxX + 8,
            y: windowFrame.midY - panelHeight / 2
        )
        newPanel.setFrameOrigin(panelOrigin)

        let contentView = NSView(frame: panelRect)

        let rotationOffsetY: CGFloat = 120
        setupRotationSection(in: contentView, angle: angle, offsetY: rotationOffsetY)

        // Separator
        let separator = NSBox(frame: NSRect(x: 10, y: 120, width: 200, height: 1))
        separator.boxType = .separator
        contentView.addSubview(separator)

        setupOpacitySection(in: contentView, opacity: opacity)

        newPanel.contentView = contentView
        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel
    }

    private func setupRotationSection(in contentView: NSView, angle: CGFloat, offsetY: CGFloat) {
        // Dial view (left side)
        let dial = RotationDialView(frame: NSRect(x: 10, y: 40 + offsetY, width: 90, height: 90))
        dial.angle = angle
        dial.onAngleChanged = { [weak self] newAngle in
            self?.angleChanged(newAngle)
        }
        contentView.addSubview(dial)
        dialView = dial

        // "角度:" label
        let label = NSTextField(labelWithString: L("adjust.angle"))
        label.frame = NSRect(x: 110, y: 100 + offsetY, width: 40, height: 20)
        label.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(label)

        // Text field
        let field = NSTextField(frame: NSRect(x: 150, y: 98 + offsetY, width: 50, height: 22))
        field.stringValue = formatAngle(angle)
        field.alignment = .right
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        field.target = self
        field.action = #selector(textFieldChanged(_:))
        contentView.addSubview(field)
        textField = field

        // "°" label
        let degreeLabel = NSTextField(labelWithString: L("adjust.degree"))
        degreeLabel.frame = NSRect(x: 202, y: 100 + offsetY, width: 15, height: 20)
        degreeLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(degreeLabel)

        // Reset button
        let resetButton = NSButton(title: L("adjust.reset"), target: self, action: #selector(resetAngle))
        resetButton.frame = NSRect(x: 110, y: 60 + offsetY, width: 90, height: 28)
        resetButton.bezelStyle = .rounded
        resetButton.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(resetButton)
    }

    private func setupOpacitySection(in contentView: NSView, opacity: CGFloat) {
        let opacitySectionLabel = NSTextField(labelWithString: L("adjust.opacity"))
        opacitySectionLabel.frame = NSRect(x: 10, y: 85, width: 50, height: 20)
        opacitySectionLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(opacitySectionLabel)

        let percentLabel = NSTextField(labelWithString: formatOpacity(opacity))
        percentLabel.frame = NSRect(x: 160, y: 85, width: 50, height: 20)
        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        percentLabel.alignment = .right
        contentView.addSubview(percentLabel)
        opacityLabel = percentLabel

        let slider = NSSlider(
            value: Double(opacity),
            minValue: 0.1,
            maxValue: 1.0,
            target: self,
            action: #selector(opacitySliderChanged(_:))
        )
        slider.frame = NSRect(x: 10, y: 58, width: 200, height: 20)
        slider.numberOfTickMarks = 0
        contentView.addSubview(slider)
        opacitySlider = slider

        let opacityResetButton = NSButton(title: L("adjust.reset"), target: self, action: #selector(resetOpacity))
        opacityResetButton.frame = NSRect(x: 110, y: 20, width: 90, height: 28)
        opacityResetButton.bezelStyle = .rounded
        opacityResetButton.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(opacityResetButton)
    }

    func close() {
        panel?.orderOut(nil)
        cleanup()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
        cleanup()
    }

    private func cleanup() {
        panel = nil
        dialView = nil
        textField = nil
        opacitySlider = nil
        opacityLabel = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func updateAngle(_ angle: CGFloat) {
        currentAngle = angle
        dialView?.angle = angle
        textField?.stringValue = formatAngle(angle)
    }

    func updateOpacity(_ opacity: CGFloat) {
        currentOpacity = opacity
        opacitySlider?.doubleValue = Double(opacity)
        opacityLabel?.stringValue = formatOpacity(opacity)
    }

    private func angleChanged(_ newAngle: CGFloat) {
        currentAngle = newAngle
        textField?.stringValue = formatAngle(newAngle)
        delegate?.rotationPanel(self, didChangeAngle: newAngle)
    }

    @objc private func textFieldChanged(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard var degrees = Double(text) else {
            sender.stringValue = formatAngle(currentAngle)
            return
        }
        degrees = GeometryUtils.normalizeAngle(degrees)
        let angle = CGFloat(degrees)
        currentAngle = angle
        dialView?.angle = angle
        sender.stringValue = formatAngle(angle)
        delegate?.rotationPanel(self, didChangeAngle: angle)
    }

    @objc private func resetAngle() {
        currentAngle = 0
        dialView?.angle = 0
        textField?.stringValue = formatAngle(0)
        delegate?.rotationPanelDidReset(self)
    }

    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        let opacity = CGFloat(sender.doubleValue)
        currentOpacity = opacity
        opacityLabel?.stringValue = formatOpacity(opacity)
        delegate?.adjustmentPanel(self, didChangeOpacity: opacity)
    }

    @objc private func resetOpacity() {
        currentOpacity = 1.0
        opacitySlider?.doubleValue = 1.0
        opacityLabel?.stringValue = formatOpacity(1.0)
        delegate?.adjustmentPanelDidResetOpacity(self)
    }

    private func formatAngle(_ angle: CGFloat) -> String {
        let rounded = angle.rounded()
        if abs(angle - rounded) < AppConstants.floatingPointTolerance {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", angle)
    }

    private func formatOpacity(_ opacity: CGFloat) -> String {
        return "\(Int(round(opacity * 100)))%"
    }
}
