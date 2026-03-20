import Cocoa
import os.log

// MARK: - Adjustment Panel Delegate

/// 調整パネルでの変更を CharacterWindow に通知するプロトコル
@MainActor
protocol AdjustmentPanelDelegate: AnyObject {
    /// 回転角度が変更された
    func rotationPanel(_ panel: AdjustmentPanelController, didChangeAngle angle: CGFloat)
    /// 回転角度がリセットされた
    func rotationPanelDidReset(_ panel: AdjustmentPanelController)
    /// 位置が変更された（グローバル座標）
    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangePosition position: CGPoint)
    /// サイズが変更された（回転前 imageView サイズ）
    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangeSize size: CGSize)
    /// モニターが選択された
    func adjustmentPanel(_ panel: AdjustmentPanelController, didSelectMonitor screen: NSScreen)
    /// 位置・サイズがリセットされた
    func adjustmentPanelDidResetPositionAndSize(_ panel: AdjustmentPanelController)
}

// MARK: - Adjustment Panel State

struct AdjustmentPanelState: Sendable {
    let angle: CGFloat
    let position: CGPoint
    let size: CGSize
    let aspectRatio: CGFloat
}

// MARK: - Section Layout Constants

enum SectionLayout {
    static let labelX: CGFloat = 10
    static let contentWidth: CGFloat = 200
    static let labelFontSize: CGFloat = 12
    static let resetButtonWidth: CGFloat = 90
    static let resetButtonHeight: CGFloat = 28
}

enum RotationLayout {
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

enum PositionSizeLayout {
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
    private let logger = Logger(category: "AdjustmentPanelController")
    private static let panelWidth: CGFloat = 220
    private static let panelHeight: CGFloat = 340
    private static let rotationSectionOffsetY: CGFloat = 180
    private static let panelGap: CGFloat = 8

    weak var delegate: AdjustmentPanelDelegate?
    var onClose: (() -> Void)?
    private var panel: NSPanel?
    private var dialView: RotationDialView?
    private var textField: NSTextField?
    private var currentAngle: CGFloat = 0
    var monitorPopup: NSPopUpButton?
    var resolutionLabel: NSTextField?
    var xField: NSTextField?
    var yField: NSTextField?
    var wField: NSTextField?
    var hField: NSTextField?
    var currentPosition: CGPoint = .zero
    var currentSize: CGSize = .zero
    var currentScreen: NSScreen?
    var currentAspectRatio: CGFloat = 1.0

    func show(near window: NSWindow, state: AdjustmentPanelState) {
        currentAngle = state.angle
        currentPosition = state.position
        currentSize = state.size
        currentAspectRatio = state.aspectRatio
        currentScreen = NSScreen.screen(containing: window.frame)

        // Lazy-initialize the panel on first show
        if panel == nil {
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
            newPanel.configureForFloating()

            let contentView = NSView(frame: panelRect)

            setupRotationSection(
                in: contentView, angle: state.angle, offsetY: Self.rotationSectionOffsetY)

            // Separator between rotation and position/size
            let sep1 = NSBox(frame: NSRect(
                x: SectionLayout.labelX, y: Self.rotationSectionOffsetY,
                width: SectionLayout.contentWidth, height: 1
            ))
            sep1.boxType = .separator
            contentView.addSubview(sep1)

            setupPositionSizeSection(in: contentView)

            newPanel.contentView = contentView
            panel = newPanel
        } else {
            // Update all control values for the new state
            dialView?.angle = state.angle
            textField?.stringValue = Self.formatAngle(state.angle)
            populateMonitorPopup()
            updateResolutionLabel()
            updatePositionFields()
            updateSizeFields()
        }

        // Reposition near the target window
        let windowFrame = window.frame
        let panelHeight: CGFloat = Self.panelHeight
        let panelOrigin = NSPoint(
            x: windowFrame.maxX + Self.panelGap,
            y: windowFrame.midY - panelHeight / 2
        )
        panel?.setFrameOrigin(panelOrigin)
        panel?.makeKeyAndOrderFront(nil)
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
            x: RotationLayout.angleLabelX, y: RotationLayout.angleLabelRelativeY + offsetY,
            width: 40, height: 20
        )
        label.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(label)

