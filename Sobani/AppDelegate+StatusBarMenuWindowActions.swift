import Cocoa

// MARK: - Status Bar Menu Window Actions

extension AppDelegate {
    func buildWindowActionsSubmenu(
        for imageWindow: ImageWindow,
        orderedWindows: [ImageWindow],
        imageNames: [String]
    ) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let windowNumber = imageWindow.window.windowNumber
        let index = orderedWindows.firstIndex(where: { $0 === imageWindow }) ?? 0
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
            imageWindow: imageWindow,
            imageNames: imageNames
        )
        changeImageItem.isEnabled = !areWindowsHidden && !imageWindow.isHidden
        changeImageItem.image = menuIcon(AppConstants.changeImageSymbol)
        submenu.addItem(changeImageItem)

        submenu.addItem(NSMenuItem.separator())

        let flipItem = NSMenuItem(
            title: L("adjust.flip"),
            action: #selector(toggleFlipByWindowNumber(_:)),
            keyEquivalent: ""
        )
        flipItem.target = self
        flipItem.state = imageWindow.imageView.isFlippedHorizontally ? .on : .off
        flipItem.tag = windowNumber
        flipItem.isEnabled = !areWindowsHidden && !imageWindow.isHidden
        flipItem.image = menuIcon("arrow.left.and.right.righttriangle.left.righttriangle.right")
        submenu.addItem(flipItem)
        submenu.addItem(buildPerWindowOpacitySliderItem(for: imageWindow))

        submenu.addItem(NSMenuItem.separator())

        buildAdjustmentMenuItems(into: submenu, for: imageWindow, windowNumber: windowNumber)
        buildGhostAndBackgroundItems(into: submenu, for: imageWindow)

        submenu.addItem(NSMenuItem.separator())

        let hideTitle = imageWindow.isHidden ? L("window.show") : L("window.hide")
        let hideIcon = imageWindow.isHidden
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
        for imageWindow: ImageWindow
    ) {
        let windowNumber = imageWindow.window.windowNumber
        submenu.addItem(NSMenuItem.separator())

        let ghostItem = NSMenuItem(
            title: L("ghost.toggle"),
            action: #selector(toggleGhostModeByWindowNumber(_:)),
            keyEquivalent: ""
        )
        ghostItem.target = self
        ghostItem.tag = windowNumber
        ghostItem.state = imageWindow.isGhostMode ? .on : .off
        ghostItem.image = menuIcon(AppConstants.ghostModeSymbol)
        submenu.addItem(ghostItem)

        if imageWindow.isGhostMode {
            submenu.addItem(buildPerWindowGhostAlphaSliderItem(for: imageWindow))
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
            removeBackgroundItem.isEnabled = !areWindowsHidden && !imageWindow.imageHasAlpha()
            removeBackgroundItem.image = menuIcon("eraser.fill")
            submenu.addItem(removeBackgroundItem)
        }
    }

    func buildChangeImageSubmenuForWindow(
        imageWindow: ImageWindow,
        imageNames: [String]
    ) -> NSMenu {
        let changeSubmenu = NSMenu()
        changeSubmenu.delegate = self
        changeSubmenu.autoenablesItems = false
        let windowNumber = imageWindow.window.windowNumber

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
        resetItem.isEnabled = imageWindow.displayName != AppConstants.defaultImageName
        resetItem.image = menuIcon("arrow.counterclockwise")
        changeSubmenu.addItem(resetItem)

        changeSubmenu.addRegisteredImageItems(
            names: imageNames,
            target: self,
            action: #selector(selectRegisteredImageByWindowNumber(_:))
        ) { item, name in
            item.tag = windowNumber
            item.state = (name == imageWindow.displayName) ? .on : .off
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
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        imageWindow.imageView.isFlippedHorizontally.toggle()
    }

    @objc func showAdjustmentPanelByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        imageWindow.showAdjustmentPanel()
    }

    @objc func resetRotationByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        imageWindow.applyRotation(0)
    }

    @objc func resetOpacityByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        imageWindow.applyOpacity(1.0)
    }

    @objc func resetDisplayByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        imageWindow.resetDisplay()
    }

    @objc func moveWindowToFrontByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        moveWindowToFront(imageWindow)
        statusItem?.menu?.cancelTracking()
    }

    @objc func moveWindowForwardByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        moveWindowForward(imageWindow)
        statusItem?.menu?.cancelTracking()
    }

    @objc func moveWindowBackwardByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        moveWindowBackward(imageWindow)
        statusItem?.menu?.cancelTracking()
    }

    @objc func moveWindowToBackByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        moveWindowToBack(imageWindow)
        statusItem?.menu?.cancelTracking()
    }

    @objc func closeWindowByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        imageWindow.closeThisWindow()
    }

    @objc func removeBackgroundByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        imageWindow.removeBackground()
    }

    @objc func changeImageByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag) else { return }
        let panel = ImageFileDialog.makeOpenPanel()
        if panel.runModal() == .OK, let url = panel.url {
            imageWindow.loadAndApplyImage(from: url)
        }
    }

    @objc func selectRegisteredImageByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag),
              let name = sender.representedObject as? String,
              let image = ImageManager.shared.loadRegisteredImage(named: name) else { return }
        imageWindow.displayName = name
        imageWindow.applyImage(image)
    }

    @objc func resetToDefaultByWindowNumber(_ sender: NSMenuItem) {
        guard let imageWindow = imageWindow(forWindowNumber: sender.tag),
              let defaultImage = ImageManager.shared.defaultImage() else { return }
        imageWindow.displayName = AppConstants.defaultImageName
        imageWindow.applyImage(defaultImage)
    }
}
