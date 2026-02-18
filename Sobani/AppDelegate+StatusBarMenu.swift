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

        let aboutItem = NSMenuItem(title: "Sobani について...", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

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

        let countLabel = areWindowsHidden ? "非表示中" : "表示中"
        let countItem = NSMenuItem(title: "\(countLabel): \(characterWindows.count)体", action: nil, keyEquivalent: "")
        if !characterWindows.isEmpty {
            countItem.submenu = buildCharacterWindowsSubmenu()
        } else {
            countItem.isEnabled = false
        }
        menu.addItem(countItem)
        menu.addItem(NSMenuItem.separator())

        let bringFrontItem = NSMenuItem(title: "すべて手前に表示", action: #selector(bringAllToFront), keyEquivalent: "f")
        bringFrontItem.target = self
        menu.addItem(bringFrontItem)

        let toggleTitle = areWindowsHidden ? "すべて表示" : "すべて非表示"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleAllWindowsVisibility), keyEquivalent: "h")
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        toggleItem.isEnabled = !characterWindows.isEmpty
        menu.addItem(toggleItem)

        menu.addItem(buildResetRotationMenuItem())
        menu.addItem(buildResetOpacityMenuItem())
        menu.addItem(NSMenuItem.separator())

        menu.addItem(buildNewWindowMenuItem())

        let closeAllItem = NSMenuItem(title: "すべて閉じる", action: #selector(closeAllWindows), keyEquivalent: "")
        closeAllItem.target = self
        menu.addItem(closeAllItem)
        menu.addItem(NSMenuItem.separator())

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

    func buildResetRotationMenuItem() -> NSMenuItem {
        let hasRotation = characterWindows.contains { $0.imageView.rotationAngle != 0 }
        let item = NSMenuItem(
            title: "すべての画像の回転をリセット",
            action: #selector(resetAllRotations),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = hasRotation
        return item
    }

    func buildResetOpacityMenuItem() -> NSMenuItem {
        let hasOpacity = characterWindows.contains { $0.imageView.opacityLevel != 1.0 }
        let item = NSMenuItem(
            title: "すべての画像の透明度をリセット",
            action: #selector(resetAllOpacity),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = hasOpacity
        return item
    }

    func buildNewWindowMenuItem() -> NSMenuItem {
        let newWindowItem = NSMenuItem(title: "画像を追加表示", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let selectImageItem = NSMenuItem(title: "画像を選択...", action: #selector(addNewWindowWithNewImageFromMenu), keyEquivalent: "")
        selectImageItem.target = self
        submenu.addItem(selectImageItem)

        let defaultWindowItem = NSMenuItem(title: "デフォルト画像", action: #selector(addNewWindowFromMenu), keyEquivalent: "")
        defaultWindowItem.target = self
        submenu.addItem(defaultWindowItem)

        let names = ImageManager.shared.registeredImageNames()
        if !names.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let registeredLabel = NSMenuItem(title: "登録画像", action: nil, keyEquivalent: "")
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
        for charWindow in orderedWindows {
            let item = NSMenuItem(title: charWindow.displayName, action: nil, keyEquivalent: "")
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

        let flipItem = NSMenuItem(title: "左右反転", action: #selector(toggleFlipByWindowNumber(_:)), keyEquivalent: "")
        flipItem.target = self
        flipItem.state = charWindow.imageView.isFlippedHorizontally ? .on : .off
        flipItem.tag = windowNumber
        submenu.addItem(flipItem)

        submenu.addItem(NSMenuItem.separator())

        let adjustItem = NSMenuItem(title: "表示の調整...", action: #selector(showAdjustmentPanelByWindowNumber(_:)), keyEquivalent: "")
        adjustItem.target = self
        adjustItem.tag = windowNumber
        submenu.addItem(adjustItem)

        submenu.addItem(NSMenuItem.separator())

        let resetRotationItem = NSMenuItem(title: "回転をリセット", action: #selector(resetRotationByWindowNumber(_:)), keyEquivalent: "")
        resetRotationItem.target = self
        resetRotationItem.tag = windowNumber
        resetRotationItem.isEnabled = charWindow.imageView.rotationAngle != 0
        submenu.addItem(resetRotationItem)

        let resetOpacityItem = NSMenuItem(title: "透明度をリセット", action: #selector(resetOpacityByWindowNumber(_:)), keyEquivalent: "")
        resetOpacityItem.target = self
        resetOpacityItem.tag = windowNumber
        resetOpacityItem.isEnabled = charWindow.imageView.opacityLevel != 1.0
        submenu.addItem(resetOpacityItem)

        submenu.addItem(NSMenuItem.separator())

        buildLayerOrderItems(into: submenu, windowNumber: windowNumber, index: index, count: count, canReorder: canReorder)

        submenu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: "この画像を閉じる", action: #selector(closeWindowByWindowNumber(_:)), keyEquivalent: "")
        closeItem.target = self
        closeItem.tag = windowNumber
        submenu.addItem(closeItem)

        return submenu
    }

    func buildLayerOrderItems(into menu: NSMenu, windowNumber: Int, index: Int, count: Int, canReorder: Bool) {
        let toFrontItem = NSMenuItem(title: "最前面へ移動", action: #selector(moveWindowToFrontByWindowNumber(_:)), keyEquivalent: "")
        toFrontItem.target = self
        toFrontItem.tag = windowNumber
        toFrontItem.isEnabled = canReorder && index > 0
        menu.addItem(toFrontItem)

        let forwardItem = NSMenuItem(title: "前面へ移動", action: #selector(moveWindowForwardByWindowNumber(_:)), keyEquivalent: "")
        forwardItem.target = self
        forwardItem.tag = windowNumber
        forwardItem.isEnabled = canReorder && index > 0
        menu.addItem(forwardItem)

        let backwardItem = NSMenuItem(title: "背面へ移動", action: #selector(moveWindowBackwardByWindowNumber(_:)), keyEquivalent: "")
        backwardItem.target = self
        backwardItem.tag = windowNumber
        backwardItem.isEnabled = canReorder && index < count - 1
        menu.addItem(backwardItem)

        let toBackItem = NSMenuItem(title: "最背面へ移動", action: #selector(moveWindowToBackByWindowNumber(_:)), keyEquivalent: "")
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

    @objc func moveWindowToFrontByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowToFront(charWindow)
    }

    @objc func moveWindowForwardByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowForward(charWindow)
    }

    @objc func moveWindowBackwardByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowBackward(charWindow)
    }

    @objc func moveWindowToBackByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        moveWindowToBack(charWindow)
    }

    @objc func closeWindowByWindowNumber(_ sender: NSMenuItem) {
        guard let charWindow = characterWindow(forWindowNumber: sender.tag) else { return }
        charWindow.closeThisWindow()
    }

    @objc func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        NSApp.orderFrontStandardAboutPanel(options: [
            .version: "v\(version)"
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
}
