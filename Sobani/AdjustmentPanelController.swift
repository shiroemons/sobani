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

@MainActor
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

struct AdjustmentPanelState: Sendable {
    let angle: CGFloat
    let opacity: CGFloat
    let position: CGPoint
    let size: CGSize
    let aspectRatio: CGFloat
}

// MARK: - Section Layout Constants

private enum SectionLayout {
    static let labelX: CGFloat = 10
    static let contentWidth: CGFloat = 200
    static let labelFontSize: CGFloat = 12
    static let resetButtonWidth: CGFloat = 90
    static let resetButtonHeight: CGFloat = 28
}

private enum RotationLayout {
    static let dialX: CGFloat = 10
    static let dialRelativeY: CGFloat = 40
    static let dialSize: CGFloat = 90
    static let angleLabelX: CGFloat = 110
    static let angleLabelRelativeY: CGFloat = 100
    static let angleFieldX: CGFloat = 150
    static let angleFieldRelativeY: CGFloat = 98
    static let angleFieldWidth: CGFloat = 50
    static let degreeLabelX: CGFloat = 202
    static let resetButtonX: CGFloat = 110
    static let resetButtonRelativeY: CGFloat = 60
}

private enum OpacityLayout {
    static let labelRelativeY: CGFloat = 85
    static let percentLabelX: CGFloat = 160
    static let sliderRelativeY: CGFloat = 58
    static let resetButtonX: CGFloat = 110
    static let resetButtonRelativeY: CGFloat = 20
}

private enum PositionSizeLayout {
    static let monitorLabelY: CGFloat = 145
    static let monitorPopupX: CGFloat = 70
    static let monitorPopupY: CGFloat = 143
    static let monitorPopupWidth: CGFloat = 140
    static let monitorPopupHeight: CGFloat = 24
    static let monitorPopupFontSize: CGFloat = 11
    static let resolutionLabelY: CGFloat = 126
    static let resolutionLabelHeight: CGFloat = 16
    static let resolutionLabelFontSize: CGFloat = 10
    static let positionRowY: CGFloat = 100
    static let sizeRowY: CGFloat = 70
    static let firstAxisLabelX: CGFloat = 55
    static let firstInputX: CGFloat = 70
    static let inputWidth: CGFloat = 60
    static let secondAxisLabelX: CGFloat = 140
    static let secondInputX: CGFloat = 155
    static let resetButtonX: CGFloat = 110
    static let resetButtonY: CGFloat = 20
}

// MARK: - Adjustment Panel Controller

