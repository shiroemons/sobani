import Cocoa
import UniformTypeIdentifiers

// MARK: - Rotatable Container

// Rotation expands the window beyond the image bounds.
// Always delegate hit testing to imageView so the entire window area remains interactive.
private class RotatableContainer: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return subviews.first ?? super.hitTest(point)
    }
}

// MARK: - Character Window

class CharacterWindow: NSObject, NSMenuDelegate {
    let window: NSWindow
    let imageView: DraggableImageView
    weak var delegate: CharacterWindowDelegate?
    private(set) var displayName: String = AppConstants.defaultImageName
    private(set) var windowId: Int = 0
    private var adjustmentPanelController: AdjustmentPanelController?
    private var spinnerOverlay: NSProgressIndicator?
    private var isRemovingBackground = false
    private var windowMoveObserver: NSObjectProtocol?

    init(image: NSImage) {
        let maxHeight: CGFloat = AppConstants.defaultWindowHeight
        let imageHeight = max(image.size.height, 1)
        let scale = maxHeight / imageHeight
        let windowWidth = image.size.width * scale
        let windowHeight = maxHeight

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
            guard let self = self else { return }
            self.delegate?.characterWindowDidBecomeActive(self)
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
            guard let self = self else { return }
            if isOption {
                self.delegate?.characterWindowRequestedNewWindowWithFileURL(self, fileURL: url)
            } else {
                self.handleDroppedImage(url: url)
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

    func applyImage(_ image: NSImage) {
        guard image.size.height > 0 else { return }
        let baseHeight = imageView.frame.height
        let scale = baseHeight / image.size.height
        let baseWidth = image.size.width * scale
        imageView.image = image
        imageView.aspectRatio = baseWidth / baseHeight
        imageView.frame.size = NSSize(width: baseWidth, height: baseHeight)
        adjustWindowForRotation()
    }

    // MARK: Actions

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
        ) { [weak self] _ in
            guard let self = self else { return }
            self.adjustmentPanelController?.updatePosition(self.currentImageOrigin())
            self.adjustmentPanelController?.updateMonitor(self.window)
        }
        imageView.onSizeChanged = { [weak self] in
            guard let self = self else { return }
            self.adjustmentPanelController?.updateSize(self.imageView.frame.size)
        }
    }

    private func closeAdjustmentPanel() {
        adjustmentPanelController?.close()
        adjustmentPanelController = nil
        imageView.scrollRotationHandler = nil
        if let observer = windowMoveObserver {
            NotificationCenter.default.removeObserver(observer)
            windowMoveObserver = nil
        }
        imageView.onSizeChanged = nil
    }

    @objc func resetRotation() {
        applyRotation(0)
    }

