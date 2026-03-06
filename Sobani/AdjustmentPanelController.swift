import Cocoa
import os.log

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
    /// 位置が変更された（グローバル座標）
    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangePosition position: CGPoint)
    /// サイズが変更された（回転前 imageView サイズ）
    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangeSize size: CGSize)
    /// モニターが選択された
    func adjustmentPanel(_ panel: AdjustmentPanelController, didSelectMonitor screen: NSScreen)
    /// 位置・サイズがリセットされた
    func adjustmentPanelDidResetPositionAndSize(_ panel: AdjustmentPanelController)
}

// MARK: - Rotation Dial View

final class RotationDialView: NSView {
    private static let outerPadding: CGFloat = 4
    private static let tickInnerOffset: CGFloat = 6
    private static let tickOuterOffset: CGFloat = 1
    private static let indicatorInset: CGFloat = 8
    private static let centerDotSize: CGFloat = 4
    private static let outerLineWidth: CGFloat = 1.5
    private static let tickLineWidth: CGFloat = 1
    private static let indicatorLineWidth: CGFloat = 2

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
        let radius = min(bounds.width, bounds.height) / 2 - Self.outerPadding

        // Outer circle
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(Self.outerLineWidth)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.strokePath()

        // Tick marks every 45 degrees
        context.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
        context.setLineWidth(Self.tickLineWidth)
        for tick in 0..<8 {
            let tickAngle = CGFloat(tick) * .pi / 4
            let innerRadius = radius - Self.tickInnerOffset
            let outerRadius = radius - Self.tickOuterOffset
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
            x: center.x + (radius - Self.indicatorInset) * cos(drawRadians),
            y: center.y + (radius - Self.indicatorInset) * sin(drawRadians)
        )
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(Self.indicatorLineWidth)
        context.move(to: center)
        context.addLine(to: indicatorEnd)
        context.strokePath()

        // Center dot
        let dotSize: CGFloat = Self.centerDotSize
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
        if abs(delta) < AppConstants.floatingPointTolerance { return }
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

// MARK: - Adjustment Panel State

struct AdjustmentPanelState {
    let angle: CGFloat
    let opacity: CGFloat
    let position: CGPoint
    let size: CGSize
    let aspectRatio: CGFloat
}

// MARK: - Adjustment Panel Controller

final class AdjustmentPanelController: NSObject, NSWindowDelegate {
    private let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "AdjustmentPanelController")
    private static let panelWidth: CGFloat = 220
    private static let panelHeight: CGFloat = 460
    private static let rotationSectionOffsetY: CGFloat = 300
    private static let opacitySectionOffsetY: CGFloat = 180
    private static let panelGap: CGFloat = 8

    weak var delegate: AdjustmentPanelDelegate?
    var onClose: (() -> Void)?
    private var panel: NSPanel?
    private var dialView: RotationDialView?
    private var textField: NSTextField?
    private var currentAngle: CGFloat = 0
    private var currentOpacity: CGFloat = 1.0
    private var opacitySlider: NSSlider?
    private var opacityLabel: NSTextField?
    private var monitorPopup: NSPopUpButton?
    private var resolutionLabel: NSTextField?
    private var xField: NSTextField?
    private var yField: NSTextField?
    private var wField: NSTextField?
    private var hField: NSTextField?
    private var currentPosition: CGPoint = .zero
    private var currentSize: CGSize = .zero
    private var currentScreen: NSScreen?
    private var currentAspectRatio: CGFloat = 1.0

    func show(near window: NSWindow, state: AdjustmentPanelState) {
        currentAngle = state.angle
        currentOpacity = state.opacity
        currentPosition = state.position
        currentSize = state.size
        currentAspectRatio = state.aspectRatio
        currentScreen = NSScreen.screen(containing: window.frame)
        close()

        let panelWidth: CGFloat = Self.panelWidth
        let panelHeight: CGFloat = Self.panelHeight
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
            x: windowFrame.maxX + Self.panelGap,
            y: windowFrame.midY - panelHeight / 2
        )
        newPanel.setFrameOrigin(panelOrigin)

        let contentView = NSView(frame: panelRect)

        let rotationOffsetY: CGFloat = Self.rotationSectionOffsetY
        setupRotationSection(in: contentView, angle: state.angle, offsetY: rotationOffsetY)

        // Separator between rotation and opacity
        let separator1 = NSBox(frame: NSRect(x: 10, y: Self.rotationSectionOffsetY, width: 200, height: 1))
        separator1.boxType = .separator
        contentView.addSubview(separator1)

        setupOpacitySection(in: contentView, opacity: state.opacity, offsetY: Self.opacitySectionOffsetY)

        // Separator between opacity and position/size
        let separator2 = NSBox(frame: NSRect(x: 10, y: Self.opacitySectionOffsetY, width: 200, height: 1))
        separator2.boxType = .separator
        contentView.addSubview(separator2)

