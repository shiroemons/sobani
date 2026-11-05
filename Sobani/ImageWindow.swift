import Cocoa
import os.log
import UniformTypeIdentifiers

// MARK: - Rotatable Container

private final class RotatableContainer: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // imageView 側で透過ピクセル判定と回転逆変換を行うため、委譲のみ。
        return (subviews.first as? DraggableImageView)?.hitTest(point)
    }
}

// MARK: - Image Window

/// デスクトップに表示される透明キャラクターウィンドウ。
///
/// 各ウィンドウは `NSWindow`（ボーダーレス透明）と `DraggableImageView` を保持し、
/// コンテキストメニュー、ゴーストモード、クロップ編集、背景除去、不透明度調整を提供する。
/// Z-order は `AppDelegate.zOrderedWindows` 配列で管理される。
@MainActor
final class ImageWindow: NSObject, NSMenuDelegate {
    private static let logger = Logger(category: "ImageWindow")
    let window: NSWindow
    let imageView: DraggableImageView
    weak var delegate: ImageWindowDelegate? {
        didSet { imageView.imageWindowDelegate = delegate }
    }
    var displayName: String = AppConstants.defaultImageName
    /// ウィンドウの一意識別子。`AppDelegate.nextWindowId` から順次割り当てられる。
    var windowId: Int = 0
    private(set) var adjustmentPanelController: AdjustmentPanelController?
    var spinnerOverlay: NSProgressIndicator?
    var isRemovingBackground = false
    var isRemoveBackgroundAvailable: Bool {
        !isRemovingBackground && !imageHasAlpha()
    }
    var cachedHasAlpha: Bool?
    /// ゴーストモードの状態。有効時は `ignoresMouseEvents = true` かつ画像の alpha が 0.3 になる。
    /// 無効化時は alpha がウィンドウ固有の `opacityLevel` に戻る（1.0 ではない）。
    private(set) var isGhostMode: Bool = false
    private(set) var isHidden: Bool = false
    private(set) var customGhostAlpha: CGFloat?
    private var floatingMenuController: FloatingMenuController?
    private var cropEditorController: CropEditorPanelController?
    nonisolated(unsafe) private var windowMoveObserver: NSObjectProtocol?