        // Text field
        let field = NSTextField(frame: NSRect(
            x: RotationLayout.angleFieldX, y: RotationLayout.angleFieldRelativeY + offsetY,
            width: RotationLayout.angleFieldWidth, height: 22
        ))
        field.stringValue = Self.formatAngle(angle)
        field.alignment = .right
        field.font = NSFont.monospacedDigitSystemFont(
            ofSize: SectionLayout.labelFontSize, weight: .regular)
        field.target = self
        field.action = #selector(textFieldChanged(_:))
        contentView.addSubview(field)
        textField = field

        // "°" label
        let degreeLabel = NSTextField(labelWithString: L("adjust.degree"))
        degreeLabel.frame = NSRect(
            x: RotationLayout.degreeLabelX, y: RotationLayout.angleLabelRelativeY + offsetY,
            width: 15, height: 20
        )
        degreeLabel.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(degreeLabel)

        // Reset button
        let resetButton = NSButton(
            title: L("adjust.reset"), target: self, action: #selector(resetAngle))
        resetButton.frame = NSRect(
            x: RotationLayout.resetButtonX, y: RotationLayout.resetButtonRelativeY + offsetY,
            width: SectionLayout.resetButtonWidth, height: SectionLayout.resetButtonHeight
        )
        resetButton.bezelStyle = .rounded
        resetButton.font = NSFont.systemFont(ofSize: SectionLayout.labelFontSize)
        contentView.addSubview(resetButton)
    }

    // MARK: - Close / Cleanup

    private func performClose() {
        let savedOnClose = onClose
        onClose = nil
        panel?.orderOut(nil)
        savedOnClose?()
    }

    func close() {
        guard panel?.isVisible == true else { return }
        performClose()
    }

    func windowWillClose(_ notification: Notification) {
        performClose()
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Existing Update Methods

    func updateAngle(_ angle: CGFloat) {
        guard !GeometryUtils.isApproximatelyEqual(currentAngle, angle) else { return }
        currentAngle = angle
        dialView?.angle = angle
        textField?.stringValue = Self.formatAngle(angle)
    }

    // MARK: - Rotation Handlers

    private func angleChanged(_ newAngle: CGFloat) {
        currentAngle = newAngle
        textField?.stringValue = Self.formatAngle(newAngle)
        delegate?.rotationPanel(self, didChangeAngle: newAngle)
    }

    @objc private func textFieldChanged(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard var degrees = Double(text) else {
            sender.stringValue = Self.formatAngle(currentAngle)
            return
        }
        degrees = GeometryUtils.normalizeAngle(degrees)
        let angle = CGFloat(degrees)
        currentAngle = angle
        dialView?.angle = angle
        sender.stringValue = Self.formatAngle(angle)
        delegate?.rotationPanel(self, didChangeAngle: angle)
    }

    @objc private func resetAngle() {
        currentAngle = 0
        dialView?.angle = 0
        textField?.stringValue = Self.formatAngle(0)
        delegate?.rotationPanelDidReset(self)
    }

    // MARK: - Static Helpers

    static func formatAngle(_ angle: CGFloat) -> String {
        let rounded = angle.rounded()
        if GeometryUtils.isApproximatelyEqual(angle, rounded) {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", angle)
    }

    static func clampedSize(newValue: CGFloat, aspectRatio: CGFloat, isWidth: Bool) -> CGSize? {
        guard newValue > 0 else { return nil }
        guard aspectRatio > 0 else { return nil }
        let height: CGFloat
        if isWidth {
            height = newValue / aspectRatio
        } else {
            height = newValue
        }
        let clampedH = max(AppConstants.minImageHeight, min(AppConstants.maxImageHeight, height))
        let clampedW = clampedH * aspectRatio
        return CGSize(width: clampedW, height: clampedH)
    }

    // MARK: - Testable Static Methods

    nonisolated static func generateMonitorPopupTitles(
        screenSizes: [(width: Int, height: Int)]) -> [String] {
        return screenSizes.enumerated().map { index, size in
            "\(index + 1): \(size.width)×\(size.height)"
        }
    }

    nonisolated static func formatResolutionLabel(width: Int, height: Int) -> String {
        return "\(width)×\(height)"
    }

    nonisolated static func updatedRelativePosition(
        newAxisValue: CGFloat, currentRelative: CGPoint, isXField: Bool
    ) -> CGPoint {
        if isXField {
            return CGPoint(x: newAxisValue, y: currentRelative.y)
        } else {
            return CGPoint(x: currentRelative.x, y: newAxisValue)
        }
    }

}
