import Cocoa
import os.log

// MARK: - Floating Menu Delegate

@MainActor
protocol FloatingMenuDelegate: AnyObject {
    func floatingMenuDidSelectCrop(_ menu: FloatingMenuController)
    func floatingMenuDidSelectFlip(_ menu: FloatingMenuController)
    func floatingMenuDidSelectAdjust(_ menu: FloatingMenuController)
    func floatingMenuDidSelectRemoveBackground(_ menu: FloatingMenuController)
    func floatingMenuDidSelectClose(_ menu: FloatingMenuController)
    func floatingMenuDidSelectResetDisplay(_ menu: FloatingMenuController)
    func floatingMenuDidSelectGhostMode(_ menu: FloatingMenuController)
    func floatingMenu(_ menu: FloatingMenuController, didChangeOpacity opacity: CGFloat)
    func floatingMenuDidSelectHide(_ menu: FloatingMenuController)
}

// MARK: - Floating Menu Controller

@MainActor
final class FloatingMenuController {
    private let logger = Logger(category: "FloatingMenuController")

    // Layout constants
    private static let aboveOffset: CGFloat = 8
    private static let labelHeight: CGFloat = 12
    private static let labelTopGap: CGFloat = 2
    private static let labelFontSize: CGFloat = 9
    private static let buttonIconPointSize: CGFloat = 18

    weak var delegate: FloatingMenuDelegate?
    var currentOpacity: CGFloat = 1.0
    private var opacitySlider: NSSlider?
    private var opacityLabel: NSTextField?
    var isRemoveBackgroundEnabled: Bool = true

    private var panel: NSPanel?
    nonisolated(unsafe) private var globalMonitor: Any?
    nonisolated(unsafe) private var localMonitor: Any?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Show / Dismiss

