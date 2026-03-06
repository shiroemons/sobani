import Cocoa

// MARK: - Draggable Image View

class DraggableImageView: NSImageView {
    var aspectRatio: CGFloat = 1.0
    let minHeight: CGFloat = AppConstants.minImageHeight
    let maxHeight: CGFloat = AppConstants.maxImageHeight
    private var dragStartLocation: NSPoint = .zero
    private var isDraggingAll = false
    var isFlippedHorizontally: Bool = false {
        didSet { needsLayout = true }
    }
    var rotationAngle: CGFloat = 0 {
        didSet {
            needsLayout = true
            onRotationChanged?()
        }
    }
    var onRotationChanged: (() -> Void)?
    var opacityLevel: CGFloat = 1.0 {
        didSet {
            alphaValue = opacityLevel
            onOpacityChanged?()
        }
    }
    var onOpacityChanged: (() -> Void)?
    var scrollRotationHandler: ((CGFloat) -> Void)?
    var onMouseDown: (() -> Void)?
    var onDropImage: ((URL, Bool) -> Void)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onSizeChanged: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    private var allCharacterWindows: [NSWindow] {
        NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.borderless) }
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        isDraggingAll = event.modifierFlags.contains(.option)
        dragStartLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - dragStartLocation.x
        let deltaY = currentLocation.y - dragStartLocation.y
        dragStartLocation = currentLocation
        let windows = isDraggingAll ? allCharacterWindows : (window.map { [$0] } ?? [])
        for targetWindow in windows {
            var origin = targetWindow.frame.origin
            origin.x += deltaX
            origin.y += deltaY
            targetWindow.setFrameOrigin(origin)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        if delta == 0 { return }
        if let handler = scrollRotationHandler {
            handler(delta)
            return
        }
        let scaleFactor: CGFloat = 1.0 + (delta * AppConstants.scrollScaleSensitivity)
        if event.modifierFlags.contains(.option) {
            let allWindows = allCharacterWindows
            for targetWindow in allWindows {
                guard let targetImageView = targetWindow.contentView?.subviews.first as? DraggableImageView else { continue }
                resizeWindow(targetWindow, imageView: targetImageView, scaleFactor: scaleFactor)
            }
        } else {
            guard let window = window else { return }
            resizeWindow(window, imageView: self, scaleFactor: scaleFactor)
        }
    }

    private func resizeWindow(_ window: NSWindow, imageView: DraggableImageView, scaleFactor: CGFloat) {
        let currentHeight = imageView.frame.height
        var newHeight = currentHeight * scaleFactor
        newHeight = max(minHeight, min(maxHeight, newHeight))
        let newWidth = newHeight * imageView.aspectRatio

        let boundingBox = GeometryUtils.rotatedBoundingBox(
            width: newWidth, height: newHeight, angleDegrees: imageView.rotationAngle
        )
        let bbWidth = boundingBox.width
        let bbHeight = boundingBox.height

        let centerX = window.frame.midX
        let centerY = window.frame.midY
        window.setFrame(NSRect(
            x: round(centerX - bbWidth / 2),
            y: round(centerY - bbHeight / 2),
            width: round(bbWidth),
            height: round(bbHeight)
        ), display: true)

        imageView.frame = NSRect(
            x: (bbWidth - newWidth) / 2,
            y: (bbHeight - newHeight) / 2,
            width: newWidth,
            height: newHeight
        )
        onSizeChanged?()
    }

    override func layout() {
        super.layout()
        var transform = CGAffineTransform.identity
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2

        if abs(rotationAngle) > AppConstants.floatingPointTolerance {
            let radians = -rotationAngle * .pi / 180
            transform = transform
                .translatedBy(x: centerX, y: centerY)
                .rotated(by: radians)
                .translatedBy(x: -centerX, y: -centerY)
        }

        if isFlippedHorizontally {
            let flip = CGAffineTransform.identity
                .translatedBy(x: centerX, y: centerY)
                .scaledBy(x: -1, y: 1)
                .translatedBy(x: -centerX, y: -centerY)
            transform = transform.concatenating(flip)
        }

        layer?.setAffineTransform(transform)
    }
}

// MARK: - NSDraggingDestination

extension DraggableImageView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = DragDropUtils.extractImageURLs(from: sender)
        guard !urls.isEmpty else { return [] }
        onDragEntered?()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDragExited?()
        let urls = DragDropUtils.extractImageURLs(from: sender)
        guard let url = urls.first else { return false }
        let isOption = NSEvent.modifierFlags.contains(.option)
        onDropImage?(url, isOption)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        // NSImageView のデフォルト動作（image プロパティの自動差し替え）を無効化
    }
}
