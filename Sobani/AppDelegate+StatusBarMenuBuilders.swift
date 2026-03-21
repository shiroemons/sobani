import Cocoa

// MARK: - Status Bar Menu Builder Helpers

extension AppDelegate {
    func buildWindowControlMenuItems(into menu: NSMenu, ghostCount: Int) {
        let toggleTitle = areWindowsHidden ? L("window.show_all") : L("window.hide_all")
        let toggleItem = NSMenuItem(
            title: toggleTitle,
            action: #selector(toggleAllWindowsVisibility),
            keyEquivalent: "h"
        )
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        toggleItem.isEnabled = !zOrderedWindows.isEmpty
        toggleItem.image = menuIcon(
            areWindowsHidden ? AppConstants.visibleWindowSymbol : AppConstants.hiddenWindowSymbol
        )
        menu.addItem(toggleItem)

        let bringFrontItem = NSMenuItem(
            title: L("window.bring_to_front"),
            action: #selector(bringAllToFront),
            keyEquivalent: "f"
        )
        bringFrontItem.target = self
        bringFrontItem.image = menuIcon("square.3.layers.3d.top.filled")
        menu.addItem(bringFrontItem)

        menu.addItem(buildLayoutMenuItem())

        menu.addItem(NSMenuItem.separator())

        menu.addItem(buildBulkResetMenuItem(ghostCount: ghostCount))

        let closeAllItem = NSMenuItem(
            title: L("menu.close_all"),
            action: #selector(closeAllWindows),
            keyEquivalent: ""
        )
        closeAllItem.target = self
        closeAllItem.image = menuIcon(AppConstants.closeSymbol)
        menu.addItem(closeAllItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(buildSettingsMenuItem())

        let managementItem = NSMenuItem(
            title: L("management.title"),
            action: #selector(showManagementPanel),
            keyEquivalent: "m"
        )
        managementItem.keyEquivalentModifierMask = [.option]
        managementItem.target = self
        managementItem.tag = MenuItemTag.managementPanel.rawValue
        managementItem.image = menuIcon("macwindow.on.rectangle")
        menu.addItem(managementItem)

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
        let quitItem = NSMenuItem(
            title: L("menu.quit"),
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        quitItem.image = menuIcon("power")
        menu.addItem(quitItem)

        let quitWithoutSavingItem = NSMenuItem(
            title: L("menu.quit_without_saving"),
            action: #selector(quitWithoutSavingFromMenu),
            keyEquivalent: "q"
        )
        quitWithoutSavingItem.keyEquivalentModifierMask = [.command, .option]
        quitWithoutSavingItem.isAlternate = true
        quitWithoutSavingItem.target = self
        quitWithoutSavingItem.image = menuIcon("power")
        menu.addItem(quitWithoutSavingItem)
    }

    func buildAdjustmentMenuItems(
        into submenu: NSMenu,
        for imageWindow: ImageWindow,
        windowNumber: Int
    ) {
        let adjustItem = NSMenuItem(
            title: L("adjust.open"),
            action: #selector(showAdjustmentPanelByWindowNumber(_:)),
            keyEquivalent: ""
        )
        adjustItem.target = self
        adjustItem.tag = windowNumber
        adjustItem.isEnabled = !areWindowsHidden && !imageWindow.isHidden
        adjustItem.image = menuIcon("slider.horizontal.3")
        submenu.addItem(adjustItem)

        let resetRotationItem = NSMenuItem(
            title: L("adjust.reset_rotation"),
            action: #selector(resetRotationByWindowNumber(_:)),
            keyEquivalent: ""
        )
        resetRotationItem.target = self
        resetRotationItem.tag = windowNumber
        resetRotationItem.isEnabled = MenuStateUtils.isRotationResetEnabled(
            angle: imageWindow.imageView.rotationAngle
        )
        resetRotationItem.image = menuIcon("arrow.counterclockwise")
        submenu.addItem(resetRotationItem)

        let resetOpacityItem = NSMenuItem(
            title: L("adjust.reset_opacity"),
            action: #selector(resetOpacityByWindowNumber(_:)),
            keyEquivalent: ""
        )
        resetOpacityItem.target = self
        resetOpacityItem.tag = windowNumber
        resetOpacityItem.isEnabled = MenuStateUtils.isOpacityResetEnabled(
            opacity: imageWindow.imageView.opacityLevel
        )
        resetOpacityItem.image = menuIcon(AppConstants.opacitySymbol)
        submenu.addItem(resetOpacityItem)

        submenu.addItem(NSMenuItem.separator())

        let resetDisplayItem = NSMenuItem(
            title: L("adjust.reset_display"),
            action: #selector(resetDisplayByWindowNumber(_:)),
            keyEquivalent: ""
        )
        resetDisplayItem.target = self
        resetDisplayItem.tag = windowNumber
        resetDisplayItem.image = menuIcon(AppConstants.resetSymbol)
        submenu.addItem(resetDisplayItem)
    }
}
