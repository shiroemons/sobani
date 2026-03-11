import Cocoa

// MARK: - AppDelegate + Layout Preset

extension AppDelegate {
    // MARK: - Window Array Management

    func addCharacterWindow(_ window: CharacterWindow) {
        characterWindows.append(window)
        zOrderedWindows.insert(window, at: 0)
    }

    func removeCharacterWindow(_ window: CharacterWindow) {
        characterWindows.removeAll { $0 === window }
        zOrderedWindows.removeAll { $0 === window }
    }

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
        layoutItem.image = menuIcon("square.grid.2x2")
        let submenu = NSMenu()

        let saveItem = NSMenuItem(
            title: L("layout.save_current"),
            action: #selector(saveLayoutFromMenu),
            keyEquivalent: ""
        )
        saveItem.target = self
        saveItem.tag = MenuItemTag.saveLayout.rawValue
        saveItem.isEnabled = !characterWindows.isEmpty
        saveItem.image = menuIcon("square.and.arrow.down")
        submenu.addItem(saveItem)

        let createItem = NSMenuItem(
            title: L("layout.create_new"),
            action: #selector(createNewLayoutFromMenu),
            keyEquivalent: ""
        )
        createItem.target = self
        createItem.tag = MenuItemTag.createLayout.rawValue
        createItem.image = menuIcon("plus.square")
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
            updateItem.image = menuIcon("arrow.triangle.2.circlepath")
            submenu.addItem(updateItem)

            let renameItem = buildLayoutPresetSubmenu(
                title: L("layout.rename"), tag: .renameLayout,
                action: #selector(renameLayoutFromMenu(_:)), presets: presets
            )
            renameItem.image = menuIcon("pencil")
            submenu.addItem(renameItem)

            let deleteItem = buildLayoutPresetSubmenu(
                title: L("layout.delete"), tag: .deleteLayout,
                action: #selector(deleteLayoutFromMenu(_:)), presets: presets
            )
            deleteItem.image = menuIcon("trash")
            submenu.addItem(deleteItem)
        }

        layoutItem.submenu = submenu
        return layoutItem
    }

    @objc func saveLayoutFromMenu() {
        let alert = AlertFactory.make(
            style: .informational,
            messageText: L("layout.save_title"),
            informativeText: L("layout.save_message"),
            buttonTitles: [L("layout.save_button"), L("quit.cancel")]
        )

        let textField = makeLayoutNameField(for: alert)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if LayoutPresetManager.shared.presetExists(named: name) {
            let overwriteAlert = AlertFactory.confirmation(
                messageText: L("layout.overwrite_title"),
                informativeText: String(format: L("layout.overwrite_message"), name),
                okTitle: L("layout.overwrite_button"),
                cancelTitle: L("quit.cancel")
            )
            guard overwriteAlert.runModal() == .alertFirstButtonReturn else { return }
        }

        let sortedWindows = Array(getZOrderedCharacterWindows().reversed())
        let states = sortedWindows.map { WindowStateManager.captureState(from: $0) }
        LayoutPresetManager.shared.savePreset(name: name, states: states)
    }

    @objc func createNewLayoutFromMenu() {
        let alert = AlertFactory.make(
            style: .informational,
            messageText: L("layout.create_title"),
            informativeText: L("layout.create_message"),
            buttonTitles: [L("layout.create_button"), L("quit.cancel")]
        )

        let textField = makeLayoutNameField(for: alert)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if LayoutPresetManager.shared.presetExists(named: name) {
            let overwriteAlert = AlertFactory.confirmation(
                messageText: L("layout.overwrite_title"),
                informativeText: String(format: L("layout.overwrite_message"), name),
                okTitle: L("layout.overwrite_button"),
                cancelTitle: L("quit.cancel")
            )
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

        let alert = AlertFactory.confirmation(
            messageText: L("layout.overwrite_title"),
            informativeText: String(format: L("layout.update_confirm_message"), name),
            okTitle: L("layout.overwrite_button"),
            cancelTitle: L("quit.cancel")
        )

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let sortedWindows = Array(getZOrderedCharacterWindows().reversed())
        let states = sortedWindows.map { WindowStateManager.captureState(from: $0) }
        LayoutPresetManager.shared.savePreset(name: name, states: states)
    }

    @objc func deleteLayoutFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }

        let alert = AlertFactory.confirmation(
            messageText: L("layout.delete_confirm_title"),
            informativeText: String(format: L("layout.delete_confirm_message"), name),
            okTitle: L("layout.delete_button"),
            cancelTitle: L("quit.cancel")
        )

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        LayoutPresetManager.shared.deletePreset(named: name)
    }

    @objc func renameLayoutFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }

        let alert = AlertFactory.make(
            style: .informational,
            messageText: L("layout.rename_title"),
            informativeText: L("layout.rename_message"),
            buttonTitles: [L("layout.rename_button"), L("quit.cancel")]
        )

        let textField = makeLayoutNameField(for: alert)
        textField.stringValue = name

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        guard newName != name else { return }

        if LayoutPresetManager.shared.presetExists(named: newName) {
            let overwriteAlert = AlertFactory.confirmation(
                messageText: L("layout.overwrite_title"),
                informativeText: String(format: L("layout.overwrite_message"), newName),
                okTitle: L("layout.overwrite_button"),
                cancelTitle: L("quit.cancel")
            )
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
        let textField = NSTextField(
            frame: NSRect(
                x: 0, y: 0,
                width: AppConstants.layoutDialogFieldWidth,
                height: AppConstants.layoutDialogFieldHeight
            )
        )
        textField.placeholderString = L("layout.name_placeholder")
        alert.accessoryView = textField
        return textField
    }

}
