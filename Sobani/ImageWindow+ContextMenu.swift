import Cocoa

// MARK: - ImageWindow + Context Menu

extension ImageWindow {
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

        let adjustPanelItem = NSMenuItem(title: L("adjust.open"), action: #selector(showAdjustmentPanel), keyEquivalent: "")
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
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.tag = MenuItemTag.quit.rawValue
        quitItem.target = self
        quitItem.image = SFSymbolUtils.icon("power")
        menu.addItem(quitItem)

        let quitWithoutSavingItem = NSMenuItem(
            title: L("menu.quit_without_saving"),
            action: #selector(quitAppWithoutSaving),
            keyEquivalent: "q"
        )
        quitWithoutSavingItem.keyEquivalentModifierMask = [.command, .option]
        quitWithoutSavingItem.isAlternate = true
        quitWithoutSavingItem.tag = MenuItemTag.quitWithoutSaving.rawValue
        quitWithoutSavingItem.target = self
        quitWithoutSavingItem.image = SFSymbolUtils.icon("power")
        menu.addItem(quitWithoutSavingItem)
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
        label.frame.origin = NSPoint(
            x: iconX + iconSize + 4,
            y: iconY + (iconSize - label.frame.height) / 2
        )
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
        slider.frame = NSRect(
            x: sliderX,
            y: (bottomRowH - sliderH) / 2,
            width: containerW - sliderX - pctWidth - trailing,
            height: sliderH
        )
        slider.isContinuous = true
        slider.trackFillColor = .systemGray
        container.addSubview(slider)

        let percentLabel = NSTextField(
            labelWithString: FormatUtils.formatOpacity(imageView.opacityLevel)
        )
        percentLabel.font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize, weight: .regular
        )
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
                action: #selector(removeBackground as () -> Void),
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

// MARK: - ImageWindow + Menu Title Update

extension ImageWindow {
    nonisolated(unsafe) private static let menuTitleMap: [MenuItemTag: String] = [
        .changeImageSubmenu: "image.change",
        .flipContext: "adjust.flip",
        .adjustPanelContext: "adjust.open",
        .addNewWindowSubmenu: "image.add_display",
        .otherSubmenu: "menu.other",
        .close: "menu.close_image",
        .quit: "menu.quit",
        .quitWithoutSaving: "menu.quit_without_saving"
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

// MARK: - ImageWindow + Highlight Border

extension ImageWindow {
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
