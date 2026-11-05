import Cocoa

@MainActor
final class ImagePreviewPanel {
    static let shared = ImagePreviewPanel()
    private let panel: NSPanel
    private let imageView: NSImageView
    /// 画像の周囲の余白
    nonisolated static let padding: CGFloat = 8
    private static let cornerRadius: CGFloat = 8

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    /// - Parameter createUI: false を指定するとパネル・画像ビュー生成をスキップする（テスト用）
    init(createUI: Bool = true) {
        if createUI {
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
            panel.configureForFloating()
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
        } else {
            panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: true
            )
            imageView = NSImageView()
        }
    }

    /// 表示中のメニューの横（入らなければ反対側）に画像のプレビューを出す。
    func show(image: NSImage) {
        let (panelSize, imageFrame) = Self.calculatePanelFrames(imageSize: image.size)

        imageView.image = image
        imageView.frame = imageFrame

        let panelOrigin = calculatePosition(panelSize: panelSize)

        panel.setFrame(
            NSRect(origin: panelOrigin, size: panelSize),
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
    nonisolated static func scaledSize(
        for imageSize: NSSize,
        maxDimension: CGFloat = AppConstants.previewMaxDimension) -> NSSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: maxDimension, height: maxDimension)
        }
        let scale = GeometryUtils.downscaleFactor(for: imageSize, maxDimension: maxDimension)
        guard scale < 1 else { return imageSize }
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
        let fallbackMaxY = screenFrame?.maxY ?? AppConstants.fallbackScreenHeight
        let maxY = (visibleFrame?.maxY ?? fallbackMaxY) - panelSize.height
        let clampedY = min(max(panelY, minY), maxY)

        return NSPoint(x: panelX, y: clampedY)
    }

    /// フォールバック位置を計算
    nonisolated static func fallbackPosition(
        mouseLocation: NSPoint,
        panelSize: NSSize,
        offset: CGFloat = AppConstants.previewFallbackMouseOffset
    ) -> NSPoint {
        return NSPoint(x: mouseLocation.x + offset, y: mouseLocation.y - panelSize.height / 2)
    }

    /// 画像サイズからパネルサイズと画像フレームを計算
    nonisolated static func calculatePanelFrames(
        imageSize: NSSize,
        maxDimension: CGFloat = AppConstants.previewMaxDimension,
        padding: CGFloat = padding
    ) -> (panelSize: NSSize, imageFrame: NSRect) {
        let previewSize = scaledSize(for: imageSize, maxDimension: maxDimension)
        let panelSize = NSSize(
            width: previewSize.width + padding * 2,
            height: previewSize.height + padding * 2
        )
        let imageFrame = NSRect(
            x: padding,
            y: padding,
            width: previewSize.width,
            height: previewSize.height
        )
        return (panelSize, imageFrame)
    }

    /// ウィンドウフレーム情報からメニューウィンドウをフィルタリング
    nonisolated static func filterMenuWindowFrames(
        frames: [(frame: NSRect, level: Int)],
        menuLevel: Int,
        minWidth: CGFloat = AppConstants.menuWindowMinWidth
    ) -> [NSRect] {
        return frames
            .filter { $0.level >= menuLevel && $0.frame.width > minWidth }
            .map { $0.frame }
    }

    /// メニューウィンドウフレーム群の境界
    /// （右端最大値と左端最小値）を計算
    nonisolated static func menuWindowBounds(frames: [NSRect])
        -> (rightmostX: CGFloat, leftmostX: CGFloat)? {
        guard let rightmostX = frames.map({ $0.maxX }).max(),
              let leftmostX = frames.map({ $0.minX }).min() else {
            return nil
        }
        return (rightmostX, leftmostX)
    }

    // MARK: - Private

    private func calculatePosition(panelSize: NSSize) -> NSPoint {
        let visibleWindows = NSApp.windows.filter { $0 !== panel && $0.isVisible }
        let menuFrames = Self.filterMenuWindowFrames(
            frames: visibleWindows.map { (frame: $0.frame, level: $0.level.rawValue) },
            menuLevel: Int(CGWindowLevelForKey(.popUpMenuWindow))
        )

        let mouseLocation = NSEvent.mouseLocation
        guard let bounds = Self.menuWindowBounds(frames: menuFrames) else {
            return Self.fallbackPosition(mouseLocation: mouseLocation, panelSize: panelSize)
        }

        let screen = NSScreen.screen(containingPoint: NSPoint(x: bounds.rightmostX, y: mouseLocation.y))
            ?? NSScreen.main

        return Self.calculatePanelPosition(
            rightmostX: bounds.rightmostX, leftmostX: bounds.leftmostX,
            mouseY: mouseLocation.y, panelSize: panelSize,
            screenFrame: screen?.frame, visibleFrame: screen?.visibleFrame
        )
    }
}

// MARK: - Shared Preview Helper

extension ImagePreviewPanel {
    /// メニュー項目に応じてプレビューを表示または
    /// 非表示にする共通ヘルパー。
    ///
    /// - Parameters:
    ///   - item: ハイライトされたメニュー項目（nilの場合は非表示）
    ///   - registeredImageActions: 登録済み画像名をプレビューするセレクター群
    ///   - defaultImageActions: デフォルト画像をプレビューするセレクター群
    func showPreviewIfApplicable(
        for item: NSMenuItem?,
        registeredImageActions: Set<Selector>,
        defaultImageActions: Set<Selector>
    ) {
        if let item = item,
           let name = item.representedObject as? String,
           let action = item.action,
           registeredImageActions.contains(action) {
            if let image = ImageManager.shared.loadRegisteredImageCached(named: name) {
                show(image: image)
            }
        } else if let item = item,
                  let action = item.action,
                  defaultImageActions.contains(action) {
            if let image = ImageManager.shared.defaultImage() {
                show(image: image)
            }
        } else {
            hide()
        }
    }
}
