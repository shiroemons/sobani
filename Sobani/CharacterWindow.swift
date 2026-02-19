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
    var displayName: String = "デフォルト"
    var windowId: Int = 0
    private var adjustmentPanelController: AdjustmentPanelController?

    init(image: NSImage) {
        let maxHeight: CGFloat = 600
        let scale = maxHeight / image.size.height
        let windowWidth = image.size.width * scale
        let windowHeight = maxHeight

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = true
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

        imageView.onRotationChanged = { [weak self] in
            self?.adjustmentPanelController?.updateAngle(self?.imageView.rotationAngle ?? 0)
        }

        imageView.onOpacityChanged = { [weak self] in
            self?.adjustmentPanelController?.updateOpacity(self?.imageView.opacityLevel ?? 1.0)
        }

        let screenCenter = NSScreen.main?.frame ?? NSRect.zero
        let offsetX = CGFloat.random(in: -100...100)
        let offsetY = CGFloat.random(in: -100...100)
        let originX = (screenCenter.width - windowWidth) / 2 + offsetX
        let originY = (screenCenter.height - windowHeight) / 2 + offsetY
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
        window.makeKeyAndOrderFront(nil)
    }

    func applyImage(_ image: NSImage) {
        let baseHeight = imageView.frame.height
        let scale = baseHeight / image.size.height
        let baseWidth = image.size.width * scale
        imageView.image = image
        imageView.aspectRatio = baseWidth / baseHeight
        imageView.frame.size = NSSize(width: baseWidth, height: baseHeight)
        adjustWindowForRotation()
    }

    // MARK: Menu

    func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let registeredItem = NSMenuItem(title: "表示画像の変更", action: nil, keyEquivalent: "")
        registeredItem.submenu = NSMenu()
        menu.addItem(registeredItem)
        menu.addItem(NSMenuItem.separator())
        let newWindowItem = NSMenuItem(title: "画像を追加表示", action: nil, keyEquivalent: "")
        newWindowItem.submenu = NSMenu()
        menu.addItem(newWindowItem)
        menu.addItem(NSMenuItem.separator())
        let deleteRegisteredItem = NSMenuItem(title: "登録画像を削除", action: nil, keyEquivalent: "")
        let deleteRegisteredSubmenu = NSMenu()
        deleteRegisteredItem.submenu = deleteRegisteredSubmenu
        menu.addItem(deleteRegisteredItem)
        menu.addItem(NSMenuItem.separator())

        let adjustItem = NSMenuItem(title: "表示の調整", action: nil, keyEquivalent: "")
        let adjustSubmenu = NSMenu()
        adjustSubmenu.autoenablesItems = false
        adjustItem.submenu = adjustSubmenu
        menu.addItem(adjustItem)
        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: "この画像を閉じる", action: #selector(closeThisWindow), keyEquivalent: "w")
        closeItem.target = self
        menu.addItem(closeItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        imageView.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let registeredItem = menu.items.first(where: { $0.title == "表示画像の変更" }),
              let submenu = registeredItem.submenu else { return }

        submenu.removeAllItems()
        submenu.autoenablesItems = false

        let changeItem = NSMenuItem(title: "画像を変更...", action: #selector(changeImage), keyEquivalent: "o")
        changeItem.target = self
        submenu.addItem(changeItem)

        let defaultItem = NSMenuItem(title: "デフォルト画像に戻す", action: #selector(resetToDefault), keyEquivalent: "d")
        defaultItem.target = self
        defaultItem.isEnabled = displayName != "デフォルト"
        submenu.addItem(defaultItem)

        let names = ImageManager.shared.registeredImageNames()
        if !names.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let registeredLabel = NSMenuItem(title: "登録画像", action: nil, keyEquivalent: "")
            registeredLabel.isEnabled = false
            submenu.addItem(registeredLabel)
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(selectRegisteredImage(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                submenu.addItem(item)
            }
        }

        guard let newWindowItem = menu.items.first(where: { $0.title == "画像を追加表示" }),
              let newWindowSubmenu = newWindowItem.submenu else { return }

        newWindowSubmenu.removeAllItems()
        let selectImageItem = NSMenuItem(title: "画像を選択...", action: #selector(addNewWindowWithNewImage(_:)), keyEquivalent: "")
        selectImageItem.target = self
        newWindowSubmenu.addItem(selectImageItem)

        let defaultWindowItem = NSMenuItem(title: "デフォルト画像", action: #selector(addNewWindow), keyEquivalent: "n")
        defaultWindowItem.target = self
        newWindowSubmenu.addItem(defaultWindowItem)

        if !names.isEmpty {
            newWindowSubmenu.addItem(NSMenuItem.separator())
            let registeredWindowLabel = NSMenuItem(title: "登録画像", action: nil, keyEquivalent: "")
            registeredWindowLabel.isEnabled = false
            newWindowSubmenu.addItem(registeredWindowLabel)
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(addNewWindowWithImage(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                newWindowSubmenu.addItem(item)
            }
        }

        if let deleteRegisteredItem = menu.items.first(where: { $0.title == "登録画像を削除" }),
           let deleteRegisteredSubmenu = deleteRegisteredItem.submenu {
            deleteRegisteredSubmenu.removeAllItems()
            if !names.isEmpty {
                for name in names {
                    let item = NSMenuItem(title: name, action: #selector(deleteRegisteredImage(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = name
                    deleteRegisteredSubmenu.addItem(item)
                }
            }
            deleteRegisteredItem.isEnabled = !names.isEmpty
        }

        if let adjustItem = menu.items.first(where: { $0.title == "表示の調整" }),
           let adjustSubmenu = adjustItem.submenu {
            populateAdjustSubmenu(adjustSubmenu)
        }
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
            self?.adjustmentPanelController = nil
        }
        controller.show(near: window, currentAngle: imageView.rotationAngle, currentOpacity: imageView.opacityLevel)
        adjustmentPanelController = controller
        let scrollRotationSensitivity: CGFloat = 0.5
        imageView.scrollRotationHandler = { [weak self] delta in
            guard let self = self else { return }
            let angleDelta = delta * scrollRotationSensitivity
            var newAngle = self.imageView.rotationAngle + angleDelta
            newAngle = newAngle.truncatingRemainder(dividingBy: 360)
            if newAngle < 0 { newAngle += 360 }
            self.applyRotation(newAngle)
        }
    }

    private func closeAdjustmentPanel() {
        adjustmentPanelController?.close()
        adjustmentPanelController = nil
        imageView.scrollRotationHandler = nil
    }

    @objc func resetRotation() {
        applyRotation(0)
    }

    @objc func resetOpacity() {
        applyOpacity(1.0)
    }

    func applyOpacity(_ opacity: CGFloat) {
        let clamped = min(max(opacity, 0.1), 1.0)
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
        let radians = imageView.rotationAngle * .pi / 180

        let bbWidth = abs(baseWidth * cos(radians)) + abs(baseHeight * sin(radians))
        let bbHeight = abs(baseWidth * sin(radians)) + abs(baseHeight * cos(radians))

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
        panel.title = "画像を選択"
        panel.message = "表示する画像ファイルを選択してください"
        panel.prompt = "選択"
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
            displayName = "デフォルト"
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
        panel.title = "画像を選択"
        panel.message = "追加表示する画像ファイルを選択してください"
        panel.prompt = "選択"
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
}

// MARK: - Character Window Delegate

protocol CharacterWindowDelegate: AnyObject {
    func characterWindowRequestedNewWindow(_ sender: CharacterWindow, imageName: String?)
    func characterWindowRequestedNewWindowWithFileURL(_ sender: CharacterWindow, fileURL: URL)
    func characterWindowDidClose(_ sender: CharacterWindow)
    func characterWindowDidDeleteImage(named name: String)
}

// MARK: - CharacterWindow + Adjust Submenu

extension CharacterWindow {
    func populateAdjustSubmenu(_ adjustSubmenu: NSMenu) {
        adjustSubmenu.removeAllItems()

        let flipItem = NSMenuItem(title: "左右反転", action: #selector(toggleFlip), keyEquivalent: "")
        flipItem.target = self
        flipItem.state = imageView.isFlippedHorizontally ? .on : .off
        adjustSubmenu.addItem(flipItem)

        adjustSubmenu.addItem(NSMenuItem.separator())

        let adjustPanelItem = NSMenuItem(title: "表示の調整...", action: #selector(showAdjustmentPanel), keyEquivalent: "")
        adjustPanelItem.target = self
        adjustSubmenu.addItem(adjustPanelItem)

        adjustSubmenu.addItem(NSMenuItem.separator())

        let resetRotationItem = NSMenuItem(title: "回転をリセット", action: #selector(resetRotation), keyEquivalent: "")
        resetRotationItem.target = self
        resetRotationItem.isEnabled = imageView.rotationAngle != 0
        adjustSubmenu.addItem(resetRotationItem)

        let resetOpacityItem = NSMenuItem(title: "透明度をリセット", action: #selector(resetOpacity), keyEquivalent: "")
        resetOpacityItem.target = self
        resetOpacityItem.isEnabled = imageView.opacityLevel != 1.0
        adjustSubmenu.addItem(resetOpacityItem)

        adjustSubmenu.addItem(NSMenuItem.separator())

        let resetDisplayItem = NSMenuItem(title: "表示をリセット", action: #selector(resetDisplay), keyEquivalent: "")
        resetDisplayItem.target = self
        adjustSubmenu.addItem(resetDisplayItem)
    }

    @objc func resetDisplay() {
        imageView.isFlippedHorizontally = false
        imageView.rotationAngle = 0
        imageView.opacityLevel = 1.0
        adjustmentPanelController?.updateAngle(0)
        adjustmentPanelController?.updateOpacity(1.0)

        let defaultHeight: CGFloat = 600
        let defaultWidth = defaultHeight * imageView.aspectRatio

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let originX = screenFrame.minX + (screenFrame.width - defaultWidth) / 2
        let originY = screenFrame.minY + (screenFrame.height - defaultHeight) / 2

        window.setFrame(NSRect(x: originX, y: originY, width: defaultWidth, height: defaultHeight), display: true)
        imageView.frame = NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight)
        imageView.needsLayout = true
    }
}

// MARK: - CharacterWindow + Highlight Border

extension CharacterWindow {
    func showHighlightBorder() {
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.borderWidth = 3.0
        contentView.layer?.borderColor = NSColor.systemBlue.cgColor
    }

    func hideHighlightBorder() {
        window.contentView?.layer?.borderWidth = 0
        window.contentView?.layer?.borderColor = nil
    }
}
