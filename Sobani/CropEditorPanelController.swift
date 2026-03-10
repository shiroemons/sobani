import Cocoa
import os.log

// MARK: - Crop Editor Panel Delegate

@MainActor
protocol CropEditorPanelDelegate: AnyObject {
    func cropEditorDidConfirm(_ editor: CropEditorPanelController, cropRect: CropRect)
    func cropEditorDidCancel(_ editor: CropEditorPanelController)
    func cropEditorDidReset(_ editor: CropEditorPanelController)
}

// MARK: - Crop Editor Panel Controller

@MainActor
final class CropEditorPanelController: NSObject {
    private let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: "CropEditorPanelController")

    // MARK: - Constants

    private static let panelWidth: CGFloat = 480
    private static let panelHeight: CGFloat = 640
    private static let topBarHeight: CGFloat = 44
    private static let toolbarHeight: CGFloat = 120
    private static let buttonPadding: CGFloat = 16
    private static let buttonWidth: CGFloat = 80
    private static let buttonHeight: CGFloat = 28
    private static let buttonBottomInset: CGFloat = 8
    private static let panelGap: CGFloat = 20

    // MARK: - Properties

    weak var delegate: CropEditorPanelDelegate?
    private var panel: NSPanel?
    private var canvasView: CropEditorCanvasView?
    private var toolbarView: CropEditorToolbarView?
    private var originalImage: NSImage?
    private(set) var currentCropRect: CropRect
    nonisolated(unsafe) private var keyMonitor: Any?

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Init

    init(cropRect: CropRect = .full) {
        self.currentCropRect = cropRect
        super.init()
    }

    // MARK: - Show / Close

    func show(image: NSImage, near window: NSWindow) {
        close()
        originalImage = image

        let panelRect = NSRect(
            x: 0, y: 0,
            width: Self.panelWidth, height: Self.panelHeight
        )
        let newPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.title = L("crop_editor.title")
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = false
        newPanel.isReleasedWhenClosed = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.delegate = self

        let contentView = NSView(frame: panelRect)
        contentView.wantsLayer = true

        // Top bar (cancel / reset / done buttons)
        let topBar = createTopBar(width: Self.panelWidth)
        topBar.frame.origin = NSPoint(x: 0, y: Self.panelHeight - Self.topBarHeight)
        contentView.addSubview(topBar)

        // Bottom toolbar
        let toolbar = CropEditorToolbarView(
            frame: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.toolbarHeight)
        )
        toolbar.onStraightenAngleChanged = { [weak self] angle in
            self?.handleStraightenAngleChanged(angle)
        }
        toolbar.onRotate90Tapped = { [weak self] in
            self?.handleRotate90()
        }
        toolbar.onAspectRatioTapped = { [weak self] in
            self?.handleAspectRatioCycle()
        }
        contentView.addSubview(toolbar)
        toolbarView = toolbar

        // Central canvas
        let canvasY = Self.toolbarHeight
        let canvasHeight = Self.panelHeight - Self.topBarHeight - Self.toolbarHeight
        let canvas = CropEditorCanvasView(
            frame: NSRect(x: 0, y: canvasY, width: Self.panelWidth, height: canvasHeight)
        )
        canvas.setImage(image)
        canvas.cropRect = currentCropRect
        canvas.onCropRectChanged = { [weak self] newRect in
            self?.currentCropRect = newRect
        }
        contentView.addSubview(canvas)
        canvasView = canvas

        newPanel.contentView = contentView

        // Position near the target window
        let panelOrigin = Self.calculatePanelOrigin(near: window, panelSize: panelRect.size)
        newPanel.setFrameOrigin(panelOrigin)
        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel

        installKeyMonitor()
        logger.debug("Crop editor panel shown")
    }

    func close() {
        removeKeyMonitor()
        canvasView = nil
        toolbarView = nil
        panel?.orderOut(nil)
        panel = nil
        originalImage = nil
    }

    // MARK: - Top Bar

    private func createTopBar(width: CGFloat) -> NSView {
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: width, height: Self.topBarHeight))
        bar.wantsLayer = true

        // Cancel button (left)
        let cancelButton = NSButton(
            title: L("crop_editor.cancel"),
            target: self,
            action: #selector(cancelTapped)
        )
        cancelButton.frame = NSRect(
            x: Self.buttonPadding, y: Self.buttonBottomInset,
            width: Self.buttonWidth, height: Self.buttonHeight
        )
        cancelButton.bezelStyle = .rounded
        bar.addSubview(cancelButton)

        // Reset button (center)
        let resetButton = NSButton(
            title: L("crop_editor.reset"),
            target: self,
            action: #selector(resetTapped)
        )
        resetButton.frame = NSRect(
            x: (width - Self.buttonWidth) / 2, y: Self.buttonBottomInset,
            width: Self.buttonWidth, height: Self.buttonHeight
        )
        resetButton.bezelStyle = .rounded
        bar.addSubview(resetButton)

        // Done button (right)
        let doneButton = NSButton(
            title: L("crop_editor.done"),
            target: self,
            action: #selector(doneTapped)
        )
        doneButton.frame = NSRect(
            x: width - Self.buttonWidth - Self.buttonPadding, y: Self.buttonBottomInset,
            width: Self.buttonWidth, height: Self.buttonHeight
        )
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        bar.addSubview(doneButton)

        return bar
    }

    // MARK: - Button Actions

    @objc private func cancelTapped() {
        delegate?.cropEditorDidCancel(self)
        close()
    }

    @objc private func doneTapped() {
        delegate?.cropEditorDidConfirm(self, cropRect: currentCropRect)
        close()
    }

    @objc private func resetTapped() {
        currentCropRect = .full
        canvasView?.cropRect = .full
        toolbarView?.resetStraightenAngle()
        delegate?.cropEditorDidReset(self)
    }

    // MARK: - Toolbar Handlers

    private func handleStraightenAngleChanged(_ angle: CGFloat) {
        let clamped = CropGeometry.clampStraightenAngle(angle)
        var updated = CropRect(
            x: currentCropRect.x, y: currentCropRect.y,
            width: currentCropRect.width, height: currentCropRect.height,
            straightenAngle: clamped,
            quarterTurns: currentCropRect.quarterTurns,
            isFlippedInCrop: currentCropRect.isFlippedInCrop,
            aspectRatioPreset: currentCropRect.aspectRatioPreset
        )
        updated = applyCurrentAspectRatioConstraint(to: updated)
        currentCropRect = updated
        canvasView?.cropRect = currentCropRect
    }

    private func handleRotate90() {
        let newTurns = CropGeometry.normalizeQuarterTurns(currentCropRect.quarterTurns + 1)
        var updated = CropRect(
            x: currentCropRect.x, y: currentCropRect.y,
            width: currentCropRect.width, height: currentCropRect.height,
            straightenAngle: currentCropRect.straightenAngle,
            quarterTurns: newTurns,
            isFlippedInCrop: currentCropRect.isFlippedInCrop,
            aspectRatioPreset: currentCropRect.aspectRatioPreset
        )
        updated = applyCurrentAspectRatioConstraint(to: updated)
        currentCropRect = updated
        canvasView?.cropRect = currentCropRect
    }

    private func handleAspectRatioCycle() {
        let allPresets = AspectRatioPreset.allCases
        let currentPreset = AspectRatioPreset.from(presetName: currentCropRect.aspectRatioPreset)
        let currentIndex = currentPreset.flatMap { allPresets.firstIndex(of: $0) } ?? -1
        let nextIndex = (currentIndex + 1) % allPresets.count
        let nextPreset = allPresets[nextIndex]

        let imageSize = effectiveImageSize()
        if let ratio = resolveAspectRatio(for: nextPreset, imageSize: imageSize) {
            let constrained = CropGeometry.constrainCropRect(
                currentCropRect, toAspectRatio: ratio, within: imageSize
            )
            currentCropRect = CropRect(
                x: constrained.x, y: constrained.y,
                width: constrained.width, height: constrained.height,
                straightenAngle: currentCropRect.straightenAngle,
                quarterTurns: currentCropRect.quarterTurns,
                isFlippedInCrop: currentCropRect.isFlippedInCrop,
                aspectRatioPreset: nextPreset.rawValue
            )
        } else {
            // free モード：現在の矩形を維持し、プリセット名のみ更新
            currentCropRect = CropRect(
                x: currentCropRect.x, y: currentCropRect.y,
                width: currentCropRect.width, height: currentCropRect.height,
                straightenAngle: currentCropRect.straightenAngle,
                quarterTurns: currentCropRect.quarterTurns,
                isFlippedInCrop: currentCropRect.isFlippedInCrop,
                aspectRatioPreset: nextPreset.rawValue
            )
        }
        canvasView?.cropRect = currentCropRect
    }

    // MARK: - Aspect Ratio Helpers

    /// 現在の画像サイズを取得（フォールバック: 1:1）
    private func effectiveImageSize() -> CGSize {
        guard let size = originalImage?.size, size.width > 0, size.height > 0 else {
            return CGSize(width: 1, height: 1)
        }
        return size
    }

    /// プリセットに対応するアスペクト比を解決する（free は nil を返す）
    private func resolveAspectRatio(for preset: AspectRatioPreset, imageSize: CGSize) -> CGFloat? {
        switch preset {
        case .original:
            return imageSize.width / imageSize.height
        default:
            return preset.ratio
        }
    }

    /// 現在設定されているアスペクト比制約を再適用する
    private func applyCurrentAspectRatioConstraint(to rect: CropRect) -> CropRect {
        guard let preset = AspectRatioPreset.from(presetName: rect.aspectRatioPreset) else {
            return rect
        }
        let imageSize = effectiveImageSize()
        guard let ratio = resolveAspectRatio(for: preset, imageSize: imageSize) else {
            return rect
        }
        let constrained = CropGeometry.constrainCropRect(rect, toAspectRatio: ratio, within: imageSize)
        return CropRect(
            x: constrained.x, y: constrained.y,
            width: constrained.width, height: constrained.height,
            straightenAngle: rect.straightenAngle,
            quarterTurns: rect.quarterTurns,
            isFlippedInCrop: rect.isFlippedInCrop,
            aspectRatioPreset: rect.aspectRatioPreset
        )
    }

    // MARK: - Key Monitor

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                DispatchQueue.main.async {
                    self?.cancelTapped()
                }
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Position Calculation

    static func calculatePanelOrigin(near window: NSWindow, panelSize: NSSize) -> NSPoint {
        let windowFrame = window.frame
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        // Try to place to the right of the window
        var x = windowFrame.maxX + panelGap
        var y = windowFrame.midY - panelSize.height / 2

        // If it doesn't fit on the right, try the left
        if x + panelSize.width > screenFrame.maxX {
            x = windowFrame.minX - panelSize.width - panelGap
        }
        // If it still doesn't fit, center on screen
        if x < screenFrame.minX {
            x = screenFrame.midX - panelSize.width / 2
        }

        // Clamp vertically
        y = max(screenFrame.minY, min(y, screenFrame.maxY - panelSize.height))

        return NSPoint(x: x, y: y)
    }
}

// MARK: - NSWindowDelegate

extension CropEditorPanelController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        delegate?.cropEditorDidCancel(self)
        close()
    }
}
