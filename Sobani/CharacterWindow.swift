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
            self?.adjustmentPanelController?.updateOpacity(self?.imageView.opacityLevel ?? 1.0)
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
                opacity: imageView.opacityLevel,
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
        imageView.opacityLevel = clamped
        adjustmentPanelController?.updateOpacity(clamped)
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
        imageView.isFlippedHorizontally = false
        imageView.resetCrop()
        imageView.rotationAngle = 0
        imageView.opacityLevel = 1.0
        adjustmentPanelController?.updateAngle(0)
        adjustmentPanelController?.updateOpacity(1.0)

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
        floatingMenuController?.show(at: windowPoint, in: window)
    }

    func floatingMenuDidSelectCrop(_ menu: FloatingMenuController) { enterCropMode() }
    func floatingMenuDidSelectFlip(_ menu: FloatingMenuController) { toggleFlip() }
    func floatingMenuDidSelectAdjust(_ menu: FloatingMenuController) { showAdjustmentPanel() }
    func floatingMenuDidSelectRemoveBackground(_ menu: FloatingMenuController) { removeBackground() }
    func floatingMenuDidSelectClose(_ menu: FloatingMenuController) { closeThisWindow() }
    func floatingMenuDidSelectResetDisplay(_ menu: FloatingMenuController) { resetDisplay() }
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

    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangeOpacity opacity: CGFloat) {
        applyOpacity(opacity)
    }

    func adjustmentPanelDidResetOpacity(_ panel: AdjustmentPanelController) {
        applyOpacity(1.0)
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
        return Self.imageOrigin(windowFrame: window.frame, imageViewSize: imageView.frame.size)
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
        registeredItem.image = SFSymbolUtils.icon("photo.on.rectangle")
        menu.addItem(registeredItem)
        menu.addItem(NSMenuItem.separator())

        let flipItem = NSMenuItem(title: L("adjust.flip"), action: #selector(toggleFlip), keyEquivalent: "")
        flipItem.tag = MenuItemTag.flipContext.rawValue
        flipItem.target = self
        flipItem.image = SFSymbolUtils.icon("arrow.left.and.right.righttriangle.left.righttriangle.right")
        menu.addItem(flipItem)

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
        closeItem.image = SFSymbolUtils.icon("xmark.circle")
        menu.addItem(closeItem)

        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.tag = MenuItemTag.quit.rawValue
        quitItem.target = self
        quitItem.image = SFSymbolUtils.icon("power")
        menu.addItem(quitItem)
        imageView.menu = menu
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

// MARK: - Testable Static Methods

extension CharacterWindow {
    /// ウィンドウフレームから画像の原点座標を計算
    nonisolated static func imageOrigin(windowFrame: NSRect, imageViewSize: NSSize) -> CGPoint {
        return CGPoint(
            x: windowFrame.midX - imageViewSize.width / 2,
            y: windowFrame.midY - imageViewSize.height / 2
        )
    }

    /// 画像原点座標からウィンドウ原点座標を計算（逆変換）
    nonisolated static func windowOrigin(
        forImageOrigin imageOrigin: CGPoint, imageViewSize: NSSize, rotationAngle: CGFloat
    ) -> NSPoint {
        let bbSize = GeometryUtils.rotatedBoundingBox(
            width: imageViewSize.width, height: imageViewSize.height, angleDegrees: rotationAngle
        )
        let centerX = imageOrigin.x + imageViewSize.width / 2
        let centerY = imageOrigin.y + imageViewSize.height / 2
        return NSPoint(
            x: round(centerX - bbSize.width / 2),
            y: round(centerY - bbSize.height / 2)
        )
    }

    /// 画像サイズからウィンドウサイズを計算（maxHeight以下にアスペクト比維持で縮小）
    nonisolated static func calculateWindowSize(imageSize: NSSize, maxHeight: CGFloat) -> NSSize {
        let imageHeight = max(imageSize.height, 1)
        let scale = maxHeight / imageHeight
        let windowWidth = imageSize.width * scale
        return NSSize(width: windowWidth, height: maxHeight)
    }

    /// baseHeightに基づいてアスペクト比を維持した画像寸法を計算
    nonisolated static func calculateImageDimensions(
        baseHeight: CGFloat, imageSize: NSSize
    ) -> (width: CGFloat, aspectRatio: CGFloat) {
        let scale = baseHeight / imageSize.height
        let baseWidth = imageSize.width * scale
        let aspectRatio = baseWidth / baseHeight
        return (width: baseWidth, aspectRatio: aspectRatio)
    }

    /// 表示名のローカライズ処理（デフォルト名と一致する場合はローカライズ名を返す）
    nonisolated static func formatLocalizedDisplayName(
        displayName: String, defaultName: String, localizedDefault: String
    ) -> String {
        if displayName == defaultName {
            return localizedDefault
        }
        return displayName
    }

    /// CGImageAlphaInfoが透明情報を持つかどうかを判定
    nonisolated static func isAlphaInfoTransparent(_ alphaInfo: CGImageAlphaInfo) -> Bool {
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }

    /// メニュータグに対応するローカライズキーを返す（該当なしならnil）
    nonisolated static func menuTitleLocalizationKey(forTag tag: Int) -> String? {
        guard let menuTag = MenuItemTag(rawValue: tag) else { return nil }
        return menuTitleMap[menuTag]
    }
}

// MARK: - CharacterWindow + Background Removal

extension CharacterWindow {
    @objc func removeBackground() {
        guard !isRemovingBackground else { return }
        if #available(macOS 14.0, *) {
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
    }

    private func showSpinner() {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.sizeToFit()
        if let contentView = window.contentView {
            spinner.frame.origin = NSPoint(
                x: (contentView.bounds.width - spinner.frame.width) / 2,
                y: (contentView.bounds.height - spinner.frame.height) / 2)
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
        if let cached = cachedHasAlpha {
            return cached
        }
        let result = computeImageHasAlpha()
        cachedHasAlpha = result
        return result
    }

    private func computeImageHasAlpha() -> Bool {
        guard let image = imageView.image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        let alphaInfo = cgImage.alphaInfo
        if !Self.isAlphaInfoTransparent(alphaInfo) {
            return false
        }
        let width = cgImage.width
        let height = cgImage.height
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return false }
        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let rowStride = width * 4
        let interval = AppConstants.alphaCheckRowSampleInterval
        // First pass: sample every N-th row for a fast check
        for row in stride(from: 0, to: height, by: interval) {
            let rowStart = row * rowStride
            if stride(from: 3, to: rowStride, by: 4).contains(where: { ptr[rowStart + $0] < 255 }) {
                return true
            }
        }
        // Second pass: scan all remaining (non-sampled) rows
        for row in 0..<height where row % interval != 0 {
            let rowStart = row * rowStride
            if stride(from: 3, to: rowStride, by: 4).contains(where: { ptr[rowStart + $0] < 255 }) {
                return true
            }
        }
        return false
    }
}
