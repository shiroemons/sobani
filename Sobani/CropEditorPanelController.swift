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

    private static let panelGap: CGFloat = 20
    private static let topBarSidePadding: CGFloat = 16
    private static let topBarRowSpacing: CGFloat = 8
    private static let separatorWidth: CGFloat = 1
    private static let pillIconPointSize: CGFloat = 14
    private static let revertPillWidth: CGFloat = 60
    private static let revertFontSize: CGFloat = 12
    private static let separatorInset: CGFloat = 4

    // MARK: - Appearance Helpers

    /// 現在の外観に応じたピル背景色を返す
    private static func pillBackgroundCGColor() -> CGColor {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            return NSColor(white: 1.0, alpha: AppConstants.cropEditorPillBackgroundDarkAlpha).cgColor
        } else {
            return NSColor.white.cgColor
        }
    }

    /// 現在の外観に応じたセパレータ色を返す
    private static func separatorCGColor() -> CGColor {
        NSColor.separatorColor.cgColor
    }

    /// 現在の外観に応じたツールバー背景NSColorを返す
    private static func toolbarBackgroundNSColor() -> NSColor {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            return NSColor(white: AppConstants.cropEditorToolbarBackgroundDark, alpha: 1.0)
        } else {
            return NSColor(white: AppConstants.cropEditorToolbarBackgroundLight, alpha: 1.0)
        }
    }

    /// 現在の外観に応じたツールバー背景CGColorを返す
    private static func toolbarBackgroundCGColor() -> CGColor {
        toolbarBackgroundNSColor().cgColor
    }

    // MARK: - Properties

    weak var delegate: CropEditorPanelDelegate?
    private var panel: NSPanel?
    private var canvasView: CropEditorCanvasView?
    private var toolbarView: CropEditorToolbarView?
    private var topBarView: NSView?
    private var originalImage: NSImage?
    private(set) var currentCropRect: CropRect
    nonisolated(unsafe) private var keyMonitor: Any?

    private var revertButton: NSButton?
    private var doneButton: NSButton?
    private var donePillContainer: NSView?
    private var initialCropRect: CropRect
    private var history: CropEditHistory?
    private var undoButton: NSButton?
    private var redoButton: NSButton?
    private var modeButtons: [NSButton] = []

    /// 外観変更時にlayer背景色を再適用するためのピルコンテナ一覧（donePillContainerを除く）
    private var pillContainers: [NSView] = []
    /// 外観変更時にlayer背景色を再適用するためのセパレータ一覧
    private var separatorViews: [NSView] = []
    nonisolated(unsafe) private var appearanceObserver: Any?

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
        let canvasY = AppConstants.cropEditorToolbarHeight + AppConstants.cropEditorCanvasGap
        let canvasHeight = AppConstants.cropEditorPanelHeight
            - AppConstants.cropEditorTopBarHeight
            - AppConstants.cropEditorToolbarHeight
            - AppConstants.cropEditorCanvasGap * 2
        let canvas = CropEditorCanvasView(
            frame: NSRect(x: 0, y: canvasY, width: AppConstants.cropEditorPanelWidth, height: canvasHeight)
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
        syncToolbarState(to: currentCropRect)
        recordCurrentState()
        updateRevertButtonVisibility()
    }

    @objc private func flipTapped() {
        currentCropRect = currentCropRect.with(isFlippedInCrop: !currentCropRect.isFlippedInCrop)
        canvasView?.cropRect = currentCropRect
        recordCurrentState()
        updateRevertButtonVisibility()
    }

    @objc private func rotate90Tapped() {
        handleRotate90()
        recordCurrentState()
        updateRevertButtonVisibility()
    }

    @objc private func undoTapped() {
        guard let state = history?.undo() else { return }
        applyHistoryState(state)
    }

    @objc private func redoTapped() {
        guard let state = history?.redo() else { return }
        applyHistoryState(state)
    }

    @objc private func correctionModeTapped() {
        switchToolbarMode(to: .correction)
    }

    @objc private func aspectRatioModeTapped() {
        switchToolbarMode(to: .aspectRatio)
    }

    private func switchToolbarMode(to mode: ToolbarMode) {
        toolbarView?.setMode(mode)
        UserDefaults.standard.set(mode.rawValue, forKey: AppConstants.cropEditorLastToolbarModeKey)
        updateModeButtonsAppearance()
    }

    private func updateModeButtonsAppearance() {
        let currentMode = toolbarView?.currentToolbarMode ?? .correction
        guard modeButtons.count >= 2 else { return }
        let correctionBtn = modeButtons[0]
        let aspectRatioBtn = modeButtons[1]

        correctionBtn.contentTintColor = currentMode == .correction ? .labelColor : .tertiaryLabelColor
        aspectRatioBtn.contentTintColor = currentMode == .aspectRatio ? .labelColor : .tertiaryLabelColor
    }

    private func restoreSavedToolbarMode() -> ToolbarMode {
        if let saved = UserDefaults.standard.string(forKey: AppConstants.cropEditorLastToolbarModeKey),
           let mode = ToolbarMode(rawValue: saved) {
            return mode
        }
        return .aspectRatio
    }

    // MARK: - History Helpers

    private func applyHistoryState(_ state: CropRect) {
        currentCropRect = state
        canvasView?.initializeFromCropRect(state)
        syncToolbarState(to: state)
        updateRevertButtonVisibility()
        updateUndoRedoButtons()
    }

    private func recordCurrentState() {
        history?.record(currentCropRect)
        updateUndoRedoButtons()
    }

    private func updateUndoRedoButtons() {
        let canUndo = history?.canUndo ?? false
        let canRedo = history?.canRedo ?? false
        undoButton?.isEnabled = canUndo
        redoButton?.isEnabled = canRedo
        undoButton?.contentTintColor = canUndo ? .labelColor : .tertiaryLabelColor
        redoButton?.contentTintColor = canRedo ? .labelColor : .tertiaryLabelColor
    }

    // MARK: - Toolbar Sync

    private func syncToolbarState(to cropRect: CropRect) {
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
    private func currentAspectOrientation(_ cropRect: CropRect) -> CropGeometry.AspectOrientation {
        let imageSize = effectiveImageSize()
        let pixelWidth = cropRect.width * imageSize.width
        let pixelHeight = cropRect.height * imageSize.height
        if GeometryUtils.isApproximatelyEqual(pixelWidth, pixelHeight) {
            return .square
        }
        return pixelWidth > pixelHeight ? .landscape : .portrait
    }

    // MARK: - Revert Button Visibility

    private func updateRevertButtonVisibility() {
        let shouldShow = !currentCropRect.isEffectivelyEqual(to: .full)
        let isCurrentlyHidden = revertButton?.isHidden ?? true
        if shouldShow == isCurrentlyHidden {
            revertButton?.isHidden = !shouldShow
            revertButton?.superview?.isHidden = !shouldShow
        }
        updateDoneButtonAppearance()
    }

    private func updateDoneButtonAppearance() {
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

// MARK: - Toolbar Handlers

extension CropEditorPanelController {

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
        toolbarView?.updateShapeAspectOrientation(currentAspectOrientation(currentCropRect))
        recordCurrentState()
        updateRevertButtonVisibility()
    }
}

// MARK: - Aspect Ratio Helpers

extension CropEditorPanelController {

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
}

// MARK: - Key Monitor & Position Calculation

extension CropEditorPanelController {

    private func installAppearanceObserver() {
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: AppConstants.appearanceChangedNotificationName,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateAppearanceDependentColors()
            }
        }
    }

    private func removeAppearanceObserver() {
        if let observer = appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            appearanceObserver = nil
        }
    }

    private func updateAppearanceDependentColors() {
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
        bar.layer?.backgroundColor = Self.toolbarBackgroundCGColor()
        topBarView = bar

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
        // ── Row 1: [× Cancel]  [↩ Undo | Redo ↪]  [✓ Done] ──
        let (cancelPill, _) = makePillButton(symbolName: "xmark", action: #selector(cancelTapped))
        cancelPill.frame = NSRect(x: sidePad, y: rowY, width: pillSize, height: pillSize)
        bar.addSubview(cancelPill)
        pillContainers.append(cancelPill)

        let (donePill, doneBtn) = makePillButton(symbolName: "checkmark", action: #selector(doneTapped))
        doneBtn.keyEquivalent = "\r"
        donePill.frame = NSRect(x: width - sidePad - pillSize, y: rowY, width: pillSize, height: pillSize)
        bar.addSubview(donePill)
        doneButton = doneBtn
        donePillContainer = donePill
        // donePillContainer は updateDoneButtonAppearance で色管理するため pillContainers に追加しない

        // Center: grouped Undo/Redo pill
        let groupWidth = pillSize * 2 + Self.separatorWidth
        let undoRedoResult = makeGroupedPill(
            symbols: [
                ("arrow.uturn.backward", #selector(undoTapped)),
                ("arrow.uturn.forward", #selector(redoTapped))
            ],
            width: groupWidth
        )
        let groupX = (width - groupWidth) / 2
        undoRedoResult.container.frame = NSRect(x: groupX, y: rowY, width: groupWidth, height: pillSize)
        bar.addSubview(undoRedoResult.container)
        pillContainers.append(undoRedoResult.container)
        separatorViews.append(contentsOf: undoRedoResult.separators)

        if undoRedoResult.buttons.count >= 2 {
            undoButton = undoRedoResult.buttons[0]
            redoButton = undoRedoResult.buttons[1]
        }
    }

    private func addRow2(to bar: NSView, rowY: CGFloat) {
        let pillSize = AppConstants.cropEditorPillButtonSize
        let sidePad = Self.topBarSidePadding
        let width = AppConstants.cropEditorPanelWidth
        // ── Row 2: [Flip | Rotate]  [戻す] ──

        // Left: grouped pill [Flip | Rotate90]
        let groupWidth = pillSize * 2 + Self.separatorWidth
        let flipRotateResult = makeGroupedPill(
            symbols: [
                ("arrow.left.and.right.righttriangle.left.righttriangle.right", #selector(flipTapped)),
                ("rotate.left", #selector(rotate90Tapped))
            ],
            width: groupWidth
        )
        flipRotateResult.container.frame = NSRect(x: sidePad, y: rowY, width: groupWidth, height: pillSize)
        bar.addSubview(flipRotateResult.container)
        pillContainers.append(flipRotateResult.container)
        separatorViews.append(contentsOf: flipRotateResult.separators)

        // Center: "戻す" revert button
        let revertX = (width - Self.revertPillWidth) / 2
        let revertContainer = makePillContainer(frame: NSRect(x: revertX, y: rowY, width: Self.revertPillWidth, height: pillSize))

        let revertBtn = NSButton(frame: revertContainer.bounds)
        revertBtn.bezelStyle = .regularSquare
        revertBtn.isBordered = false
        revertBtn.imagePosition = .noImage
        revertBtn.title = L("crop_editor.reset")
        revertBtn.font = NSFont.systemFont(ofSize: Self.revertFontSize, weight: .medium)
        revertBtn.contentTintColor = .systemYellow
        revertBtn.target = self
        revertBtn.action = #selector(resetTapped)
        revertContainer.addSubview(revertBtn)
        bar.addSubview(revertContainer)
        revertButton = revertBtn
        pillContainers.append(revertContainer)

        // Right: mode toggle pill [angle | aspectratio]
        let modeGroupWidth = pillSize * 2 + Self.separatorWidth
        let modeResult = makeGroupedPill(
            symbols: [
                ("angle", #selector(correctionModeTapped)),
                ("aspectratio", #selector(aspectRatioModeTapped))
            ],
            width: modeGroupWidth
        )
        modeResult.container.frame = NSRect(x: width - sidePad - modeGroupWidth, y: rowY, width: modeGroupWidth, height: pillSize)
        bar.addSubview(modeResult.container)
        modeButtons = modeResult.buttons
        pillContainers.append(modeResult.container)
        separatorViews.append(contentsOf: modeResult.separators)
    }

    private func makePillContainer(frame: NSRect) -> NSView {
        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = Self.pillBackgroundCGColor()
        container.layer?.cornerRadius = AppConstants.cropEditorPillCornerRadius
        return container
    }

    private func configureIconButton(_ button: NSButton, symbolName: String, action: Selector) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.image = SFSymbolUtils.icon(symbolName, pointSize: Self.pillIconPointSize, weight: .medium)
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

    private struct GroupedPillResult {
        let container: NSView
        let buttons: [NSButton]
        let separators: [NSView]
    }

    /// Creates a grouped pill with multiple icon buttons separated by a 1px vertical line.
    private func makeGroupedPill(symbols: [(String, Selector)], width: CGFloat) -> GroupedPillResult {
        let height = AppConstants.cropEditorPillButtonSize
        let container = makePillContainer(frame: NSRect(x: 0, y: 0, width: width, height: height))

        let buttonWidth = (width - CGFloat(symbols.count - 1) * Self.separatorWidth) / CGFloat(symbols.count)
        var buttons: [NSButton] = []
        var separators: [NSView] = []

        for (index, (symbolName, action)) in symbols.enumerated() {
            let buttonX = CGFloat(index) * (buttonWidth + Self.separatorWidth)
            let button = NSButton(frame: NSRect(x: buttonX, y: 0, width: buttonWidth, height: height))
            configureIconButton(button, symbolName: symbolName, action: action)
            container.addSubview(button)
            buttons.append(button)

            // Add 1px separator between buttons
            if index < symbols.count - 1 {
                let sepX = buttonX + buttonWidth
                let separator = NSView(frame: NSRect(x: sepX, y: Self.separatorInset, width: Self.separatorWidth, height: height - Self.separatorInset * 2))
                separator.wantsLayer = true
                separator.layer?.backgroundColor = Self.separatorCGColor()
                container.addSubview(separator)
                separators.append(separator)
            }
        }

        return GroupedPillResult(container: container, buttons: buttons, separators: separators)
    }
}

// MARK: - Shape Handlers

extension CropEditorPanelController {

    private func handleShapeSelected(_ shape: CropShape) {
        var updated = currentCropRect.with(shape: shape)

        if shape == .roundedRectangle && updated.cornerRadii == .zero {
            // 角丸初回選択: デフォルト角丸を設定
            updated = updated.with(cornerRadii: CornerRadii.defaultLinked)
        }

        currentCropRect = updated
        canvasView?.initializeFromCropRect(updated)
        syncToolbarState(to: updated)
        recordCurrentState()
        updateRevertButtonVisibility()
    }

    private func handleCornersLinkedToggled(_ linked: Bool) {
        currentCropRect = currentCropRect.with(cornersLinked: linked)
        canvasView?.cropRect = currentCropRect
        recordCurrentState()
    }
}

// MARK: - NSWindowDelegate

extension CropEditorPanelController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        delegate?.cropEditorDidCancel(self)
        close()
    }
}
