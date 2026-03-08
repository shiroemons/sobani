import Cocoa
import UniformTypeIdentifiers

// MARK: - Status Bar Menu

extension AppDelegate {
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "person.fill", accessibilityDescription: "Sobani")
            button.image?.size = NSSize(width: AppConstants.statusBarIconSize, height: AppConstants.statusBarIconSize)
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        menu.removeAllItems()

        // About & Update
        let aboutItem = NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(buildUpdateMenuItem())

        menu.addItem(NSMenuItem.separator())

        // 画像を追加表示 & 表示中
        menu.addItem(buildNewWindowMenuItem())

        let countTitle = MenuStateUtils.formatWindowCountText(
            count: characterWindows.count,
            isHidden: areWindowsHidden,
            showingFormat: L("status.showing_count"),
            showingLabel: L("status.showing"),
            hiddenLabel: L("status.hidden")
        )
        let countItem = NSMenuItem(
            title: countTitle,
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

        // 操作グループ
        let toggleTitle = areWindowsHidden ? L("window.show_all") : L("window.hide_all")
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleAllWindowsVisibility), keyEquivalent: "h")
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        toggleItem.isEnabled = !characterWindows.isEmpty
        menu.addItem(toggleItem)

        let bringFrontItem = NSMenuItem(title: L("window.bring_to_front"), action: #selector(bringAllToFront), keyEquivalent: "f")
        bringFrontItem.target = self
        menu.addItem(bringFrontItem)

        menu.addItem(buildLayoutMenuItem())

        menu.addItem(NSMenuItem.separator())

        // リセット & 閉じる
        menu.addItem(buildBulkResetMenuItem())

        let closeAllItem = NSMenuItem(title: L("menu.close_all"), action: #selector(closeAllWindows), keyEquivalent: "")
        closeAllItem.target = self
        menu.addItem(closeAllItem)

        menu.addItem(NSMenuItem.separator())

        // 設定 & ガイド
        menu.addItem(buildSettingsMenuItem())

        let onboardingItem = NSMenuItem(
            title: L("menu.show_onboarding"),
            action: #selector(showOnboarding),
            keyEquivalent: ""
        )
        onboardingItem.target = self
        onboardingItem.tag = MenuItemTag.showOnboarding.rawValue
        menu.addItem(onboardingItem)

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
        let hasRotation = MenuStateUtils.hasRotation(angles: characterWindows.map(\.imageView.rotationAngle))
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
        let hasOpacity = MenuStateUtils.hasNonDefaultOpacity(opacities: characterWindows.map(\.imageView.opacityLevel))
        let item = NSMenuItem(
            title: L("adjust.reset_all_opacity"),
            action: #selector(resetAllOpacity),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = hasOpacity
        return item
    }

    func buildBulkResetMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("menu.bulk_reset"), action: nil, keyEquivalent: "")
        item.tag = MenuItemTag.bulkResetSubmenu.rawValue
        let submenu = NSMenu()

        let rotationItem = buildResetRotationMenuItem()
        submenu.addItem(rotationItem)

        let opacityItem = buildResetOpacityMenuItem()
        submenu.addItem(opacityItem)

        item.submenu = submenu
        // 両方 disabled なら親も disabled
        item.isEnabled = MenuStateUtils.isBulkResetEnabled(hasRotation: rotationItem.isEnabled, hasOpacity: opacityItem.isEnabled)
        return item
    }

    func buildNewWindowMenuItem() -> NSMenuItem {
        let newWindowItem = NSMenuItem(title: L("image.add_display"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.delegate = self

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

        let maxLeftWidth: CGFloat = orderedWindows.enumerated().reduce(0) { maxWidth, pair in
            let info = MenuStateUtils.buildWindowInfoText(
                index: pair.offset, displayName: pair.element.localizedDisplayName,
                windowId: pair.element.windowId,
                imageSize: (Int(pair.element.imageView.frame.width), Int(pair.element.imageView.frame.height)),
                screenName: ""
            )
            // swiftlint:disable:next legacy_objc_type
            let width = (info.leftText as NSString).size(withAttributes: [.font: font]).width
            return max(maxWidth, width)
        }
        let tabPosition = maxLeftWidth + AppConstants.menuTabPadding

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: tabPosition)]

        for (index, charWindow) in orderedWindows.enumerated() {
            let rawName = charWindow.window.screen?.localizedName ?? ""
            let info = MenuStateUtils.buildWindowInfoText(
                index: index, displayName: charWindow.localizedDisplayName,
                windowId: charWindow.windowId,
                imageSize: (Int(charWindow.imageView.frame.width), Int(charWindow.imageView.frame.height)),
                screenName: rawName.isEmpty ? L("image.unknown") : rawName
            )
            let fullText = "\(info.leftText)\t\(info.rightText)"

            let attributedTitle = NSAttributedString(
                string: fullText,
                attributes: [.font: font, .paragraphStyle: paragraphStyle]
            )

            let item = NSMenuItem(title: info.leftText, action: nil, keyEquivalent: "")
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
        let canReorder = MenuStateUtils.canReorder(areWindowsHidden: areWindowsHidden, windowCount: count)

        buildLayerOrderItems(into: submenu, windowNumber: windowNumber, index: index, count: count, canReorder: canReorder)

        submenu.addItem(NSMenuItem.separator())

        let changeImageItem = NSMenuItem(title: L("image.change"), action: nil, keyEquivalent: "")
        changeImageItem.submenu = buildChangeImageSubmenuForWindow(charWindow: charWindow)
        changeImageItem.isEnabled = !areWindowsHidden
        submenu.addItem(changeImageItem)

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
        resetRotationItem.isEnabled = MenuStateUtils.isRotationResetEnabled(angle: charWindow.imageView.rotationAngle)
        submenu.addItem(resetRotationItem)

        let resetOpacityItem = NSMenuItem(title: L("adjust.reset_opacity"), action: #selector(resetOpacityByWindowNumber(_:)), keyEquivalent: "")
        resetOpacityItem.target = self
        resetOpacityItem.tag = windowNumber
        resetOpacityItem.isEnabled = MenuStateUtils.isOpacityResetEnabled(opacity: charWindow.imageView.opacityLevel)
        submenu.addItem(resetOpacityItem)

        submenu.addItem(NSMenuItem.separator())

        let resetDisplayItem = NSMenuItem(title: L("adjust.reset_display"), action: #selector(resetDisplayByWindowNumber(_:)), keyEquivalent: "")
        resetDisplayItem.target = self
        resetDisplayItem.tag = windowNumber
        submenu.addItem(resetDisplayItem)

        if #available(macOS 14.0, *) {
            submenu.addItem(NSMenuItem.separator())
            let removeBackgroundItem = NSMenuItem(
                title: L("image.remove_background"),
                action: #selector(removeBackgroundByWindowNumber(_:)),
                keyEquivalent: ""
            )
            removeBackgroundItem.target = self
            removeBackgroundItem.tag = windowNumber
            removeBackgroundItem.isEnabled = !areWindowsHidden && !charWindow.imageHasAlpha()
            submenu.addItem(removeBackgroundItem)
        }

        submenu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: L("menu.close_image"), action: #selector(closeWindowByWindowNumber(_:)), keyEquivalent: "")
        closeItem.target = self
        closeItem.tag = windowNumber
        submenu.addItem(closeItem)

        return submenu
    }

    func buildChangeImageSubmenuForWindow(charWindow: CharacterWindow) -> NSMenu {
        let changeSubmenu = NSMenu()
        changeSubmenu.delegate = self
        changeSubmenu.autoenablesItems = false
        let windowNumber = charWindow.window.windowNumber

        let selectItem = NSMenuItem(title: L("image.change_select"), action: #selector(changeImageByWindowNumber(_:)), keyEquivalent: "")
        selectItem.target = self
        selectItem.tag = windowNumber
        changeSubmenu.addItem(selectItem)

        let resetItem = NSMenuItem(title: L("image.default_reset"), action: #selector(resetToDefaultByWindowNumber(_:)), keyEquivalent: "")
        resetItem.target = self
        resetItem.tag = windowNumber
        resetItem.isEnabled = charWindow.displayName != AppConstants.defaultImageName
        changeSubmenu.addItem(resetItem)

        let names = ImageManager.shared.registeredImageNames()
        if !names.isEmpty {
            changeSubmenu.addItem(NSMenuItem.separator())
            let registeredLabel = NSMenuItem(title: L("image.registered"), action: nil, keyEquivalent: "")
            registeredLabel.isEnabled = false
            changeSubmenu.addItem(registeredLabel)
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(selectRegisteredImageByWindowNumber(_:)), keyEquivalent: "")
                item.target = self
                item.tag = windowNumber
                item.representedObject = name
                item.state = (name == charWindow.displayName) ? .on : .off
                changeSubmenu.addItem(item)
            }
        }

        return changeSubmenu
    }

    func buildLayerOrderItems(into menu: NSMenu, windowNumber: Int, index: Int, count: Int, canReorder: Bool) {
        let toFrontItem = NSMenuItem(title: L("window.move_to_front"), action: #selector(moveWindowToFrontByWindowNumber(_:)), keyEquivalent: "")
        toFrontItem.target = self
        toFrontItem.tag = windowNumber
        toFrontItem.isEnabled = MenuStateUtils.canMoveForward(index: index, count: count, canReorder: canReorder)
        menu.addItem(toFrontItem)

        let forwardItem = NSMenuItem(title: L("window.move_forward"), action: #selector(moveWindowForwardByWindowNumber(_:)), keyEquivalent: "")
        forwardItem.target = self
        forwardItem.tag = windowNumber
        forwardItem.isEnabled = MenuStateUtils.canMoveForward(index: index, count: count, canReorder: canReorder)
        menu.addItem(forwardItem)

        let backwardItem = NSMenuItem(title: L("window.move_backward"), action: #selector(moveWindowBackwardByWindowNumber(_:)), keyEquivalent: "")
        backwardItem.target = self
        backwardItem.tag = windowNumber
        backwardItem.isEnabled = MenuStateUtils.canMoveBackward(index: index, count: count, canReorder: canReorder)
        menu.addItem(backwardItem)

        let toBackItem = NSMenuItem(title: L("window.move_to_back"), action: #selector(moveWindowToBackByWindowNumber(_:)), keyEquivalent: "")
        toBackItem.target = self
        toBackItem.tag = windowNumber
        toBackItem.isEnabled = MenuStateUtils.canMoveBackward(index: index, count: count, canReorder: canReorder)
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
        statusItem?.menu?.cancelTracking()
    }

    @objc func moveWindowForwardByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowForward(charWindow)
        statusItem?.menu?.cancelTracking()
    }

    @objc func moveWindowBackwardByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowBackward(charWindow)
        statusItem?.menu?.cancelTracking()
    }

    @objc func moveWindowToBackByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowToBack(charWindow)
        statusItem?.menu?.cancelTracking()
    }

    @objc func closeWindowByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.closeThisWindow()
    }

    @objc func removeBackgroundByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.removeBackground()
    }

    @objc func changeImageByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        let panel = ImageFileDialog.makeOpenPanel()
        if panel.runModal() == .OK, let url = panel.url, let newImage = NSImage(contentsOf: url) {
            let savedName = ImageManager.shared.registerImage(from: url)
            charWindow.setDisplayName(savedName ?? url.deletingPathExtension().lastPathComponent)
            charWindow.applyImage(newImage)
        }
    }

    @objc func selectRegisteredImageByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag),
              let name = sender.representedObject as? String,
              let image = ImageManager.shared.loadRegisteredImage(named: name) else { return }
        charWindow.setDisplayName(name)
        charWindow.applyImage(image)
    }

    @objc func resetToDefaultByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag),
              let defaultImage = ImageManager.shared.defaultImage() else { return }
        charWindow.setDisplayName(AppConstants.defaultImageName)
        charWindow.applyImage(defaultImage)
    }

    func buildLanguageMenuItem() -> NSMenuItem {
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
        return languageItem
    }

    func buildSettingsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("menu.settings"), action: nil, keyEquivalent: "")
        item.tag = MenuItemTag.settingsSubmenu.rawValue
        let submenu = NSMenu()

        let loginItem = NSMenuItem(
            title: L("menu.launch_at_login"),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        submenu.addItem(loginItem)

        submenu.addItem(NSMenuItem.separator())

        let changeDefaultItem = NSMenuItem(
            title: L("image.default_change"),
            action: #selector(changeDefaultImageFromMenu),
            keyEquivalent: ""
        )
        changeDefaultItem.target = self
        submenu.addItem(changeDefaultItem)

        if ImageManager.shared.hasCustomDefault {
            let resetDefaultItem = NSMenuItem(
                title: L("image.default_reset_action"),
                action: #selector(resetDefaultImage),
                keyEquivalent: ""
            )
            resetDefaultItem.target = self
            submenu.addItem(resetDefaultItem)
        }

        submenu.addItem(NSMenuItem.separator())

        submenu.addItem(buildLanguageMenuItem())

        item.submenu = submenu
        return item
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
        // Image preview for registered image items
        if let item = item, let name = item.representedObject as? String,
           item.action == #selector(addNewWindowWithImageFromMenu(_:))
            || item.action == #selector(selectRegisteredImageByWindowNumber(_:)) {
            if let image = ImageManager.shared.loadRegisteredImage(named: name) {
                ImagePreviewPanel.shared.show(image: image, relativeTo: item, ofMenu: menu)
            }
        } else if let item = item,
                  item.action == #selector(addNewWindowFromMenu)
                    || item.action == #selector(resetToDefaultByWindowNumber(_:)) {
            if let image = ImageManager.shared.defaultImage() {
                ImagePreviewPanel.shared.show(image: image, relativeTo: item, ofMenu: menu)
            }
        } else {
            ImagePreviewPanel.shared.hide()
        }

        // Window highlight border (for character windows submenu)
        guard menu !== statusItem?.menu else { return }
        for charWindow in characterWindows {
            charWindow.hideHighlightBorder()
        }
        if let charWindow = item?.representedObject as? CharacterWindow {
            charWindow.showHighlightBorder()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        ImagePreviewPanel.shared.hide()
        guard menu === statusItem?.menu else { return }
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

    @objc func showOnboarding() {
        let controller = OnboardingWindowController()
        controller.onAddImage = { [weak self] in
            self?.changeDefaultImageFromMenu()
        }
        controller.show()
        onboardingController = controller
    }

    // MARK: - Layout Preset

    func applyLayout(_ preset: LayoutPreset) {
        isApplyingLayout = true
        areWindowsHidden = false

        for charWindow in characterWindows {
            charWindow.window.orderOut(nil)
        }
        characterWindows.removeAll()
        zOrderedWindows.removeAll()

        for state in preset.states {
            let image: NSImage
            let resolvedDisplayName: String

            if state.imageName == AppConstants.defaultImageName {
                image = ImageManager.shared.defaultImage() ?? NSImage()
                resolvedDisplayName = AppConstants.defaultImageName
            } else if let registered = ImageManager.shared.loadRegisteredImage(named: state.imageName) {
                image = registered
                resolvedDisplayName = state.imageName
            } else {
                image = ImageManager.shared.defaultImage() ?? NSImage()
                resolvedDisplayName = AppConstants.defaultImageName
            }

            let charWindow = CharacterWindow(image: image)
            charWindow.delegate = self
            charWindow.setDisplayName(resolvedDisplayName)
            charWindow.setWindowId(nextWindowId)
            nextWindowId += 1
            charWindow.restore(from: state)
            characterWindows.append(charWindow)
        }

        zOrderedWindows = characterWindows.reversed()

        isApplyingLayout = false
        quitIfNoWindows()
    }

    func buildLayoutMenuItem() -> NSMenuItem {
        let layoutItem = NSMenuItem(title: L("layout.title"), action: nil, keyEquivalent: "")
        layoutItem.tag = MenuItemTag.layoutSubmenu.rawValue
        let submenu = NSMenu()

        let saveItem = NSMenuItem(
            title: L("layout.save_current"),
            action: #selector(saveLayoutFromMenu),
            keyEquivalent: ""
        )
        saveItem.target = self
        saveItem.tag = MenuItemTag.saveLayout.rawValue
        saveItem.isEnabled = !characterWindows.isEmpty
        submenu.addItem(saveItem)

        let createItem = NSMenuItem(
            title: L("layout.create_new"),
            action: #selector(createNewLayoutFromMenu),
            keyEquivalent: ""
        )
        createItem.target = self
        createItem.tag = MenuItemTag.createLayout.rawValue
        submenu.addItem(createItem)

        let presets = LayoutPresetManager.shared.loadPresets()
        if !presets.isEmpty {
            submenu.addItem(NSMenuItem.separator())

            let savedLabel = NSMenuItem(title: L("layout.saved"), action: nil, keyEquivalent: "")
            savedLabel.isEnabled = false
            submenu.addItem(savedLabel)

            for preset in presets {
                let item = NSMenuItem(
                    title: preset.name,
                    action: #selector(applyLayoutFromMenu(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = preset.name
                submenu.addItem(item)
            }

            submenu.addItem(NSMenuItem.separator())

            let updateItem = buildLayoutPresetSubmenu(
                title: L("layout.update"), tag: .updateLayout,
                action: #selector(updateLayoutFromMenu(_:)), presets: presets
            )
            updateItem.isEnabled = !characterWindows.isEmpty
            submenu.addItem(updateItem)

            submenu.addItem(buildLayoutPresetSubmenu(
                title: L("layout.rename"), tag: .renameLayout,
                action: #selector(renameLayoutFromMenu(_:)), presets: presets
            ))

            submenu.addItem(buildLayoutPresetSubmenu(
                title: L("layout.delete"), tag: .deleteLayout,
                action: #selector(deleteLayoutFromMenu(_:)), presets: presets
            ))
        }

        layoutItem.submenu = submenu
        return layoutItem
    }

    @objc func saveLayoutFromMenu() {
        let alert = NSAlert()
        alert.messageText = L("layout.save_title")
        alert.informativeText = L("layout.save_message")
        alert.addButton(withTitle: L("layout.save_button"))
        alert.addButton(withTitle: L("quit.cancel"))
        alert.alertStyle = .informational

        let textField = makeLayoutNameField(for: alert)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if LayoutPresetManager.shared.presetExists(named: name) {
            let overwriteAlert = NSAlert()
            overwriteAlert.messageText = L("layout.overwrite_title")
            overwriteAlert.informativeText = String(format: L("layout.overwrite_message"), name)
            overwriteAlert.addButton(withTitle: L("layout.overwrite_button"))
            overwriteAlert.addButton(withTitle: L("quit.cancel"))
            overwriteAlert.alertStyle = .warning
            guard overwriteAlert.runModal() == .alertFirstButtonReturn else { return }
        }

        let sortedWindows = Array(getZOrderedCharacterWindows().reversed())
        let states = sortedWindows.map { WindowStateManager.captureState(from: $0) }
        LayoutPresetManager.shared.savePreset(name: name, states: states)
    }

    @objc func createNewLayoutFromMenu() {
        let alert = NSAlert()
        alert.messageText = L("layout.create_title")
        alert.informativeText = L("layout.create_message")
        alert.addButton(withTitle: L("layout.create_button"))
        alert.addButton(withTitle: L("quit.cancel"))
        alert.alertStyle = .informational

        let textField = makeLayoutNameField(for: alert)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if LayoutPresetManager.shared.presetExists(named: name) {
            let overwriteAlert = NSAlert()
            overwriteAlert.messageText = L("layout.overwrite_title")
            overwriteAlert.informativeText = String(format: L("layout.overwrite_message"), name)
            overwriteAlert.addButton(withTitle: L("layout.overwrite_button"))
            overwriteAlert.addButton(withTitle: L("quit.cancel"))
            overwriteAlert.alertStyle = .warning
            guard overwriteAlert.runModal() == .alertFirstButtonReturn else { return }
        }

        let mainFrame = NSScreen.main?.frame ?? NSRect(origin: .zero, size: AppConstants.fallbackScreenSize)
        let defaultState = WindowState(
            imageName: AppConstants.defaultImageName,
            originX: mainFrame.midX - AppConstants.defaultWindowHeight / 2,
            originY: mainFrame.midY - AppConstants.defaultWindowHeight / 2,
            width: AppConstants.defaultWindowHeight,
            height: AppConstants.defaultWindowHeight,
            isFlippedHorizontally: false
        )
        LayoutPresetManager.shared.savePreset(name: name, states: [defaultState])

        if let preset = LayoutPresetManager.shared.loadPreset(named: name) {
            applyLayout(preset)
        }
    }

    @objc func applyLayoutFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let preset = LayoutPresetManager.shared.loadPreset(named: name) else { return }
        applyLayout(preset)
    }

    @objc func updateLayoutFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }

        let alert = NSAlert()
        alert.messageText = L("layout.overwrite_title")
        alert.informativeText = String(format: L("layout.update_confirm_message"), name)
        alert.addButton(withTitle: L("layout.overwrite_button"))
        alert.addButton(withTitle: L("quit.cancel"))
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let sortedWindows = Array(getZOrderedCharacterWindows().reversed())
        let states = sortedWindows.map { WindowStateManager.captureState(from: $0) }
        LayoutPresetManager.shared.savePreset(name: name, states: states)
    }

    @objc func deleteLayoutFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }

        let alert = NSAlert()
        alert.messageText = L("layout.delete_confirm_title")
        alert.informativeText = String(format: L("layout.delete_confirm_message"), name)
        alert.addButton(withTitle: L("layout.delete_button"))
        alert.addButton(withTitle: L("quit.cancel"))
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        LayoutPresetManager.shared.deletePreset(named: name)
    }

    @objc func renameLayoutFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }

        let alert = NSAlert()
        alert.messageText = L("layout.rename_title")
        alert.informativeText = L("layout.rename_message")
        alert.addButton(withTitle: L("layout.rename_button"))
        alert.addButton(withTitle: L("quit.cancel"))
        alert.alertStyle = .informational

        let textField = makeLayoutNameField(for: alert)
        textField.stringValue = name

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        guard newName != name else { return }

        if LayoutPresetManager.shared.presetExists(named: newName) {
            let overwriteAlert = NSAlert()
            overwriteAlert.messageText = L("layout.overwrite_title")
            overwriteAlert.informativeText = String(format: L("layout.overwrite_message"), newName)
            overwriteAlert.addButton(withTitle: L("layout.overwrite_button"))
            overwriteAlert.addButton(withTitle: L("quit.cancel"))
            overwriteAlert.alertStyle = .warning
            guard overwriteAlert.runModal() == .alertFirstButtonReturn else { return }
        }

        _ = LayoutPresetManager.shared.renamePreset(from: name, to: newName)
    }

    private func buildLayoutPresetSubmenu(
        title: String, tag: MenuItemTag, action: Selector, presets: [LayoutPreset]
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.tag = tag.rawValue
        let sub = NSMenu()
        for preset in presets {
            let item = NSMenuItem(title: preset.name, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = preset.name
            sub.addItem(item)
        }
        menuItem.submenu = sub
        return menuItem
    }

    private func makeLayoutNameField(for alert: NSAlert) -> NSTextField {
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: AppConstants.layoutDialogFieldWidth, height: AppConstants.layoutDialogFieldHeight))
        textField.placeholderString = L("layout.name_placeholder")
        alert.accessoryView = textField
        return textField
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
