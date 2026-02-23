import Cocoa
import UniformTypeIdentifiers

// MARK: - Status Bar Menu

extension AppDelegate {
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
        guard menu === statusItem.menu else { return }
        menu.removeAllItems()

        let aboutItem = NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(buildUpdateMenuItem())

        let loginItem = NSMenuItem(
            title: L("menu.launch_at_login"),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let countItem = NSMenuItem(
            title: areWindowsHidden
                ? String(format: L("status.showing_count"), "\(characterWindows.count)")
                    .replacingOccurrences(of: L("status.showing"), with: L("status.hidden"))
                : String(format: L("status.showing_count"), "\(characterWindows.count)"),
            action: nil,
            keyEquivalent: ""
        )
        if !characterWindows.isEmpty {
            countItem.submenu = buildCharacterWindowsSubmenu()
        } else {
            countItem.isEnabled = false
        }
        menu.addItem(countItem)
        menu.addItem(NSMenuItem.separator())

        let bringFrontItem = NSMenuItem(title: L("window.bring_to_front"), action: #selector(bringAllToFront), keyEquivalent: "f")
        bringFrontItem.target = self
        menu.addItem(bringFrontItem)

        let toggleTitle = areWindowsHidden ? L("window.show_all") : L("window.hide_all")
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleAllWindowsVisibility), keyEquivalent: "h")
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        toggleItem.isEnabled = !characterWindows.isEmpty
        menu.addItem(toggleItem)

        menu.addItem(buildResetRotationMenuItem())
        menu.addItem(buildResetOpacityMenuItem())
        menu.addItem(NSMenuItem.separator())

        menu.addItem(buildNewWindowMenuItem())