    func show(at point: NSPoint, in window: NSWindow) {
        let buttonCount = Self.buttonCount()
        let panelWidth = AppConstants.floatingMenuPadding * 2 + AppConstants.floatingMenuColumnWidth * CGFloat(buttonCount)
            + AppConstants.floatingMenuGap * CGFloat(buttonCount - 1)
        let panelHeight = AppConstants.floatingMenuPadding * 2 + AppConstants.floatingMenuButtonSize + Self.labelTopGap + Self.labelHeight
            + AppConstants.floatingMenuSeparatorHeight + AppConstants.floatingMenuSliderRowHeight

        // Convert window-local point to screen coordinates
        let screenPoint = window.convertPoint(toScreen: point)

        // Determine position: prefer above, fall back to below if off-screen
        var origin = NSPoint(
            x: screenPoint.x - panelWidth / 2,
            y: screenPoint.y + Self.aboveOffset
        )

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(screenPoint) }) ?? NSScreen.main {
            // If panel would go above visible area, show below instead
            if origin.y + panelHeight > screen.visibleFrame.maxY {
                origin.y = screenPoint.y - panelHeight - Self.aboveOffset
            }
            // Clamp horizontally
            origin.x = max(screen.visibleFrame.minX, min(origin.x, screen.visibleFrame.maxX - panelWidth))
        }

        // Lazy-initialize the panel on first show
        if panel == nil {
            let panelRect = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
            let newPanel = NSPanel(
                contentRect: panelRect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.becomesKeyOnlyIfNeeded = true
            newPanel.level = .floating + 1
            newPanel.hasShadow = true
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.configureForFloating()
            newPanel.allowsToolTipsWhenApplicationIsInactive = true

            let contentView = NSVisualEffectView(frame: panelRect)
            contentView.material = .menu
            contentView.state = .active
            contentView.blendingMode = .behindWindow
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = AppConstants.floatingMenuCornerRadius
            contentView.layer?.masksToBounds = true

            setupButtons(in: contentView)
            setupOpacitySlider(in: contentView)

            newPanel.contentView = contentView
            panel = newPanel
        }

        panel?.setFrameOrigin(origin)
        panel?.orderFront(nil)

        opacitySlider?.doubleValue = Double(currentOpacity)
        opacityLabel?.stringValue = FormatUtils.formatOpacity(currentOpacity)

        removeEventMonitors()
        installEventMonitors()
        logger.debug("Floating menu shown at (\(origin.x), \(origin.y))")
    }

    func dismiss() {
        removeEventMonitors()
        panel?.orderOut(nil)
    }

    // MARK: - Button Setup

    private static func buttonCount() -> Int {
        if #available(macOS 14.0, *) {
            return 8
        } else {
            return 7
        }
    }

    private struct ButtonSpec {
        let symbolName: String
        let tooltip: String
        let label: String
        let action: Selector
    }

    private func setupButtons(in container: NSView) {
        var buttons: [ButtonSpec] = [
            ButtonSpec(symbolName: "crop", tooltip: L("floating_menu.crop"), label: L("floating_menu.label.crop"), action: #selector(cropTapped)),
            ButtonSpec(
                symbolName: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                tooltip: L("floating_menu.flip"),
                label: L("floating_menu.label.flip"),
                action: #selector(flipTapped)
            ),
            ButtonSpec(
                symbolName: "slider.horizontal.3", tooltip: L("floating_menu.adjust"),
                label: L("floating_menu.label.adjust"), action: #selector(adjustTapped)
            )
        ]

        var removeBackgroundIndex: Int?
        if #available(macOS 14.0, *) {
            removeBackgroundIndex = buttons.count
            buttons.append(ButtonSpec(
                symbolName: "eraser.fill",
                tooltip: L("floating_menu.remove_background"),
                label: L("floating_menu.label.remove_background"),
                action: #selector(removeBackgroundTapped)
            ))
        }

        buttons.append(ButtonSpec(
            symbolName: AppConstants.ghostModeSymbol, tooltip: L("floating_menu.ghost_mode"),
            label: L("floating_menu.label.ghost_mode"), action: #selector(ghostModeTapped)
        ))
        buttons.append(ButtonSpec(
            symbolName: "arrow.counterclockwise", tooltip: L("floating_menu.reset_display"),
            label: L("floating_menu.label.reset_display"),
            action: #selector(resetDisplayTapped)
        ))
        buttons.append(ButtonSpec(
            symbolName: AppConstants.hiddenWindowSymbol, tooltip: L("floating_menu.hide"),
            label: L("floating_menu.label.hide"), action: #selector(hideTapped)
        ))
        buttons.append(ButtonSpec(
            symbolName: AppConstants.closeSymbol, tooltip: L("floating_menu.close"),
            label: L("floating_menu.label.close"), action: #selector(closeTapped)
        ))

        let sliderAreaHeight = AppConstants.floatingMenuSliderRowHeight + AppConstants.floatingMenuSeparatorHeight
        for (index, spec) in buttons.enumerated() {
            createButtonView(spec: spec, index: index, removeBackgroundIndex: removeBackgroundIndex, sliderAreaHeight: sliderAreaHeight, in: container)
        }
    }

    private func createButtonView(spec: ButtonSpec, index: Int, removeBackgroundIndex: Int?, sliderAreaHeight: CGFloat, in container: NSView) {
        let columnX = AppConstants.floatingMenuPadding + (AppConstants.floatingMenuColumnWidth + AppConstants.floatingMenuGap) * CGFloat(index)
        let buttonX = columnX + (AppConstants.floatingMenuColumnWidth - AppConstants.floatingMenuButtonSize) / 2
        let buttonY = sliderAreaHeight + AppConstants.floatingMenuPadding + Self.labelHeight + Self.labelTopGap
        let buttonFrame = NSRect(x: buttonX, y: buttonY, width: AppConstants.floatingMenuButtonSize, height: AppConstants.floatingMenuButtonSize)

        let button = NSButton(frame: buttonFrame)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = spec.tooltip
        button.target = self
        button.action = spec.action

        button.image = SFSymbolUtils.icon(spec.symbolName, pointSize: Self.buttonIconPointSize, weight: .medium)

        // Hover effect via tracking area
        button.wantsLayer = true
        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: button,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)

        container.addSubview(button)

        // Label below button
        let labelY = sliderAreaHeight + AppConstants.floatingMenuPadding
        let labelFrame = NSRect(x: columnX, y: labelY, width: AppConstants.floatingMenuColumnWidth, height: Self.labelHeight)
        let label = NSTextField(frame: labelFrame)
        label.stringValue = spec.label
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .center
        label.font = .systemFont(ofSize: Self.labelFontSize)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail

        if index == removeBackgroundIndex && !isRemoveBackgroundEnabled {
            button.isEnabled = false
            label.textColor = .tertiaryLabelColor
        }

        container.addSubview(label)
    }

    private func setupOpacitySlider(in container: NSView) {
        let containerBounds = container.bounds
        let rowHeight = AppConstants.floatingMenuSliderRowHeight
        let separatorY = AppConstants.floatingMenuSliderRowHeight
        let sliderRowY: CGFloat = 0

        // Separator line
        let separatorWidth = containerBounds.width - AppConstants.floatingMenuPadding * 2
        let separator = NSBox(frame: NSRect(
            x: AppConstants.floatingMenuPadding, y: separatorY,
            width: separatorWidth, height: AppConstants.floatingMenuSeparatorHeight
        ))
        separator.boxType = .separator
        container.addSubview(separator)

        // Icon
        let iconSize: CGFloat = 16
        let iconX = AppConstants.floatingMenuPadding + 4
        let iconPointSize: CGFloat = 12
        let iconView = NSImageView(frame: NSRect(x: iconX, y: sliderRowY + (rowHeight - iconSize) / 2, width: iconSize, height: iconSize))
        iconView.image = SFSymbolUtils.icon(AppConstants.opacitySymbol, pointSize: iconPointSize)
        iconView.imageScaling = .scaleProportionallyDown
        container.addSubview(iconView)

        // Label
        let labelX = iconX + iconSize + 4
        let label = NSTextField(labelWithString: L("floating_menu.label.opacity"))
        label.font = NSFont.systemFont(ofSize: 10)
        label.textColor = .secondaryLabelColor
        label.sizeToFit()
        label.frame.origin = NSPoint(x: labelX, y: sliderRowY + (rowHeight - label.frame.height) / 2)
        container.addSubview(label)

        // Percent label (right side)
        let percentWidth: CGFloat = AppConstants.ghostAlphaSliderPercentWidth
        let percentX = containerBounds.width - AppConstants.floatingMenuPadding - percentWidth
        let percentLabel = NSTextField(labelWithString: FormatUtils.formatOpacity(currentOpacity))
        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        percentLabel.alignment = .right
        let percentY = sliderRowY + (rowHeight - percentLabel.frame.height) / 2
        percentLabel.frame = NSRect(x: percentX, y: percentY, width: percentWidth, height: percentLabel.frame.height)
        container.addSubview(percentLabel)
        opacityLabel = percentLabel

        // Slider
        let sliderX = label.frame.maxX + 6
        let sliderWidth = percentX - sliderX - 4
        let sliderHeight: CGFloat = AppConstants.ghostAlphaSliderHeight
        let slider = NSSlider(
            value: Double(currentOpacity),
            minValue: Double(AppConstants.opacityMin),
            maxValue: Double(AppConstants.opacityMax),
            target: self,
            action: #selector(opacitySliderChanged(_:))
        )
        slider.frame = NSRect(x: sliderX, y: sliderRowY + (rowHeight - sliderHeight) / 2, width: sliderWidth, height: sliderHeight)
        slider.isContinuous = true
        container.addSubview(slider)
        opacitySlider = slider
    }

    // MARK: - Button Actions

    private func dismissAndNotify(_ action: (FloatingMenuDelegate) -> Void) {
        dismiss()
        if let delegate { action(delegate) }
    }

    @objc private func cropTapped() {
        dismissAndNotify { $0.floatingMenuDidSelectCrop(self) }
    }

    @objc private func flipTapped() {
        dismissAndNotify { $0.floatingMenuDidSelectFlip(self) }
    }

    @objc private func adjustTapped() {
        dismissAndNotify { $0.floatingMenuDidSelectAdjust(self) }
    }

    @objc private func removeBackgroundTapped() {
        dismissAndNotify { $0.floatingMenuDidSelectRemoveBackground(self) }
    }

    @objc private func ghostModeTapped() {
        dismissAndNotify { $0.floatingMenuDidSelectGhostMode(self) }
    }

    @objc private func resetDisplayTapped() {
        dismissAndNotify { $0.floatingMenuDidSelectResetDisplay(self) }
    }

    @objc private func hideTapped() {
        dismissAndNotify { $0.floatingMenuDidSelectHide(self) }
    }

    @objc private func closeTapped() {
        dismissAndNotify { $0.floatingMenuDidSelectClose(self) }
    }

    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        opacityLabel?.stringValue = FormatUtils.formatOpacity(value)
        currentOpacity = value
        delegate?.floatingMenu(self, didChangeOpacity: value)
    }

    // MARK: - Event Monitors

    private func installEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.dismiss()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }

            if event.type == .keyDown && event.keyCode == AppConstants.escKeyCode {
                // ESC key
                self.dismiss()
                return nil
            }

            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if event.window == self.panel {
                    return event
                }
                self.dismiss()
            }

            return event
        }
    }

    nonisolated private func removeEventMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        removeEventMonitors()
    }
}
