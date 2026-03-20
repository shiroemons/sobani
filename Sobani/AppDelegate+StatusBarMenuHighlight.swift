import Cocoa

// MARK: - Menu Highlight

extension AppDelegate {
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
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
}
