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
}

// MARK: - Floating Menu Controller

@MainActor
final class FloatingMenuController {
    private let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: "FloatingMenuController")

    // Layout constants
    private static let aboveOffset: CGFloat = 8
    private static let labelHeight: CGFloat = 12
    private static let labelTopGap: CGFloat = 2
    private static let labelFontSize: CGFloat = 9
    private static let buttonIconPointSize: CGFloat = 18

    weak var delegate: FloatingMenuDelegate?
    var isRemoveBackgroundEnabled: Bool = true

    private var panel: NSPanel?
    nonisolated(unsafe) private var globalMonitor: Any?
    nonisolated(unsafe) private var localMonitor: Any?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Show / Dismiss

    func show(at point: NSPoint, in window: NSWindow) {
        dismiss()

        let buttonCount = Self.buttonCount()
        let panelWidth = AppConstants.floatingMenuPadding * 2 + AppConstants.floatingMenuColumnWidth * CGFloat(buttonCount)
            + AppConstants.floatingMenuGap * CGFloat(buttonCount - 1)
        let panelHeight = AppConstants.floatingMenuPadding * 2 + AppConstants.floatingMenuButtonSize + Self.labelTopGap + Self.labelHeight

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
        newPanel.hidesOnDeactivate = false
        newPanel.isReleasedWhenClosed = false
        newPanel.allowsToolTipsWhenApplicationIsInactive = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = NSVisualEffectView(frame: panelRect)
        contentView.material = .menu
        contentView.state = .active
        contentView.blendingMode = .behindWindow
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = AppConstants.floatingMenuCornerRadius
        contentView.layer?.masksToBounds = true

        setupButtons(in: contentView)

        newPanel.contentView = contentView
        newPanel.setFrameOrigin(origin)
        newPanel.orderFront(nil)
        panel = newPanel

        installEventMonitors()
        logger.debug("Floating menu shown at (\(origin.x), \(origin.y))")
    }

    func dismiss() {
        removeEventMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Button Setup

    private static func buttonCount() -> Int {
        if #available(macOS 14.0, *) {
            return 6
        } else {
            return 5
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
            symbolName: "arrow.counterclockwise", tooltip: L("floating_menu.reset_display"),
            label: L("floating_menu.label.reset_display"),
            action: #selector(resetDisplayTapped)
        ))
        buttons.append(ButtonSpec(
            symbolName: "xmark.circle", tooltip: L("floating_menu.close"),
            label: L("floating_menu.label.close"), action: #selector(closeTapped)
        ))

        for (index, spec) in buttons.enumerated() {
            let columnX = AppConstants.floatingMenuPadding + (AppConstants.floatingMenuColumnWidth + AppConstants.floatingMenuGap) * CGFloat(index)
            let buttonX = columnX + (AppConstants.floatingMenuColumnWidth - AppConstants.floatingMenuButtonSize) / 2
            let buttonY = AppConstants.floatingMenuPadding + Self.labelHeight + Self.labelTopGap
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
            let labelFrame = NSRect(x: columnX, y: AppConstants.floatingMenuPadding, width: AppConstants.floatingMenuColumnWidth, height: Self.labelHeight)
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
    }

    // MARK: - Button Actions

    @objc private func cropTapped() {
        dismiss()
        delegate?.floatingMenuDidSelectCrop(self)
    }

    @objc private func flipTapped() {
        dismiss()
        delegate?.floatingMenuDidSelectFlip(self)
    }

    @objc private func adjustTapped() {
        dismiss()
        delegate?.floatingMenuDidSelectAdjust(self)
    }

    @objc private func removeBackgroundTapped() {
        dismiss()
        delegate?.floatingMenuDidSelectRemoveBackground(self)
    }

    @objc private func resetDisplayTapped() {
        dismiss()
        delegate?.floatingMenuDidSelectResetDisplay(self)
    }

    @objc private func closeTapped() {
        dismiss()
        delegate?.floatingMenuDidSelectClose(self)
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
