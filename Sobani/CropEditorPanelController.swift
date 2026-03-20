import Cocoa
import os.log

// MARK: - Crop Editor Panel Delegate

@MainActor
protocol CropEditorPanelDelegate: AnyObject {
    func cropEditorDidConfirm(_ editor: CropEditorPanelController, cropRect: CropRect)
    func cropEditorDidCancel(_ editor: CropEditorPanelController)
}

// MARK: - Crop Editor Panel Controller

@MainActor
final class CropEditorPanelController: NSObject {
    private let logger = Logger(category: "CropEditorPanelController")

    // MARK: - Constants

    static let panelGap: CGFloat = 20
    static let topBarSidePadding: CGFloat = 16
    static let topBarRowSpacing: CGFloat = 8
    static let separatorWidth: CGFloat = 1
    static let pillIconPointSize: CGFloat = 14
    static let revertPillWidth: CGFloat = 60
    static let revertFontSize: CGFloat = 12
    static let separatorInset: CGFloat = 4

    // MARK: - Appearance Helpers

    /// 現在の外観に応じたピル背景色を返す
    static func pillBackgroundCGColor() -> CGColor {
        if NSApp.effectiveAppearance.isDark {
            return NSColor(
                white: 1.0, alpha: AppConstants.cropEditorPillBackgroundDarkAlpha
            ).cgColor
        } else {
            return NSColor.white.cgColor
        }
    }

    /// 現在の外観に応じたセパレータ色を返す
    static func separatorCGColor() -> CGColor {
        NSColor.separatorColor.cgColor
    }

    /// 現在の外観に応じたツールバー背景NSColorを返す
    static func toolbarBackgroundNSColor() -> NSColor {
        if NSApp.effectiveAppearance.isDark {
            return NSColor(white: AppConstants.cropEditorToolbarBackgroundDark, alpha: 1.0)
        } else {
            return NSColor(white: AppConstants.cropEditorToolbarBackgroundLight, alpha: 1.0)
        }
    }

    /// 現在の外観に応じたツールバー背景CGColorを返す
    static func toolbarBackgroundCGColor() -> CGColor {
        toolbarBackgroundNSColor().cgColor
    }

    // MARK: - Properties

    weak var delegate: CropEditorPanelDelegate?
    var panel: NSPanel?
    var canvasView: CropEditorCanvasView?
    var toolbarView: CropEditorToolbarView?
    var topBarView: NSView?
    var originalImage: NSImage?
    var currentCropRect: CropRect
    nonisolated(unsafe) private var keyMonitor: Any?

    var revertButton: NSButton?
    var doneButton: NSButton?
    var donePillContainer: NSView?
    private var initialCropRect: CropRect
    private var history: CropEditHistory?
    var undoButton: NSButton?
    var redoButton: NSButton?
    var modeButtons: [NSButton] = []

    /// 外観変更時にlayer背景色を再適用するためのピルコンテナ一覧（donePillContainerを除く）
    var pillContainers: [NSView] = []
    /// 外観変更時にlayer背景色を再適用するためのセパレータ一覧
    var separatorViews: [NSView] = []
    private var appearanceObserver: NSKeyValueObservation?

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Init

    init(cropRect: CropRect = .full) {
        self.currentCropRect = cropRect
        self.initialCropRect = cropRect
        super.init()
    }

    // MARK: - Show / Close

    func show(image: NSImage, near window: NSWindow) {
        close()
        initialCropRect = currentCropRect
        originalImage = image
        history = CropEditHistory(initialState: currentCropRect)

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
        newPanel.titlebarAppearsTransparent = true
        newPanel.backgroundColor = Self.toolbarBackgroundNSColor()
        newPanel.configureForFloating()
        newPanel.delegate = self

        let contentView = NSView(frame: panelRect)
        contentView.wantsLayer = true

        // Top bar (2-row iPhone-style)
        let topBar = createTopBar(width: AppConstants.cropEditorPanelWidth)
        topBar.frame.origin = NSPoint(
            x: 0, y: AppConstants.cropEditorPanelHeight - AppConstants.cropEditorTopBarHeight
        )
        contentView.addSubview(topBar)

        // Bottom toolbar
        let toolbar = CropEditorToolbarView(
            frame: NSRect(
                x: 0, y: 0,
                width: AppConstants.cropEditorPanelWidth,
                height: AppConstants.cropEditorToolbarHeight
            )
        )
        toolbar.onStraightenAngleChanged = { [weak self] angle in
            self?.handleStraightenAngleChanged(angle)
        }
        toolbar.onAspectRatioSelected = { [weak self] preset in
            self?.handleAspectRatioSelected(preset)
        }
        toolbar.onSliderDragEnded = { [weak self] in
            self?.recordCurrentState()
        }
        toolbar.onShapeSelected = { [weak self] shape in
            self?.handleShapeSelected(shape)
        }
        toolbar.onCornersLinkedToggled = { [weak self] linked in
            self?.handleCornersLinkedToggled(linked)
        }
        contentView.addSubview(toolbar)
        toolbarView = toolbar
        let savedMode = restoreSavedToolbarMode()
        toolbar.setMode(savedMode)
        updateModeButtonsAppearance()
        syncToolbarState(to: currentCropRect)

        // Central canvas
        setupCanvasView(image: image, contentView: contentView)

        newPanel.contentView = contentView

        // Position near the target window
        let panelOrigin = Self.calculatePanelOrigin(near: window, panelSize: panelRect.size)
        newPanel.setFrameOrigin(panelOrigin)
        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel

        updateRevertButtonVisibility()
        updateUndoRedoButtons()
        installKeyMonitor()
        installAppearanceObserver()
        logger.debug("Crop editor panel shown")
    }