    init(image: NSImage) {
        let windowSize = Self.calculateWindowSize(imageSize: image.size, maxHeight: AppConstants.defaultWindowHeight)
        let windowWidth = windowSize.width
        let windowHeight = windowSize.height
        window = UnconstrainedWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isRestorable = false

        imageView = DraggableImageView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.aspectRatio = windowWidth / windowHeight
        imageView.wantsLayer = true
        imageView.autoresizingMask = []

        let container = RotatableContainer(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        container.wantsLayer = true
        container.autoresizesSubviews = false
        container.addSubview(imageView)
        window.contentView = container

        super.init()
        setupMenu()

        imageView.onMouseDown = { [weak self] in
            guard let self else { return }
            self.delegate?.imageWindowDidBecomeActive(self)
        }
        imageView.onDoubleClick = { [weak self] in
            guard let self else { return }
            self.showFloatingMenu(at: NSEvent.mouseLocation)
        }
        imageView.onRotationChanged = { [weak self] in
            self?.adjustmentPanelController?.updateAngle(self?.imageView.rotationAngle ?? 0)
        }
        imageView.onOpacityChanged = { [weak self] in
            self?.refreshImageAlpha()
        }
        imageView.onPositionChanged = { [weak self] in
            self?.notifyStateDidChange(.position)
        }
        installSizeChangedHandler()
        imageView.onDragEntered = { [weak self] in self?.showHighlightBorder() }
        imageView.onDragExited = { [weak self] in self?.hideHighlightBorder() }
        imageView.onDropImage = { [weak self] url, isOption in
            guard let self else { return }
            if isOption {
                self.delegate?.imageWindowRequestedNewWindowWithFileURL(self, fileURL: url)
            } else {
                self.loadAndApplyImage(from: url)
            }
        }
        let screenCenter = NSScreen.main?.frame ?? NSRect.zero
        let offsetX = CGFloat.random(in: -AppConstants.windowSpawnRandomOffset...AppConstants.windowSpawnRandomOffset)
        let offsetY = CGFloat.random(in: -AppConstants.windowSpawnRandomOffset...AppConstants.windowSpawnRandomOffset)
        let originX = (screenCenter.width - windowWidth) / 2 + offsetX
        let originY = (screenCenter.height - windowHeight) / 2 + offsetY
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
        window.makeKeyAndOrderFront(nil)
    }

    deinit {
        if let observer = windowMoveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func notifyStateDidChange(_ trigger: AppConstants.SnapshotTrigger) {
        NotificationCenter.default.post(
            name: AppConstants.imageWindowStateDidChange,
            object: self,
            userInfo: [AppConstants.notificationTriggerKey: trigger.rawValue]
        )
    }

    private func installSizeChangedHandler() {
        imageView.onSizeChanged = { [weak self] in
            self?.notifyStateDidChange(.size)
        }
    }

    /// 表示画像を別の画像に差し替える。旧画像のクロップは破棄し、高さを保ったまま新しい縦横比にする。
    func applyImage(_ image: NSImage) {
        guard image.size.height > 0 else { return }
        // 開いているクロップエディタは旧画像を編集しているため閉じる
        cropEditorController?.close()
        cropEditorController = nil
        let baseHeight = imageView.frame.height
        let dims = Self.calculateImageDimensions(baseHeight: baseHeight, imageSize: image.size)
        imageView.replaceImage(image)
        imageView.aspectRatio = dims.aspectRatio
        imageView.frame.size = NSSize(width: dims.width, height: baseHeight)
        cachedHasAlpha = nil
        adjustWindowForRotation()
        notifyStateDidChange(.image)
    }

    @objc func toggleFlip() {
        imageView.isFlippedHorizontally.toggle()
        notifyStateDidChange(.flip)
    }

    @objc func showAdjustmentPanel() {
        if adjustmentPanelController?.isVisible == true {
            closeAdjustmentPanel()
            return
        }
        let controller = AdjustmentPanelController()
        controller.delegate = self
        controller.onClose = { [weak self] in
            self?.imageView.scrollRotationHandler = nil
            if let observer = self?.windowMoveObserver {
                NotificationCenter.default.removeObserver(observer)
                self?.windowMoveObserver = nil
            }
            self?.installSizeChangedHandler()
            self?.imageView.isAdjustmentPanelActive = false
            self?.adjustmentPanelController = nil
        }
        controller.show(
            near: window,
            state: AdjustmentPanelState(
                angle: imageView.rotationAngle,
                position: currentImageOrigin(),
                size: imageView.frame.size,
                aspectRatio: imageView.aspectRatio
            )
        )
        adjustmentPanelController = controller
        imageView.isAdjustmentPanelActive = true
        imageView.scrollRotationHandler = { [weak self] delta in
            guard let self = self else { return }
            let angleDelta = delta * AppConstants.dialScrollSensitivity
            var newAngle = self.imageView.rotationAngle + angleDelta
            newAngle = GeometryUtils.normalizeAngle(newAngle)
            self.applyRotation(newAngle)
        }
        windowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: window, queue: .main
        ) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.adjustmentPanelController?.updatePosition(self.currentImageOrigin())
                self.adjustmentPanelController?.updateMonitor(self.window)
            }
        }
        imageView.onSizeChanged = { [weak self] in
            guard let self = self else { return }
            self.adjustmentPanelController?.updateSize(self.imageView.frame.size)
            self.notifyStateDidChange(.size)
        }
    }

    private func closeAdjustmentPanel() {
        adjustmentPanelController?.close()
    }

    @objc func resetRotation() { applyRotation(0) }
    @objc func resetOpacity() { applyOpacity(1.0) }

    func applyOpacity(_ opacity: CGFloat) {
        let clamped = min(max(opacity, AppConstants.opacityMin), AppConstants.opacityMax)
        guard !GeometryUtils.isApproximatelyEqual(clamped, imageView.opacityLevel) else { return }
        imageView.opacityLevel = clamped
        notifyStateDidChange(.opacity)
    }

    func applyRotation(_ angle: CGFloat) {
        // NaN/無限大はフレームや CALayer を壊し、JSON 保存も失敗させるため無視する
        guard angle.isFinite else { return }
        imageView.rotationAngle = angle
        adjustWindowForRotation()
        adjustmentPanelController?.updateAngle(angle)
        notifyStateDidChange(.rotation)
    }

    func adjustWindowForRotation() {
        let baseWidth = imageView.frame.width
        let baseHeight = imageView.frame.height
        let boundingBox = GeometryUtils.rotatedBoundingBox(
            width: baseWidth, height: baseHeight, angleDegrees: imageView.rotationAngle
        )
        let bbWidth = boundingBox.width
        let bbHeight = boundingBox.height

        let centerX = window.frame.midX
        let centerY = window.frame.midY
        window.setFrame(NSRect(
            x: round(centerX - bbWidth / 2),
            y: round(centerY - bbHeight / 2),
            width: round(bbWidth),
            height: round(bbHeight)
        ), display: false)
        imageView.frame = NSRect(
            x: (bbWidth - baseWidth) / 2,
            y: (bbHeight - baseHeight) / 2,
            width: baseWidth,
            height: baseHeight
        )
        imageView.needsLayout = true
    }

    @objc func changeImage() {
        let panel = ImageFileDialog.makeOpenPanel()
        if panel.runModal() == .OK, let url = panel.url {
            loadAndApplyImage(from: url)
        }
    }

    /// 外部の画像ファイルを登録してから表示する。
    ///
    /// 登録できなかった画像を表示すると、`displayName` が保存先に存在しない名前になり
    /// 再起動後にデフォルト画像へ戻ってしまうため、登録に失敗したら何もしない。
    func loadAndApplyImage(from url: URL) {
        guard let savedName = ImageManager.shared.registerImage(from: url) else {
            Self.logger.error("Failed to register image: \(url.lastPathComponent, privacy: .public)")
            return
        }
        if !selectRegisteredImage(named: savedName) {
            Self.logger.error("Failed to load registered image: \(savedName, privacy: .public)")
        }
    }

    /// 登録済み画像に切り替える。
    ///
    /// - Returns: 画像を読み込めて切り替えた場合 true。
    @discardableResult
    func selectRegisteredImage(named name: String) -> Bool {
        guard let image = ImageManager.shared.loadRegisteredImage(named: name) else { return false }
        displayName = name
        applyImage(image)
        return true
    }

    @objc func selectRegisteredImage(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        selectRegisteredImage(named: name)
    }

    @objc func deleteRegisteredImage(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        ImageManager.shared.removeRegisteredImage(named: name)
        delegate?.imageWindowDidDeleteImage(named: name)
    }

    @objc func resetToDefault() {
        if let defaultImage = ImageManager.shared.defaultImage() {
            displayName = AppConstants.defaultImageName
            applyImage(defaultImage)
        }
    }

    @objc func addNewWindow() {
        delegate?.imageWindowRequestedNewWindow(self, imageName: nil)
    }

    @objc func addNewWindowWithImage(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        delegate?.imageWindowRequestedNewWindow(self, imageName: name)
    }

    @objc func addNewWindowWithNewImage(_ sender: NSMenuItem) {
        let panel = ImageFileDialog.makeOpenPanel(message: L("dialog.select_add_image_message"))
        if panel.runModal() == .OK, let url = panel.url {
            delegate?.imageWindowRequestedNewWindowWithFileURL(self, fileURL: url)
        }
    }

    @objc func closeThisWindow() {
        window.orderOut(nil)
        delegate?.imageWindowDidClose(self)
    }

    @objc func quitApp() {
        delegate?.requestQuit()
    }

    @objc func quitAppWithoutSaving() {
        delegate?.requestQuitWithoutSaving()
    }

    @objc func resetDisplay() {
        if isGhostMode {
            setGhostMode(false)
            setCustomGhostAlpha(nil)
        }
        imageView.isFlippedHorizontally = false
        imageView.resetCrop()
        imageView.rotationAngle = 0
        adjustmentPanelController?.updateAngle(0)
        applyOpacity(1.0)

        let defaultHeight: CGFloat = AppConstants.defaultWindowHeight
        let defaultWidth = defaultHeight * imageView.aspectRatio

        let screenFrame = NSScreen.mainFrameOrFallback
        let originX = screenFrame.minX + (screenFrame.width - defaultWidth) / 2
        let originY = screenFrame.minY + (screenFrame.height - defaultHeight) / 2

        window.setFrame(NSRect(x: originX, y: originY, width: defaultWidth, height: defaultHeight), display: true)
        imageView.frame = NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight)
        imageView.needsLayout = true
        notifyStateDidChange(.reset)
    }
}

