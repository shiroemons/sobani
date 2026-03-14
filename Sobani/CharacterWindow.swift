import Cocoa
import UniformTypeIdentifiers

// MARK: - Rotatable Container

private final class RotatableContainer: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point), hit !== self { return hit }
        return subviews.first
    }
}

// MARK: - Character Window

@MainActor
final class CharacterWindow: NSObject, NSMenuDelegate {
    let window: NSWindow
    let imageView: DraggableImageView
    weak var delegate: CharacterWindowDelegate? {
        didSet { imageView.characterWindowDelegate = delegate }
    }
    var displayName: String = AppConstants.defaultImageName
    var windowId: Int = 0
    private(set) var adjustmentPanelController: AdjustmentPanelController?
    private var spinnerOverlay: NSProgressIndicator?
    private var isRemovingBackground = false
    private var cachedHasAlpha: Bool?
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
            self.delegate?.characterWindowDidBecomeActive(self)
        }
        imageView.onDoubleClick = { [weak self] in
            guard let self else { return }
            self.showFloatingMenu(at: NSEvent.mouseLocation)
        }
        imageView.onRotationChanged = { [weak self] in
            self?.adjustmentPanelController?.updateAngle(self?.imageView.rotationAngle ?? 0)
        }
        imageView.onOpacityChanged = { [weak self] in
            self?.updateImageAlpha()
        }
        imageView.onDragEntered = { [weak self] in self?.showHighlightBorder() }
        imageView.onDragExited = { [weak self] in self?.hideHighlightBorder() }
        imageView.onDropImage = { [weak self] url, isOption in
            guard let self else { return }
            if isOption {
                self.delegate?.characterWindowRequestedNewWindowWithFileURL(self, fileURL: url)
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

    func applyImage(_ image: NSImage) {
        guard image.size.height > 0 else { return }
        let baseHeight = imageView.frame.height
        let dims = Self.calculateImageDimensions(baseHeight: baseHeight, imageSize: image.size)
        imageView.image = image
        imageView.aspectRatio = dims.aspectRatio
        imageView.frame.size = NSSize(width: dims.width, height: baseHeight)
        cachedHasAlpha = nil
        adjustWindowForRotation()
    }

    @objc func toggleFlip() {
        imageView.isFlippedHorizontally.toggle()
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
            self?.imageView.onSizeChanged = nil
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
    }

    func applyRotation(_ angle: CGFloat) {
        imageView.rotationAngle = angle
        adjustWindowForRotation()
        adjustmentPanelController?.updateAngle(angle)
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

    func loadAndApplyImage(from url: URL) {
        guard let newImage = NSImage(contentsOf: url) else { return }
        let savedName = ImageManager.shared.registerImage(from: url)
        displayName = savedName ?? url.deletingPathExtension().lastPathComponent
        applyImage(newImage)
    }

    @objc func selectRegisteredImage(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let image = ImageManager.shared.loadRegisteredImage(named: name) else { return }
        displayName = name
        applyImage(image)
    }

    @objc func deleteRegisteredImage(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        ImageManager.shared.removeRegisteredImage(named: name)
        delegate?.characterWindowDidDeleteImage(named: name)
    }

    @objc func resetToDefault() {
        if let defaultImage = ImageManager.shared.defaultImage() {
            displayName = AppConstants.defaultImageName
            applyImage(defaultImage)
        }
    }

    @objc func addNewWindow() {
        delegate?.characterWindowRequestedNewWindow(self, imageName: nil)
    }

    @objc func addNewWindowWithImage(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        delegate?.characterWindowRequestedNewWindow(self, imageName: name)
    }

    @objc func addNewWindowWithNewImage(_ sender: NSMenuItem) {
        let panel = ImageFileDialog.makeOpenPanel(message: L("dialog.select_add_image_message"))
        if panel.runModal() == .OK, let url = panel.url {
            delegate?.characterWindowRequestedNewWindowWithFileURL(self, fileURL: url)
        }
    }

    @objc func closeThisWindow() {
        window.orderOut(nil)
        delegate?.characterWindowDidClose(self)
    }

    @objc func quitApp() {
        delegate?.requestQuit()
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
    }
}

// MARK: - Ghost Mode

extension CharacterWindow {
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
    }

    func setCustomGhostAlpha(_ alpha: CGFloat?) {
        guard alpha != customGhostAlpha else { return }
        customGhostAlpha = alpha
        if isGhostMode {
            updateImageAlpha()
        }
    }

    private func updateImageAlpha() {
        imageView.alphaValue = composedImageAlpha
    }
}

// MARK: - Hidden Window

extension CharacterWindow {
    func setHidden(_ hidden: Bool) {
        guard hidden != isHidden else { return }
        isHidden = hidden
        if hidden {
            floatingMenuController?.dismiss()
            adjustmentPanelController?.close()
            cropEditorController?.close()
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
        }
        delegate?.characterWindowDidChangeHidden(self)
    }

    @objc func hideThisWindow() {
        setHidden(true)
    }
}

// MARK: - Floating Menu

extension CharacterWindow: FloatingMenuDelegate {
    func showFloatingMenu(at screenPoint: NSPoint) {
        guard cropEditorController?.isVisible != true else { return }
        if floatingMenuController == nil {
            floatingMenuController = FloatingMenuController()
            floatingMenuController?.delegate = self
        }
        floatingMenuController?.isRemoveBackgroundEnabled = !isRemovingBackground && !imageHasAlpha()
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

extension CharacterWindow: CropEditorPanelDelegate {
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
        imageView.resetCrop()
    }

    func cropEditorDidConfirm(_ editor: CropEditorPanelController, cropRect: CropRect) {
        let oldWidth = imageView.frame.size.width
        let oldHeight = imageView.frame.size.height
        imageView.cropRect = cropRect
        let newAspect = imageView.aspectRatio
        // フレーム面積を維持しながら、新しいアスペクト比に合わせてリサイズ
        let oldArea = oldWidth * oldHeight
        let newHeight = sqrt(oldArea / newAspect)
        let newWidth = newHeight * newAspect
        imageView.frame.size = NSSize(width: round(newWidth), height: round(newHeight))
        adjustWindowForRotation()
        cropEditorController = nil
    }

    func cropEditorDidCancel(_ editor: CropEditorPanelController) { cropEditorController = nil }

    func cropEditorDidReset(_ editor: CropEditorPanelController) { imageView.resetCrop() }
}

// MARK: - Adjustment Panel Delegate

extension CharacterWindow: AdjustmentPanelDelegate {
    func rotationPanel(_ panel: AdjustmentPanelController, didChangeAngle angle: CGFloat) {
        applyRotation(angle)
    }

    func rotationPanelDidReset(_ panel: AdjustmentPanelController) {
        applyRotation(0)
    }

    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangePosition position: CGPoint) {
        let origin = Self.windowOrigin(
            forImageOrigin: position, imageViewSize: imageView.frame.size, rotationAngle: imageView.rotationAngle
        )
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
        let newOrigin = CGPoint(
            x: screen.frame.origin.x + relativeX,
            y: screen.frame.origin.y + relativeY
        )
        let newWindowOrigin = Self.windowOrigin(
            forImageOrigin: newOrigin, imageViewSize: imageView.frame.size, rotationAngle: imageView.rotationAngle
        )
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

// MARK: - Character Window Delegate

@MainActor
protocol CharacterWindowDelegate: AnyObject {
    var allCharacterWindows: [CharacterWindow] { get }
    func characterWindowRequestedNewWindow(_ sender: CharacterWindow, imageName: String?)
    func characterWindowRequestedNewWindowWithFileURL(_ sender: CharacterWindow, fileURL: URL)
    func characterWindowDidClose(_ sender: CharacterWindow)
    func characterWindowDidDeleteImage(named name: String)
    func characterWindowDidBecomeActive(_ sender: CharacterWindow)
    func characterWindowDidChangeHidden(_ sender: CharacterWindow)
    func requestQuit()
}

// MARK: - CharacterWindow + Context Menu

extension CharacterWindow {
    func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let registeredItem = NSMenuItem(title: L("image.change"), action: nil, keyEquivalent: "")
        registeredItem.tag = MenuItemTag.changeImageSubmenu.rawValue
        registeredItem.submenu = NSMenu()
        registeredItem.image = SFSymbolUtils.icon(AppConstants.changeImageSymbol)
        menu.addItem(registeredItem)
        menu.addItem(NSMenuItem.separator())

        let flipItem = NSMenuItem(title: L("adjust.flip"), action: #selector(toggleFlip), keyEquivalent: "")
        flipItem.tag = MenuItemTag.flipContext.rawValue
        flipItem.target = self
        flipItem.image = SFSymbolUtils.icon("arrow.left.and.right.righttriangle.left.righttriangle.right")
        menu.addItem(flipItem)
        menu.addItem(buildOpacitySliderMenuItem())

        let adjustPanelItem = NSMenuItem(
            title: L("adjust.open"), action: #selector(showAdjustmentPanel), keyEquivalent: ""
        )
        adjustPanelItem.tag = MenuItemTag.adjustPanelContext.rawValue
        adjustPanelItem.target = self
        adjustPanelItem.image = SFSymbolUtils.icon("slider.horizontal.3")
        menu.addItem(adjustPanelItem)
        menu.addItem(NSMenuItem.separator())

        let newWindowItem = NSMenuItem(title: L("image.add_display"), action: nil, keyEquivalent: "")
        newWindowItem.tag = MenuItemTag.addNewWindowSubmenu.rawValue
        newWindowItem.submenu = NSMenu()
        newWindowItem.image = SFSymbolUtils.icon("plus.rectangle.on.rectangle")
        menu.addItem(newWindowItem)
        menu.addItem(NSMenuItem.separator())

        let otherItem = NSMenuItem(title: L("menu.other"), action: nil, keyEquivalent: "")
        otherItem.tag = MenuItemTag.otherSubmenu.rawValue
        let otherSubmenu = NSMenu()
        otherSubmenu.autoenablesItems = false
        otherItem.submenu = otherSubmenu
        otherItem.image = SFSymbolUtils.icon("ellipsis.circle")
        menu.addItem(otherItem)
        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: L("menu.close_image"), action: #selector(closeThisWindow), keyEquivalent: "w")
        closeItem.tag = MenuItemTag.close.rawValue
        closeItem.target = self
        closeItem.image = SFSymbolUtils.icon(AppConstants.closeSymbol)
        menu.addItem(closeItem)

        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.tag = MenuItemTag.quit.rawValue
        quitItem.target = self
        quitItem.image = SFSymbolUtils.icon("power")
        menu.addItem(quitItem)
        imageView.menu = menu
    }

    private func buildOpacitySliderMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.tag = MenuItemTag.opacitySliderContext.rawValue

        let containerW = AppConstants.ghostAlphaSliderContainerWidth
        let containerH = AppConstants.opacitySliderContainerHeight
        let topRowH = AppConstants.opacitySliderTopRowHeight
        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerW, height: containerH))

        // Top row: icon + label
        let iconSize: CGFloat = 16
        let iconX: CGFloat = 16
        let iconY = containerH - topRowH + (topRowH - iconSize) / 2
        let iconView = NSImageView(frame: NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
        iconView.image = SFSymbolUtils.icon(AppConstants.opacitySymbol, pointSize: 12)
        iconView.imageScaling = .scaleProportionallyDown
        container.addSubview(iconView)

        let label = NSTextField(labelWithString: L("adjust.opacity"))
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        label.sizeToFit()
        label.frame.origin = NSPoint(x: iconX + iconSize + 4, y: iconY + (iconSize - label.frame.height) / 2)
        container.addSubview(label)

        // Bottom row: slider + percent
        let bottomRowH = containerH - topRowH
        let trailing = AppConstants.ghostAlphaSliderTrailingMargin
        let pctWidth = AppConstants.ghostAlphaSliderPercentWidth
        let sliderX: CGFloat = iconX + iconSize + 4
        let sliderH = AppConstants.ghostAlphaSliderHeight
        let slider = NSSlider(
            value: Double(imageView.opacityLevel),
            minValue: Double(AppConstants.opacityMin),
            maxValue: Double(AppConstants.opacityMax),
            target: self,
            action: #selector(contextMenuOpacitySliderChanged(_:))
        )
        slider.frame = NSRect(x: sliderX, y: (bottomRowH - sliderH) / 2,
                              width: containerW - sliderX - pctWidth - trailing, height: sliderH)
        slider.isContinuous = true
        slider.trackFillColor = .systemGray
        container.addSubview(slider)

        let percentLabel = NSTextField(labelWithString: FormatUtils.formatOpacity(imageView.opacityLevel))
        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        percentLabel.alignment = .right
        percentLabel.frame = NSRect(
            x: containerW - pctWidth - trailing,
            y: (bottomRowH - percentLabel.frame.height) / 2,
            width: pctWidth,
            height: percentLabel.frame.height
        )
        container.addSubview(percentLabel)

        item.view = container
        return item
    }

    @objc private func contextMenuOpacitySliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        applyOpacity(value)
        if let container = sender.superview,
           let percentLabel = container.subviews.compactMap({ $0 as? NSTextField }).last {
            percentLabel.stringValue = FormatUtils.formatOpacity(value)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let registeredItem = menu.item(withMenuTag: .changeImageSubmenu),
              let submenu = registeredItem.submenu else { return }

        updateTopLevelMenuTitles(menu)

        let names = ImageManager.shared.registeredImageNames()
        populateChangeImageSubmenu(submenu, names: names)
        populateNewWindowSubmenu(menu, names: names)

        if let flipItem = menu.item(withMenuTag: .flipContext) {
            flipItem.state = imageView.isFlippedHorizontally ? .on : .off
        }

        if let opacityItem = menu.item(withMenuTag: .opacitySliderContext),
           let container = opacityItem.view {
            if let slider = container.subviews.compactMap({ $0 as? NSSlider }).first {
                slider.doubleValue = Double(imageView.opacityLevel)
            }
            if let percentLabel = container.subviews.compactMap({ $0 as? NSTextField }).last {
                percentLabel.stringValue = FormatUtils.formatOpacity(imageView.opacityLevel)
            }
        }

        if let otherItem = menu.item(withMenuTag: .otherSubmenu),
           let otherSubmenu = otherItem.submenu {
            populateOtherSubmenu(otherSubmenu, names: names)
        }
    }

    private func populateChangeImageSubmenu(_ submenu: NSMenu, names: [String]) {
        submenu.removeAllItems()
        submenu.delegate = self
        submenu.autoenablesItems = false

        let changeItem = NSMenuItem(title: L("image.change_select"), action: #selector(changeImage), keyEquivalent: "o")
        changeItem.target = self
        changeItem.image = SFSymbolUtils.icon("photo")
        submenu.addItem(changeItem)

        let defaultItem = NSMenuItem(title: L("image.default_reset"), action: #selector(resetToDefault), keyEquivalent: "d")
        defaultItem.target = self
        defaultItem.isEnabled = displayName != AppConstants.defaultImageName
        defaultItem.image = SFSymbolUtils.icon("arrow.counterclockwise")
        submenu.addItem(defaultItem)

        submenu.addRegisteredImageItems(names: names, target: self, action: #selector(selectRegisteredImage(_:)))

        if #available(macOS 14.0, *) {
            submenu.addItem(NSMenuItem.separator())
            let removeBackgroundItem = NSMenuItem(
                title: L("image.remove_background"),
                action: #selector(removeBackground),
                keyEquivalent: ""
            )
            removeBackgroundItem.target = self
            removeBackgroundItem.tag = MenuItemTag.removeBackground.rawValue
            removeBackgroundItem.isEnabled = !isRemovingBackground && !imageHasAlpha()
            removeBackgroundItem.image = SFSymbolUtils.icon("eraser.fill")
            submenu.addItem(removeBackgroundItem)
        }
    }

    private func populateNewWindowSubmenu(_ menu: NSMenu, names: [String]) {
        guard let newWindowItem = menu.item(withMenuTag: .addNewWindowSubmenu),
              let newWindowSubmenu = newWindowItem.submenu else { return }

        newWindowSubmenu.removeAllItems()
        newWindowSubmenu.delegate = self
        let selectImageItem = NSMenuItem(title: L("image.select"), action: #selector(addNewWindowWithNewImage(_:)), keyEquivalent: "")
        selectImageItem.target = self
        newWindowSubmenu.addItem(selectImageItem)

        let defaultWindowItem = NSMenuItem(title: L("image.default"), action: #selector(addNewWindow), keyEquivalent: "n")
        defaultWindowItem.target = self
        newWindowSubmenu.addItem(defaultWindowItem)

        newWindowSubmenu.addRegisteredImageItems(names: names, target: self, action: #selector(addNewWindowWithImage(_:)))
    }

    // MARK: - Menu Highlight (Image Preview)

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        ImagePreviewPanel.shared.showPreviewIfApplicable(
            for: item,
            in: menu,
            registeredImageActions: [
                #selector(selectRegisteredImage(_:)),
                #selector(addNewWindowWithImage(_:)),
                #selector(deleteRegisteredImage(_:))
            ],
            defaultImageActions: [
                #selector(addNewWindow),
                #selector(resetToDefault)
            ]
        )
    }

    func menuDidClose(_ menu: NSMenu) {
        ImagePreviewPanel.shared.hide()
    }
}

// MARK: - CharacterWindow + Menu Title Update

extension CharacterWindow {
    nonisolated(unsafe) private static let menuTitleMap: [MenuItemTag: String] = [
        .changeImageSubmenu: "image.change",
        .flipContext: "adjust.flip",
        .adjustPanelContext: "adjust.open",
        .addNewWindowSubmenu: "image.add_display",
        .otherSubmenu: "menu.other",
        .close: "menu.close_image",
        .quit: "menu.quit"
    ]

    var localizedDisplayName: String {
        return Self.formatLocalizedDisplayName(
            displayName: displayName,
            defaultName: AppConstants.defaultImageName,
            localizedDefault: L("image.default_display")
        )
    }

    func updateTopLevelMenuTitles(_ menu: NSMenu) {
        for item in menu.items {
            if let key = Self.menuTitleLocalizationKey(forTag: item.tag) {
                item.title = L(key)
            }
        }
    }

    /// メニュータグに対応するローカライズキーを返す（該当なしならnil）
    nonisolated static func menuTitleLocalizationKey(forTag tag: Int) -> String? {
        guard let menuTag = MenuItemTag(rawValue: tag) else { return nil }
        return menuTitleMap[menuTag]
    }
}

// MARK: - CharacterWindow + Highlight Border

extension CharacterWindow {
    private static let highlightBorderWidth: CGFloat = 3.0

    func showHighlightBorder() {
        guard let contentView = window.contentView else { return }
        contentView.layer?.borderWidth = Self.highlightBorderWidth
        contentView.layer?.borderColor = NSColor.systemBlue.cgColor
    }

    func hideHighlightBorder() {
        window.contentView?.layer?.borderWidth = 0
        window.contentView?.layer?.borderColor = nil
    }
}

// MARK: - CharacterWindow + Background Removal

extension CharacterWindow {
    @objc func removeBackground() {
        guard !isRemovingBackground else { return }
        guard #available(macOS 14.0, *) else { return }
        isRemovingBackground = true
        guard let currentImage = imageView.image else {
            isRemovingBackground = false
            return
        }
        showSpinner()
        BackgroundRemovalManager.shared.removeBackground(from: currentImage) { [weak self] result in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.hideSpinner()
                self.isRemovingBackground = false
                switch result {
                case .success(let newImage):
                    let baseName = URL(fileURLWithPath: self.displayName).deletingPathExtension().lastPathComponent
                    let newName = "\(baseName)_nobg.png"
                    ImageManager.shared.registerImage(newImage, name: newName)
                    self.displayName = newName
                    self.applyImage(newImage)
                case .failure(let error):
                    AlertFactory.make(
                        style: .warning,
                        messageText: L("background_removal.error.title"),
                        informativeText: error.localizedDescription,
                        buttonTitles: [L("update.ok")]
                    ).runModal()
                }
            }
        }
    }

    private func showSpinner() {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.sizeToFit()
        if let contentView = window.contentView {
            spinner.frame.origin = NSPoint(
                x: (contentView.bounds.width - spinner.frame.width) / 2,
                y: (contentView.bounds.height - spinner.frame.height) / 2
            )
            spinner.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
            contentView.addSubview(spinner)
            spinner.startAnimation(nil)
        }
        spinnerOverlay = spinner
    }

    private func hideSpinner() {
        spinnerOverlay?.stopAnimation(nil)
        spinnerOverlay?.removeFromSuperview()
        spinnerOverlay = nil
    }

    func imageHasAlpha() -> Bool {
        if let cached = cachedHasAlpha { return cached }
        let result = computeImageHasAlpha()
        cachedHasAlpha = result
        return result
    }

    private func computeImageHasAlpha() -> Bool {
        guard let image = imageView.image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              Self.isAlphaInfoTransparent(cgImage.alphaInfo) else { return false }
        let (w, h) = (cgImage.width, cgImage.height)
        guard let context = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = context.data else { return false }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        return stride(from: 3, to: w * h * 4, by: 4).contains { ptr[$0] < 255 }
    }
}
