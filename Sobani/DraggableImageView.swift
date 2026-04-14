import Cocoa
import os.log

// MARK: - Draggable Image View

@MainActor
final class DraggableImageView: NSImageView {
    private let logger = Logger(category: "DraggableImageView")

    var aspectRatio: CGFloat = 1.0
    let minHeight: CGFloat = AppConstants.minImageHeight
    let maxHeight: CGFloat = AppConstants.maxImageHeight
    private var initialMouseInWindow: NSPoint = .zero
    private var dragStartScreenLocation: NSPoint = .zero
    private var cachedAllWindows: [ImageWindow]?
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
    var onPositionChanged: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var cropRect: CropRect? {
        didSet { applyCrop() }
    }
    private(set) var originalImage: NSImage?
    var isCropModeActive: Bool = false
    var isAdjustmentPanelActive: Bool = false
    private var cachedAlphaMask: AlphaMask?
    private var alphaMaskBuildAttempted: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    weak var imageWindowDelegate: ImageWindowDelegate?

    private var allImageWindows: [ImageWindow] {
        imageWindowDelegate?.allImageWindows ?? []
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        if isCropModeActive { return }
        onMouseDown?()
        isDraggingAll = event.modifierFlags.contains(.option)
        isSnapEnabled = SnapSettings.isEnabled

        if isDraggingAll {
            guard let currentWindow = window else { return }
            dragStartScreenLocation = currentWindow.convertPoint(toScreen: event.locationInWindow)
            cachedAllWindows = allImageWindows
        } else if let currentWindow = window {
            initialMouseInWindow = event.locationInWindow
            let allWindows = allImageWindows
            cachedOtherWindowFrames = allWindows
                .filter { $0.window !== currentWindow }
                .map { $0.window.frame }
            cachedScreenFrames = NSScreen.screens.map { $0.visibleFrame }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isCropModeActive { return }

        if isDraggingAll, let currentWindow = window {
            let screenPoint = currentWindow.convertPoint(toScreen: event.locationInWindow)
            let deltaX = screenPoint.x - dragStartScreenLocation.x
            let deltaY = screenPoint.y - dragStartScreenLocation.y
            dragStartScreenLocation = screenPoint
            for imageWindow in cachedAllWindows ?? [] {
                var origin = imageWindow.window.frame.origin
                origin.x += deltaX
                origin.y += deltaY
                imageWindow.window.setFrameOrigin(origin)
            }
        } else if let currentWindow = window {
            let current = event.locationInWindow
            let deltaX = current.x - initialMouseInWindow.x
            let deltaY = current.y - initialMouseInWindow.y
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
        onPositionChanged?()
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingAll = false
        cachedAllWindows = nil
        cachedOtherWindowFrames = nil
        cachedScreenFrames = nil
        onPositionChanged?()
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
            let allWindows = allImageWindows
            for imageWindow in allWindows {
                resizeWindow(
                    imageWindow.window, imageView: imageWindow.imageView, scaleFactor: scaleFactor)
            }
        } else {
            guard let window = window else { return }
            resizeWindow(window, imageView: self, scaleFactor: scaleFactor)
        }
    }

    private func resizeWindow(
        _ window: NSWindow, imageView: DraggableImageView, scaleFactor: CGFloat) {
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
            size: NSSize(width: croppedCG.width, height: croppedCG.height))
        image = croppedImage
        if CGFloat(croppedCG.height) > 0 {
            aspectRatio = CGFloat(croppedCG.width) / CGFloat(croppedCG.height)
        }
        needsDisplay = true
        onSizeChanged?()
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

// MARK: - CGImage Extraction

extension DraggableImageView {
    /// NSImage から CGImage を安全に取得する
    /// cgImage(forProposedRect:) が nil を返す場合は
    /// NSBitmapImageRep に描画してフォールバック
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
            bytesPerRow: 0, bitsPerPixel: 0) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        nsImage.draw(
            in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
            from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        return bitmapRep.cgImage
    }
}

// MARK: - Hit Test Static Helpers

extension DraggableImageView {
    nonisolated static func displayRect(viewSize: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let displayWidth = imageSize.width * scale
        let displayHeight = imageSize.height * scale
        let originX = (viewSize.width - displayWidth) / 2
        let originY = (viewSize.height - displayHeight) / 2
        return CGRect(x: originX, y: originY, width: displayWidth, height: displayHeight)
    }

