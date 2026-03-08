import Cocoa
import os.log

@MainActor
final class ImagePreviewPanel {
    static let shared = ImagePreviewPanel()
    private let logger = Logger(subsystem: "com.shiroemons.Sobani", category: "ImagePreviewPanel")
    private let panel: NSPanel
    private let imageView: NSImageView
    private static let padding: CGFloat = 8
    private static let cornerRadius: CGFloat = 8

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
        contentView.layer?.cornerRadius = Self.cornerRadius
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

    // MARK: - Testable Static Methods

    /// 画像サイズを最大寸法に収まるようスケーリング
    nonisolated static func scaledSize(for imageSize: NSSize, maxDimension: CGFloat = AppConstants.previewMaxDimension) -> NSSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: maxDimension, height: maxDimension)
        }

        let maxSide = max(imageSize.width, imageSize.height)
        if maxSide <= maxDimension {
            return imageSize
        }

        let scale = maxDimension / maxSide
        return NSSize(
            width: round(imageSize.width * scale),
            height: round(imageSize.height * scale)
        )
    }

    /// プレビューパネルの表示位置を計算
    nonisolated static func calculatePanelPosition( // swiftlint:disable:this function_parameter_count
        rightmostX: CGFloat, leftmostX: CGFloat,
        mouseY: CGFloat, panelSize: NSSize,
        screenFrame: NSRect?, visibleFrame: NSRect?,
        gap: CGFloat = AppConstants.previewGap
    ) -> NSPoint {
        // Vertical: center on mouse cursor
        let panelY = mouseY - panelSize.height / 2

        // Horizontal: place to the right of all menus
        var panelX = rightmostX + gap

        // If off-screen to the right, place to the left of all menus
        if let screenFrame = screenFrame, panelX + panelSize.width > screenFrame.maxX {
            panelX = leftmostX - panelSize.width - gap
        }

        // Clamp vertical position to screen bounds
        let minY = visibleFrame?.minY ?? 0
        let maxY = (visibleFrame?.maxY ?? screenFrame?.maxY ?? AppConstants.fallbackScreenHeight) - panelSize.height
        let clampedY = min(max(panelY, minY), maxY)

        return NSPoint(x: panelX, y: clampedY)
    }

    /// フォールバック位置を計算
    nonisolated static func fallbackPosition(
        mouseLocation: NSPoint, panelSize: NSSize, offset: CGFloat = AppConstants.previewFallbackMouseOffset
    ) -> NSPoint {
        return NSPoint(x: mouseLocation.x + offset, y: mouseLocation.y - panelSize.height / 2)
    }

    // MARK: - Private

    private func scaledSize(for image: NSImage) -> NSSize {
        return Self.scaledSize(for: image.size)
    }

    private func calculatePosition(menuItem: NSMenuItem, menu: NSMenu, panelSize: NSSize) -> NSPoint {
        let menuWindows = Self.findMenuWindows(excluding: panel)

        guard !menuWindows.isEmpty else {
            let mouseLocation = NSEvent.mouseLocation
            return Self.fallbackPosition(mouseLocation: mouseLocation, panelSize: panelSize)
        }

        // Find the bounding rect of all menu windows (parent + submenus)
        let rightmostX = menuWindows.map { $0.frame.maxX }.max() ?? 0
        let leftmostX = menuWindows.map { $0.frame.minX }.min() ?? 0

        let mouseY = NSEvent.mouseLocation.y

        let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: rightmostX, y: mouseY))
        }) ?? NSScreen.main

        return Self.calculatePanelPosition(
            rightmostX: rightmostX, leftmostX: leftmostX,
            mouseY: mouseY, panelSize: panelSize,
            screenFrame: screen?.frame, visibleFrame: screen?.visibleFrame
        )
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
