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
    /// ドラッグ開始時の各ウィンドウの原点。mouseUp で実際に動いたウィンドウだけ位置変更を通知する。
    private var dragStartOrigins: [(imageView: DraggableImageView, origin: NSPoint)] = []
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
    private(set) var originalImage: NSImage? {
        didSet { cachedSourceHasAlpha = nil }
    }
    var isCropModeActive: Bool = false
    var isAdjustmentPanelActive: Bool = false
    private var cachedAlphaMask: AlphaMask?
    private var alphaMaskBuildAttempted: Bool = false
    private var cachedSourceHasAlpha: Bool?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    weak var imageWindowDelegate: ImageWindowDelegate?

    /// 一括ドラッグ・一括リサイズ・スナップの対象にする、表示中のウィンドウ
    private var visibleImageWindows: [ImageWindow] {
        (imageWindowDelegate?.allImageWindows ?? []).filter { !$0.isHidden }
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
            let targets = visibleImageWindows
            cachedAllWindows = targets
            dragStartOrigins = targets.map { ($0.imageView, $0.window.frame.origin) }
        } else if let currentWindow = window {
            initialMouseInWindow = event.locationInWindow
            cachedOtherWindowFrames = visibleImageWindows
                .filter { $0.window !== currentWindow }
                .map { $0.window.frame }
            cachedScreenFrames = NSScreen.screens.map { $0.visibleFrame }
            dragStartOrigins = [(self, currentWindow.frame.origin)]
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
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingAll = false
        cachedAllWindows = nil
        cachedOtherWindowFrames = nil
        cachedScreenFrames = nil
        // クリックだけで動いていないウィンドウには位置変更を通知しない
        let movedViews = dragStartOrigins.filter { target in
            guard let currentOrigin = target.imageView.window?.frame.origin else { return false }
            return Self.hasMoved(from: target.origin, to: currentOrigin)
        }
        dragStartOrigins = []
        for target in movedViews {
            target.imageView.onPositionChanged?()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if isCropModeActive { return }
        let delta = event.scrollingDeltaY
        if GeometryUtils.isApproximatelyZero(delta) { return }
        if let handler = scrollRotationHandler {
            handler(delta)
            return
        }
        let scaleFactor = Self.scaleFactor(fromScrollDelta: delta, isPrecise: event.hasPreciseScrollingDeltas)
        if event.modifierFlags.contains(.option) {
            for imageWindow in visibleImageWindows {
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
        // 丸めたウィンドウ中心ではなく画像の中心を基準にする（繰り返すと位置がずれていくため）
        let frames = Self.calculateResizedFrames(
            currentHeight: imageView.frame.height,
            scaleFactor: scaleFactor,
            aspectRatio: imageView.aspectRatio,
            rotationAngle: imageView.rotationAngle,
            imageCenter: CGPoint(
                x: window.frame.minX + imageView.frame.midX,
                y: window.frame.minY + imageView.frame.midY
            )
        )
        window.setFrame(frames.windowFrame, display: true)
        imageView.frame = frames.imageViewFrame
        imageView.onSizeChanged?()
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
            // cropRect が nil なら元画像と元の縦横比に戻す
            if let original = originalImage {
                image = original
                originalImage = nil
                if original.size.height > 0 {
                    aspectRatio = original.size.width / original.size.height
                }
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

    /// 表示する画像そのものを差し替える（画像変更・ドロップ・デフォルトに戻す等）。
    ///
    /// 旧画像に対するクロップ範囲と元画像は新しい画像とは無関係なので破棄する。
    /// `originalImage` を先に消すことで、`cropRect = nil` で旧画像が復元されないようにする。
    func replaceImage(_ newImage: NSImage) {
        originalImage = nil
        cropRect = nil
        image = newImage
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

    /// ドラッグの前後でウィンドウ原点が動いたか
    nonisolated static func hasMoved(from start: NSPoint, to end: NSPoint) -> Bool {
        !GeometryUtils.isApproximatelyEqual(start.x, end.x) || !GeometryUtils.isApproximatelyEqual(start.y, end.y)
    }

    /// 非精密スクロール（マウスホイール）の 1 行あたりの点数。NSScrollView の既定の行スクロール量に合わせる。
    nonisolated private static let scrollLineHeight: CGFloat = 10

    /// スクロールデルタからスケールファクターを計算する。
    ///
    /// 指数関数にすることで +δ と −δ の拡大縮小が打ち消し合い（往復しても大きさがずれない）、
    /// 大きな負のデルタでも倍率が 0 以下にならない。非精密スクロールのデルタは行単位のため点に換算する。
    nonisolated static func scaleFactor(fromScrollDelta delta: CGFloat, isPrecise: Bool = true) -> CGFloat {
        let points = isPrecise ? delta : delta * scrollLineHeight
        return exp(points * AppConstants.scrollScaleSensitivity)
    }

    /// リサイズ時のウィンドウフレームと画像ビューフレームを計算する（画像の中心を固定）
    nonisolated static func calculateResizedFrames(
        currentHeight: CGFloat, scaleFactor: CGFloat, aspectRatio: CGFloat,
        rotationAngle: CGFloat, imageCenter: CGPoint,
        minHeight: CGFloat = AppConstants.minImageHeight,
        maxHeight: CGFloat = AppConstants.maxImageHeight
    ) -> (windowFrame: NSRect, imageViewFrame: NSRect) {
        let newSize = ImageWindow.clampedImageSize(
            height: currentHeight * scaleFactor, aspectRatio: aspectRatio,
            minHeight: minHeight, maxHeight: maxHeight
        )
        return ImageWindow.anchoredFrames(imageCenter: imageCenter, imageSize: newSize, rotationAngle: rotationAngle)
    }

    /// 回転・反転のアフィン変換を計算する（中心基準）。
    ///
    /// 先に左右反転し、その後に回転する。反転の有無にかかわらず、見た目の傾きは
    /// ダイアルに表示される角度（時計回り `rotationDegrees` 度）と一致する。
    nonisolated static func imageTransform(
        rotationDegrees: CGFloat, isFlipped: Bool,
        boundsWidth: CGFloat, boundsHeight: CGFloat
    ) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        let centerX = boundsWidth / 2
        let centerY = boundsHeight / 2

        if isFlipped {
            transform = CGAffineTransform.identity
                .translatedBy(x: centerX, y: centerY)
                .scaledBy(x: -1, y: 1)
                .translatedBy(x: -centerX, y: -centerY)
        }

        if !GeometryUtils.isApproximatelyZero(rotationDegrees) {
            let radians = -rotationDegrees * .pi / 180
            let rotation = CGAffineTransform.identity
                .translatedBy(x: centerX, y: centerY)
                .rotated(by: radians)
                .translatedBy(x: -centerX, y: -centerY)
            // CGAffineTransform は行ベクトル規約のため、a.concatenating(b) は「a の後に b」を適用する
            transform = transform.concatenating(rotation)
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

    /// アルファマスクの長辺の上限（ピクセル）。ヒットテストは比率で参照するため、縮小しても判定位置はずれない。
    nonisolated static let alphaMaskMaxDimension = 2048

    /// 長辺を `maxDimension` 以下に縮小したマスクのサイズ（縦横比を保ち、各辺 1 以上）
    nonisolated static func alphaMaskSize(width: Int, height: Int, maxDimension: Int) -> (width: Int, height: Int) {
        let longSide = max(width, height)
        guard longSide > maxDimension, maxDimension > 0 else { return (width, height) }
        let scale = Double(maxDimension) / Double(longSide)
        return (
            max(1, Int((Double(width) * scale).rounded())),
            max(1, Int((Double(height) * scale).rounded()))
        )
    }

    /// 画像のアルファ値だけを取り出したマスクを作る。大きな画像は長辺 `maxDimension` に縮小する。
    nonisolated static func buildAlphaMask(
        from cgImage: CGImage, maxDimension: Int = alphaMaskMaxDimension
    ) -> AlphaMask? {
        guard cgImage.width > 0, cgImage.height > 0 else { return nil }
        let (width, height) = alphaMaskSize(width: cgImage.width, height: cgImage.height, maxDimension: maxDimension)
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

    /// 表示画像が変わったら（クロップの適用・解除を含む）マスクと透過判定のキャッシュを破棄する。
    private func invalidateAlphaMask() {
        cachedAlphaMask = nil
        alphaMaskBuildAttempted = false
        cachedSourceHasAlpha = nil
    }

    func ensureAlphaMask() -> AlphaMask? {
        if alphaMaskBuildAttempted { return cachedAlphaMask }
        alphaMaskBuildAttempted = true
        guard let img = image, let cgImage = Self.extractCGImage(from: img) else { return nil }
        cachedAlphaMask = Self.buildAlphaMask(from: cgImage)
        return cachedAlphaMask
    }

    /// 元画像（クロップ前）が透過ピクセルを含むか。背景除去の可否判定に使う。
    ///
    /// 円形などのクロップは表示画像に透過を作るため、表示画像ではなく元画像で判定する。
    /// クロップしていなければヒットテスト用のマスクを流用する。
    func sourceImageHasAlpha() -> Bool {
        if let cached = cachedSourceHasAlpha { return cached }
        let result = computeSourceImageHasAlpha()
        cachedSourceHasAlpha = result
        return result
    }

    private func computeSourceImageHasAlpha() -> Bool {
        guard let source = originalImage ?? image,
              let cgImage = Self.extractCGImage(from: source),
              ImageWindow.isAlphaInfoTransparent(cgImage.alphaInfo) else { return false }
        let mask = originalImage == nil ? ensureAlphaMask() : Self.buildAlphaMask(from: cgImage)
        return mask?.bytes.contains { $0 < UInt8.max } ?? false
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