@MainActor
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
        let sep1 = NSBox(frame: NSRect(
            x: SectionLayout.labelX, y: Self.rotationSectionOffsetY, width: SectionLayout.contentWidth, height: 1
        ))
        sep1.boxType = .separator
        contentView.addSubview(sep1)

        setupOpacitySection(in: contentView, opacity: state.opacity, offsetY: Self.opacitySectionOffsetY)

        // Separator between opacity and position/size
        let sep2 = NSBox(frame: NSRect(
            x: SectionLayout.labelX, y: Self.opacitySectionOffsetY, width: SectionLayout.contentWidth, height: 1
        ))
        sep2.boxType = .separator
        contentView.addSubview(sep2)

        setupPositionSizeSection(in: contentView)

        newPanel.contentView = contentView
        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel
    }

    private func setupRotationSection(in contentView: NSView, angle: CGFloat, offsetY: CGFloat) {
        // Dial view (left side)
        let dialFrame = NSRect(
            x: RotationLayout.dialX, y: RotationLayout.dialRelativeY + offsetY,
            width: RotationLayout.dialSize, height: RotationLayout.dialSize
        )
        let dial = RotationDialView(frame: dialFrame)
        dial.angle = angle
        dial.onAngleChanged = { [weak self] newAngle in
            self?.angleChanged(newAngle)
        }
        contentView.addSubview(dial)
        dialView = dial

        // "角度:" label
        let label = NSTextField(labelWithString: L("adjust.angle"))
        label.frame = NSRect(
            x: RotationLayout.angleLabelX, y: RotationLayout.angleLabelRelativeY + offsetY, width: 40, height: 20
        )
        label.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(label)

        // Text field
        let field = NSTextField(frame: NSRect(
            x: RotationLayout.angleFieldX, y: RotationLayout.angleFieldRelativeY + offsetY,
            width: RotationLayout.angleFieldWidth, height: 22
        ))
        field.stringValue = formatAngle(angle)
        field.alignment = .right
        field.font = NSFont.monospacedDigitSystemFont(ofSize: SectionLayout.labelFontSize, weight: .regular)
        field.target = self
        field.action = #selector(textFieldChanged(_:))
        contentView.addSubview(field)
        textField = field

        // "°" label
        let degreeLabel = NSTextField(labelWithString: L("adjust.degree"))
        degreeLabel.frame = NSRect(
            x: RotationLayout.degreeLabelX, y: RotationLayout.angleLabelRelativeY + offsetY, width: 15, height: 20
        )
        degreeLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(degreeLabel)

        // Reset button
        let resetButton = NSButton(title: L("adjust.reset"), target: self, action: #selector(resetAngle))
        resetButton.frame = NSRect(
            x: RotationLayout.resetButtonX, y: RotationLayout.resetButtonRelativeY + offsetY,
            width: SectionLayout.resetButtonWidth, height: SectionLayout.resetButtonHeight
        )
        resetButton.bezelStyle = .rounded
        resetButton.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(resetButton)
    }

    private func setupOpacitySection(in contentView: NSView, opacity: CGFloat, offsetY: CGFloat = 0) {
        let opacitySectionLabel = NSTextField(labelWithString: L("adjust.opacity"))
        opacitySectionLabel.frame = NSRect(
            x: SectionLayout.labelX, y: OpacityLayout.labelRelativeY + offsetY, width: 50, height: 20
        )
        opacitySectionLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(opacitySectionLabel)

        let percentLabel = NSTextField(labelWithString: formatOpacity(opacity))
        percentLabel.frame = NSRect(
            x: OpacityLayout.percentLabelX, y: OpacityLayout.labelRelativeY + offsetY, width: 50, height: 20
        )
        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: SectionLayout.labelFontSize, weight: .regular)
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
        slider.frame = NSRect(
            x: SectionLayout.labelX, y: OpacityLayout.sliderRelativeY + offsetY,
            width: SectionLayout.contentWidth, height: 20
        )
        slider.numberOfTickMarks = 0
        contentView.addSubview(slider)
        opacitySlider = slider

        let opacityResetButton = NSButton(
            title: L("adjust.reset"),
            target: self,
            action: #selector(resetOpacity)
        )
        opacityResetButton.frame = NSRect(
            x: OpacityLayout.resetButtonX, y: OpacityLayout.resetButtonRelativeY + offsetY,
            width: SectionLayout.resetButtonWidth, height: SectionLayout.resetButtonHeight
        )
        opacityResetButton.bezelStyle = .rounded
        opacityResetButton.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
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
            width: PositionSizeLayout.monitorPopupWidth, height: PositionSizeLayout.monitorPopupHeight
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
            width: PositionSizeLayout.monitorPopupWidth, height: PositionSizeLayout.resolutionLabelHeight
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
            x: PositionSizeLayout.firstAxisLabelX, y: PositionSizeLayout.positionRowY, width: 15, height: 20
        )
        xLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(xLabel)

        let xInput = NSTextField(frame: NSRect(
            x: PositionSizeLayout.firstInputX, y: PositionSizeLayout.positionRowY - 2,
            width: PositionSizeLayout.inputWidth, height: 22
        ))
        xInput.alignment = .right
        xInput.font = NSFont.monospacedDigitSystemFont(ofSize: SectionLayout.labelFontSize, weight: .regular)
        xInput.target = self
        xInput.action = #selector(xFieldChanged(_:))
        contentView.addSubview(xInput)
        xField = xInput

        let yLabel = NSTextField(labelWithString: "Y")
        yLabel.frame = NSRect(
            x: PositionSizeLayout.secondAxisLabelX, y: PositionSizeLayout.positionRowY, width: 15, height: 20
        )
        yLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(yLabel)

        let yInput = NSTextField(frame: NSRect(
            x: PositionSizeLayout.secondInputX, y: PositionSizeLayout.positionRowY - 2,
            width: PositionSizeLayout.inputWidth, height: 22
        ))
        yInput.alignment = .right
        yInput.font = NSFont.monospacedDigitSystemFont(ofSize: SectionLayout.labelFontSize, weight: .regular)
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
            x: PositionSizeLayout.firstAxisLabelX, y: PositionSizeLayout.sizeRowY, width: 15, height: 20
        )
        wLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(wLabel)

        let wInput = NSTextField(frame: NSRect(
            x: PositionSizeLayout.firstInputX, y: PositionSizeLayout.sizeRowY - 2,
            width: PositionSizeLayout.inputWidth, height: 22
        ))
        wInput.alignment = .right
        wInput.font = NSFont.monospacedDigitSystemFont(ofSize: SectionLayout.labelFontSize, weight: .regular)
        wInput.target = self
        wInput.action = #selector(wFieldChanged(_:))
        contentView.addSubview(wInput)
        wField = wInput

        let hLabel = NSTextField(labelWithString: "H")
        hLabel.frame = NSRect(
            x: PositionSizeLayout.secondAxisLabelX, y: PositionSizeLayout.sizeRowY, width: 15, height: 20
        )
        hLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(hLabel)

        let hInput = NSTextField(frame: NSRect(
            x: PositionSizeLayout.secondInputX, y: PositionSizeLayout.sizeRowY - 2,
            width: PositionSizeLayout.inputWidth, height: 22
        ))
        hInput.alignment = .right
        hInput.font = NSFont.monospacedDigitSystemFont(ofSize: SectionLayout.labelFontSize, weight: .regular)
        hInput.target = self
        hInput.action = #selector(hFieldChanged(_:))
        contentView.addSubview(hInput)
        hField = hInput
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
        let relative = CGPoint(
            x: CGFloat(value),
            y: globalToMonitorRelative(currentPosition, screen: screen).y
        )
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
        let relative = CGPoint(
            x: globalToMonitorRelative(currentPosition, screen: screen).x,
            y: CGFloat(value)
        )
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
        let clampedH = max(
            AppConstants.minImageHeight,
            min(AppConstants.maxImageHeight, CGFloat(value) / currentAspectRatio)
        )
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
        let clampedH = max(
            AppConstants.minImageHeight,
            min(AppConstants.maxImageHeight, CGFloat(value))
        )
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
