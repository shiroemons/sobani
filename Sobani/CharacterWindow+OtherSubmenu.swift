import Cocoa

// MARK: - CharacterWindow + Other Submenu

extension CharacterWindow {
    func populateOtherSubmenu(_ otherSubmenu: NSMenu, names: [String]) {
        otherSubmenu.removeAllItems()

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: AppConstants.menuIconPointSize, weight: .regular)

        let resetRotationItem = NSMenuItem(
            title: L("adjust.reset_rotation"), action: #selector(resetRotation), keyEquivalent: ""
        )
        resetRotationItem.target = self
        resetRotationItem.isEnabled = abs(imageView.rotationAngle) > AppConstants.floatingPointTolerance
        resetRotationItem.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        otherSubmenu.addItem(resetRotationItem)

        let resetOpacityItem = NSMenuItem(
            title: L("adjust.reset_opacity"), action: #selector(resetOpacity), keyEquivalent: ""
        )
        resetOpacityItem.target = self
        resetOpacityItem.isEnabled = abs(imageView.opacityLevel - 1.0) > AppConstants.floatingPointTolerance
        resetOpacityItem.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        otherSubmenu.addItem(resetOpacityItem)

        otherSubmenu.addItem(NSMenuItem.separator())

        let resetDisplayItem = NSMenuItem(
            title: L("adjust.reset_display"), action: #selector(resetDisplay), keyEquivalent: ""
        )
        resetDisplayItem.target = self
        resetDisplayItem.image = NSImage(systemSymbolName: "arrow.counterclockwise.circle", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        otherSubmenu.addItem(resetDisplayItem)

        otherSubmenu.addItem(NSMenuItem.separator())

        let cropItem = NSMenuItem(
            title: L("menu.crop"), action: #selector(enterCropModeAction), keyEquivalent: ""
        )
        cropItem.tag = MenuItemTag.cropImage.rawValue
        cropItem.target = self
        cropItem.image = NSImage(systemSymbolName: "crop", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        otherSubmenu.addItem(cropItem)

        let resetCropItem = NSMenuItem(
            title: L("menu.reset_crop"), action: #selector(resetCrop), keyEquivalent: ""
        )
        resetCropItem.tag = MenuItemTag.resetCrop.rawValue
        resetCropItem.target = self
        resetCropItem.isEnabled = imageView.cropRect != nil
        resetCropItem.image = NSImage(systemSymbolName: "crop", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        otherSubmenu.addItem(resetCropItem)

        otherSubmenu.addItem(NSMenuItem.separator())

        let deleteRegisteredItem = NSMenuItem(title: L("image.delete_registered"), action: nil, keyEquivalent: "")
        deleteRegisteredItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig)
        let deleteSubmenu = NSMenu()
        deleteSubmenu.delegate = self
        for name in names {
            let item = NSMenuItem(title: name, action: #selector(deleteRegisteredImage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            deleteSubmenu.addItem(item)
        }
        deleteRegisteredItem.submenu = deleteSubmenu
        deleteRegisteredItem.isEnabled = !names.isEmpty
        otherSubmenu.addItem(deleteRegisteredItem)
    }

}