    @objc func resetOpacity() {
        applyOpacity(1.0)
    }

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
        let panel = NSOpenPanel()
        panel.title = L("dialog.select_image")
        panel.message = L("dialog.select_image_message")
        panel.prompt = L("dialog.select")
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .floating
        if panel.runModal() == .OK, let url = panel.url, let newImage = NSImage(contentsOf: url) {
            let savedName = ImageManager.shared.registerImage(from: url)
            displayName = savedName ?? url.deletingPathExtension().lastPathComponent
            applyImage(newImage)
        }
    }

    private func handleDroppedImage(url: URL) {
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
        let panel = NSOpenPanel()
        panel.title = L("dialog.select_image")
        panel.message = L("dialog.select_add_image_message")
        panel.prompt = L("dialog.select")
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .floating
        if panel.runModal() == .OK, let url = panel.url {
            delegate?.characterWindowRequestedNewWindowWithFileURL(self, fileURL: url)
        }
    }

    @objc func closeThisWindow() {
        window.orderOut(nil)
        delegate?.characterWindowDidClose(self)
    }

    @objc func quitApp() {
        (NSApp.delegate as? AppDelegate)?.quitApp()
    }
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
        // position is the image origin in global coordinates
        let bbSize = GeometryUtils.rotatedBoundingBox(
            width: imageView.frame.width, height: imageView.frame.height, angleDegrees: imageView.rotationAngle
        )
        let centerX = position.x + imageView.frame.width / 2
        let centerY = position.y + imageView.frame.height / 2
        window.setFrameOrigin(NSPoint(
            x: round(centerX - bbSize.width / 2),
            y: round(centerY - bbSize.height / 2)
        ))
    }

    func adjustmentPanel(_ panel: AdjustmentPanelController, didChangeSize size: CGSize) {
        imageView.frame.size = size
        adjustWindowForRotation()
        adjustmentPanelController?.updatePosition(currentImageOrigin())
    }

    func adjustmentPanel(_ panel: AdjustmentPanelController, didSelectMonitor screen: NSScreen) {
        // Maintain monitor-relative position when switching monitors
        guard let oldScreen = NSScreen.screen(containing: window.frame) else { return }
        let oldOrigin = currentImageOrigin()
        let relativeX = oldOrigin.x - oldScreen.frame.origin.x
        let relativeY = oldOrigin.y - oldScreen.frame.origin.y
        let newOrigin = CGPoint(
            x: screen.frame.origin.x + relativeX,
            y: screen.frame.origin.y + relativeY
        )
        let bbSize = GeometryUtils.rotatedBoundingBox(
            width: imageView.frame.width, height: imageView.frame.height, angleDegrees: imageView.rotationAngle
        )
        let centerX = newOrigin.x + imageView.frame.width / 2
        let centerY = newOrigin.y + imageView.frame.height / 2
        window.setFrameOrigin(NSPoint(
            x: round(centerX - bbSize.width / 2),
            y: round(centerY - bbSize.height / 2)
        ))
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
        return CGPoint(
            x: window.frame.midX - imageView.frame.width / 2,
            y: window.frame.midY - imageView.frame.height / 2
        )
    }
}

// MARK: - Character Window Delegate

/// CharacterWindow からのイベントを AppDelegate に通知するプロトコル
protocol CharacterWindowDelegate: AnyObject {
    /// 新しいウィンドウの作成を要求する
    func characterWindowRequestedNewWindow(_ sender: CharacterWindow, imageName: String?)
    /// ファイルURLを指定して新しいウィンドウの作成を要求する
    func characterWindowRequestedNewWindowWithFileURL(_ sender: CharacterWindow, fileURL: URL)
    /// ウィンドウが閉じられたことを通知する
    func characterWindowDidClose(_ sender: CharacterWindow)
    /// 登録画像が削除されたことを通知する
    func characterWindowDidDeleteImage(named name: String)
    /// ウィンドウがアクティブになったことを通知する（Z-order更新用）
    func characterWindowDidBecomeActive(_ sender: CharacterWindow)
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
        menu.addItem(registeredItem)
        menu.addItem(NSMenuItem.separator())

        let flipItem = NSMenuItem(title: L("adjust.flip"), action: #selector(toggleFlip), keyEquivalent: "")
        flipItem.tag = MenuItemTag.flipContext.rawValue
        flipItem.target = self
        menu.addItem(flipItem)

        let adjustPanelItem = NSMenuItem(
            title: L("adjust.open"), action: #selector(showAdjustmentPanel), keyEquivalent: ""
        )
        adjustPanelItem.tag = MenuItemTag.adjustPanelContext.rawValue
        adjustPanelItem.target = self
        menu.addItem(adjustPanelItem)
        menu.addItem(NSMenuItem.separator())

        let newWindowItem = NSMenuItem(title: L("image.add_display"), action: nil, keyEquivalent: "")
        newWindowItem.tag = MenuItemTag.addNewWindowSubmenu.rawValue
        newWindowItem.submenu = NSMenu()
        menu.addItem(newWindowItem)
        menu.addItem(NSMenuItem.separator())

        let otherItem = NSMenuItem(title: L("menu.other"), action: nil, keyEquivalent: "")
        otherItem.tag = MenuItemTag.otherSubmenu.rawValue
        let otherSubmenu = NSMenu()
        otherSubmenu.autoenablesItems = false
        otherItem.submenu = otherSubmenu
        menu.addItem(otherItem)
        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: L("menu.close_image"), action: #selector(closeThisWindow), keyEquivalent: "w")
        closeItem.tag = MenuItemTag.close.rawValue
        closeItem.target = self
        menu.addItem(closeItem)

        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.tag = MenuItemTag.quit.rawValue
        quitItem.target = self
        menu.addItem(quitItem)
        imageView.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let registeredItem = menu.items.first(where: { $0.tag == MenuItemTag.changeImageSubmenu.rawValue }),
              let submenu = registeredItem.submenu else { return }

        updateTopLevelMenuTitles(menu)

        let names = ImageManager.shared.registeredImageNames()
        populateChangeImageSubmenu(submenu, names: names)
        populateNewWindowSubmenu(menu, names: names)

        if let flipItem = menu.items.first(where: { $0.tag == MenuItemTag.flipContext.rawValue }) {
            flipItem.state = imageView.isFlippedHorizontally ? .on : .off
        }

        if let otherItem = menu.items.first(where: { $0.tag == MenuItemTag.otherSubmenu.rawValue }),
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
        submenu.addItem(changeItem)

        let defaultItem = NSMenuItem(title: L("image.default_reset"), action: #selector(resetToDefault), keyEquivalent: "d")
        defaultItem.target = self
        defaultItem.isEnabled = displayName != AppConstants.defaultImageName
        submenu.addItem(defaultItem)

        if !names.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let registeredLabel = NSMenuItem(title: L("image.registered"), action: nil, keyEquivalent: "")
            registeredLabel.isEnabled = false
            submenu.addItem(registeredLabel)
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(selectRegisteredImage(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                submenu.addItem(item)
            }
        }

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
            submenu.addItem(removeBackgroundItem)
        }
    }

