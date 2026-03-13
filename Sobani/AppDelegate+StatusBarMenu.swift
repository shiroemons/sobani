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

        // About & Update
        let aboutItem = NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = menuIcon("info.circle")
        menu.addItem(aboutItem)
        menu.addItem(buildUpdateMenuItem())

        menu.addItem(NSMenuItem.separator())

        // 画像を追加表示 & 表示中
        menu.addItem(buildNewWindowMenuItem(imageNames: imageNames))

        let ghostCount = zOrderedWindows.filter { $0.isGhostMode }.count
        let countTitle = MenuStateUtils.formatWindowCountText(
            count: zOrderedWindows.count,
            isHidden: areWindowsHidden,
            showingFormat: L("status.showing_count"),
            showingLabel: L("status.showing"),
            hiddenLabel: L("status.hidden"),
            ghostCount: ghostCount,
            ghostFormat: L("status.ghost_count")
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

        // 操作グループ
        let toggleTitle = areWindowsHidden ? L("window.show_all") : L("window.hide_all")
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleAllWindowsVisibility), keyEquivalent: "h")
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        toggleItem.isEnabled = !zOrderedWindows.isEmpty
        toggleItem.image = menuIcon(areWindowsHidden ? "eye" : "eye.slash")
        menu.addItem(toggleItem)

        let bringFrontItem = NSMenuItem(title: L("window.bring_to_front"), action: #selector(bringAllToFront), keyEquivalent: "f")
        bringFrontItem.target = self
        bringFrontItem.image = menuIcon("square.3.layers.3d.top.filled")
        menu.addItem(bringFrontItem)

        menu.addItem(buildLayoutMenuItem())

        menu.addItem(NSMenuItem.separator())

        // リセット & 閉じる
        menu.addItem(buildBulkResetMenuItem(ghostCount: ghostCount))

        let closeAllItem = NSMenuItem(title: L("menu.close_all"), action: #selector(closeAllWindows), keyEquivalent: "")
        closeAllItem.target = self
        closeAllItem.image = menuIcon("xmark.circle")
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
        item.image = menuIcon("circle.lefthalf.filled")
        return item
    }

    func buildBulkResetMenuItem(ghostCount: Int) -> NSMenuItem {
        let item = NSMenuItem(title: L("menu.bulk_reset"), action: nil, keyEquivalent: "")
        item.tag = MenuItemTag.bulkResetSubmenu.rawValue
        item.image = menuIcon("arrow.counterclockwise.circle")
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
        ghostResetItem.image = menuIcon("eye")
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

        // Build info text once per window to avoid calling buildWindowInfoText twice (width pass + render pass)
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
        for (charWindow, info) in windowInfoList {
            let fullText = "\(info.leftText)\t\(info.rightText)"

            let attributedTitle = NSAttributedString(
                string: fullText,
                attributes: [.font: font, .paragraphStyle: paragraphStyle]
            )

            let item = NSMenuItem(title: info.leftText, action: nil, keyEquivalent: "")
            item.attributedTitle = attributedTitle
            if charWindow.isGhostMode {
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
        changeImageItem.isEnabled = !areWindowsHidden
        changeImageItem.image = menuIcon("photo.on.rectangle")
        submenu.addItem(changeImageItem)

        submenu.addItem(NSMenuItem.separator())

        let flipItem = NSMenuItem(title: L("adjust.flip"), action: #selector(toggleFlipByWindowNumber(_:)), keyEquivalent: "")
        flipItem.target = self
        flipItem.state = charWindow.imageView.isFlippedHorizontally ? .on : .off
        flipItem.tag = windowNumber
        flipItem.isEnabled = !areWindowsHidden
        flipItem.image = menuIcon("arrow.left.and.right.righttriangle.left.righttriangle.right")
        submenu.addItem(flipItem)

        submenu.addItem(NSMenuItem.separator())

        let adjustItem = NSMenuItem(title: L("adjust.open"), action: #selector(showAdjustmentPanelByWindowNumber(_:)), keyEquivalent: "")
        adjustItem.target = self
        adjustItem.tag = windowNumber
        adjustItem.isEnabled = !areWindowsHidden
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
        resetOpacityItem.image = menuIcon("circle.lefthalf.filled")
        submenu.addItem(resetOpacityItem)

        submenu.addItem(NSMenuItem.separator())

        let resetDisplayItem = NSMenuItem(title: L("adjust.reset_display"), action: #selector(resetDisplayByWindowNumber(_:)), keyEquivalent: "")
        resetDisplayItem.target = self
        resetDisplayItem.tag = windowNumber
        resetDisplayItem.image = menuIcon("arrow.counterclockwise.circle")
        submenu.addItem(resetDisplayItem)

        submenu.addItem(NSMenuItem.separator())

        let ghostItem = NSMenuItem(
            title: L("ghost.toggle"),
            action: #selector(toggleGhostModeByWindowNumber(_:)),
            keyEquivalent: ""
        )
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
            let removeBackgroundItem = NSMenuItem(
                title: L("image.remove_background"),
                action: #selector(removeBackgroundByWindowNumber(_:)),
                keyEquivalent: ""
            )
            removeBackgroundItem.target = self
            removeBackgroundItem.tag = windowNumber
            removeBackgroundItem.isEnabled = !areWindowsHidden && !charWindow.imageHasAlpha()
            removeBackgroundItem.image = menuIcon("eraser.fill")
            submenu.addItem(removeBackgroundItem)
        }

        submenu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: L("menu.close_image"), action: #selector(closeWindowByWindowNumber(_:)), keyEquivalent: "")
        closeItem.target = self
        closeItem.tag = windowNumber
        closeItem.image = menuIcon("xmark.circle")
        submenu.addItem(closeItem)

        return submenu
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

    private func makePercentLabel(alpha: CGFloat, containerWidth: CGFloat, containerHeight: CGFloat) -> NSTextField {
        let percentWidth = AppConstants.ghostAlphaSliderPercentWidth
        let margin = AppConstants.ghostAlphaSliderTrailingMargin
        let label = NSTextField(labelWithString: AdjustmentPanelController.formatOpacity(alpha))
        label.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        label.alignment = .right
        label.frame = NSRect(
            x: containerWidth - percentWidth - margin,
            y: (containerHeight - label.frame.height) / 2,
            width: percentWidth,
            height: label.frame.height
        )
        return label
    }

    private func updatePercentLabel(in container: NSView, alpha: CGFloat) {
        if let label = container.subviews.compactMap({ $0 as? NSTextField }).last {
            label.stringValue = AdjustmentPanelController.formatOpacity(alpha)
        }
    }

    func buildPerWindowGhostAlphaSliderItem(for charWindow: CharacterWindow) -> NSMenuItem {
        let item = NSMenuItem()

        let containerWidth = AppConstants.ghostAlphaSliderContainerWidth
        let containerHeight = AppConstants.ghostAlphaSliderContainerHeight
        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))

        let isCustom = charWindow.customGhostAlpha != nil
        let currentAlpha = charWindow.effectiveGhostAlpha

        // チェックボックス（インデントを深くして親項目との階層感を出す）
        let checkboxX: CGFloat = 32
        let checkboxSize: CGFloat = 18
        let checkboxTrailingGap: CGFloat = 22
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(togglePerWindowGhostAlphaCustom(_:)))
        checkbox.frame = NSRect(x: checkboxX, y: (containerHeight - checkboxSize) / 2, width: checkboxSize, height: checkboxSize)
        checkbox.state = isCustom ? .on : .off
        checkbox.tag = charWindow.window.windowNumber
        container.addSubview(checkbox)

        // スライダー
        let sliderX: CGFloat = checkboxX + checkboxTrailingGap
        let sliderWidth = containerWidth - sliderX - AppConstants.ghostAlphaSliderPercentWidth - AppConstants.ghostAlphaSliderTrailingMargin
        let slider = NSSlider(
            value: Double(currentAlpha),
            minValue: Double(AppConstants.ghostModeAlphaMin),
            maxValue: Double(AppConstants.ghostModeAlphaMax),
            target: self,
            action: #selector(perWindowGhostAlphaSliderChanged(_:))
        )
        let sliderHeight = AppConstants.ghostAlphaSliderHeight
        slider.frame = NSRect(x: sliderX, y: (containerHeight - sliderHeight) / 2,
                              width: sliderWidth, height: sliderHeight)
        slider.isContinuous = true
        slider.tag = charWindow.window.windowNumber
        slider.isEnabled = isCustom
        container.addSubview(slider)

        // パーセント表示
        let percentLabel = makePercentLabel(alpha: currentAlpha, containerWidth: containerWidth, containerHeight: containerHeight)
        percentLabel.alphaValue = isCustom ? 1.0 : 0.5
        container.addSubview(percentLabel)

        item.view = container
        return item
    }

    func buildGhostAlphaSliderItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.tag = MenuItemTag.ghostModeAlphaSlider.rawValue

        let containerWidth = AppConstants.ghostAlphaSliderContainerWidth
        let containerHeight = AppConstants.ghostAlphaSliderContainerHeight
        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))

        let iconSize: CGFloat = 16
        let iconX: CGFloat = 16
        let iconPointSize: CGFloat = 12
        let iconLabelGap: CGFloat = 4
        let iconView = NSImageView(frame: NSRect(x: iconX, y: (containerHeight - iconSize) / 2, width: iconSize, height: iconSize))
        iconView.image = SFSymbolUtils.icon(AppConstants.ghostModeSymbol, pointSize: iconPointSize)
        iconView.imageScaling = .scaleProportionallyDown
        container.addSubview(iconView)

        let label = NSTextField(labelWithString: L("ghost.alpha_setting"))
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        label.sizeToFit()
        label.frame.origin = NSPoint(x: iconX + iconSize + iconLabelGap, y: (containerHeight - label.frame.height) / 2)
        container.addSubview(label)

        let sliderX = label.frame.maxX + AppConstants.ghostAlphaSliderTrailingMargin
        let sliderWidth = containerWidth - sliderX - AppConstants.ghostAlphaSliderPercentWidth - AppConstants.ghostAlphaSliderTrailingMargin
        let slider = NSSlider(
            value: Double(GhostModeSettings.globalAlpha),
            minValue: Double(AppConstants.ghostModeAlphaMin),
            maxValue: Double(AppConstants.ghostModeAlphaMax),
            target: self,
            action: #selector(ghostAlphaSliderChanged(_:))
        )
        let sliderHeight = AppConstants.ghostAlphaSliderHeight
        slider.frame = NSRect(x: sliderX, y: (containerHeight - sliderHeight) / 2,
                              width: sliderWidth, height: sliderHeight)
        slider.isContinuous = true
        container.addSubview(slider)

        let percentLabel = makePercentLabel(alpha: GhostModeSettings.globalAlpha, containerWidth: containerWidth, containerHeight: containerHeight)
        container.addSubview(percentLabel)

        item.view = container
        return item
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

        item.submenu = submenu
        return item
    }

    @objc func perWindowGhostAlphaSliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        let windowNumber = sender.tag

        // パーセント表示を更新
        if let container = sender.superview { updatePercentLabel(in: container, alpha: value) }

        // 対象ウィンドウのカスタム透明度を更新
        if let charWindow = zOrderedWindows.first(where: { $0.window.windowNumber == windowNumber }) {
            charWindow.setCustomGhostAlpha(value)
        }
    }

    @objc func togglePerWindowGhostAlphaCustom(_ sender: NSButton) {
        let windowNumber = sender.tag
        guard let charWindow = zOrderedWindows.first(where: { $0.window.windowNumber == windowNumber }) else { return }

        if sender.state == .on {
            // カスタムに切り替え: 現在のグローバル値をカスタム初期値として設定
            charWindow.setCustomGhostAlpha(GhostModeSettings.globalAlpha)
        } else {
            // グローバルに戻す
            charWindow.setCustomGhostAlpha(nil)
        }

        // スライダーとパーセント表示を更新
        if let container = sender.superview {
            let isCustom = charWindow.customGhostAlpha != nil
            let currentAlpha = charWindow.effectiveGhostAlpha
            if let slider = container.subviews.compactMap({ $0 as? NSSlider }).first {
                slider.doubleValue = Double(currentAlpha)
                slider.isEnabled = isCustom
            }
            if let percentLabel = container.subviews.compactMap({ $0 as? NSTextField }).last {
                percentLabel.stringValue = AdjustmentPanelController.formatOpacity(currentAlpha)
                percentLabel.alphaValue = isCustom ? 1.0 : 0.5
            }
        }
    }

    @objc func ghostAlphaSliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        GhostModeSettings.globalAlpha = value

        // パーセント表示を更新
        if let container = sender.superview { updatePercentLabel(in: container, alpha: value) }

        // グローバル設定を使用中のゴーストモードウィンドウに即時反映
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

        // Window highlight border (for character windows submenu)
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

}
