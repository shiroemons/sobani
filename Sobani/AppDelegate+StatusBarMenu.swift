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
        countItem.isEnabled = false
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
        menu.addItem(NSMenuItem.separator())

        menu.addItem(buildNewWindowMenuItem())

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

    func buildNewWindowMenuItem() -> NSMenuItem {
        let newWindowItem = NSMenuItem(title: "画像を追加表示", action: nil, keyEquivalent: "")
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

    @objc func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        NSApp.orderFrontStandardAboutPanel(options: [
            .version: "v\(version)"
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