    private func populateNewWindowSubmenu(_ menu: NSMenu, names: [String]) {
        guard let newWindowItem = menu.items.first(where: { $0.tag == MenuItemTag.addNewWindowSubmenu.rawValue }),
              let newWindowSubmenu = newWindowItem.submenu else { return }

        newWindowSubmenu.removeAllItems()
        newWindowSubmenu.delegate = self
        let selectImageItem = NSMenuItem(title: L("image.select"), action: #selector(addNewWindowWithNewImage(_:)), keyEquivalent: "")
        selectImageItem.target = self
        newWindowSubmenu.addItem(selectImageItem)

        let defaultWindowItem = NSMenuItem(title: L("image.default"), action: #selector(addNewWindow), keyEquivalent: "n")
        defaultWindowItem.target = self
        newWindowSubmenu.addItem(defaultWindowItem)

        if !names.isEmpty {
            newWindowSubmenu.addItem(NSMenuItem.separator())
            let registeredWindowLabel = NSMenuItem(title: L("image.registered"), action: nil, keyEquivalent: "")
            registeredWindowLabel.isEnabled = false
            newWindowSubmenu.addItem(registeredWindowLabel)
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(addNewWindowWithImage(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                newWindowSubmenu.addItem(item)
            }
        }
    }

    // MARK: - Menu Highlight (Image Preview)

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        if let item = item, let name = item.representedObject as? String,
           item.action == #selector(selectRegisteredImage(_:))
            || item.action == #selector(addNewWindowWithImage(_:))
            || item.action == #selector(deleteRegisteredImage(_:)) {
            if let image = ImageManager.shared.loadRegisteredImage(named: name) {
                ImagePreviewPanel.shared.show(image: image, relativeTo: item, ofMenu: menu)
            }
        } else if let item = item,
                  item.action == #selector(addNewWindow)
                    || item.action == #selector(resetToDefault) {
            if let image = ImageManager.shared.defaultImage() {
                ImagePreviewPanel.shared.show(image: image, relativeTo: item, ofMenu: menu)
            }
        } else {
            ImagePreviewPanel.shared.hide()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        ImagePreviewPanel.shared.hide()
    }
}

// MARK: - CharacterWindow + Other Submenu

extension CharacterWindow {
    func populateOtherSubmenu(_ otherSubmenu: NSMenu, names: [String]) {
        otherSubmenu.removeAllItems()

        let resetRotationItem = NSMenuItem(
            title: L("adjust.reset_rotation"), action: #selector(resetRotation), keyEquivalent: ""
        )
        resetRotationItem.target = self
        resetRotationItem.isEnabled = abs(imageView.rotationAngle) > AppConstants.floatingPointTolerance
        otherSubmenu.addItem(resetRotationItem)

        let resetOpacityItem = NSMenuItem(
            title: L("adjust.reset_opacity"), action: #selector(resetOpacity), keyEquivalent: ""
        )
        resetOpacityItem.target = self
        resetOpacityItem.isEnabled = abs(imageView.opacityLevel - 1.0) > AppConstants.floatingPointTolerance
        otherSubmenu.addItem(resetOpacityItem)

        otherSubmenu.addItem(NSMenuItem.separator())

        let resetDisplayItem = NSMenuItem(
            title: L("adjust.reset_display"), action: #selector(resetDisplay), keyEquivalent: ""
        )
        resetDisplayItem.target = self
        otherSubmenu.addItem(resetDisplayItem)

        otherSubmenu.addItem(NSMenuItem.separator())

        let deleteRegisteredItem = NSMenuItem(title: L("image.delete_registered"), action: nil, keyEquivalent: "")
        let deleteSubmenu = NSMenu()
        deleteSubmenu.delegate = self
        for name in names {
            let item = NSMenuItem(title: name, action: #selector(deleteRegisteredImage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            deleteSubmenu.addItem(item)
        }
        deleteRegisteredItem.submenu = deleteSubmenu
        deleteRegisteredItem.isEnabled = !names.isEmpty
        otherSubmenu.addItem(deleteRegisteredItem)
    }

    @objc func resetDisplay() {
        imageView.isFlippedHorizontally = false
        imageView.rotationAngle = 0
        imageView.opacityLevel = 1.0
        adjustmentPanelController?.updateAngle(0)
        adjustmentPanelController?.updateOpacity(1.0)

        let defaultHeight: CGFloat = AppConstants.defaultWindowHeight
        let defaultWidth = defaultHeight * imageView.aspectRatio

        let screenFrame = NSScreen.main?.frame ?? NSRect(origin: .zero, size: AppConstants.fallbackScreenSize)
        let originX = screenFrame.minX + (screenFrame.width - defaultWidth) / 2
        let originY = screenFrame.minY + (screenFrame.height - defaultHeight) / 2

        window.setFrame(NSRect(x: originX, y: originY, width: defaultWidth, height: defaultHeight), display: true)
        imageView.frame = NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight)
        imageView.needsLayout = true
    }
}

// MARK: - CharacterWindow + Menu Title Update

extension CharacterWindow {
    private static let menuTitleMap: [Int: String] = [
        MenuItemTag.changeImageSubmenu.rawValue: "image.change",
        MenuItemTag.flipContext.rawValue: "adjust.flip",
        MenuItemTag.adjustPanelContext.rawValue: "adjust.open",
        MenuItemTag.addNewWindowSubmenu.rawValue: "image.add_display",
        MenuItemTag.otherSubmenu.rawValue: "menu.other",
        MenuItemTag.close.rawValue: "menu.close_image",
        MenuItemTag.quit.rawValue: "menu.quit"
    ]

