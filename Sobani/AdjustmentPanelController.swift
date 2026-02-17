import Cocoa

// MARK: - Adjustment Panel Delegate

protocol AdjustmentPanelDelegate: AnyObject {
    func rotationPanel(_ panel: AdjustmentPanelController, didChangeAngle angle: CGFloat)
    func rotationPanelDidReset(_ panel: AdjustmentPanelController)
}

// MARK: - Rotation Dial View

class RotationDialView: NSView {
    private let scrollSensitivity: CGFloat = 0.5
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
        var newAngle = angle + delta * scrollSensitivity
        newAngle = newAngle.truncatingRemainder(dividingBy: 360)
        if newAngle < 0 { newAngle += 360 }
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
        degrees = degrees.truncatingRemainder(dividingBy: 360)
        if degrees < 0 { degrees += 360 }
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

    func show(near window: NSWindow, currentAngle angle: CGFloat) {
        currentAngle = angle
        close()

        let panelWidth: CGFloat = 220
        let panelHeight: CGFloat = 160
        let panelRect = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        let newPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "回転"
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

        // Dial view (left side)
        let dial = RotationDialView(frame: NSRect(x: 10, y: 40, width: 90, height: 90))
        dial.angle = angle
        dial.onAngleChanged = { [weak self] newAngle in
            self?.angleChanged(newAngle)
        }
        contentView.addSubview(dial)
        dialView = dial

        // "角度:" label
        let label = NSTextField(labelWithString: "角度:")
        label.frame = NSRect(x: 110, y: 100, width: 40, height: 20)
        label.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(label)

        // Text field
        let field = NSTextField(frame: NSRect(x: 150, y: 98, width: 50, height: 22))
        field.stringValue = formatAngle(angle)
        field.alignment = .right
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        field.target = self
        field.action = #selector(textFieldChanged(_:))
        contentView.addSubview(field)
        textField = field

        // "°" label
        let degreeLabel = NSTextField(labelWithString: "°")
        degreeLabel.frame = NSRect(x: 202, y: 100, width: 15, height: 20)
        degreeLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(degreeLabel)

        // Reset button
        let resetButton = NSButton(title: "リセット", target: self, action: #selector(resetAngle))
        resetButton.frame = NSRect(x: 110, y: 60, width: 90, height: 28)
        resetButton.bezelStyle = .rounded
        resetButton.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(resetButton)

        newPanel.contentView = contentView
        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel
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
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func updateAngle(_ angle: CGFloat) {
        currentAngle = angle
        dialView?.angle = angle
        textField?.stringValue = formatAngle(angle)
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
        degrees = degrees.truncatingRemainder(dividingBy: 360)
        if degrees < 0 { degrees += 360 }
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

    private func formatAngle(_ angle: CGFloat) -> String {
        if angle == angle.rounded() {
            return String(format: "%.0f", angle)
        }
        return String(format: "%.1f", angle)
    }
}
