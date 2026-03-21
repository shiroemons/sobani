import Cocoa
import UniformTypeIdentifiers

// MARK: - Status Bar Menu

extension AppDelegate {
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "person.fill",
                accessibilityDescription: "Sobani"
            )
            button.image?.size = NSSize(
                width: AppConstants.statusBarIconSize,
                height: AppConstants.statusBarIconSize
            )
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        menu.removeAllItems()

        let imageNames = ImageManager.shared.registeredImageNames()

        let aboutItem = NSMenuItem(
            title: L("menu.about"),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
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
        let countItem = NSMenuItem(title: countTitle, action: nil, keyEquivalent: "")
        if !zOrderedWindows.isEmpty {
            countItem.submenu = buildImageWindowsSubmenu(imageNames: imageNames)
        } else {
            countItem.isEnabled = false
        }
        menu.addItem(countItem)

        menu.addItem(NSMenuItem.separator())

        buildWindowControlMenuItems(into: menu, ghostCount: ghostCount)
    }

    func buildUpdateMenuItem() -> NSMenuItem {
        let manager = SparkleManager.shared
        let item = NSMenuItem(
            title: L("update.check"),
            action: manager.checkForUpdatesAction,
            keyEquivalent: ""
        )
        item.target = manager.updaterTarget
        item.isEnabled = manager.canCheckForUpdates
        item.image = menuIcon("arrow.triangle.2.circlepath")
        return item
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

        let hasRotation = MenuStateUtils.hasRotation(
            angles: zOrderedWindows.map { $0.imageView.rotationAngle }
        )
        let hasOpacity = MenuStateUtils.hasNonDefaultOpacity(
            opacities: zOrderedWindows.map { $0.imageView.opacityLevel }
        )

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
        item.isEnabled = MenuStateUtils.isBulkResetEnabled(
            hasRotation: hasRotation,
            hasOpacity: hasOpacity,
            hasGhost: hasGhost
        )
        return item
    }

    func buildNewWindowMenuItem(imageNames: [String]) -> NSMenuItem {
        let newWindowItem = NSMenuItem(
            title: L("image.add_display"),
            action: nil,
            keyEquivalent: ""
        )
        newWindowItem.image = menuIcon("plus.rectangle.on.rectangle")
        let submenu = NSMenu()
        submenu.delegate = self

        let selectImageItem = NSMenuItem(
            title: L("image.select"),
            action: #selector(addNewWindowWithNewImageFromMenu),
            keyEquivalent: ""
        )
        selectImageItem.target = self
        selectImageItem.image = menuIcon("photo")
        submenu.addItem(selectImageItem)

        let defaultWindowItem = NSMenuItem(
            title: L("image.default"),
            action: #selector(addNewWindowFromMenu),
            keyEquivalent: ""
        )
        defaultWindowItem.target = self
        defaultWindowItem.image = menuIcon("person.fill")
        submenu.addItem(defaultWindowItem)

        submenu.addRegisteredImageItems(
            names: imageNames,
            target: self,
            action: #selector(addNewWindowWithImageFromMenu(_:))
        )

        newWindowItem.submenu = submenu
        return newWindowItem
    }

    func buildImageWindowsSubmenu(imageNames: [String]) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.delegate = self
        let orderedWindows = zOrderedWindows

        let font = NSFont.menuFont(ofSize: 0)

        typealias WindowInfo = (
            imageWindow: ImageWindow,
            info: (leftText: String, rightText: String)
        )
        let windowInfoList: [WindowInfo] = orderedWindows.enumerated().map { index, imageWindow in
            let rawName = imageWindow.window.screen?.localizedName ?? ""
            let info = MenuStateUtils.buildWindowInfoText(
                index: index, displayName: imageWindow.localizedDisplayName,
                windowId: imageWindow.windowId,
                imageSize: (
                    Int(imageWindow.imageView.frame.width),
                    Int(imageWindow.imageView.frame.height)
                ),
                screenName: rawName.isEmpty ? L("image.unknown") : rawName
            )
            return (imageWindow, info)
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
        for (imageWindow, info) in windowInfoList {
            let fullText = "\(info.leftText)\t\(info.rightText)"

            let attributedTitle = NSAttributedString(
                string: fullText,
                attributes: [.font: font, .paragraphStyle: paragraphStyle]
            )

            let item = NSMenuItem(title: info.leftText, action: nil, keyEquivalent: "")
            item.attributedTitle = attributedTitle
            if imageWindow.isHidden {
                item.image = hiddenIcon
            } else if imageWindow.isGhostMode {
                item.image = ghostIcon
            }
            item.representedObject = imageWindow
            item.submenu = buildWindowActionsSubmenu(
                for: imageWindow,
                orderedWindows: orderedWindows,
                imageNames: imageNames
            )
            submenu.addItem(item)
        }
        return submenu
    }

    func buildLanguageMenuItem() -> NSMenuItem {
        let languageItem = NSMenuItem(title: L("language.title"), action: nil, keyEquivalent: "")
        languageItem.image = menuIcon("globe")
        let languageSubmenu = NSMenu()
        let currentLanguage = LanguageManager.shared.currentLanguage
        for language in Language.allCases {
            let item = NSMenuItem(
                title: language.displayName,
                action: #selector(changeLanguage(_:)),
                keyEquivalent: ""
            )
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
            let item = NSMenuItem(
                title: theme.displayName,
                action: #selector(changeTheme(_:)),
                keyEquivalent: ""
            )
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
        snapItem.state = SnapSettings.isEnabled ? .on : .off
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

        if let imageWindow = zOrderedWindows.first(where: {
            $0.window.windowNumber == windowNumber
        }) {
            imageWindow.applyOpacity(value)
        }
    }

    @objc func perWindowGhostAlphaSliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        if let container = sender.superview { updatePercentLabel(in: container, alpha: value) }
        if let imageWindow = zOrderedWindows.first(where: { $0.window.windowNumber == sender.tag }) {
            imageWindow.setCustomGhostAlpha(value)
        }
    }

    @objc func togglePerWindowGhostAlphaCustom(_ sender: NSButton) {
        guard let imageWindow = zOrderedWindows.first(where: {
            $0.window.windowNumber == sender.tag
        }) else { return }
        imageWindow.setCustomGhostAlpha(sender.state == .on ? GhostModeSettings.globalAlpha : nil)

        guard let container = sender.superview else { return }
        let isCustom = imageWindow.customGhostAlpha != nil
        let currentAlpha = imageWindow.effectiveGhostAlpha
        if let slider = container.subviews.first(where: { $0 is NSSlider }) as? NSSlider {
            slider.doubleValue = Double(currentAlpha)
            slider.isEnabled = isCustom
        }
        if let percentLabel = container.subviews.last(where: {
            $0 is NSTextField
        }) as? NSTextField {
            percentLabel.stringValue = FormatUtils.formatOpacity(currentAlpha)
            percentLabel.alphaValue = isCustom ? 1.0 : 0.5
        }
    }

    @objc func ghostAlphaSliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        GhostModeSettings.globalAlpha = value
        if let container = sender.superview { updatePercentLabel(in: container, alpha: value) }
        for imageWindow in zOrderedWindows
        where imageWindow.isGhostMode && imageWindow.customGhostAlpha == nil {
            imageWindow.window.alphaValue = value
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
        let version = AppConstants.appVersion

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: String(format: L("about.version"), version, "v\(version)"),
            .version: ""
        ])
        NSApp.activate(ignoringOtherApps: true)
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
        for imageWindow in zOrderedWindows
        where imageWindow.displayName == AppConstants.defaultImageName {
            imageWindow.applyImage(newDefault)
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
        for imageWindow in zOrderedWindows {
            imageWindow.applyRotation(0)
        }
    }

    @objc func resetAllOpacity() {
        for imageWindow in zOrderedWindows {
            imageWindow.applyOpacity(1.0)
        }
    }

    @objc func toggleGhostModeByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        imageWindow.setGhostMode(!imageWindow.isGhostMode)
    }

    @objc func toggleHiddenByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        imageWindow.setHidden(!imageWindow.isHidden)
    }

}