    var localizedDisplayName: String {
        if displayName == AppConstants.defaultImageName {
            return L("image.default_display")
        }
        return displayName
    }

    func updateTopLevelMenuTitles(_ menu: NSMenu) {
        for item in menu.items {
            if let key = Self.menuTitleMap[item.tag] {
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
        contentView.wantsLayer = true
        contentView.layer?.borderWidth = Self.highlightBorderWidth
        contentView.layer?.borderColor = NSColor.systemBlue.cgColor
    }

    func hideHighlightBorder() {
        window.contentView?.layer?.borderWidth = 0
        window.contentView?.layer?.borderColor = nil
    }
}

// MARK: - CharacterWindow + Property Setters

extension CharacterWindow {
    func setDisplayName(_ name: String) {
        displayName = name
    }

    func setWindowId(_ newId: Int) {
        windowId = newId
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
                    let alert = NSAlert()
                    alert.messageText = L("background_removal.error.title")
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
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
        guard let image = imageView.image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        let alphaInfo = cgImage.alphaInfo
        if alphaInfo == .none || alphaInfo == .noneSkipFirst || alphaInfo == .noneSkipLast {
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
        let totalBytes = width * height * 4
        return stride(from: 3, to: totalBytes, by: 4).contains { ptr[$0] < 255 }
    }
}