// MARK: - Ghost Mode

extension ImageWindow {
    var effectiveGhostAlpha: CGFloat {
        customGhostAlpha ?? GhostModeSettings.globalAlpha
    }

    private var composedImageAlpha: CGFloat {
        let ghostFactor = isGhostMode ? effectiveGhostAlpha : 1.0
        return imageView.opacityLevel * ghostFactor
    }

    @objc func toggleGhostMode() {
        setGhostMode(!isGhostMode)
    }

    func setGhostMode(_ enabled: Bool) {
        guard enabled != isGhostMode else { return }
        isGhostMode = enabled
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppConstants.ghostModeAnimationDuration
            imageView.animator().alphaValue = composedImageAlpha
        }
        window.ignoresMouseEvents = enabled
        notifyStateDidChange(.ghost)
    }

    func setCustomGhostAlpha(_ alpha: CGFloat?) {
        guard alpha != customGhostAlpha else { return }
        customGhostAlpha = alpha
        if isGhostMode {
            refreshImageAlpha()
        }
        notifyStateDidChange(.ghostAlpha)
    }

    /// 不透明度とゴーストモードを合成した alpha を imageView に再適用する。
    ///
    /// ゴーストの共通 alpha（`GhostModeSettings.globalAlpha`）を変えたときなど、
    /// ウィンドウ側の状態が変わらないまま見た目だけ更新したい場合に呼ぶ。
    func refreshImageAlpha() {
        imageView.alphaValue = composedImageAlpha
    }
}

