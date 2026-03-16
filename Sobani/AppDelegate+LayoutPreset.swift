import Cocoa
import os.log

private let layoutPresetLogger = Logger(category: "LayoutPreset")

// MARK: - AppDelegate + Layout Preset

extension AppDelegate {
    // MARK: - Window Array Management

    func addCharacterWindow(_ window: CharacterWindow) {
        zOrderedWindows.insert(window, at: 0)
        notifyWindowListDidChange()
    }

    func removeCharacterWindow(_ window: CharacterWindow) {
        zOrderedWindows.removeAll { $0 === window }
        notifyWindowListDidChange()
    }

    func closeCharacterWindow(_ window: CharacterWindow) {
        window.window.orderOut(nil)
        removeCharacterWindow(window)
        quitIfNoWindows()
    }

    func reorderWindows(from sourceIndices: IndexSet, to destination: Int) {
        zOrderedWindows.move(fromOffsets: sourceIndices, toOffset: destination)
        applyZOrderToWindows()
    }

    /// Z-order（背面→前面）順でウィンドウ状態をキャプチャする
    func captureCurrentWindowStates() -> [WindowState] {
        Array(zOrderedWindows.reversed()).map { WindowStateManager.captureState(from: $0) }
    }

    func applyLayout(_ preset: LayoutPreset) {
        isApplyingLayout = true
        areWindowsHidden = false

        for charWindow in zOrderedWindows {
            charWindow.window.orderOut(nil)
        }
        zOrderedWindows.removeAll()

        var loadedWindows: [CharacterWindow] = []
        for state in preset.states {
            let charWindow = createCharacterWindow(from: state, windowId: nextWindowId)
            nextWindowId += 1
            charWindow.restore(from: state)
            loadedWindows.append(charWindow)
        }

        zOrderedWindows = loadedWindows.reversed()

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
        saveItem.isEnabled = !zOrderedWindows.isEmpty
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
            updateItem.isEnabled = !zOrderedWindows.isEmpty
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
        guard let name = promptLayoutName(
            messageText: L("layout.save_title"),
            informativeText: L("layout.save_message"),
            okTitle: L("layout.save_button")
        ) else { return }

        let states = captureCurrentWindowStates()
        LayoutPresetManager.shared.savePreset(name: name, states: states)
    }

    @objc func createNewLayoutFromMenu() {
        guard let name = promptLayoutName(
            messageText: L("layout.create_title"),
            informativeText: L("layout.create_message"),
            okTitle: L("layout.create_button")
        ) else { return }

        createNewLayout(name: name)
    }

    func createNewLayout(name: String) {
        let mainFrame = NSScreen.mainFrameOrFallback
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
        let states = captureCurrentWindowStates()
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

        guard let newName = promptLayoutName(
            messageText: L("layout.rename_title"),
            informativeText: L("layout.rename_message"),
            okTitle: L("layout.rename_button"),
            initialValue: name,
            checkOverwrite: false
        ) else { return }
        guard newName != name else { return }
        guard confirmOverwriteIfNeeded(name: newName) else { return }

        if !LayoutPresetManager.shared.renamePreset(from: name, to: newName) {
            layoutPresetLogger.warning("renamePreset failed: '\(name, privacy: .public)' -> '\(newName, privacy: .public)'")
        }
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

    /// レイアウト名を入力させるアラートを表示し、有効な名前を返す。
    /// - Parameters:
    ///   - messageText: アラートのタイトル
    ///   - informativeText: アラートの説明文
    ///   - okTitle: OKボタンのラベル
    ///   - initialValue: テキストフィールドの初期値（デフォルト: 空文字）
    ///   - checkOverwrite: 既存プリセットへの上書き確認を行うか（デフォルト: true）
    /// - Returns: トリム済みの名前。キャンセル・空文字・上書きキャンセル時は nil
    private func promptLayoutName(
        messageText: String,
        informativeText: String,
        okTitle: String,
        initialValue: String = "",
        checkOverwrite: Bool = true
    ) -> String? {
        let alert = AlertFactory.make(
            style: .informational,
            messageText: messageText,
            informativeText: informativeText,
            buttonTitles: [okTitle, L("quit.cancel")]
        )
        let textField = makeLayoutNameField(for: alert)
        if !initialValue.isEmpty {
            textField.stringValue = initialValue
        }
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if checkOverwrite {
            guard confirmOverwriteIfNeeded(name: name) else { return nil }
        }
        return name
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

    /// 指定された名前のプリセットが既に存在する場合、上書き確認ダイアログを表示する。
    /// - Returns: 上書きOK（または存在しない）の場合は true、キャンセルの場合は false
    private func confirmOverwriteIfNeeded(name: String) -> Bool {
        guard LayoutPresetManager.shared.presetExists(named: name) else { return true }
        let overwriteAlert = AlertFactory.confirmation(
            messageText: L("layout.overwrite_title"),
            informativeText: String(format: L("layout.overwrite_message"), name),
            okTitle: L("layout.overwrite_button"),
            cancelTitle: L("quit.cancel")
        )
        return overwriteAlert.runModal() == .alertFirstButtonReturn
    }

}
