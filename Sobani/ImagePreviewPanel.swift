import Cocoa
import os.log

final class ImagePreviewPanel {
    static let shared = ImagePreviewPanel()
    private let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "ImagePreviewPanel")
    private let panel: NSPanel
    private let imageView: NSImageView
    private static let maxDimension: CGFloat = 256
    private static let padding: CGFloat = 8
    private static let fallbackMouseOffset: CGFloat = 20

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 8
        contentView.layer?.masksToBounds = true
        panel.contentView = contentView

        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        contentView.addSubview(imageView)
    }

    func show(image: NSImage, relativeTo menuItem: NSMenuItem, ofMenu menu: NSMenu) {
        let previewSize = scaledSize(for: image)
        let totalWidth = previewSize.width + Self.padding * 2
        let totalHeight = previewSize.height + Self.padding * 2

        imageView.image = image
        imageView.frame = NSRect(
            x: Self.padding,
            y: Self.padding,
            width: previewSize.width,
            height: previewSize.height
        )

        let panelOrigin = calculatePosition(
            menuItem: menuItem,
            menu: menu,
            panelSize: NSSize(width: totalWidth, height: totalHeight)
        )

        panel.setFrame(
            NSRect(origin: panelOrigin, size: NSSize(width: totalWidth, height: totalHeight)),
            display: true
        )
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
        imageView.image = nil
    }

    var isVisible: Bool {
        return panel.isVisible
    }

    // MARK: - Private

    private func scaledSize(for image: NSImage) -> NSSize {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            return NSSize(width: Self.maxDimension, height: Self.maxDimension)
        }

        let maxSide = max(originalSize.width, originalSize.height)
        if maxSide <= Self.maxDimension {
            return originalSize
        }

        let scale = Self.maxDimension / maxSide
        return NSSize(
            width: round(originalSize.width * scale),
            height: round(originalSize.height * scale)
        )
    }

    private static let gap: CGFloat = 6

    private func calculatePosition(menuItem: NSMenuItem, menu: NSMenu, panelSize: NSSize) -> NSPoint {
        let menuWindows = Self.findMenuWindows(excluding: panel)

        guard !menuWindows.isEmpty else {
            return fallbackPosition(panelSize: panelSize)
        }

        // Find the bounding rect of all menu windows (parent + submenus)
        let rightmostX = menuWindows.map { $0.frame.maxX }.max() ?? 0
        let leftmostX = menuWindows.map { $0.frame.minX }.min() ?? 0

        // Vertical: center on mouse cursor
        let mouseY = NSEvent.mouseLocation.y
        let panelY = mouseY - panelSize.height / 2

        // Horizontal: place to the right of all menus
        var panelX = rightmostX + Self.gap

        // If off-screen to the right, place to the left of all menus
        let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: rightmostX, y: mouseY))
        }) ?? NSScreen.main
        if let screen = screen, panelX + panelSize.width > screen.frame.maxX {
            panelX = leftmostX - panelSize.width - Self.gap
        }

        // Clamp vertical position to screen bounds
        let minY = screen?.visibleFrame.minY ?? 0
        let maxY = (screen?.visibleFrame.maxY ?? NSScreen.main?.frame.maxY ?? AppConstants.fallbackScreenHeight) - panelSize.height
        let clampedY = min(max(panelY, minY), maxY)

        return NSPoint(x: panelX, y: clampedY)
    }

    private func fallbackPosition(panelSize: NSSize) -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        return NSPoint(x: mouseLocation.x + Self.fallbackMouseOffset, y: mouseLocation.y - panelSize.height / 2)
    }

    private static func findMenuWindows(excluding excludedPanel: NSPanel) -> [NSWindow] {
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return NSApp.windows.filter { window in
            window !== excludedPanel
                && window.isVisible
                && window.level.rawValue >= menuLevel
                && window.frame.width > AppConstants.menuWindowMinWidth
        }
    }
}