    private func setupCanvasView(image: NSImage, contentView: NSView) {
        let canvasY = AppConstants.cropEditorToolbarHeight + AppConstants.cropEditorCanvasGap
        let canvasHeight = AppConstants.cropEditorPanelHeight
            - AppConstants.cropEditorTopBarHeight
            - AppConstants.cropEditorToolbarHeight
            - AppConstants.cropEditorCanvasGap * 2
        let canvas = CropEditorCanvasView(
            frame: NSRect(
                x: 0, y: canvasY,
                width: AppConstants.cropEditorPanelWidth, height: canvasHeight
            )
        )
        canvas.setImage(image)
        canvas.initializeFromCropRect(currentCropRect)
        canvas.onCropRectChanged = { [weak self] newRect in
            self?.currentCropRect = newRect
            self?.updateRevertButtonVisibility()
        }
        canvas.onDragEnded = { [weak self] in
            self?.recordCurrentState()
        }
        contentView.addSubview(canvas)
        canvasView = canvas
    }

    func close() {
        removeKeyMonitor()
        removeAppearanceObserver()
        revertButton = nil
        doneButton = nil
        donePillContainer = nil
        pillContainers = []
        separatorViews = []
        undoButton = nil
        redoButton = nil
        modeButtons = []
        history = nil
        canvasView = nil
        toolbarView?.cleanup()
        toolbarView = nil
        topBarView = nil
        panel?.orderOut(nil)
        panel = nil
        originalImage = nil
    }

    // MARK: - Button Actions

    @objc func cancelTapped() {
        delegate?.cropEditorDidCancel(self)
        close()
    }

    @objc func doneTapped() {
        let finalRect = canvasView?.computeFinalCropRect() ?? currentCropRect
        currentCropRect = finalRect
        delegate?.cropEditorDidConfirm(self, cropRect: finalRect)
        close()
    }

    @objc func resetTapped() {
        currentCropRect = .full
        canvasView?.cropRect = .full
        canvasView?.resetZoomAndOffset()
        toolbarView?.resetStraightenAngle()
        toolbarView?.hideAspectRatioSelector()
        syncToolbarState(to: currentCropRect)
        recordCurrentState()
        updateRevertButtonVisibility()
    }

    @objc func flipTapped() {
        currentCropRect = currentCropRect.with(isFlippedInCrop: !currentCropRect.isFlippedInCrop)
        canvasView?.cropRect = currentCropRect
        recordCurrentState()
        updateRevertButtonVisibility()
    }

    @objc func rotate90Tapped() {
        handleRotate90()
        recordCurrentState()
        updateRevertButtonVisibility()
    }

    @objc func undoTapped() {
        guard let state = history?.undo() else { return }
        applyHistoryState(state)
    }

    @objc func redoTapped() {
        guard let state = history?.redo() else { return }
        applyHistoryState(state)
    }

    @objc func correctionModeTapped() {
        switchToolbarMode(to: .correction)
    }

    @objc func aspectRatioModeTapped() {
        switchToolbarMode(to: .aspectRatio)
    }

    func switchToolbarMode(to mode: ToolbarMode) {
        toolbarView?.setMode(mode)
        UserDefaults.standard.set(mode.rawValue, forKey: AppConstants.cropEditorLastToolbarModeKey)
        updateModeButtonsAppearance()
    }

