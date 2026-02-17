import Cocoa
import UniformTypeIdentifiers

// MARK: - Character Window

class CharacterWindow: NSObject, NSMenuDelegate {
    let window: NSWindow
    let imageView: DraggableImageView
    weak var delegate: CharacterWindowDelegate?
    var displayName: String = "デフォルト"

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
        window.contentView = imageView

        super.init()
        setupMenu()

        let screenCenter = NSScreen.main?.frame ?? NSRect.zero
        let offsetX = CGFloat.random(in: -100...100)
        let offsetY = CGFloat.random(in: -100...100)
        let originX = (screenCenter.width - windowWidth) / 2 + offsetX
        let originY = (screenCenter.height - windowHeight) / 2 + offsetY
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
        window.makeKeyAndOrderFront(nil)
    }

    func applyImage(_ image: NSImage) {
        let currentHeight = window.frame.height
        let scale = currentHeight / image.size.height
        let windowWidth = image.size.width * scale
        let centerX = window.frame.midX
        let centerY = window.frame.midY
        let newOriginX = centerX - windowWidth / 2
        let newOriginY = centerY - currentHeight / 2
        imageView.image = image
        imageView.aspectRatio = windowWidth / currentHeight
        window.setFrame(NSRect(x: newOriginX, y: newOriginY, width: windowWidth, height: currentHeight), display: true)
    }

    // MARK: Menu

    func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let registeredItem = NSMenuItem(title: "表示画像の変更", action: nil, keyEquivalent: "")
        let registeredSubmenu = NSMenu()
        registeredItem.submenu = registeredSubmenu
        menu.addItem(registeredItem)
        menu.addItem(NSMenuItem.separator())

        let newWindowItem = NSMenuItem(title: "新しいウィンドウ", action: nil, keyEquivalent: "")
        let newWindowSubmenu = NSMenu()
        newWindowItem.submenu = newWindowSubmenu
        menu.addItem(newWindowItem)
        menu.addItem(NSMenuItem.separator())

        let deleteRegisteredItem = NSMenuItem(title: "登録画像を削除", action: nil, keyEquivalent: "")
        let deleteRegisteredSubmenu = NSMenu()
        deleteRegisteredItem.submenu = deleteRegisteredSubmenu
        menu.addItem(deleteRegisteredItem)
        menu.addItem(NSMenuItem.separator())

        let flipItem = NSMenuItem(title: "左右反転", action: #selector(toggleFlip), keyEquivalent: "")
        flipItem.target = self
        menu.addItem(flipItem)
        menu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: "このウィンドウを閉じる", action: #selector(closeThisWindow), keyEquivalent: "w")
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

        guard let newWindowItem = menu.items.first(where: { $0.title == "新しいウィンドウ" }),
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

        if let flipItem = menu.items.first(where: { $0.title == "左右反転" }) {
            flipItem.state = imageView.isFlippedHorizontally ? .on : .off
        }
    }

    // MARK: Actions

    @objc func toggleFlip() {
        imageView.isFlippedHorizontally.toggle()
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
    }

    @objc func changeDefaultImage() {
        let panel = NSOpenPanel()
        panel.title = "デフォルト画像を選択"
        panel.message = "デフォルトに設定する画像ファイルを選択してください"
        panel.prompt = "選択"
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .floating
        if panel.runModal() == .OK, let url = panel.url {
            ImageManager.shared.setCustomDefault(from: url)
            if displayName == "デフォルト", let newDefault = ImageManager.shared.defaultImage() {
                applyImage(newDefault)
            }
        }
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
        panel.message = "新しいウィンドウに表示する画像ファイルを選択してください"
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
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.quitApp()
        }
    }
}

// MARK: - Character Window Delegate

protocol CharacterWindowDelegate: AnyObject {
    func characterWindowRequestedNewWindow(_ sender: CharacterWindow, imageName: String?)
    func characterWindowRequestedNewWindowWithFileURL(_ sender: CharacterWindow, fileURL: URL)
    func characterWindowDidClose(_ sender: CharacterWindow)
}
