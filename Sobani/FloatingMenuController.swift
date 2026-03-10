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
}

// MARK: - Floating Menu Controller

@MainActor
final class FloatingMenuController {
    private let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: "FloatingMenuController")

    // Layout constants
    private static let buttonSize: CGFloat = 32
    private static let buttonPadding: CGFloat = 6
    private static let panelPadding: CGFloat = 8
    private static let cornerRadius: CGFloat = 10
    private static let aboveOffset: CGFloat = 8

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
        let panelWidth = Self.panelPadding * 2 + Self.buttonSize * CGFloat(buttonCount)
            + Self.buttonPadding * CGFloat(buttonCount - 1)
        let panelHeight = Self.panelPadding * 2 + Self.buttonSize

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
        contentView.layer?.cornerRadius = Self.cornerRadius
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
            return 5
        } else {
            return 4
        }
    }

    private struct ButtonSpec {
        let symbolName: String
        let tooltip: String
        let action: Selector
    }

    private func setupButtons(in container: NSView) {
        var buttons: [ButtonSpec] = [
            ButtonSpec(symbolName: "crop", tooltip: L("floating_menu.crop"), action: #selector(cropTapped)),
            ButtonSpec(
                symbolName: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                tooltip: L("floating_menu.flip"),
                action: #selector(flipTapped)
            ),
            ButtonSpec(symbolName: "slider.horizontal.3", tooltip: L("floating_menu.adjust"), action: #selector(adjustTapped))
        ]

        var removeBackgroundIndex: Int?
        if #available(macOS 14.0, *) {
            removeBackgroundIndex = buttons.count
            buttons.append(ButtonSpec(
                symbolName: "eraser.fill", tooltip: L("floating_menu.remove_background"), action: #selector(removeBackgroundTapped)
            ))
        }

        buttons.append(ButtonSpec(symbolName: "xmark.circle", tooltip: L("floating_menu.close"), action: #selector(closeTapped)))

        for (index, spec) in buttons.enumerated() {
            let x = Self.panelPadding + (Self.buttonSize + Self.buttonPadding) * CGFloat(index)
            let y = Self.panelPadding
            let buttonFrame = NSRect(x: x, y: y, width: Self.buttonSize, height: Self.buttonSize)

            let button = NSButton(frame: buttonFrame)
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = spec.tooltip
            button.target = self
            button.action = spec.action

            if let image = NSImage(systemSymbolName: spec.symbolName, accessibilityDescription: spec.tooltip) {
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
                button.image = image.withSymbolConfiguration(config)
            }

            if index == removeBackgroundIndex {
                button.isEnabled = isRemoveBackgroundEnabled
            }

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

            if event.type == .keyDown && event.keyCode == 53 {
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

    private func removeEventMonitors() {
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
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
