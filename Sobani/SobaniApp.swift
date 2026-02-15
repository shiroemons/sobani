import Cocoa
import UniformTypeIdentifiers

// MARK: - Image Manager

class ImageManager {
    static let shared = ImageManager()

    private let baseDirectory: URL?

    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory
    }

    private var appSupportURL: URL? {
        let fm = FileManager.default
        let appDir: URL
        if let base = baseDirectory {
            appDir = base
        } else {
            guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
            appDir = appSupport.appendingPathComponent("Sobani")
        }
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }

    var imagesDirectoryURL: URL? {
        guard let appDir = appSupportURL else { return nil }
        let imagesDir = appDir.appendingPathComponent("images")
        let fm = FileManager.default
        if !fm.fileExists(atPath: imagesDir.path) {
            try? fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }
        return imagesDir
    }

    // Get all registered image names (sorted)
    func registeredImageNames() -> [String] {
        guard let imagesDir = imagesDirectoryURL else { return [] }
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: imagesDir.path)) ?? []
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "heic"]
        return files
            .filter { name in
                let ext = (name as NSString).pathExtension.lowercased()
                return imageExtensions.contains(ext)
            }
            .sorted()
    }

    // Load a registered image by name
    func loadRegisteredImage(named name: String) -> NSImage? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        let url = imagesDir.appendingPathComponent(name)
        return NSImage(contentsOf: url)
    }

    // Register an image (copy to images directory), returns saved name
    @discardableResult
    func registerImage(from url: URL) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        let ext = url.pathExtension.lowercased()
        let supportedExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "heic"]
        guard supportedExtensions.contains(ext) else { return nil }
        let name = url.lastPathComponent
        let destURL = imagesDir.appendingPathComponent(name)
        let fm = FileManager.default

        // If same name exists, make unique
        var finalURL = destURL
        var finalName = name
        var counter = 1
        while fm.fileExists(atPath: finalURL.path) {
            let baseName = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            finalName = "\(baseName)_\(counter).\(ext)"
            finalURL = imagesDir.appendingPathComponent(finalName)
            counter += 1
        }

        try? fm.copyItem(at: url, to: finalURL)
        return finalName
    }

    // Register an NSImage with a given name
    @discardableResult
    func registerImage(_ image: NSImage, name: String) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }

        let destURL = imagesDir.appendingPathComponent(name)
        try? pngData.write(to: destURL)
        return name
    }

    // Remove a registered image
    func removeRegisteredImage(named name: String) {
        guard let imagesDir = imagesDirectoryURL else { return }
        let url = imagesDir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }

    // Load default bundled image
    // Custom default image path
    var customDefaultURL: URL? {
        appSupportURL?.appendingPathComponent("default.png")
    }

    var hasCustomDefault: Bool {
        guard let url = customDefaultURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    // Load default: custom default > bundled asset
    func defaultImage() -> NSImage? {
        if let url = customDefaultURL, let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(named: "character")
    }

    // Bundled asset only
    func originalDefaultImage() -> NSImage? {
        return NSImage(named: "character")
    }

    // Save a custom default image
    func setCustomDefault(from url: URL) {
        guard let destURL = customDefaultURL else { return }
        let fm = FileManager.default
        try? fm.removeItem(at: destURL)
        try? fm.copyItem(at: url, to: destURL)
    }

    // Reset to bundled default
    func resetCustomDefault() {
        guard let url = customDefaultURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Draggable Image View

class DraggableImageView: NSImageView {
    var aspectRatio: CGFloat = 1.0
    let minHeight: CGFloat = 100
    let maxHeight: CGFloat = 6000
    private var dragStartLocation: NSPoint = .zero
    private var isDraggingAll = false

    override func mouseDown(with event: NSEvent) {
        // Option key held: drag all windows together
        if event.modifierFlags.contains(.option) {
            isDraggingAll = true
            dragStartLocation = NSEvent.mouseLocation
        } else {
            isDraggingAll = false
            window?.performDrag(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingAll else { return }

        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - dragStartLocation.x
        let deltaY = currentLocation.y - dragStartLocation.y
        dragStartLocation = currentLocation

        // Move all character windows
        let allWindows = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.borderless) }
        for w in allWindows {
            var origin = w.frame.origin
            origin.x += deltaX
            origin.y += deltaY
            w.setFrameOrigin(origin)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        if delta == 0 { return }
        let scaleFactor: CGFloat = 1.0 + (delta * 0.01)

        // Option key held: resize all windows together
        if event.modifierFlags.contains(.option) {
            let allWindows = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.borderless) }
            for w in allWindows {
                guard let iv = w.contentView as? DraggableImageView else { continue }
                resizeWindow(w, imageView: iv, scaleFactor: scaleFactor)
            }
        } else {
            guard let window = window else { return }
            resizeWindow(window, imageView: self, scaleFactor: scaleFactor)
        }
    }

    private func resizeWindow(_ window: NSWindow, imageView: DraggableImageView, scaleFactor: CGFloat) {
        let currentHeight = window.frame.height
        var newHeight = currentHeight * scaleFactor
        newHeight = max(minHeight, min(maxHeight, newHeight))
        let newWidth = newHeight * imageView.aspectRatio

        let centerX = window.frame.midX
        let centerY = window.frame.midY
        let newOriginX = centerX - newWidth / 2
        let newOriginY = centerY - newHeight / 2
        let newFrame = NSRect(x: newOriginX, y: newOriginY, width: newWidth, height: newHeight)

        window.setFrame(newFrame, display: true)
    }
}

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

        window.contentView = imageView

        super.init()

        setupMenu()

        // Offset from center to avoid stacking
        let screenCenter = NSScreen.main?.frame ?? NSRect.zero
        let offsetX = CGFloat.random(in: -100...100)
        let offsetY = CGFloat.random(in: -100...100)
        let originX = (screenCenter.width - windowWidth) / 2 + offsetX
        let originY = (screenCenter.height - windowHeight) / 2 + offsetY
        window.setFrameOrigin(NSPoint(x: originX, y: originY))

        window.makeKeyAndOrderFront(nil)
    }

    func applyImage(_ image: NSImage) {
        let maxHeight: CGFloat = 600
        let scale = maxHeight / image.size.height
        let windowWidth = image.size.width * scale
        let windowHeight = maxHeight

        let centerX = window.frame.midX
        let centerY = window.frame.midY
        let newOriginX = centerX - windowWidth / 2
        let newOriginY = centerY - windowHeight / 2

        imageView.image = image
        imageView.aspectRatio = windowWidth / windowHeight
        window.setFrame(NSRect(x: newOriginX, y: newOriginY, width: windowWidth, height: windowHeight), display: true)
    }

    // MARK: Menu

    func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        // Image switch submenu (built dynamically)
        let registeredItem = NSMenuItem(title: "画像を切り替え", action: nil, keyEquivalent: "")
        let registeredSubmenu = NSMenu()
        registeredItem.submenu = registeredSubmenu
        menu.addItem(registeredItem)

        menu.addItem(NSMenuItem.separator())

        // New window submenu (built dynamically)
        let newWindowItem = NSMenuItem(title: "新しいウィンドウ", action: nil, keyEquivalent: "")
        let newWindowSubmenu = NSMenu()
        newWindowItem.submenu = newWindowSubmenu
        menu.addItem(newWindowItem)

        let closeItem = NSMenuItem(title: "このウィンドウを閉じる", action: #selector(closeThisWindow), keyEquivalent: "w")
        closeItem.target = self
        menu.addItem(closeItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        imageView.menu = menu
    }

    // Rebuild submenu when menu opens
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Find registered images submenu
        guard let registeredItem = menu.items.first(where: { $0.title == "画像を切り替え" }),
              let submenu = registeredItem.submenu else { return }

        submenu.removeAllItems()
        submenu.autoenablesItems = false

        // "デフォルト画像に戻す"
        let defaultItem = NSMenuItem(title: "デフォルト画像に戻す", action: #selector(resetToDefault), keyEquivalent: "d")
        defaultItem.target = self
        defaultItem.isEnabled = displayName != "デフォルト"
        submenu.addItem(defaultItem)

        // "画像を変更..."
        let changeItem = NSMenuItem(title: "画像を変更...", action: #selector(changeImage), keyEquivalent: "o")
        changeItem.target = self
        submenu.addItem(changeItem)

        let names = ImageManager.shared.registeredImageNames()

        if !names.isEmpty {
            submenu.addItem(NSMenuItem.separator())

            // "登録画像" label
            let registeredLabel = NSMenuItem(title: "登録画像", action: nil, keyEquivalent: "")
            registeredLabel.isEnabled = false
            submenu.addItem(registeredLabel)

            for name in names {
                let item = NSMenuItem(title: name, action: #selector(selectRegisteredImage(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                submenu.addItem(item)
            }
            submenu.addItem(NSMenuItem.separator())

            // Delete submenu
            let deleteItem = NSMenuItem(title: "登録画像から削除", action: nil, keyEquivalent: "")
            let deleteSubmenu = NSMenu()
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(deleteRegisteredImage(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                deleteSubmenu.addItem(item)
            }
            deleteItem.submenu = deleteSubmenu
            submenu.addItem(deleteItem)
        }

        // Build new window submenu
        guard let newWindowItem = menu.items.first(where: { $0.title == "新しいウィンドウ" }),
              let newWindowSubmenu = newWindowItem.submenu else { return }

        newWindowSubmenu.removeAllItems()

        let defaultWindowItem = NSMenuItem(title: "デフォルト画像", action: #selector(addNewWindow), keyEquivalent: "n")
        defaultWindowItem.target = self
        newWindowSubmenu.addItem(defaultWindowItem)

        if !names.isEmpty {
            newWindowSubmenu.addItem(NSMenuItem.separator())
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(addNewWindowWithImage(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                newWindowSubmenu.addItem(item)
            }
        }

        newWindowSubmenu.addItem(NSMenuItem.separator())
        let selectImageItem = NSMenuItem(title: "画像を選択...", action: #selector(addNewWindowWithNewImage(_:)), keyEquivalent: "")
        selectImageItem.target = self
        newWindowSubmenu.addItem(selectImageItem)
    }

    // MARK: Actions

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
            // Register the image from source file
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
            // Update this window if currently showing default
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
            appDelegate.shouldTerminate = true
        }
        NSApplication.shared.terminate(nil)
    }
}

protocol CharacterWindowDelegate: AnyObject {
    func characterWindowRequestedNewWindow(_ sender: CharacterWindow, imageName: String?)
    func characterWindowRequestedNewWindowWithFileURL(_ sender: CharacterWindow, fileURL: URL)
    func characterWindowDidClose(_ sender: CharacterWindow)
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, CharacterWindowDelegate, NSMenuDelegate {
    var characterWindows: [CharacterWindow] = []
    var statusItem: NSStatusItem!
    var shouldTerminate = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar icon
        setupStatusBar()

        guard let image = ImageManager.shared.defaultImage() else {
            print("Failed to load character image")
            return
        }

        let charWindow = CharacterWindow(image: image)
        charWindow.delegate = self
        // Center the first window properly
        charWindow.window.center()
        characterWindows.append(charWindow)

        NSApp.activate(ignoringOtherApps: true)

        // Setup update manager
        UpdateManager.shared.delegate = self
        UpdateManager.shared.startPeriodicChecks()
    }

    // MARK: - Status Bar

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "person.fill", accessibilityDescription: "Sobani")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // About
        let aboutItem = NSMenuItem(title: "Sobani について...", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Update menu item
        switch UpdateManager.shared.state {
        case .available(let version, _):
            let updateItem = NSMenuItem(
                title: "更新する（v\(version)）",
                action: #selector(performUpdate),
                keyEquivalent: ""
            )
            updateItem.target = self
            menu.addItem(updateItem)
        case .checking:
            let checkingItem = NSMenuItem(title: "確認中...", action: nil, keyEquivalent: "")
            checkingItem.isEnabled = false
            menu.addItem(checkingItem)
        case .downloading:
            let downloadingItem = NSMenuItem(title: "ダウンロード中...", action: nil, keyEquivalent: "")
            downloadingItem.isEnabled = false
            menu.addItem(downloadingItem)
        default:
            let checkItem = NSMenuItem(
                title: "更新を確認...",
                action: #selector(checkForUpdateManually),
                keyEquivalent: ""
            )
            checkItem.target = self
            menu.addItem(checkItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Window count
        let countItem = NSMenuItem(title: "表示中: \(characterWindows.count)体", action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)

        menu.addItem(NSMenuItem.separator())

        let bringFrontItem = NSMenuItem(title: "すべて手前に表示", action: #selector(bringAllToFront), keyEquivalent: "f")
        bringFrontItem.target = self
        menu.addItem(bringFrontItem)

        menu.addItem(NSMenuItem.separator())

        // New window submenu
        menu.addItem(buildNewWindowMenuItem())

        // Close individual window submenu
        if !characterWindows.isEmpty {
            let closeOneItem = NSMenuItem(title: "ウィンドウを閉じる", action: nil, keyEquivalent: "")
            let closeOneSubmenu = NSMenu()
            for (index, charWindow) in characterWindows.enumerated() {
                let title = "\(index + 1). \(charWindow.displayName)"
                let item = NSMenuItem(title: title, action: #selector(closeWindowByIndex(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                closeOneSubmenu.addItem(item)
            }
            closeOneItem.submenu = closeOneSubmenu
            menu.addItem(closeOneItem)
        }

        let closeAllItem = NSMenuItem(title: "すべて閉じる", action: #selector(closeAllWindows), keyEquivalent: "")
        closeAllItem.target = self
        menu.addItem(closeAllItem)

        menu.addItem(NSMenuItem.separator())

        // Default image management
        let changeDefaultItem = NSMenuItem(title: "デフォルト画像を変更...", action: #selector(changeDefaultImageFromMenu), keyEquivalent: "")
        changeDefaultItem.target = self
        menu.addItem(changeDefaultItem)

        if ImageManager.shared.hasCustomDefault {
            let resetDefaultItem = NSMenuItem(title: "デフォルト画像をリセット", action: #selector(resetDefaultImage), keyEquivalent: "")
            resetDefaultItem.target = self
            menu.addItem(resetDefaultItem)
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc func bringAllToFront() {
        NSApp.activate(ignoringOtherApps: true)
        for charWindow in characterWindows {
            charWindow.window.orderFront(nil)
        }
    }

    @objc func addNewWindowFromMenu() {
        createNewWindow()
    }

    @objc func addNewWindowWithImageFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        createNewWindow(imageName: name)
    }

    @objc func closeWindowByIndex(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0 && index < characterWindows.count else { return }
        let charWindow = characterWindows[index]
        charWindow.window.orderOut(nil)
        characterWindows.remove(at: index)
        quitIfNoWindows()
    }

    @objc func closeAllWindows() {
        for charWindow in characterWindows {
            charWindow.window.orderOut(nil)
        }
        characterWindows.removeAll()
        quitIfNoWindows()
    }

    func quitIfNoWindows() {
        if characterWindows.isEmpty {
            shouldTerminate = true
            NSApp.terminate(nil)
        }
    }

    @objc func changeDefaultImageFromMenu() {
        let panel = NSOpenPanel()
        panel.title = "デフォルト画像を選択"
        panel.message = "デフォルトに設定する画像ファイルを選択してください"
        panel.prompt = "選択"
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            ImageManager.shared.setCustomDefault(from: url)
            // Update all windows currently showing default
            if let newDefault = ImageManager.shared.defaultImage() {
                for charWindow in characterWindows where charWindow.displayName == "デフォルト" {
                    charWindow.applyImage(newDefault)
                }
            }
        }
    }

    @objc func resetDefaultImage() {
        ImageManager.shared.resetCustomDefault()
        // Update all windows currently showing default
        if let newDefault = ImageManager.shared.defaultImage() {
            for charWindow in characterWindows where charWindow.displayName == "デフォルト" {
                charWindow.applyImage(newDefault)
            }
        }
    }

    @objc func quitFromMenu() {
        shouldTerminate = true
        NSApplication.shared.terminate(nil)
    }

    func createNewWindow(imageName: String? = nil) {
        let image: NSImage
        if let name = imageName, let registered = ImageManager.shared.loadRegisteredImage(named: name) {
            image = registered
        } else {
            image = ImageManager.shared.defaultImage() ?? NSImage()
        }
        let charWindow = CharacterWindow(image: image)
        charWindow.delegate = self
        charWindow.displayName = imageName ?? "デフォルト"
        characterWindows.append(charWindow)
    }

    private func buildNewWindowMenuItem() -> NSMenuItem {
        let newWindowItem = NSMenuItem(title: "新しいウィンドウ", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let defaultWindowItem = NSMenuItem(title: "デフォルト画像", action: #selector(addNewWindowFromMenu), keyEquivalent: "")
        defaultWindowItem.target = self
        submenu.addItem(defaultWindowItem)

        let names = ImageManager.shared.registeredImageNames()
        if !names.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(addNewWindowWithImageFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                submenu.addItem(item)
            }
        }

        submenu.addItem(NSMenuItem.separator())
        let selectImageItem = NSMenuItem(title: "画像を選択...", action: #selector(addNewWindowWithNewImageFromMenu), keyEquivalent: "")
        selectImageItem.target = self
        submenu.addItem(selectImageItem)

        newWindowItem.submenu = submenu
        return newWindowItem
    }

    @objc func addNewWindowWithNewImageFromMenu() {
        let panel = NSOpenPanel()
        panel.title = "画像を選択"
        panel.message = "新しいウィンドウに表示する画像ファイルを選択してください"
        panel.prompt = "選択"
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let savedName = ImageManager.shared.registerImage(from: url) {
                createNewWindow(imageName: savedName)
            }
        }
    }

    // MARK: CharacterWindowDelegate

    func characterWindowRequestedNewWindow(_ sender: CharacterWindow, imageName: String?) {
        createNewWindow(imageName: imageName)
    }

    func characterWindowRequestedNewWindowWithFileURL(_ sender: CharacterWindow, fileURL: URL) {
        if let savedName = ImageManager.shared.registerImage(from: fileURL) {
            createNewWindow(imageName: savedName)
        }
    }

    func characterWindowDidClose(_ sender: CharacterWindow) {
        characterWindows.removeAll { $0 === sender }
        quitIfNoWindows()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldTerminate {
            return .terminateNow
        }
        return .terminateCancel
    }

    @objc func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        NSApp.orderFrontStandardAboutPanel(options: [
            .version: "v\(version)"
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