        setupPositionSizeSection(in: contentView)

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

    private func setupOpacitySection(in contentView: NSView, opacity: CGFloat, offsetY: CGFloat = 0) {
        let opacitySectionLabel = NSTextField(labelWithString: L("adjust.opacity"))
        opacitySectionLabel.frame = NSRect(x: 10, y: 85 + offsetY, width: 50, height: 20)
        opacitySectionLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(opacitySectionLabel)

        let percentLabel = NSTextField(labelWithString: formatOpacity(opacity))
        percentLabel.frame = NSRect(x: 160, y: 85 + offsetY, width: 50, height: 20)
        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        percentLabel.alignment = .right
        contentView.addSubview(percentLabel)
        opacityLabel = percentLabel

        let slider = NSSlider(
            value: Double(opacity),
            minValue: Double(AppConstants.opacityMin),
            maxValue: Double(AppConstants.opacityMax),
            target: self,
            action: #selector(opacitySliderChanged(_:))
        )
        slider.frame = NSRect(x: 10, y: 58 + offsetY, width: 200, height: 20)
        slider.numberOfTickMarks = 0
        contentView.addSubview(slider)
        opacitySlider = slider

        let opacityResetButton = NSButton(title: L("adjust.reset"), target: self, action: #selector(resetOpacity))
        opacityResetButton.frame = NSRect(x: 110, y: 20 + offsetY, width: 90, height: 28)
        opacityResetButton.bezelStyle = .rounded
        opacityResetButton.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(opacityResetButton)
    }

    // MARK: - Close / Cleanup

    func close() {
        onClose?()
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
        monitorPopup = nil
        resolutionLabel = nil
        xField = nil
        yField = nil
        wField = nil
        hField = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Existing Update Methods

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

    // MARK: - Rotation Handlers

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

    // MARK: - Opacity Handlers

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

    // MARK: - Formatting Helpers

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

// MARK: - Position & Size Section

extension AdjustmentPanelController {
    private func setupPositionSizeSection(in contentView: NSView) {
        // Monitor popup
        let monitorLabel = NSTextField(labelWithString: L("adjust.monitor"))
        monitorLabel.frame = NSRect(x: 10, y: 145, width: 60, height: 20)
        monitorLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(monitorLabel)

        let popup = NSPopUpButton(frame: NSRect(x: 70, y: 143, width: 140, height: 24), pullsDown: false)
        popup.font = NSFont.systemFont(ofSize: 11)
        popup.target = self
        popup.action = #selector(monitorPopupChanged(_:))
        contentView.addSubview(popup)
        monitorPopup = popup
        populateMonitorPopup()

        // Resolution label
        let resLabel = NSTextField(labelWithString: "")
        resLabel.frame = NSRect(x: 70, y: 126, width: 140, height: 16)
        resLabel.font = NSFont.systemFont(ofSize: 10)
        resLabel.textColor = .secondaryLabelColor
        contentView.addSubview(resLabel)
        resolutionLabel = resLabel
        updateResolutionLabel()

        // Position
        let posLabel = NSTextField(labelWithString: L("adjust.position"))
        posLabel.frame = NSRect(x: 10, y: 100, width: 40, height: 20)
        posLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(posLabel)

        let xLabel = NSTextField(labelWithString: "X")
        xLabel.frame = NSRect(x: 55, y: 100, width: 15, height: 20)
        xLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(xLabel)

        let xInput = NSTextField(frame: NSRect(x: 70, y: 98, width: 60, height: 22))
        xInput.alignment = .right
        xInput.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        xInput.target = self
        xInput.action = #selector(xFieldChanged(_:))
        contentView.addSubview(xInput)
        xField = xInput

        let yLabel = NSTextField(labelWithString: "Y")
        yLabel.frame = NSRect(x: 140, y: 100, width: 15, height: 20)
        yLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(yLabel)

        let yInput = NSTextField(frame: NSRect(x: 155, y: 98, width: 60, height: 22))
        yInput.alignment = .right
        yInput.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        yInput.target = self
        yInput.action = #selector(yFieldChanged(_:))
        contentView.addSubview(yInput)
        yField = yInput

        // Size
        let sizeLabel = NSTextField(labelWithString: L("adjust.size"))
        sizeLabel.frame = NSRect(x: 10, y: 70, width: 40, height: 20)
        sizeLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(sizeLabel)

        let wLabel = NSTextField(labelWithString: "W")
        wLabel.frame = NSRect(x: 55, y: 70, width: 15, height: 20)
        wLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(wLabel)

        let wInput = NSTextField(frame: NSRect(x: 70, y: 68, width: 60, height: 22))
        wInput.alignment = .right
        wInput.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        wInput.target = self
        wInput.action = #selector(wFieldChanged(_:))
        contentView.addSubview(wInput)
        wField = wInput

        let hLabel = NSTextField(labelWithString: "H")
        hLabel.frame = NSRect(x: 140, y: 70, width: 15, height: 20)
        hLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(hLabel)

        let hInput = NSTextField(frame: NSRect(x: 155, y: 68, width: 60, height: 22))
        hInput.alignment = .right
        hInput.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        hInput.target = self
        hInput.action = #selector(hFieldChanged(_:))
        contentView.addSubview(hInput)
        hField = hInput

        // Reset button
        let resetButton = NSButton(title: L("adjust.reset"), target: self, action: #selector(resetPositionAndSize))
        resetButton.frame = NSRect(x: 110, y: 20, width: 90, height: 28)
        resetButton.bezelStyle = .rounded
        resetButton.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(resetButton)

        updatePositionFields()
        updateSizeFields()
    }

    // MARK: Coordinate Conversion

    private func globalToMonitorRelative(_ point: CGPoint, screen: NSScreen) -> CGPoint {
        return CGPoint(x: point.x - screen.frame.origin.x, y: point.y - screen.frame.origin.y)
    }

    private func monitorRelativeToGlobal(_ point: CGPoint, screen: NSScreen) -> CGPoint {
        return CGPoint(x: point.x + screen.frame.origin.x, y: point.y + screen.frame.origin.y)
    }

    // MARK: Monitor Popup

    private func populateMonitorPopup() {
        guard let popup = monitorPopup else { return }
        popup.removeAllItems()
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let title = "\(index + 1): \(Int(screen.frame.width))×\(Int(screen.frame.height))"
            popup.addItem(withTitle: title)
            popup.lastItem?.representedObject = screen
        }
        if let current = currentScreen, let idx = screens.firstIndex(of: current) {
            popup.selectItem(at: idx)
        }
    }

    private func updateResolutionLabel() {
        guard let screen = currentScreen else {
            resolutionLabel?.stringValue = ""
            return
        }
        resolutionLabel?.stringValue = "\(Int(screen.frame.width))×\(Int(screen.frame.height))"
    }

    @objc private func monitorPopupChanged(_ sender: NSPopUpButton) {
        guard let screen = sender.selectedItem?.representedObject as? NSScreen else { return }
        currentScreen = screen
        updateResolutionLabel()
        updatePositionFields()
        delegate?.adjustmentPanel(self, didSelectMonitor: screen)
    }

    // MARK: Position/Size Field Handlers

    @objc private func xFieldChanged(_ sender: NSTextField) {
        guard let screen = currentScreen else { return }
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard let value = Double(text) else {
            updatePositionFields()
            return
        }
        let relative = CGPoint(x: CGFloat(value), y: globalToMonitorRelative(currentPosition, screen: screen).y)
        let global = monitorRelativeToGlobal(relative, screen: screen)
        currentPosition = global
        delegate?.adjustmentPanel(self, didChangePosition: global)
    }

    @objc private func yFieldChanged(_ sender: NSTextField) {
        guard let screen = currentScreen else { return }
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard let value = Double(text) else {
            updatePositionFields()
            return
        }
        let relative = CGPoint(x: globalToMonitorRelative(currentPosition, screen: screen).x, y: CGFloat(value))
        let global = monitorRelativeToGlobal(relative, screen: screen)
        currentPosition = global
        delegate?.adjustmentPanel(self, didChangePosition: global)
    }

    @objc private func wFieldChanged(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard let value = Double(text), value > 0 else {
            updateSizeFields()
            return
        }
        guard currentAspectRatio > 0 else {
            updateSizeFields()
            return
        }
        let clampedH = max(AppConstants.minImageHeight, min(AppConstants.maxImageHeight, CGFloat(value) / currentAspectRatio))
        let clampedW = clampedH * currentAspectRatio
        currentSize = CGSize(width: clampedW, height: clampedH)
        updateSizeFields()
        delegate?.adjustmentPanel(self, didChangeSize: currentSize)
    }

    @objc private func hFieldChanged(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard let value = Double(text), value > 0 else {
            updateSizeFields()
            return
        }
        let clampedH = max(AppConstants.minImageHeight, min(AppConstants.maxImageHeight, CGFloat(value)))
        let clampedW = clampedH * currentAspectRatio
        currentSize = CGSize(width: clampedW, height: clampedH)
        updateSizeFields()
        delegate?.adjustmentPanel(self, didChangeSize: currentSize)
    }

    @objc private func resetPositionAndSize() {
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

    private func updatePositionFields() {
        guard let screen = currentScreen else { return }
        let relative = globalToMonitorRelative(currentPosition, screen: screen)
        xField?.stringValue = "\(Int(round(relative.x)))"
        yField?.stringValue = "\(Int(round(relative.y)))"
    }

    private func updateSizeFields() {
        wField?.stringValue = "\(Int(round(currentSize.width)))"
        hField?.stringValue = "\(Int(round(currentSize.height)))"
    }
}