    nonisolated static func imagePointFromViewPoint(
        viewPoint: CGPoint,
        viewSize: CGSize,
        imageSize: CGSize,
        rotationDegrees: CGFloat,
        isFlipped: Bool
    ) -> CGPoint? {
        let transform = imageTransform(
            rotationDegrees: rotationDegrees,
            isFlipped: isFlipped,
            boundsWidth: viewSize.width,
            boundsHeight: viewSize.height
        )
        let invertedTransform = transform.inverted()
        let transformedPoint = viewPoint.applying(invertedTransform)

        guard transformedPoint.x >= 0, transformedPoint.x <= viewSize.width,
              transformedPoint.y >= 0, transformedPoint.y <= viewSize.height else { return nil }

        let rect = displayRect(viewSize: viewSize, imageSize: imageSize)
        guard rect.width > 0, rect.height > 0 else { return nil }
        guard rect.contains(transformedPoint) else { return nil }

        let imageX = (transformedPoint.x - rect.minX) * imageSize.width / rect.width
        let imageY = imageSize.height - (transformedPoint.y - rect.minY) * imageSize.height / rect.height
        return CGPoint(x: imageX, y: imageY)
    }

    nonisolated static func alphaMaskPixelIndex(
        imagePoint: CGPoint,
        imageSize: CGSize,
        mask: AlphaMask
    ) -> Int? {
        guard imagePoint.x >= 0, imagePoint.y >= 0 else { return nil }
        let pixelX = Int(imagePoint.x * CGFloat(mask.width) / imageSize.width)
        let pixelY = Int(imagePoint.y * CGFloat(mask.height) / imageSize.height)
        guard pixelX >= 0, pixelX < mask.width,
              pixelY >= 0, pixelY < mask.height else { return nil }
        return pixelY * mask.width + pixelX
    }

    nonisolated static func buildAlphaMask(from cgImage: CGImage) -> AlphaMask? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height)
        let success = bytes.withUnsafeMutableBytes { ptr -> Bool in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
                  )
            else { return false }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return success ? AlphaMask(width: width, height: height, bytes: bytes) : nil
    }
}

// MARK: - Alpha Mask Cache

extension DraggableImageView {
    override var image: NSImage? {
        get { super.image }
        set {
            guard super.image !== newValue else { return }
            super.image = newValue
            invalidateAlphaMask()
        }
    }

    private func invalidateAlphaMask() {
        cachedAlphaMask = nil
        alphaMaskBuildAttempted = false
    }

    func ensureAlphaMask() -> AlphaMask? {
        if alphaMaskBuildAttempted { return cachedAlphaMask }
        alphaMaskBuildAttempted = true
        guard let img = image, let cgImage = Self.extractCGImage(from: img) else { return nil }
        cachedAlphaMask = Self.buildAlphaMask(from: cgImage)
        return cachedAlphaMask
    }
}

// MARK: - Hit Test

extension DraggableImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        if isCropModeActive || isAdjustmentPanelActive { return super.hitTest(point) }
        guard let img = image, let superview = superview else { return super.hitTest(point) }
        let imageSize = img.size
        let localPoint = convert(point, from: superview)
        guard let mask = ensureAlphaMask() else { return super.hitTest(point) }
        guard let imagePoint = Self.imagePointFromViewPoint(
            viewPoint: localPoint,
            viewSize: bounds.size,
            imageSize: imageSize,
            rotationDegrees: rotationAngle,
            isFlipped: isFlippedHorizontally
        ) else { return nil }
        guard let idx = Self.alphaMaskPixelIndex(
            imagePoint: imagePoint,
            imageSize: imageSize,
            mask: mask
        ) else { return nil }
        return mask.bytes[idx] >= AppConstants.hitTestAlphaThreshold ? self : nil
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
        // NSImageView のデフォルト動作
        // （image プロパティの自動差し替え）を無効化
    }
}

// MARK: - Alpha Mask

struct AlphaMask {
    let width: Int
    let height: Int
    /// row-major, top-down (CGImage座標系)
    let bytes: [UInt8]
}