        let closeAllItem = NSMenuItem(title: L("menu.close_all"), action: #selector(closeAllWindows), keyEquivalent: "")
        closeAllItem.target = self
        menu.addItem(closeAllItem)
        menu.addItem(NSMenuItem.separator())

        let changeDefaultItem = NSMenuItem(title: L("image.default_change"), action: #selector(changeDefaultImageFromMenu), keyEquivalent: "")
        changeDefaultItem.target = self
        menu.addItem(changeDefaultItem)

        if ImageManager.shared.hasCustomDefault {
            let resetDefaultItem = NSMenuItem(title: L("image.default_reset_action"), action: #selector(resetDefaultImage), keyEquivalent: "")
            resetDefaultItem.target = self
            menu.addItem(resetDefaultItem)
        }

        menu.addItem(NSMenuItem.separator())

        let languageItem = NSMenuItem(title: L("language.title"), action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu()
        let currentLanguage = LanguageManager.shared.currentLanguage
        for language in Language.allCases {
            let item = NSMenuItem(title: language.displayName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = language == currentLanguage ? .on : .off
            languageSubmenu.addItem(item)
        }
        languageItem.submenu = languageSubmenu
        menu.addItem(languageItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func buildUpdateMenuItem() -> NSMenuItem {
        switch UpdateManager.shared.state {
        case .available(let version, _, _, _):
            let item = NSMenuItem(
                title: String(format: L("update.available"), version),
                action: #selector(performUpdate),
                keyEquivalent: ""
            )
            item.target = self
            return item
        case .checking:
            let item = NSMenuItem(title: L("update.checking"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        case .downloading:
            let item = NSMenuItem(title: L("update.downloading"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        default:
            let item = NSMenuItem(
                title: L("update.check"),
                action: #selector(checkForUpdateManually),
                keyEquivalent: ""
            )
            item.target = self
            return item
        }
    }

    func buildResetRotationMenuItem() -> NSMenuItem {
        let hasRotation = characterWindows.contains { abs($0.imageView.rotationAngle) > AppConstants.floatingPointTolerance }
        let item = NSMenuItem(
            title: L("adjust.reset_all_rotation"),
            action: #selector(resetAllRotations),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = hasRotation
        return item
    }

    func buildResetOpacityMenuItem() -> NSMenuItem {
        let hasOpacity = characterWindows.contains { abs($0.imageView.opacityLevel - 1.0) > AppConstants.floatingPointTolerance }
        let item = NSMenuItem(
            title: L("adjust.reset_all_opacity"),
            action: #selector(resetAllOpacity),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = hasOpacity
        return item
    }

    func buildNewWindowMenuItem() -> NSMenuItem {
        let newWindowItem = NSMenuItem(title: L("image.add_display"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let selectImageItem = NSMenuItem(title: L("image.select"), action: #selector(addNewWindowWithNewImageFromMenu), keyEquivalent: "")
        selectImageItem.target = self
        submenu.addItem(selectImageItem)

        let defaultWindowItem = NSMenuItem(title: L("image.default"), action: #selector(addNewWindowFromMenu), keyEquivalent: "")
        defaultWindowItem.target = self
        submenu.addItem(defaultWindowItem)

        let names = ImageManager.shared.registeredImageNames()
        if !names.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let registeredLabel = NSMenuItem(title: L("image.registered"), action: nil, keyEquivalent: "")
            registeredLabel.isEnabled = false
            submenu.addItem(registeredLabel)
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(addNewWindowWithImageFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                submenu.addItem(item)
            }
        }

        newWindowItem.submenu = submenu
        return newWindowItem
    }

    func buildCharacterWindowsSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.delegate = self
        let orderedWindows = getZOrderedCharacterWindows()

        let font = NSFont.menuFont(ofSize: 0)

        var maxLeftWidth: CGFloat = 0
        for (index, charWindow) in orderedWindows.enumerated() {
            let leftText = "\(index + 1): \(charWindow.localizedDisplayName) (#\(charWindow.windowId))"
            let width = (leftText as NSString).size(withAttributes: [.font: font]).width
            if width > maxLeftWidth {
                maxLeftWidth = width
            }
        }
        let tabPosition = maxLeftWidth + 16

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: tabPosition)]

        for (index, charWindow) in orderedWindows.enumerated() {
            let imageWidth = Int(charWindow.imageView.frame.width)
            let imageHeight = Int(charWindow.imageView.frame.height)
            let rawScreenName = charWindow.window.screen?.localizedName ?? ""
            let screenName = rawScreenName.isEmpty ? L("image.unknown") : rawScreenName
            let leftText = "\(index + 1): \(charWindow.localizedDisplayName) (#\(charWindow.windowId))"
            let rightText = "[\(imageWidth)\u{00d7}\(imageHeight)] \(screenName)"
            let fullText = "\(leftText)\t\(rightText)"

            let attributedTitle = NSAttributedString(
                string: fullText,
                attributes: [.font: font, .paragraphStyle: paragraphStyle]
            )

            let item = NSMenuItem(title: leftText, action: nil, keyEquivalent: "")
            item.attributedTitle = attributedTitle
            item.representedObject = charWindow
            item.submenu = buildWindowActionsSubmenu(for: charWindow, orderedWindows: orderedWindows)
            submenu.addItem(item)
        }
        return submenu
    }

    func buildWindowActionsSubmenu(for charWindow: CharacterWindow, orderedWindows: [CharacterWindow]) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let windowNumber = charWindow.window.windowNumber
        let index = orderedWindows.firstIndex(where: { $0 === charWindow }) ?? 0
        let count = orderedWindows.count
        let canReorder = !areWindowsHidden && count > 1

        buildLayerOrderItems(into: submenu, windowNumber: windowNumber, index: index, count: count, canReorder: canReorder)

        submenu.addItem(NSMenuItem.separator())

        let flipItem = NSMenuItem(title: L("adjust.flip"), action: #selector(toggleFlipByWindowNumber(_:)), keyEquivalent: "")
        flipItem.target = self
        flipItem.state = charWindow.imageView.isFlippedHorizontally ? .on : .off
        flipItem.tag = windowNumber
        flipItem.isEnabled = !areWindowsHidden
        submenu.addItem(flipItem)

        submenu.addItem(NSMenuItem.separator())

        let adjustItem = NSMenuItem(title: L("adjust.open"), action: #selector(showAdjustmentPanelByWindowNumber(_:)), keyEquivalent: "")
        adjustItem.target = self
        adjustItem.tag = windowNumber
        adjustItem.isEnabled = !areWindowsHidden
        submenu.addItem(adjustItem)

        let resetRotationItem = NSMenuItem(title: L("adjust.reset_rotation"), action: #selector(resetRotationByWindowNumber(_:)), keyEquivalent: "")
        resetRotationItem.target = self
        resetRotationItem.tag = windowNumber
        resetRotationItem.isEnabled = abs(charWindow.imageView.rotationAngle) > AppConstants.floatingPointTolerance
        submenu.addItem(resetRotationItem)

        let resetOpacityItem = NSMenuItem(title: L("adjust.reset_opacity"), action: #selector(resetOpacityByWindowNumber(_:)), keyEquivalent: "")
        resetOpacityItem.target = self
        resetOpacityItem.tag = windowNumber
        resetOpacityItem.isEnabled = abs(charWindow.imageView.opacityLevel - 1.0) > AppConstants.floatingPointTolerance
        submenu.addItem(resetOpacityItem)

        submenu.addItem(NSMenuItem.separator())

        let resetDisplayItem = NSMenuItem(title: L("adjust.reset_display"), action: #selector(resetDisplayByWindowNumber(_:)), keyEquivalent: "")
        resetDisplayItem.target = self
        resetDisplayItem.tag = windowNumber
        submenu.addItem(resetDisplayItem)

        submenu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: L("menu.close_image"), action: #selector(closeWindowByWindowNumber(_:)), keyEquivalent: "")
        closeItem.target = self
        closeItem.tag = windowNumber
        submenu.addItem(closeItem)

        return submenu
    }

    func buildLayerOrderItems(into menu: NSMenu, windowNumber: Int, index: Int, count: Int, canReorder: Bool) {
        let toFrontItem = NSMenuItem(title: L("window.move_to_front"), action: #selector(moveWindowToFrontByWindowNumber(_:)), keyEquivalent: "")
        toFrontItem.target = self
        toFrontItem.tag = windowNumber
        toFrontItem.isEnabled = canReorder && index > 0
        menu.addItem(toFrontItem)

        let forwardItem = NSMenuItem(title: L("window.move_forward"), action: #selector(moveWindowForwardByWindowNumber(_:)), keyEquivalent: "")
        forwardItem.target = self
        forwardItem.tag = windowNumber
        forwardItem.isEnabled = canReorder && index > 0
        menu.addItem(forwardItem)

        let backwardItem = NSMenuItem(title: L("window.move_backward"), action: #selector(moveWindowBackwardByWindowNumber(_:)), keyEquivalent: "")
        backwardItem.target = self
        backwardItem.tag = windowNumber
        backwardItem.isEnabled = canReorder && index < count - 1
        menu.addItem(backwardItem)

        let toBackItem = NSMenuItem(title: L("window.move_to_back"), action: #selector(moveWindowToBackByWindowNumber(_:)), keyEquivalent: "")
        toBackItem.target = self
        toBackItem.tag = windowNumber
        toBackItem.isEnabled = canReorder && index < count - 1
        menu.addItem(toBackItem)
    }

    @objc func toggleFlipByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.imageView.isFlippedHorizontally.toggle()
    }

    @objc func showAdjustmentPanelByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.showAdjustmentPanel()
    }

    @objc func resetRotationByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.applyRotation(0)
    }

    @objc func resetOpacityByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.applyOpacity(1.0)
    }

    @objc func resetDisplayByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.resetDisplay()
    }

    @objc func moveWindowToFrontByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowToFront(charWindow)
        statusItem.menu?.cancelTracking()
    }

    @objc func moveWindowForwardByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowForward(charWindow)
        statusItem.menu?.cancelTracking()
    }

    @objc func moveWindowBackwardByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowBackward(charWindow)
        statusItem.menu?.cancelTracking()
    }

    @objc func moveWindowToBackByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowToBack(charWindow)
        statusItem.menu?.cancelTracking()
    }

    @objc func closeWindowByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.closeThisWindow()
    }

    @objc func changeLanguage(_ sender: NSMenuItem) {
        guard let languageRaw = sender.representedObject as? String,
              let language = Language(rawValue: languageRaw) else { return }

        let currentLanguage = LanguageManager.shared.currentLanguage
        guard language != currentLanguage else { return }

        LanguageManager.shared.currentLanguage = language
        // Menu will rebuild automatically on next open via menuNeedsUpdate
    }

    @objc func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: String(format: L("about.version"), version, "v\(version)"),
            .version: ""
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Menu Highlight

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard menu !== statusItem.menu else { return }
        for charWindow in characterWindows {
            charWindow.hideHighlightBorder()
        }
        if let charWindow = item?.representedObject as? CharacterWindow {
            charWindow.showHighlightBorder()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        for charWindow in characterWindows {
            charWindow.hideHighlightBorder()
        }
    }

    @objc func changeDefaultImageFromMenu() {
        let panel = NSOpenPanel()
        panel.title = L("dialog.select_default_image")
        panel.message = L("dialog.select_default_image_message")
        panel.prompt = L("dialog.select")
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            ImageManager.shared.setCustomDefault(from: url)
            if let newDefault = ImageManager.shared.defaultImage() {
                for charWindow in characterWindows where charWindow.displayName == AppConstants.defaultImageName {
                    charWindow.applyImage(newDefault)
                }
            }
        }
    }

    @objc func resetDefaultImage() {
        ImageManager.shared.resetCustomDefault()
        if let newDefault = ImageManager.shared.defaultImage() {
            for charWindow in characterWindows where charWindow.displayName == AppConstants.defaultImageName {
                charWindow.applyImage(newDefault)
            }
        }
    }

    @objc func resetAllRotations() {
        for charWindow in characterWindows {
            charWindow.applyRotation(0)
        }
    }

    @objc func resetAllOpacity() {
        for charWindow in characterWindows {
            charWindow.applyOpacity(1.0)
        }
    }
}
