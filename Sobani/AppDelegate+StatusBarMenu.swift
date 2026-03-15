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

        let imageNames = ImageManager.shared.registeredImageNames()

        let aboutItem = NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = menuIcon("info.circle")
        menu.addItem(aboutItem)
        menu.addItem(buildUpdateMenuItem())

        menu.addItem(NSMenuItem.separator())

        menu.addItem(buildNewWindowMenuItem(imageNames: imageNames))

        let ghostCount = zOrderedWindows.filter(\.isGhostMode).count
        let hiddenCount = zOrderedWindows.filter(\.isHidden).count
        let countTitle = MenuStateUtils.formatWindowCountText(
            count: zOrderedWindows.count,
            isHidden: areWindowsHidden,
            showingFormat: L("status.showing_count"),
            showingLabel: L("status.showing"),
            hiddenLabel: L("status.hidden"),
            badges: [
                StatusBadge(value: ghostCount, format: L("status.ghost_count")),
                StatusBadge(value: hiddenCount, format: L("status.hidden_count"))
            ]
        )
        let countItem = NSMenuItem(
            title: countTitle,
            action: nil,
            keyEquivalent: ""
        )
        if !zOrderedWindows.isEmpty {
            countItem.submenu = buildCharacterWindowsSubmenu(imageNames: imageNames)
        } else {
            countItem.isEnabled = false
        }
        menu.addItem(countItem)

        menu.addItem(NSMenuItem.separator())

        let toggleTitle = areWindowsHidden ? L("window.show_all") : L("window.hide_all")
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleAllWindowsVisibility), keyEquivalent: "h")
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        toggleItem.isEnabled = !zOrderedWindows.isEmpty
        toggleItem.image = menuIcon(areWindowsHidden ? AppConstants.visibleWindowSymbol : AppConstants.hiddenWindowSymbol)
        menu.addItem(toggleItem)

        let bringFrontItem = NSMenuItem(title: L("window.bring_to_front"), action: #selector(bringAllToFront), keyEquivalent: "f")
        bringFrontItem.target = self
        bringFrontItem.image = menuIcon("square.3.layers.3d.top.filled")
        menu.addItem(bringFrontItem)

        menu.addItem(buildLayoutMenuItem())

        menu.addItem(NSMenuItem.separator())

        menu.addItem(buildBulkResetMenuItem(ghostCount: ghostCount))

        let closeAllItem = NSMenuItem(title: L("menu.close_all"), action: #selector(closeAllWindows), keyEquivalent: "")
        closeAllItem.target = self
        closeAllItem.image = menuIcon(AppConstants.closeSymbol)
        menu.addItem(closeAllItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(buildSettingsMenuItem())

        let managementItem = NSMenuItem(
            title: L("management.title"),
            action: #selector(showManagementPanel),
            keyEquivalent: ""
        )
        managementItem.target = self
        managementItem.tag = MenuItemTag.managementPanel.rawValue
        managementItem.image = menuIcon("macwindow.on.rectangle")
        menu.addItem(managementItem)

        let onboardingItem = NSMenuItem(
            title: L("menu.show_onboarding"),
            action: #selector(showOnboarding),
            keyEquivalent: ""
        )
        onboardingItem.target = self
        onboardingItem.tag = MenuItemTag.showOnboarding.rawValue
        onboardingItem.image = menuIcon("questionmark.circle")
        menu.addItem(onboardingItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = menuIcon("power")
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
            item.image = menuIcon("arrow.down.circle")
            return item
        case .checking:
            let item = NSMenuItem(title: L("update.checking"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.image = menuIcon("arrow.triangle.2.circlepath")
            return item
        case .downloading:
            let item = NSMenuItem(title: L("update.downloading"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.image = menuIcon("arrow.triangle.2.circlepath")
            return item
        default:
            let item = NSMenuItem(
                title: L("update.check"),
                action: #selector(checkForUpdateManually),
                keyEquivalent: ""
            )
            item.target = self
            item.image = menuIcon("arrow.triangle.2.circlepath")
            return item
        }
    }

    func buildResetRotationMenuItem(hasRotation: Bool) -> NSMenuItem {
        let item = NSMenuItem(
            title: L("adjust.reset_all_rotation"),
            action: #selector(resetAllRotations),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = hasRotation
        item.image = menuIcon("arrow.counterclockwise")
        return item
    }

    func buildResetOpacityMenuItem(hasOpacity: Bool) -> NSMenuItem {
        let item = NSMenuItem(
            title: L("adjust.reset_all_opacity"),
            action: #selector(resetAllOpacity),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = hasOpacity
        item.image = menuIcon(AppConstants.opacitySymbol)
        return item
    }

    func buildBulkResetMenuItem(ghostCount: Int) -> NSMenuItem {
        let item = NSMenuItem(title: L("menu.bulk_reset"), action: nil, keyEquivalent: "")
        item.tag = MenuItemTag.bulkResetSubmenu.rawValue
        item.image = menuIcon(AppConstants.resetSymbol)
        let submenu = NSMenu()

        let tolerance = AppConstants.floatingPointTolerance
        var hasRotation = false
        var hasOpacity = false
        for win in zOrderedWindows {
            if !hasRotation && abs(win.imageView.rotationAngle) > tolerance {
                hasRotation = true
            }
            if !hasOpacity && abs(win.imageView.opacityLevel - 1.0) > tolerance {
                hasOpacity = true
            }
            if hasRotation && hasOpacity { break }
        }

        let rotationItem = buildResetRotationMenuItem(hasRotation: hasRotation)
        submenu.addItem(rotationItem)

        let opacityItem = buildResetOpacityMenuItem(hasOpacity: hasOpacity)
        submenu.addItem(opacityItem)

        let hasGhost = ghostCount > 0

        submenu.addItem(NSMenuItem.separator())

        let ghostResetItem = NSMenuItem(
            title: L("ghost.disable_all"),
            action: #selector(disableAllGhostMode),
            keyEquivalent: ""
        )
        ghostResetItem.target = self
        ghostResetItem.tag = MenuItemTag.ghostModeAllDisable.rawValue
        ghostResetItem.isEnabled = hasGhost
        ghostResetItem.image = menuIcon(AppConstants.visibleWindowSymbol)
        submenu.addItem(ghostResetItem)

        item.submenu = submenu
        item.isEnabled = MenuStateUtils.isBulkResetEnabled(hasRotation: hasRotation, hasOpacity: hasOpacity, hasGhost: hasGhost)
        return item
    }

    func buildNewWindowMenuItem(imageNames: [String]) -> NSMenuItem {
        let newWindowItem = NSMenuItem(title: L("image.add_display"), action: nil, keyEquivalent: "")
        newWindowItem.image = menuIcon("plus.rectangle.on.rectangle")
        let submenu = NSMenu()
        submenu.delegate = self

        let selectImageItem = NSMenuItem(title: L("image.select"), action: #selector(addNewWindowWithNewImageFromMenu), keyEquivalent: "")
        selectImageItem.target = self
        selectImageItem.image = menuIcon("photo")
        submenu.addItem(selectImageItem)

        let defaultWindowItem = NSMenuItem(title: L("image.default"), action: #selector(addNewWindowFromMenu), keyEquivalent: "")
        defaultWindowItem.target = self
        defaultWindowItem.image = menuIcon("person.fill")
        submenu.addItem(defaultWindowItem)

        submenu.addRegisteredImageItems(names: imageNames, target: self, action: #selector(addNewWindowWithImageFromMenu(_:)))

        newWindowItem.submenu = submenu
        return newWindowItem
    }

    func buildCharacterWindowsSubmenu(imageNames: [String]) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.delegate = self
        let orderedWindows = zOrderedWindows

        let font = NSFont.menuFont(ofSize: 0)

        typealias WindowInfo = (charWindow: CharacterWindow, info: (leftText: String, rightText: String))
        let windowInfoList: [WindowInfo] = orderedWindows.enumerated().map { index, charWindow in
            let rawName = charWindow.window.screen?.localizedName ?? ""
            let info = MenuStateUtils.buildWindowInfoText(
                index: index, displayName: charWindow.localizedDisplayName,
                windowId: charWindow.windowId,
                imageSize: (Int(charWindow.imageView.frame.width), Int(charWindow.imageView.frame.height)),
                screenName: rawName.isEmpty ? L("image.unknown") : rawName
            )
            return (charWindow, info)
        }

        let maxLeftWidth: CGFloat = windowInfoList.reduce(0) { maxWidth, pair in
            // swiftlint:disable:next legacy_objc_type
            let width = (pair.info.leftText as NSString).size(withAttributes: [.font: font]).width
            return max(maxWidth, width)
        }
        let tabPosition = maxLeftWidth + AppConstants.menuTabPadding

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: tabPosition)]

        let ghostIcon = menuIcon(AppConstants.ghostModeSymbol)
        let hiddenIcon = menuIcon(AppConstants.hiddenWindowSymbol)
        for (charWindow, info) in windowInfoList {
            let fullText = "\(info.leftText)\t\(info.rightText)"

            let attributedTitle = NSAttributedString(
                string: fullText,
                attributes: [.font: font, .paragraphStyle: paragraphStyle]
            )

            let item = NSMenuItem(title: info.leftText, action: nil, keyEquivalent: "")
            item.attributedTitle = attributedTitle
            if charWindow.isHidden {
                item.image = hiddenIcon
            } else if charWindow.isGhostMode {
                item.image = ghostIcon
            }
            item.representedObject = charWindow
            item.submenu = buildWindowActionsSubmenu(for: charWindow, orderedWindows: orderedWindows, imageNames: imageNames)
            submenu.addItem(item)
        }
        return submenu
    }

    func buildWindowActionsSubmenu(for charWindow: CharacterWindow, orderedWindows: [CharacterWindow], imageNames: [String]) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let windowNumber = charWindow.window.windowNumber
        let index = orderedWindows.firstIndex(where: { $0 === charWindow }) ?? 0
        let count = orderedWindows.count
        let canReorder = MenuStateUtils.canReorder(areWindowsHidden: areWindowsHidden, windowCount: count)

        buildLayerOrderItems(into: submenu, windowNumber: windowNumber, index: index, count: count, canReorder: canReorder)

        submenu.addItem(NSMenuItem.separator())

        let changeImageItem = NSMenuItem(title: L("image.change"), action: nil, keyEquivalent: "")
        changeImageItem.submenu = buildChangeImageSubmenuForWindow(charWindow: charWindow, imageNames: imageNames)
        changeImageItem.isEnabled = !areWindowsHidden && !charWindow.isHidden
        changeImageItem.image = menuIcon(AppConstants.changeImageSymbol)
        submenu.addItem(changeImageItem)

        submenu.addItem(NSMenuItem.separator())

        let flipItem = NSMenuItem(title: L("adjust.flip"), action: #selector(toggleFlipByWindowNumber(_:)), keyEquivalent: "")
        flipItem.target = self
        flipItem.state = charWindow.imageView.isFlippedHorizontally ? .on : .off
        flipItem.tag = windowNumber
        flipItem.isEnabled = !areWindowsHidden && !charWindow.isHidden
        flipItem.image = menuIcon("arrow.left.and.right.righttriangle.left.righttriangle.right")
        submenu.addItem(flipItem)
        submenu.addItem(buildPerWindowOpacitySliderItem(for: charWindow))

        submenu.addItem(NSMenuItem.separator())

        let adjustItem = NSMenuItem(title: L("adjust.open"), action: #selector(showAdjustmentPanelByWindowNumber(_:)), keyEquivalent: "")
        adjustItem.target = self
        adjustItem.tag = windowNumber
        adjustItem.isEnabled = !areWindowsHidden && !charWindow.isHidden
        adjustItem.image = menuIcon("slider.horizontal.3")
        submenu.addItem(adjustItem)

        let resetRotationItem = NSMenuItem(title: L("adjust.reset_rotation"), action: #selector(resetRotationByWindowNumber(_:)), keyEquivalent: "")
        resetRotationItem.target = self
        resetRotationItem.tag = windowNumber
        resetRotationItem.isEnabled = MenuStateUtils.isRotationResetEnabled(angle: charWindow.imageView.rotationAngle)
        resetRotationItem.image = menuIcon("arrow.counterclockwise")
        submenu.addItem(resetRotationItem)

        let resetOpacityItem = NSMenuItem(title: L("adjust.reset_opacity"), action: #selector(resetOpacityByWindowNumber(_:)), keyEquivalent: "")
        resetOpacityItem.target = self
        resetOpacityItem.tag = windowNumber
        resetOpacityItem.isEnabled = MenuStateUtils.isOpacityResetEnabled(opacity: charWindow.imageView.opacityLevel)
        resetOpacityItem.image = menuIcon(AppConstants.opacitySymbol)
        submenu.addItem(resetOpacityItem)

        submenu.addItem(NSMenuItem.separator())

        let resetDisplayItem = NSMenuItem(title: L("adjust.reset_display"), action: #selector(resetDisplayByWindowNumber(_:)), keyEquivalent: "")
        resetDisplayItem.target = self
        resetDisplayItem.tag = windowNumber
        resetDisplayItem.image = menuIcon(AppConstants.resetSymbol)
        submenu.addItem(resetDisplayItem)

        buildGhostAndBackgroundItems(into: submenu, for: charWindow)

        submenu.addItem(NSMenuItem.separator())

        let hideTitle = charWindow.isHidden ? L("window.show") : L("window.hide")
        let hideIcon = charWindow.isHidden ? AppConstants.visibleWindowSymbol : AppConstants.hiddenWindowSymbol
        let hideItem = NSMenuItem(title: hideTitle, action: #selector(toggleHiddenByWindowNumber(_:)), keyEquivalent: "")
        hideItem.target = self
        hideItem.tag = windowNumber
        hideItem.image = menuIcon(hideIcon)
        submenu.addItem(hideItem)

        let closeItem = NSMenuItem(title: L("menu.close_image"), action: #selector(closeWindowByWindowNumber(_:)), keyEquivalent: "")
        closeItem.target = self
        closeItem.tag = windowNumber
        closeItem.image = menuIcon(AppConstants.closeSymbol)
        submenu.addItem(closeItem)

        return submenu
    }

    private func buildGhostAndBackgroundItems(into submenu: NSMenu, for charWindow: CharacterWindow) {
        let windowNumber = charWindow.window.windowNumber
        submenu.addItem(NSMenuItem.separator())

        let ghostItem = NSMenuItem(title: L("ghost.toggle"), action: #selector(toggleGhostModeByWindowNumber(_:)), keyEquivalent: "")
        ghostItem.target = self
        ghostItem.tag = windowNumber
        ghostItem.state = charWindow.isGhostMode ? .on : .off
        ghostItem.image = menuIcon(AppConstants.ghostModeSymbol)
        submenu.addItem(ghostItem)

        if charWindow.isGhostMode {
            submenu.addItem(buildPerWindowGhostAlphaSliderItem(for: charWindow))
        }

        if #available(macOS 14.0, *) {
            submenu.addItem(NSMenuItem.separator())
            let removeBackgroundItem = NSMenuItem(title: L("image.remove_background"), action: #selector(removeBackgroundByWindowNumber(_:)), keyEquivalent: "")
            removeBackgroundItem.target = self
            removeBackgroundItem.tag = windowNumber
            removeBackgroundItem.isEnabled = !areWindowsHidden && !charWindow.imageHasAlpha()
            removeBackgroundItem.image = menuIcon("eraser.fill")
            submenu.addItem(removeBackgroundItem)
        }
    }

    func buildChangeImageSubmenuForWindow(charWindow: CharacterWindow, imageNames: [String]) -> NSMenu {
        let changeSubmenu = NSMenu()
        changeSubmenu.delegate = self
        changeSubmenu.autoenablesItems = false
        let windowNumber = charWindow.window.windowNumber

        let selectItem = NSMenuItem(title: L("image.change_select"), action: #selector(changeImageByWindowNumber(_:)), keyEquivalent: "")
        selectItem.target = self
        selectItem.tag = windowNumber
        selectItem.image = menuIcon("photo")
        changeSubmenu.addItem(selectItem)

        let resetItem = NSMenuItem(title: L("image.default_reset"), action: #selector(resetToDefaultByWindowNumber(_:)), keyEquivalent: "")
        resetItem.target = self
        resetItem.tag = windowNumber
        resetItem.isEnabled = charWindow.displayName != AppConstants.defaultImageName
        resetItem.image = menuIcon("arrow.counterclockwise")
        changeSubmenu.addItem(resetItem)

        changeSubmenu.addRegisteredImageItems(
            names: imageNames,
            target: self,
            action: #selector(selectRegisteredImageByWindowNumber(_:))
        ) { item, name in
            item.tag = windowNumber
            item.state = (name == charWindow.displayName) ? .on : .off
        }

        return changeSubmenu
    }

    func buildLayerOrderItems(into menu: NSMenu, windowNumber: Int, index: Int, count: Int, canReorder: Bool) {
        let toFrontItem = NSMenuItem(title: L("window.move_to_front"), action: #selector(moveWindowToFrontByWindowNumber(_:)), keyEquivalent: "")
        toFrontItem.target = self
        toFrontItem.tag = windowNumber
        toFrontItem.isEnabled = MenuStateUtils.canMoveForward(index: index, canReorder: canReorder)
        toFrontItem.image = menuIcon("square.3.layers.3d.top.filled")
        menu.addItem(toFrontItem)

        let forwardItem = NSMenuItem(title: L("window.move_forward"), action: #selector(moveWindowForwardByWindowNumber(_:)), keyEquivalent: "")
        forwardItem.target = self
        forwardItem.tag = windowNumber
        forwardItem.isEnabled = MenuStateUtils.canMoveForward(index: index, canReorder: canReorder)
        forwardItem.image = menuIcon("chevron.up")
        menu.addItem(forwardItem)

        let backwardItem = NSMenuItem(title: L("window.move_backward"), action: #selector(moveWindowBackwardByWindowNumber(_:)), keyEquivalent: "")
        backwardItem.target = self
        backwardItem.tag = windowNumber
        backwardItem.isEnabled = MenuStateUtils.canMoveBackward(index: index, count: count, canReorder: canReorder)
        backwardItem.image = menuIcon("chevron.down")
        menu.addItem(backwardItem)

        let toBackItem = NSMenuItem(title: L("window.move_to_back"), action: #selector(moveWindowToBackByWindowNumber(_:)), keyEquivalent: "")
        toBackItem.target = self
        toBackItem.tag = windowNumber
        toBackItem.isEnabled = MenuStateUtils.canMoveBackward(index: index, count: count, canReorder: canReorder)
        toBackItem.image = menuIcon("square.3.layers.3d.bottom.filled")
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
        if panel.runModal() == .OK, let url = panel.url {
            charWindow.loadAndApplyImage(from: url)
        }
    }

    @objc func selectRegisteredImageByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag),
              let name = sender.representedObject as? String,
              let image = ImageManager.shared.loadRegisteredImage(named: name) else { return }
        charWindow.displayName = name
        charWindow.applyImage(image)
    }

    @objc func resetToDefaultByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag),
              let defaultImage = ImageManager.shared.defaultImage() else { return }
        charWindow.displayName = AppConstants.defaultImageName
        charWindow.applyImage(defaultImage)
    }

    func buildLanguageMenuItem() -> NSMenuItem {
        let languageItem = NSMenuItem(title: L("language.title"), action: nil, keyEquivalent: "")
        languageItem.image = menuIcon("globe")
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

    func buildThemeMenuItem() -> NSMenuItem {
        let themeItem = NSMenuItem(title: L("theme.title"), action: nil, keyEquivalent: "")
        themeItem.image = menuIcon(AppConstants.themeParentSymbol)
        let themeSubmenu = NSMenu()
        let currentTheme = AppThemeSettings.currentTheme
        for theme in AppTheme.allCases {
            let item = NSMenuItem(title: theme.displayName, action: #selector(changeTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.rawValue
            item.state = theme == currentTheme ? .on : .off
            item.image = menuIcon(theme.iconName)
            themeSubmenu.addItem(item)
        }
        themeItem.submenu = themeSubmenu
        return themeItem
    }

    func buildSettingsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("menu.settings"), action: nil, keyEquivalent: "")
        item.tag = MenuItemTag.settingsSubmenu.rawValue
        item.image = menuIcon("gearshape")
        let submenu = NSMenu()

        let loginItem = NSMenuItem(
            title: L("menu.launch_at_login"),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        loginItem.image = menuIcon("play.circle")
        submenu.addItem(loginItem)

        let snapItem = NSMenuItem(
            title: L("menu.snap_placement"),
            action: #selector(toggleWindowSnap),
            keyEquivalent: ""
        )
        snapItem.target = self
        snapItem.state = UserDefaults.standard.bool(forKey: AppConstants.snapEnabledKey) ? .on : .off
        snapItem.image = menuIcon("rectangle.arrowtriangle.2.inward")
        submenu.addItem(snapItem)

        submenu.addItem(NSMenuItem.separator())
        submenu.addItem(buildGhostAlphaSliderItem())

        submenu.addItem(NSMenuItem.separator())

        let changeDefaultItem = NSMenuItem(
            title: L("image.default_change"),
            action: #selector(changeDefaultImageFromMenu),
            keyEquivalent: ""
        )
        changeDefaultItem.target = self
        changeDefaultItem.image = menuIcon("photo")
        submenu.addItem(changeDefaultItem)

        if ImageManager.shared.hasCustomDefault {
            let resetDefaultItem = NSMenuItem(
                title: L("image.default_reset_action"),
                action: #selector(resetDefaultImage),
                keyEquivalent: ""
            )
            resetDefaultItem.target = self
            resetDefaultItem.image = menuIcon("arrow.counterclockwise")
            submenu.addItem(resetDefaultItem)
        }

        submenu.addItem(NSMenuItem.separator())

        submenu.addItem(buildLanguageMenuItem())
        submenu.addItem(buildThemeMenuItem())

        item.submenu = submenu
        return item
    }

    @objc func perWindowOpacitySliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        let windowNumber = sender.tag

        if let container = sender.superview { updatePercentLabel(in: container, alpha: value) }

        if let charWindow = zOrderedWindows.first(where: { $0.window.windowNumber == windowNumber }) {
            charWindow.applyOpacity(value)
        }
    }

    @objc func perWindowGhostAlphaSliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        if let container = sender.superview { updatePercentLabel(in: container, alpha: value) }
        if let charWindow = zOrderedWindows.first(where: { $0.window.windowNumber == sender.tag }) {
            charWindow.setCustomGhostAlpha(value)
        }
    }

    @objc func togglePerWindowGhostAlphaCustom(_ sender: NSButton) {
        guard let charWindow = zOrderedWindows.first(where: { $0.window.windowNumber == sender.tag }) else { return }
        charWindow.setCustomGhostAlpha(sender.state == .on ? GhostModeSettings.globalAlpha : nil)

        guard let container = sender.superview else { return }
        let isCustom = charWindow.customGhostAlpha != nil
        let currentAlpha = charWindow.effectiveGhostAlpha
        if let slider = container.subviews.first(where: { $0 is NSSlider }) as? NSSlider {
            slider.doubleValue = Double(currentAlpha)
            slider.isEnabled = isCustom
        }
        if let percentLabel = container.subviews.last(where: { $0 is NSTextField }) as? NSTextField {
            percentLabel.stringValue = FormatUtils.formatOpacity(currentAlpha)
            percentLabel.alphaValue = isCustom ? 1.0 : 0.5
        }
    }

    @objc func ghostAlphaSliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        GhostModeSettings.globalAlpha = value
        if let container = sender.superview { updatePercentLabel(in: container, alpha: value) }
        for charWindow in zOrderedWindows where charWindow.isGhostMode && charWindow.customGhostAlpha == nil {
            charWindow.window.alphaValue = value
        }
    }

    @objc func changeLanguage(_ sender: NSMenuItem) {
        guard let languageRaw = sender.representedObject as? String,
              let language = Language(rawValue: languageRaw) else { return }

        let currentLanguage = LanguageManager.shared.currentLanguage
        guard language != currentLanguage else { return }

        LanguageManager.shared.currentLanguage = language
    }

    @objc func changeTheme(_ sender: NSMenuItem) {
        guard let themeRaw = sender.representedObject as? String,
              let theme = AppTheme(rawValue: themeRaw) else { return }
        let currentTheme = AppThemeSettings.currentTheme
        guard theme != currentTheme else { return }
        AppThemeSettings.currentTheme = theme
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
        ImagePreviewPanel.shared.showPreviewIfApplicable(
            for: item,
            in: menu,
            registeredImageActions: [
                #selector(addNewWindowWithImageFromMenu(_:)),
                #selector(selectRegisteredImageByWindowNumber(_:))
            ],
            defaultImageActions: [
                #selector(addNewWindowFromMenu),
                #selector(resetToDefaultByWindowNumber(_:))
            ]
        )

        guard menu !== statusItem?.menu else { return }
        lastHighlightedWindow?.hideHighlightBorder()
        lastHighlightedWindow = nil
        if let charWindow = item?.representedObject as? CharacterWindow {
            charWindow.showHighlightBorder()
            lastHighlightedWindow = charWindow
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        ImagePreviewPanel.shared.hide()
        guard menu === statusItem?.menu else { return }
        lastHighlightedWindow?.hideHighlightBorder()
        lastHighlightedWindow = nil
    }

    func menuIcon(_ name: String) -> NSImage? {
        SFSymbolUtils.icon(name)
    }

    @objc func changeDefaultImageFromMenu() {
        let panel = ImageFileDialog.makeOpenPanel(
            title: L("dialog.select_default_image"),
            message: L("dialog.select_default_image_message")
        )
        if panel.runModal() == .OK, let url = panel.url {
            ImageManager.shared.setCustomDefault(from: url)
            refreshDefaultImageWindows()
        }
    }

    @objc func resetDefaultImage() {
        ImageManager.shared.resetCustomDefault()
        refreshDefaultImageWindows()
    }

    private func refreshDefaultImageWindows() {
        guard let newDefault = ImageManager.shared.defaultImage() else { return }
        for charWindow in zOrderedWindows where charWindow.displayName == AppConstants.defaultImageName {
            charWindow.applyImage(newDefault)
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

    @objc func resetAllRotations() {
        for charWindow in zOrderedWindows {
            charWindow.applyRotation(0)
        }
    }

    @objc func resetAllOpacity() {
        for charWindow in zOrderedWindows {
            charWindow.applyOpacity(1.0)
        }
    }

    @objc func toggleGhostModeByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.setGhostMode(!charWindow.isGhostMode)
    }

    @objc func toggleHiddenByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.setHidden(!charWindow.isHidden)
    }

}
