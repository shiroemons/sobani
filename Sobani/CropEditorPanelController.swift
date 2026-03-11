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

    private static let panelGap: CGFloat = 20
    private static let topBarSidePadding: CGFloat = 16
    private static let topBarRowSpacing: CGFloat = 4
    private static let separatorWidth: CGFloat = 1
    private static let pillIconPointSize: CGFloat = 14
    private static let revertPillWidth: CGFloat = 60
    private static let revertFontSize: CGFloat = 12
    private static let separatorInset: CGFloat = 4
    private static let pillBackgroundAlpha: CGFloat = 0.15

    // MARK: - Properties

    weak var delegate: CropEditorPanelDelegate?
    private var panel: NSPanel?
    private var canvasView: CropEditorCanvasView?
    private var toolbarView: CropEditorToolbarView?
    private var originalImage: NSImage?
    private(set) var currentCropRect: CropRect
    nonisolated(unsafe) private var keyMonitor: Any?

    private var revertButton: NSButton?
    private var modeToggleButton: NSButton?

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
            width: AppConstants.cropEditorPanelWidth, height: AppConstants.cropEditorPanelHeight
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

        // Top bar (2-row iPhone-style)
        let topBar = createTopBar(width: AppConstants.cropEditorPanelWidth)
        topBar.frame.origin = NSPoint(x: 0, y: AppConstants.cropEditorPanelHeight - AppConstants.cropEditorTopBarHeight)
        contentView.addSubview(topBar)

        // Bottom toolbar
        let toolbar = CropEditorToolbarView(
            frame: NSRect(x: 0, y: 0, width: AppConstants.cropEditorPanelWidth, height: AppConstants.cropEditorToolbarHeight)
        )
        toolbar.onStraightenAngleChanged = { [weak self] angle in
            self?.handleStraightenAngleChanged(angle)
        }
        toolbar.onAspectRatioSelected = { [weak self] preset in
            self?.handleAspectRatioSelected(preset)
        }
        toolbar.onModeChanged = { [weak self] mode in
            self?.handleModeChanged(mode)
        }
        contentView.addSubview(toolbar)
        toolbarView = toolbar
        if let preset = AspectRatioPreset.from(presetName: currentCropRect.aspectRatioPreset) {
            toolbar.updateAspectRatioSelection(preset)
        }

        // Central canvas
        let canvasY = AppConstants.cropEditorToolbarHeight
        let canvasHeight = AppConstants.cropEditorPanelHeight - AppConstants.cropEditorTopBarHeight - AppConstants.cropEditorToolbarHeight
        let canvas = CropEditorCanvasView(
            frame: NSRect(x: 0, y: canvasY, width: AppConstants.cropEditorPanelWidth, height: canvasHeight)
        )
        canvas.setImage(image)
        canvas.initializeFromCropRect(currentCropRect)
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

        updateRevertButtonVisibility()
        installKeyMonitor()
        logger.debug("Crop editor panel shown")
    }

    func close() {
        removeKeyMonitor()
        revertButton = nil
        modeToggleButton = nil
        canvasView = nil
        toolbarView = nil
        panel?.orderOut(nil)
        panel = nil
        originalImage = nil
    }

    // MARK: - Button Actions

    @objc private func cancelTapped() {
        delegate?.cropEditorDidCancel(self)
        close()
    }

    @objc private func doneTapped() {
        let finalRect = canvasView?.computeFinalCropRect() ?? currentCropRect
        currentCropRect = finalRect
        delegate?.cropEditorDidConfirm(self, cropRect: finalRect)
        close()
    }

    @objc private func resetTapped() {
        currentCropRect = .full
        canvasView?.cropRect = .full
        canvasView?.resetZoomAndOffset()
        toolbarView?.resetStraightenAngle()
        toolbarView?.hideAspectRatioSelector()
        toolbarView?.updateAspectRatioSelection(.free)
        delegate?.cropEditorDidReset(self)
        updateRevertButtonVisibility()
    }

    @objc private func flipTapped() {
        currentCropRect = currentCropRect.with(isFlippedInCrop: !currentCropRect.isFlippedInCrop)
        canvasView?.cropRect = currentCropRect
        updateRevertButtonVisibility()
    }

    @objc private func rotate90Tapped() {
        handleRotate90()
        updateRevertButtonVisibility()
    }

    @objc private func modeToggleTapped() {
        guard let toolbar = toolbarView else { return }
        let newMode: ToolbarMode = (toolbar.currentToolbarMode == .correction) ? .aspectRatio : .correction
        toolbar.setMode(newMode)
        updateModeToggleAppearance()
    }

    // MARK: - Revert Button Visibility

    private func updateRevertButtonVisibility() {
        let shouldShow = currentCropRect != .full
        let isCurrentlyHidden = revertButton?.isHidden ?? true
        guard shouldShow == isCurrentlyHidden else { return }
        revertButton?.isHidden = !shouldShow
        revertButton?.superview?.isHidden = !shouldShow
    }

    // MARK: - Mode Toggle Appearance

    private func updateModeToggleAppearance() {
        let mode = toolbarView?.currentToolbarMode ?? .correction
        let symbolName = mode.toggleSymbolName
        let config = NSImage.SymbolConfiguration(pointSize: Self.pillIconPointSize, weight: .medium)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            modeToggleButton?.image = image.withSymbolConfiguration(config)
        }
    }

    // MARK: - Toolbar Handlers

    private func handleStraightenAngleChanged(_ angle: CGFloat) {
        let clamped = CropGeometry.clampStraightenAngle(angle)
        let currentMode = toolbarView?.currentStraightenMode ?? .straighten
        var updated: CropRect
        switch currentMode {
        case .straighten:
            updated = currentCropRect.with(straightenAngle: clamped)
        case .verticalPerspective:
            updated = currentCropRect.with(verticalPerspective: clamped)
        case .horizontalPerspective:
            updated = currentCropRect.with(horizontalPerspective: clamped)
        }
        updated = applyCurrentAspectRatioConstraint(to: updated)
        currentCropRect = updated
        canvasView?.cropRect = currentCropRect
        updateRevertButtonVisibility()
    }

    private func handleModeChanged(_ mode: StraightenMode) {
        // モード切り替え時はキャンバスの再描画不要（角度は変更しない）
    }

    private func handleRotate90() {
        var updated = CropGeometry.cropRectAfterQuarterTurn(cropRect: currentCropRect, turns: 1)
        updated = applyCurrentAspectRatioConstraint(to: updated)
        currentCropRect = updated
        canvasView?.cropRect = currentCropRect
    }

    private func handleAspectRatioSelected(_ preset: AspectRatioPreset) {
        let imageSize = effectiveImageSize()
        if let ratio = resolveAspectRatio(for: preset, imageSize: imageSize) {
            let base = CropGeometry.cropRectForAspectRatio(
                ratio: ratio, within: imageSize
            )
            currentCropRect = currentCropRect.with(
                x: base.x, y: base.y,
                width: base.width, height: base.height,
                aspectRatioPreset: .some(preset.rawValue)
            )
        } else {
            // フリー: aspectRatioPresetのみ更新、サイズ変更なし
            currentCropRect = currentCropRect.with(aspectRatioPreset: .some(preset.rawValue))
        }
        canvasView?.initializeFromCropRect(currentCropRect)
        toolbarView?.updateAspectRatioSelection(preset)
        updateRevertButtonVisibility()
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
        return rect.with(
            x: constrained.x, y: constrained.y,
            width: constrained.width, height: constrained.height
        )
    }

    // MARK: - Key Monitor

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == AppConstants.escKeyCode { // ESC
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

// MARK: - Top Bar Builder

extension CropEditorPanelController {

    private func createTopBar(width: CGFloat) -> NSView {
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: width, height: AppConstants.cropEditorTopBarHeight))
        bar.wantsLayer = true

        let pillSize = AppConstants.cropEditorPillButtonSize
        let rowSpacing = Self.topBarRowSpacing

        // Centre the two rows within the bar height
        let twoRowsHeight = pillSize * 2 + rowSpacing
        let verticalOffset = (AppConstants.cropEditorTopBarHeight - twoRowsHeight) / 2

        let row2Y = verticalOffset                         // bottom row (row 2)
        let row1Y = verticalOffset + pillSize + rowSpacing // top row (row 1)

        addRow1(to: bar, rowY: row1Y)
        addRow2(to: bar, rowY: row2Y)

        return bar
    }

    private func addRow1(to bar: NSView, rowY: CGFloat) {
        let pillSize = AppConstants.cropEditorPillButtonSize
        let sidePad = Self.topBarSidePadding
        let width = AppConstants.cropEditorPanelWidth
        // ── Row 1: [× Cancel]  ···  [✓ Done] ──
        let (cancelPill, _) = makePillButton(symbolName: "xmark", action: #selector(cancelTapped))
        cancelPill.frame = NSRect(x: sidePad, y: rowY, width: pillSize, height: pillSize)
        bar.addSubview(cancelPill)

        let (donePill, doneBtn) = makePillButton(symbolName: "checkmark", action: #selector(doneTapped))
        doneBtn.keyEquivalent = "\r"
        donePill.frame = NSRect(x: width - sidePad - pillSize, y: rowY, width: pillSize, height: pillSize)
        bar.addSubview(donePill)
    }

    private func addRow2(to bar: NSView, rowY: CGFloat) {
        let pillSize = AppConstants.cropEditorPillButtonSize
        let sidePad = Self.topBarSidePadding
        let width = AppConstants.cropEditorPanelWidth
        // ── Row 2: [Flip | Rotate]  [戻す]  [ModeToggle] ──

        // Left: grouped pill [Flip | Rotate90]
        let groupWidth = pillSize * 2 + Self.separatorWidth
        let groupPill = makeGroupedPill(
            symbols: [
                ("arrow.left.and.right.righttriangle.left.righttriangle.right", #selector(flipTapped)),
                ("rotate.left", #selector(rotate90Tapped))
            ],
            width: groupWidth
        )
        groupPill.frame = NSRect(x: sidePad, y: rowY, width: groupWidth, height: pillSize)
        bar.addSubview(groupPill)

        // Right: mode toggle pill
        let (modeTogglePill, toggleBtn) = makePillButton(symbolName: ToolbarMode.correction.toggleSymbolName, action: #selector(modeToggleTapped))
        modeTogglePill.frame = NSRect(x: width - sidePad - pillSize, y: rowY, width: pillSize, height: pillSize)
        bar.addSubview(modeTogglePill)
        modeToggleButton = toggleBtn

        // Center: "戻す" revert button
        let revertX = (width - Self.revertPillWidth) / 2
        let revertContainer = makePillContainer(frame: NSRect(x: revertX, y: rowY, width: Self.revertPillWidth, height: pillSize))

        let revertBtn = NSButton(frame: revertContainer.bounds)
        revertBtn.bezelStyle = .regularSquare
        revertBtn.isBordered = false
        revertBtn.imagePosition = .noImage
        revertBtn.title = L("crop_editor.reset")
        revertBtn.font = NSFont.systemFont(ofSize: Self.revertFontSize, weight: .medium)
        revertBtn.contentTintColor = .labelColor
        revertBtn.target = self
        revertBtn.action = #selector(resetTapped)
        revertContainer.addSubview(revertBtn)
        bar.addSubview(revertContainer)
        revertButton = revertBtn
    }

    private func makePillContainer(frame: NSRect) -> NSView {
        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.withAlphaComponent(Self.pillBackgroundAlpha).cgColor
        container.layer?.cornerRadius = AppConstants.cropEditorPillCornerRadius
        return container
    }

    private func configureIconButton(_ button: NSButton, symbolName: String, action: Selector) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        let config = NSImage.SymbolConfiguration(pointSize: Self.pillIconPointSize, weight: .medium)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            button.image = image.withSymbolConfiguration(config)
        }
        button.contentTintColor = .labelColor
    }

    /// Creates a pill-shaped container with a single icon button inside.
    private func makePillButton(symbolName: String, action: Selector) -> (container: NSView, button: NSButton) {
        let size = AppConstants.cropEditorPillButtonSize
        let container = makePillContainer(frame: NSRect(x: 0, y: 0, width: size, height: size))

        let button = NSButton(frame: container.bounds)
        configureIconButton(button, symbolName: symbolName, action: action)
        container.addSubview(button)
        return (container, button)
    }

    /// Creates a grouped pill with multiple icon buttons separated by a 1px vertical line.
    private func makeGroupedPill(symbols: [(String, Selector)], width: CGFloat) -> NSView {
        let height = AppConstants.cropEditorPillButtonSize
        let container = makePillContainer(frame: NSRect(x: 0, y: 0, width: width, height: height))

        let buttonWidth = (width - CGFloat(symbols.count - 1) * Self.separatorWidth) / CGFloat(symbols.count)

        for (index, (symbolName, action)) in symbols.enumerated() {
            let buttonX = CGFloat(index) * (buttonWidth + Self.separatorWidth)
            let button = NSButton(frame: NSRect(x: buttonX, y: 0, width: buttonWidth, height: height))
            configureIconButton(button, symbolName: symbolName, action: action)
            container.addSubview(button)

            // Add 1px separator between buttons
            if index < symbols.count - 1 {
                let sepX = buttonX + buttonWidth
                let separator = NSView(frame: NSRect(x: sepX, y: Self.separatorInset, width: Self.separatorWidth, height: height - Self.separatorInset * 2))
                separator.wantsLayer = true
                separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
                container.addSubview(separator)
            }
        }

        return container
    }
}

// MARK: - NSWindowDelegate

extension CropEditorPanelController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        delegate?.cropEditorDidCancel(self)
        close()
    }
}