// MARK: - Hidden Window

extension ImageWindow {
    /// このウィンドウに付属するパネル（フローティングメニュー・調整パネル・クロップエディタ）をすべて閉じる。
    ///
    /// 非表示化・クローズ・レイアウト適用など、ウィンドウが画面から消えるすべての経路で呼ぶこと。
    /// 閉じずに解放するとクロップエディタのキー監視などが残る。
    func dismissAuxiliaryPanels() {
        floatingMenuController?.dismiss()
        adjustmentPanelController?.close()
        cropEditorController?.close()
    }

    func setHidden(_ hidden: Bool) {
        guard hidden != isHidden else { return }
        isHidden = hidden
        if hidden {
            dismissAuxiliaryPanels()
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
        }
        delegate?.imageWindowDidChangeHidden(self)
        notifyStateDidChange(.hidden)
    }

    @objc func hideThisWindow() {
        setHidden(true)
    }
}

// MARK: - Floating Menu

extension ImageWindow: FloatingMenuDelegate {
    func showFloatingMenu(at screenPoint: NSPoint) {
        guard cropEditorController?.isVisible != true else { return }
        if floatingMenuController == nil {
            floatingMenuController = FloatingMenuController()
            floatingMenuController?.delegate = self
        }
        floatingMenuController?.isRemoveBackgroundEnabled = isRemoveBackgroundAvailable
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        floatingMenuController?.currentOpacity = imageView.opacityLevel
        floatingMenuController?.show(at: windowPoint, in: window)
    }

    func floatingMenuDidSelectCrop(_ menu: FloatingMenuController) { enterCropMode() }
    func floatingMenuDidSelectFlip(_ menu: FloatingMenuController) { toggleFlip() }
    func floatingMenuDidSelectAdjust(_ menu: FloatingMenuController) { showAdjustmentPanel() }
    func floatingMenuDidSelectRemoveBackground(_ menu: FloatingMenuController) { removeBackground() }
    func floatingMenuDidSelectClose(_ menu: FloatingMenuController) { closeThisWindow() }
    func floatingMenuDidSelectResetDisplay(_ menu: FloatingMenuController) { resetDisplay() }
    func floatingMenuDidSelectGhostMode(_ menu: FloatingMenuController) { setGhostMode(true) }
    func floatingMenuDidSelectHide(_ menu: FloatingMenuController) { setHidden(true) }

    func floatingMenu(_ menu: FloatingMenuController, didChangeOpacity opacity: CGFloat) {
        applyOpacity(opacity)
    }
}

// MARK: - Crop Mode