    func updateModeButtonsAppearance() {
        let currentMode = toolbarView?.currentToolbarMode ?? .correction
        guard modeButtons.count >= 2 else { return }
        let correctionBtn = modeButtons[0]
        let aspectRatioBtn = modeButtons[1]

        correctionBtn.contentTintColor =
            currentMode == .correction ? .labelColor : .tertiaryLabelColor
        aspectRatioBtn.contentTintColor =
            currentMode == .aspectRatio ? .labelColor : .tertiaryLabelColor
    }

    func restoreSavedToolbarMode() -> ToolbarMode {
        let key = AppConstants.cropEditorLastToolbarModeKey
        if let saved = UserDefaults.standard.string(forKey: key),
           let mode = ToolbarMode(rawValue: saved) {
            return mode
        }
        return .aspectRatio
    }

    // MARK: - History Helpers

    func applyHistoryState(_ state: CropRect) {
        currentCropRect = state
        canvasView?.initializeFromCropRect(state)
        syncToolbarState(to: state)
        updateRevertButtonVisibility()
        updateUndoRedoButtons()
    }

    func recordCurrentState() {
        history?.record(currentCropRect)
        updateUndoRedoButtons()
    }

    func updateUndoRedoButtons() {
        let canUndo = history?.canUndo ?? false
        let canRedo = history?.canRedo ?? false
        undoButton?.isEnabled = canUndo
        redoButton?.isEnabled = canRedo
        undoButton?.contentTintColor = canUndo ? .labelColor : .tertiaryLabelColor
        redoButton?.contentTintColor = canRedo ? .labelColor : .tertiaryLabelColor
    }

    // MARK: - Toolbar Sync

    func syncToolbarState(to cropRect: CropRect) {
        toolbarView?.syncAngles(
            straighten: cropRect.straightenAngle,
            verticalPerspective: cropRect.verticalPerspective,
            horizontalPerspective: cropRect.horizontalPerspective
        )
        if let preset = AspectRatioPreset.from(presetName: cropRect.aspectRatioPreset) {
            toolbarView?.updateAspectRatioSelection(preset)
        }
        toolbarView?.updateShapeSelection(cropRect.shape)
        toolbarView?.setCornersLinked(cropRect.cornersLinked)
        toolbarView?.updateShapeAspectOrientation(currentAspectOrientation(cropRect))
    }

    /// 現在のクロップ領域のアスペクト比の向きを判定
    func currentAspectOrientation(_ cropRect: CropRect) -> CropGeometry.AspectOrientation {
        let imageSize = effectiveImageSize()
        let pixelWidth = cropRect.width * imageSize.width
        let pixelHeight = cropRect.height * imageSize.height
        if GeometryUtils.isApproximatelyEqual(pixelWidth, pixelHeight) {
            return .square
        }
        return pixelWidth > pixelHeight ? .landscape : .portrait
    }

    // MARK: - Revert Button Visibility

    func updateRevertButtonVisibility() {
        let shouldShow = !currentCropRect.isEffectivelyEqual(to: .full)
        let isCurrentlyHidden = revertButton?.isHidden ?? true
        if shouldShow == isCurrentlyHidden {
            revertButton?.isHidden = !shouldShow
            revertButton?.superview?.isHidden = !shouldShow
        }
        updateDoneButtonAppearance()
    }

    func updateDoneButtonAppearance() {
        let hasChanges = !currentCropRect.isEffectivelyEqual(to: initialCropRect)
        if hasChanges {
            donePillContainer?.layer?.backgroundColor = NSColor.systemGreen.cgColor
            doneButton?.contentTintColor = .white // 緑背景上では白固定
        } else {
            donePillContainer?.layer?.backgroundColor = Self.pillBackgroundCGColor()
            doneButton?.contentTintColor = .labelColor
        }
    }

}

// MARK: - Key Monitor & Position Calculation

extension CropEditorPanelController {

    func installAppearanceObserver() {
        appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.updateAppearanceDependentColors()
            }
        }
    }

    func removeAppearanceObserver() {
        appearanceObserver?.invalidate()
        appearanceObserver = nil
    }

    func updateAppearanceDependentColors() {
        let pillBg = Self.pillBackgroundCGColor()
        for container in pillContainers {
            container.layer?.backgroundColor = pillBg
        }
        let sepColor = Self.separatorCGColor()
        for separator in separatorViews {
            separator.layer?.backgroundColor = sepColor
        }
        // トップバー・パネル背景色の再適用
        let toolbarBg = Self.toolbarBackgroundNSColor()
        topBarView?.layer?.backgroundColor = toolbarBg.cgColor
        panel?.backgroundColor = toolbarBg
        // donePillContainerは状態依存のため updateDoneButtonAppearance で再適用
        updateDoneButtonAppearance()
    }

    func installKeyMonitor() {
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

    func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

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
