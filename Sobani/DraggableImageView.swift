import Cocoa
import os.log

// MARK: - Draggable Image View

@MainActor
final class DraggableImageView: NSImageView {
    private let logger = Logger(category: "DraggableImageView")

    var aspectRatio: CGFloat = 1.0
    let minHeight: CGFloat = AppConstants.minImageHeight
    let maxHeight: CGFloat = AppConstants.maxImageHeight
    private var dragStartLocation: NSPoint = .zero
    private var isDraggingAll = false
    private var isSnapEnabled = false
    private var cachedOtherWindowFrames: [CGRect]?
    private var cachedScreenFrames: [CGRect]?
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
            if onOpacityChanged != nil {
                onOpacityChanged?()
            } else {
                alphaValue = opacityLevel
            }
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
    private(set) var originalImage: NSImage?
    var isCropModeActive: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    weak var characterWindowDelegate: CharacterWindowDelegate?

    private var allCharacterWindows: [CharacterWindow] {
        characterWindowDelegate?.allCharacterWindows ?? []
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        if isCropModeActive { return }
        onMouseDown?()
        isDraggingAll = event.modifierFlags.contains(.option)
        isSnapEnabled = UserDefaults.standard.bool(forKey: AppConstants.snapEnabledKey)
        dragStartLocation = NSEvent.mouseLocation

        if !isDraggingAll, let currentWindow = window {
            let allWindows = allCharacterWindows
            cachedOtherWindowFrames = allWindows
                .filter { $0.window !== currentWindow }
                .map { $0.window.frame }
            cachedScreenFrames = NSScreen.screens.map { $0.visibleFrame }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isCropModeActive { return }
        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - dragStartLocation.x
        let deltaY = currentLocation.y - dragStartLocation.y
        dragStartLocation = currentLocation

        if isDraggingAll {
            let allWindows = allCharacterWindows
            for charWindow in allWindows {
                var origin = charWindow.window.frame.origin
                origin.x += deltaX
                origin.y += deltaY
                charWindow.window.setFrameOrigin(origin)
            }
        } else if let currentWindow = window {
            var origin = currentWindow.frame.origin
            origin.x += deltaX
            origin.y += deltaY

            if isSnapEnabled {
                let proposedFrame = NSRect(origin: origin, size: currentWindow.frame.size)
                let otherFrames = cachedOtherWindowFrames ?? []
                let screenFrame = currentWindow.screen?.visibleFrame
                    ?? cachedScreenFrames?.first
                    ?? NSScreen.main?.visibleFrame
                    ?? NSRect(origin: .zero, size: AppConstants.fallbackScreenSize)
                let snap = SnapUtils.calculateSnap(
                    draggingFrame: proposedFrame,
                    otherFrames: otherFrames,
                    screenVisibleFrame: screenFrame
                )
                if !GeometryUtils.isApproximatelyZero(snap.deltaX) {
                    origin.x += snap.deltaX
                }
                if !GeometryUtils.isApproximatelyZero(snap.deltaY) {
                    origin.y += snap.deltaY
                }
            }

            currentWindow.setFrameOrigin(origin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        cachedOtherWindowFrames = nil
        cachedScreenFrames = nil
    }

    override func scrollWheel(with event: NSEvent) {
        if isCropModeActive { return }
        let delta = event.scrollingDeltaY
        if GeometryUtils.isApproximatelyZero(delta) { return }
        if let handler = scrollRotationHandler {
            handler(delta)
            return
        }
        let scaleFactor = Self.scaleFactor(fromScrollDelta: delta)
        if event.modifierFlags.contains(.option) {
            let allWindows = allCharacterWindows
            for charWindow in allWindows {
                resizeWindow(charWindow.window, imageView: charWindow.imageView, scaleFactor: scaleFactor)
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
                onSizeChanged?()
            }
            return
        }
        // Save original if not already saved
        if originalImage == nil {
            originalImage = image
        }
        guard let cgImage = Self.extractCGImage(from: original) else {
            logger.error("Failed to get CGImage from original image for crop")
            return
        }
        guard let croppedCG = CropImageProcessor.applyFullCrop(to: cgImage, cropRect: crop) else {
            logger.error("CropImageProcessor.applyFullCrop returned nil")
            return
        }
        let croppedImage = NSImage(
            cgImage: croppedCG,
            size: NSSize(width: croppedCG.width, height: croppedCG.height)
        )
        image = croppedImage
        if CGFloat(croppedCG.height) > 0 {
            aspectRatio = CGFloat(croppedCG.width) / CGFloat(croppedCG.height)
        }
        needsDisplay = true
        onSizeChanged?()
    }

    /// NSImage から CGImage を安全に取得する
    /// cgImage(forProposedRect:) が nil を返す場合は NSBitmapImageRep に描画してフォールバック
    nonisolated static func extractCGImage(from nsImage: NSImage) -> CGImage? {
        // 高速パス: 埋め込みCGImageを直接取得
        if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }

        // 低速パス: NSBitmapImageRep に描画して向きを正規化
        // ピクセル寸法を使用（Retina対応）
        let pixelWidth: Int
        let pixelHeight: Int
        if let rep = nsImage.bestRepresentation(for: .infinite, context: nil, hints: nil),
           rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            pixelWidth = rep.pixelsWide
            pixelHeight = rep.pixelsHigh
        } else {
            pixelWidth = Int(nsImage.size.width)
            pixelHeight = Int(nsImage.size.height)
        }
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth, pixelsHigh: pixelHeight,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        nsImage.draw(
            in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
            from: .zero, operation: .copy, fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        return bitmapRep.cgImage
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

        if !GeometryUtils.isApproximatelyZero(rotationDegrees) {
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
