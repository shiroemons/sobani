import Cocoa

// MARK: - Draggable Image View

@MainActor
final class DraggableImageView: NSImageView {
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
    var onDoubleClick: (() -> Void)?
    var cropRect: CropRect? {
        didSet { applyCrop() }
    }
    private var originalImage: NSImage?
    var isCropModeActive: Bool = false

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
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        if isCropModeActive { return }
        onMouseDown?()
        isDraggingAll = event.modifierFlags.contains(.option)
        dragStartLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        if isCropModeActive { return }
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
        if isCropModeActive { return }
        let delta = event.scrollingDeltaY
        if abs(delta) < AppConstants.floatingPointTolerance { return }
        if let handler = scrollRotationHandler {
            handler(delta)
            return
        }
        let scaleFactor = Self.scaleFactor(fromScrollDelta: delta)
        if event.modifierFlags.contains(.option) {
            let allWindows = allCharacterWindows
            for targetWindow in allWindows {
                guard let targetImageView = targetWindow.contentView?.subviews.first as? Self else { continue }
                resizeWindow(targetWindow, imageView: targetImageView, scaleFactor: scaleFactor)
            }
        } else {
            guard let window = window else { return }
            resizeWindow(window, imageView: self, scaleFactor: scaleFactor)
        }
    }

    private func resizeWindow(_ window: NSWindow, imageView: DraggableImageView, scaleFactor: CGFloat) {
        let frames = Self.calculateResizedFrames(
            currentHeight: imageView.frame.height,
            scaleFactor: scaleFactor,
            aspectRatio: imageView.aspectRatio,
            rotationAngle: imageView.rotationAngle,
            windowCenter: CGPoint(x: window.frame.midX, y: window.frame.midY)
        )
        window.setFrame(frames.windowFrame, display: true)
        imageView.frame = frames.imageViewFrame
        onSizeChanged?()
    }

    override func layout() {
        super.layout()
        let transform = Self.imageTransform(
            rotationDegrees: rotationAngle,
            isFlipped: isFlippedHorizontally,
            boundsWidth: bounds.width,
            boundsHeight: bounds.height
        )
        layer?.setAffineTransform(transform)
    }

    // MARK: - Crop Support

    private func applyCrop() {
        guard let crop = cropRect, let original = originalImage ?? image else {
            // If cropRect is nil, restore original image
            if let original = originalImage {
                image = original
                originalImage = nil
            }
            return
        }
        // Save original if not already saved
        if originalImage == nil {
            originalImage = image
        }
        guard let cgImage = original.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let imgWidth = CGFloat(cgImage.width)
        let imgHeight = CGFloat(cgImage.height)
        let cropX = crop.x * imgWidth
        let cropY = crop.y * imgHeight
        let cropW = crop.width * imgWidth
        let cropH = crop.height * imgHeight
        let cropCGRect = CGRect(x: cropX, y: imgHeight - cropY - cropH, width: cropW, height: cropH)
        guard cropW > 0, cropH > 0, let croppedCG = cgImage.cropping(to: cropCGRect) else { return }
        let croppedImage = NSImage(cgImage: croppedCG, size: NSSize(width: cropW, height: cropH))
        image = croppedImage
        // Update aspect ratio
        if cropH > 0 {
            aspectRatio = cropW / cropH
        }
    }

    func setOriginalImage(_ newImage: NSImage) {
        originalImage = newImage
        if cropRect != nil {
            applyCrop()
        } else {
            image = newImage
        }
    }

    func resetCrop() {
        cropRect = nil
    }

    // MARK: - Testable Static Methods

    /// スクロールデルタからスケールファクターを計算
    nonisolated static func scaleFactor(fromScrollDelta delta: CGFloat) -> CGFloat {
        return 1.0 + (delta * AppConstants.scrollScaleSensitivity)
    }

    /// リサイズ時のウィンドウフレームと画像ビューフレームを計算
    nonisolated static func calculateResizedFrames(
        currentHeight: CGFloat, scaleFactor: CGFloat, aspectRatio: CGFloat,
        rotationAngle: CGFloat, windowCenter: CGPoint,
        minHeight: CGFloat = AppConstants.minImageHeight,
        maxHeight: CGFloat = AppConstants.maxImageHeight
    ) -> (windowFrame: NSRect, imageViewFrame: NSRect) {
        var newHeight = currentHeight * scaleFactor
        newHeight = max(minHeight, min(maxHeight, newHeight))
        let newWidth = newHeight * aspectRatio

        let boundingBox = GeometryUtils.rotatedBoundingBox(
            width: newWidth, height: newHeight, angleDegrees: rotationAngle
        )
        let bbWidth = boundingBox.width
        let bbHeight = boundingBox.height

        let windowFrame = NSRect(
            x: round(windowCenter.x - bbWidth / 2),
            y: round(windowCenter.y - bbHeight / 2),
            width: round(bbWidth),
            height: round(bbHeight)
        )
        let imageViewFrame = NSRect(
            x: (bbWidth - newWidth) / 2,
            y: (bbHeight - newHeight) / 2,
            width: newWidth,
            height: newHeight
        )
        return (windowFrame, imageViewFrame)
    }

    /// 回転・反転のアフィン変換を計算
    nonisolated static func imageTransform(
        rotationDegrees: CGFloat, isFlipped: Bool,
        boundsWidth: CGFloat, boundsHeight: CGFloat
    ) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        let centerX = boundsWidth / 2
        let centerY = boundsHeight / 2

        if abs(rotationDegrees) > AppConstants.floatingPointTolerance {
            let radians = -rotationDegrees * .pi / 180
            transform = transform
                .translatedBy(x: centerX, y: centerY)
                .rotated(by: radians)
                .translatedBy(x: -centerX, y: -centerY)
        }

        if isFlipped {
            let flip = CGAffineTransform.identity
                .translatedBy(x: centerX, y: centerY)
                .scaledBy(x: -1, y: 1)
                .translatedBy(x: -centerX, y: -centerY)
            transform = transform.concatenating(flip)
        }

        return transform
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
