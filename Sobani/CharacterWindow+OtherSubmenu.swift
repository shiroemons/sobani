import Cocoa

// MARK: - CharacterWindow + Other Submenu

extension CharacterWindow {
    func populateOtherSubmenu(_ otherSubmenu: NSMenu, names: [String]) {
        otherSubmenu.removeAllItems()

        let resetRotationItem = NSMenuItem(
            title: L("adjust.reset_rotation"), action: #selector(resetRotation), keyEquivalent: ""
        )
        resetRotationItem.target = self
        resetRotationItem.isEnabled = MenuStateUtils.isRotationResetEnabled(angle: imageView.rotationAngle)
        resetRotationItem.image = SFSymbolUtils.icon("arrow.counterclockwise")
        otherSubmenu.addItem(resetRotationItem)

        let resetOpacityItem = NSMenuItem(
            title: L("adjust.reset_opacity"), action: #selector(resetOpacity), keyEquivalent: ""
        )
        resetOpacityItem.target = self
        resetOpacityItem.isEnabled = MenuStateUtils.isOpacityResetEnabled(opacity: imageView.opacityLevel)
        resetOpacityItem.image = SFSymbolUtils.icon("circle.lefthalf.filled")
        otherSubmenu.addItem(resetOpacityItem)

        otherSubmenu.addItem(NSMenuItem.separator())

        let resetDisplayItem = NSMenuItem(
            title: L("adjust.reset_display"), action: #selector(resetDisplay), keyEquivalent: ""
        )
        resetDisplayItem.target = self
        resetDisplayItem.image = SFSymbolUtils.icon("arrow.counterclockwise.circle")
        otherSubmenu.addItem(resetDisplayItem)

        otherSubmenu.addItem(NSMenuItem.separator())

        let cropItem = NSMenuItem(
            title: L("menu.crop"), action: #selector(enterCropModeAction), keyEquivalent: ""
        )
        cropItem.tag = MenuItemTag.cropImage.rawValue
        cropItem.target = self
        cropItem.image = SFSymbolUtils.icon("crop")
        otherSubmenu.addItem(cropItem)

        let resetCropItem = NSMenuItem(
            title: L("menu.reset_crop"), action: #selector(resetCrop), keyEquivalent: ""
        )
        resetCropItem.tag = MenuItemTag.resetCrop.rawValue
        resetCropItem.target = self
        resetCropItem.isEnabled = imageView.cropRect != nil
        resetCropItem.image = SFSymbolUtils.icon("crop")
        otherSubmenu.addItem(resetCropItem)

        otherSubmenu.addItem(NSMenuItem.separator())

        let deleteRegisteredItem = NSMenuItem(title: L("image.delete_registered"), action: nil, keyEquivalent: "")
        deleteRegisteredItem.image = SFSymbolUtils.icon("trash")
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

        otherSubmenu.addItem(NSMenuItem.separator())

        let ghostItem = NSMenuItem(
            title: L("ghost.toggle"), action: #selector(toggleGhostMode), keyEquivalent: ""
        )
        ghostItem.tag = MenuItemTag.ghostModeToggle.rawValue
        ghostItem.target = self
        ghostItem.state = isGhostMode ? .on : .off
        ghostItem.image = SFSymbolUtils.icon("eye.slash.circle")
        otherSubmenu.addItem(ghostItem)
    }

}
