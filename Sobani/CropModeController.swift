import Cocoa

// MARK: - Crop Mode Controller

/// クロップモードのライフサイクル管理 — オーバーレイ表示、確認/キャンセルボタンを制御する
@MainActor
final class CropModeController: NSObject {
    private static let toolbarHeight: CGFloat = 40
    private static let toolbarWidth: CGFloat = 144
    private static let toolbarCornerRadius: CGFloat = 10
    private static let toolbarBottomMargin: CGFloat = 12
    private static let buttonSize: CGFloat = 28
    private static let buttonSpacing: CGFloat = 16

    private weak var window: NSWindow?
    private weak var imageView: DraggableImageView?
    private var overlayView: CropOverlayView?
    private var toolbarView: NSView?
    nonisolated(unsafe) private var keyMonitor: Any?
    private(set) var isActive: Bool = false

    // MARK: - Callbacks

    var onCropConfirmed: ((CropRect) -> Void)?
    var onCropReset: (() -> Void)?
    var onCropCancelled: (() -> Void)?

    // MARK: - Public Methods

    func enterCropMode(in window: NSWindow, imageView: DraggableImageView, currentCropRect: CropRect?) {
        guard !isActive else { return }

        self.window = window
        self.imageView = imageView
        isActive = true

        guard let contentView = window.contentView else { return }

        // Create overlay matching imageView frame
        let overlay = CropOverlayView(frame: imageView.frame)
        overlay.cropRect = currentCropRect ?? .full
        overlay.onConfirm = { [weak self] _ in
            self?.confirmCrop()
        }
        overlay.onCancel = { [weak self] in
            self?.cancelCrop()
        }
        contentView.addSubview(overlay)
        overlayView = overlay

        // Create toolbar
        let toolbar = createToolbar(overlayFrame: overlay.frame)
        contentView.addSubview(toolbar)
        toolbarView = toolbar

        // Install ESC key monitor
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                DispatchQueue.main.async {
                    self?.cancelCrop()
                }
                return nil
            }
            return event
        }
    }

    func exitCropMode() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        overlayView?.removeFromSuperview()
        toolbarView?.removeFromSuperview()
        overlayView = nil
        toolbarView = nil
        window = nil
        imageView = nil
        isActive = false
    }

    // MARK: - Private Methods

    private func confirmCrop() {
        guard let cropRect = overlayView?.cropRect else { return }
        onCropConfirmed?(cropRect)
        exitCropMode()
    }

    private func cancelCrop() {
        onCropCancelled?()
        exitCropMode()
    }

    private func createToolbar(overlayFrame: NSRect) -> NSView {
        let toolbar = NSView(frame: NSRect(
            x: overlayFrame.midX - Self.toolbarWidth / 2,
            y: overlayFrame.origin.y + Self.toolbarBottomMargin,
            width: Self.toolbarWidth,
            height: Self.toolbarHeight
        ))
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        toolbar.layer?.cornerRadius = Self.toolbarCornerRadius

        let buttonY = (Self.toolbarHeight - Self.buttonSize) / 2
        let totalButtonsWidth = Self.buttonSize * 3 + Self.buttonSpacing * 2
        let startX = (Self.toolbarWidth - totalButtonsWidth) / 2

        // Confirm button
        let confirmButton = NSButton(frame: NSRect(
            x: startX, y: buttonY, width: Self.buttonSize, height: Self.buttonSize
        ))
        configureButton(
            confirmButton, symbolName: "checkmark.circle.fill",
            tintColor: .systemGreen, action: #selector(confirmButtonTapped),
            tooltip: L("crop.confirm")
        )
        toolbar.addSubview(confirmButton)

        // Reset button
        let resetButton = NSButton(frame: NSRect(
            x: startX + Self.buttonSize + Self.buttonSpacing, y: buttonY,
            width: Self.buttonSize, height: Self.buttonSize
        ))
        configureButton(
            resetButton, symbolName: "arrow.counterclockwise.circle.fill",
            tintColor: .systemOrange, action: #selector(resetButtonTapped),
            tooltip: L("crop.reset")
        )
        toolbar.addSubview(resetButton)

        // Cancel button
        let cancelButton = NSButton(frame: NSRect(
            x: startX + (Self.buttonSize + Self.buttonSpacing) * 2, y: buttonY,
            width: Self.buttonSize, height: Self.buttonSize
        ))
        configureButton(
            cancelButton, symbolName: "xmark.circle.fill",
            tintColor: .systemRed, action: #selector(cancelButtonTapped),
            tooltip: L("crop.cancel")
        )
        toolbar.addSubview(cancelButton)

        return toolbar
    }

    private func configureButton(
        _ button: NSButton,
        symbolName: String,
        tintColor: NSColor,
        action: Selector,
        tooltip: String
    ) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.target = self
        button.action = action
        button.toolTip = tooltip

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip) {
            let config = NSImage.SymbolConfiguration(pointSize: Self.buttonSize, weight: .regular)
            let configured = image.withSymbolConfiguration(config) ?? image
            button.image = configured
            button.contentTintColor = tintColor
        }

        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
    }

    // MARK: - Button Actions

    @objc private func confirmButtonTapped() {
        confirmCrop()
    }

    @objc private func resetButtonTapped() {
        onCropReset?()
        exitCropMode()
    }

    @objc private func cancelButtonTapped() {
        cancelCrop()
    }
}
