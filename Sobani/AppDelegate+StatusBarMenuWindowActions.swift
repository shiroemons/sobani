import Cocoa

// MARK: - Status Bar Menu Window Actions

extension AppDelegate {
    func buildWindowActionsSubmenu(
        for charWindow: CharacterWindow,
        orderedWindows: [CharacterWindow],
        imageNames: [String]
    ) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let windowNumber = charWindow.window.windowNumber
        let index = orderedWindows.firstIndex(where: { $0 === charWindow }) ?? 0
        let count = orderedWindows.count
        let canReorder = MenuStateUtils.canReorder(
            areWindowsHidden: areWindowsHidden,
            windowCount: count
        )

        buildLayerOrderItems(
            into: submenu,
            windowNumber: windowNumber,
            index: index,
            count: count,
            canReorder: canReorder
        )

        submenu.addItem(NSMenuItem.separator())

        let changeImageItem = NSMenuItem(title: L("image.change"), action: nil, keyEquivalent: "")
        changeImageItem.submenu = buildChangeImageSubmenuForWindow(
            charWindow: charWindow,
            imageNames: imageNames
        )
        changeImageItem.isEnabled = !areWindowsHidden && !charWindow.isHidden
        changeImageItem.image = menuIcon(AppConstants.changeImageSymbol)
        submenu.addItem(changeImageItem)

        submenu.addItem(NSMenuItem.separator())

        let flipItem = NSMenuItem(
            title: L("adjust.flip"),
            action: #selector(toggleFlipByWindowNumber(_:)),
            keyEquivalent: ""
        )
        flipItem.target = self
        flipItem.state = charWindow.imageView.isFlippedHorizontally ? .on : .off
        flipItem.tag = windowNumber
        flipItem.isEnabled = !areWindowsHidden && !charWindow.isHidden
        flipItem.image = menuIcon("arrow.left.and.right.righttriangle.left.righttriangle.right")
        submenu.addItem(flipItem)
        submenu.addItem(buildPerWindowOpacitySliderItem(for: charWindow))

        submenu.addItem(NSMenuItem.separator())

        buildAdjustmentMenuItems(into: submenu, for: charWindow, windowNumber: windowNumber)
        buildGhostAndBackgroundItems(into: submenu, for: charWindow)

        submenu.addItem(NSMenuItem.separator())

        let hideTitle = charWindow.isHidden ? L("window.show") : L("window.hide")
        let hideIcon = charWindow.isHidden
            ? AppConstants.visibleWindowSymbol
            : AppConstants.hiddenWindowSymbol
        let hideItem = NSMenuItem(
            title: hideTitle,
            action: #selector(toggleHiddenByWindowNumber(_:)),
            keyEquivalent: ""
        )
        hideItem.target = self
        hideItem.tag = windowNumber
        hideItem.image = menuIcon(hideIcon)
        submenu.addItem(hideItem)

        let closeItem = NSMenuItem(
            title: L("menu.close_image"),
            action: #selector(closeWindowByWindowNumber(_:)),
            keyEquivalent: ""
        )
        closeItem.target = self
        closeItem.tag = windowNumber
        closeItem.image = menuIcon(AppConstants.closeSymbol)
        submenu.addItem(closeItem)

        return submenu
    }

    private func buildGhostAndBackgroundItems(
        into submenu: NSMenu,
        for charWindow: CharacterWindow
    ) {
        let windowNumber = charWindow.window.windowNumber
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
    }

    func buildChangeImageSubmenuForWindow(
        charWindow: CharacterWindow,
        imageNames: [String]
    ) -> NSMenu {
        let changeSubmenu = NSMenu()
        changeSubmenu.delegate = self
        changeSubmenu.autoenablesItems = false
        let windowNumber = charWindow.window.windowNumber

        let selectItem = NSMenuItem(
            title: L("image.change_select"),
            action: #selector(changeImageByWindowNumber(_:)),
            keyEquivalent: ""
        )
        selectItem.target = self
        selectItem.tag = windowNumber
        selectItem.image = menuIcon("photo")
        changeSubmenu.addItem(selectItem)

        let resetItem = NSMenuItem(
            title: L("image.default_reset"),
            action: #selector(resetToDefaultByWindowNumber(_:)),
            keyEquivalent: ""
        )
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

    func buildLayerOrderItems(
        into menu: NSMenu,
        windowNumber: Int,
        index: Int,
        count: Int,
        canReorder: Bool
    ) {
        let toFrontItem = NSMenuItem(
            title: L("window.move_to_front"),
            action: #selector(moveWindowToFrontByWindowNumber(_:)),
            keyEquivalent: ""
        )
        toFrontItem.target = self
        toFrontItem.tag = windowNumber
        toFrontItem.isEnabled = MenuStateUtils.canMoveForward(index: index, canReorder: canReorder)
        toFrontItem.image = menuIcon("square.3.layers.3d.top.filled")
        menu.addItem(toFrontItem)

        let forwardItem = NSMenuItem(
            title: L("window.move_forward"),
            action: #selector(moveWindowForwardByWindowNumber(_:)),
            keyEquivalent: ""
        )
        forwardItem.target = self
        forwardItem.tag = windowNumber
        forwardItem.isEnabled = MenuStateUtils.canMoveForward(index: index, canReorder: canReorder)
        forwardItem.image = menuIcon("chevron.up")
        menu.addItem(forwardItem)

        let backwardItem = NSMenuItem(
            title: L("window.move_backward"),
            action: #selector(moveWindowBackwardByWindowNumber(_:)),
            keyEquivalent: ""
        )
        backwardItem.target = self
        backwardItem.tag = windowNumber
        backwardItem.isEnabled = MenuStateUtils.canMoveBackward(
            index: index,
            count: count,
            canReorder: canReorder
        )
        backwardItem.image = menuIcon("chevron.down")
        menu.addItem(backwardItem)

        let toBackItem = NSMenuItem(
            title: L("window.move_to_back"),
            action: #selector(moveWindowToBackByWindowNumber(_:)),
            keyEquivalent: ""
        )
        toBackItem.target = self
        toBackItem.tag = windowNumber
        toBackItem.isEnabled = MenuStateUtils.canMoveBackward(
            index: index,
            count: count,
            canReorder: canReorder
        )
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
}