extension ImageWindow: CropEditorPanelDelegate {
    func enterCropMode() {
        guard cropEditorController?.isVisible != true else { return }
        let controller = CropEditorPanelController(cropRect: imageView.cropRect ?? .full)
        controller.delegate = self

        let sourceImage: NSImage
        if let original = imageView.originalImage {
            sourceImage = original
        } else if let current = imageView.image {
            sourceImage = current
        } else {
            return
        }

        controller.show(image: sourceImage, near: window)
        cropEditorController = controller
    }

    @objc func enterCropModeAction() {
        enterCropMode()
    }

    @objc func resetCrop() {
        guard imageView.cropRect != nil else { return }
        let oldSize = imageView.frame.size
        imageView.resetCrop()
        fitImageViewToAspectRatio(preservingAreaOf: oldSize)
        notifyStateDidChange(.crop)
    }

    func cropEditorDidConfirm(_ editor: CropEditorPanelController, cropRect: CropRect) {
        let oldSize = imageView.frame.size
        imageView.cropRect = cropRect
        fitImageViewToAspectRatio(preservingAreaOf: oldSize)
        cropEditorController = nil
        notifyStateDidChange(.crop)
    }

    /// クロップで縦横比が変わったとき、表示面積を保ったまま imageView とウィンドウを新しい縦横比に合わせる。
    private func fitImageViewToAspectRatio(preservingAreaOf oldSize: NSSize) {
        guard let newSize = Self.areaPreservingImageSize(
            currentSize: oldSize, aspectRatio: imageView.aspectRatio
        ) else { return }
        imageView.frame.size = NSSize(width: round(newSize.width), height: round(newSize.height))
        adjustWindowForRotation()
    }

    func cropEditorDidCancel(_ editor: CropEditorPanelController) { cropEditorController = nil }
}

// MARK: - Adjustment Panel Delegate

extension ImageWindow: AdjustmentPanelDelegate {
    func rotationPanel(_ panel: AdjustmentPanelController, didChangeAngle angle: CGFloat) {
        applyRotation(angle)
    }

    func rotationPanelDidReset(_ panel: AdjustmentPanelController) {
        applyRotation(0)
    }

    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangePosition position: CGPoint) {
        let origin = Self.windowOrigin(forImageOrigin: position, imageViewSize: imageView.frame.size, rotationAngle: imageView.rotationAngle)
        window.setFrameOrigin(origin)
    }

    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangeSize size: CGSize) {
        imageView.frame.size = size
        adjustWindowForRotation()
        adjustmentPanelController?.updatePosition(currentImageOrigin())
    }

    func adjustmentPanel(_ panel: AdjustmentPanelController, didSelectMonitor screen: NSScreen) {
        guard let oldScreen = NSScreen.screen(containing: window.frame) else { return }
        let oldOrigin = currentImageOrigin()
        let relativeX = oldOrigin.x - oldScreen.frame.origin.x
        let relativeY = oldOrigin.y - oldScreen.frame.origin.y
        let newOrigin = CGPoint(x: screen.frame.origin.x + relativeX, y: screen.frame.origin.y + relativeY)
        let newWindowOrigin = Self.windowOrigin(forImageOrigin: newOrigin, imageViewSize: imageView.frame.size, rotationAngle: imageView.rotationAngle)
        window.setFrameOrigin(newWindowOrigin)
        adjustmentPanelController?.updatePosition(currentImageOrigin())
    }

    func adjustmentPanelDidResetPositionAndSize(_ panel: AdjustmentPanelController) {
        resetDisplay()
        panel.updatePosition(currentImageOrigin())
        panel.updateSize(imageView.frame.size)
        panel.updateMonitor(window)
    }

    // MARK: Helpers
    private func currentImageOrigin() -> CGPoint {
        Self.imageOrigin(windowFrame: window.frame, imageViewSize: imageView.frame.size)
    }
}

// MARK: - Image Window Delegate

@MainActor
protocol ImageWindowDelegate: AnyObject {
    var allImageWindows: [ImageWindow] { get }
    func imageWindowRequestedNewWindow(_ sender: ImageWindow, imageName: String?)
    func imageWindowRequestedNewWindowWithFileURL(_ sender: ImageWindow, fileURL: URL)
    func imageWindowDidClose(_ sender: ImageWindow)
    func imageWindowDidDeleteImage(named name: String)
    func imageWindowDidBecomeActive(_ sender: ImageWindow)
    func imageWindowDidChangeHidden(_ sender: ImageWindow)
    func requestQuit()
    func requestQuitWithoutSaving()
}
