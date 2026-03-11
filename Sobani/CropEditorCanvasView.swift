import Cocoa

// MARK: - Crop Editor Canvas View

@MainActor
final class CropEditorCanvasView: NSView {

    // MARK: - Constants

    private static let padding: CGFloat = 20
    private static let handleLength: CGFloat = 20
    private static let handleThickness: CGFloat = 3
    private static let handleHitTolerance: CGFloat = 14
    private static let gridLineWidth: CGFloat = 0.5
    private static let overlayAlpha: CGFloat = 0.6
    private static let minCropProportion: CGFloat = 0.1
    private static let minZoom: CGFloat = 1.0
    private static let maxZoom: CGFloat = 10.0
    private static let zoomSensitivity: CGFloat = 0.02

    // MARK: - Handle Position

    enum HandlePosition: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    // MARK: - Drag State

    private enum DragState {
        case idle
        case movingImage
        case resizingHandle(HandlePosition)
    }

    // MARK: - Properties

    var cropRect: CropRect = .full {
        didSet { needsDisplay = true }
    }
    var onCropRectChanged: ((CropRect) -> Void)?
    private(set) var displayImage: NSImage?

    private var imageOffset: CGPoint = .zero
    private var imageZoom: CGFloat = 1.0
    private var dragState: DragState = .idle
    private var dragStartPoint: NSPoint = .zero
    private var dragStartCropRect: CropRect = .full
    private var dragStartImageOffset: CGPoint = .zero

    // MARK: - Setup

    func setImage(_ image: NSImage) {
        displayImage = image
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)

        let cropFrame = calculateCropFrameRect()
        guard cropFrame.width > 0, cropFrame.height > 0 else { return }

        let imgDrawRect = calculateImageDrawRect(cropFrame: cropFrame)

        // 画像がキャンバス領域外に描画されないようクリッピング
        context.saveGState()
        context.clip(to: bounds)
        drawTransformedImage(context: context, imageDrawRect: imgDrawRect)
        context.restoreGState()
        drawOverlay(context: context, cropFrame: cropFrame)
        drawCropBorder(context: context, cropFrame: cropFrame)
        drawGrid(context: context, cropFrame: cropFrame)
        drawHandles(context: context, cropFrame: cropFrame)
    }

    // MARK: - Coordinate Helpers

    func clamp(_ value: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minVal), maxVal)
    }

    func handleCornerPoint(for position: HandlePosition,
                           cropFrame: NSRect) -> NSPoint {
        switch position {
        case .topLeft: return NSPoint(x: cropFrame.minX, y: cropFrame.maxY)
        case .topRight: return NSPoint(x: cropFrame.maxX, y: cropFrame.maxY)
        case .bottomLeft: return NSPoint(x: cropFrame.minX, y: cropFrame.minY)
        case .bottomRight: return NSPoint(x: cropFrame.maxX, y: cropFrame.minY)
        case .top: return NSPoint(x: cropFrame.midX, y: cropFrame.maxY)
        case .bottom: return NSPoint(x: cropFrame.midX, y: cropFrame.minY)
        case .left: return NSPoint(x: cropFrame.minX, y: cropFrame.midY)
        case .right: return NSPoint(x: cropFrame.maxX, y: cropFrame.midY)
        }
    }

    // MARK: - Final Crop Rect

    /// 現在のズーム/オフセット状態から最終的な正規化 CropRect を計算
    func computeFinalCropRect() -> CropRect {
        let cropFrame = calculateCropFrameRect()
        let imgRect = calculateImageDrawRect(cropFrame: cropFrame)
        guard imgRect.width > 0, imgRect.height > 0 else { return cropRect }

        let normalized = CropGeometry.viewRectToNormalizedCrop(
            cropFrame: cropFrame, imageRect: imgRect
        )

        return CropRect(
            x: normalized.x, y: normalized.y,
            width: normalized.width, height: normalized.height,
            straightenAngle: cropRect.straightenAngle,
            quarterTurns: cropRect.quarterTurns,
            isFlippedInCrop: cropRect.isFlippedInCrop,
            aspectRatioPreset: cropRect.aspectRatioPreset
        )
    }

    // MARK: - State Initialization

    /// 既存の CropRect からズーム/オフセットの初期状態を復元する
    func initializeFromCropRect(_ rect: CropRect) {
        cropRect = rect
        let state = CropGeometry.initialStateFromCropRect(
            cropRect: rect,
            canvasSize: bounds.size,
            imageSize: displayImage?.size ?? CGSize(width: 1, height: 1)
        )
        imageZoom = clamp(state.zoom, min: Self.minZoom, max: Self.maxZoom)
        imageOffset = state.offset
        clampImageOffset()
        needsDisplay = true
    }

    /// ズーム/オフセットをリセットする
    func resetZoomAndOffset() {
        imageZoom = Self.minZoom
        imageOffset = .zero
        needsDisplay = true
    }
}

// MARK: - Crop Frame & Image Rect Calculation

extension CropEditorCanvasView {

    /// クロップ枠をキャンバス中央に配置
    private func calculateCropFrameRect() -> NSRect {
        guard let image = displayImage, image.size.width > 0, image.size.height > 0 else {
            return .zero
        }
        let imageSize = image.size
        let normalizedTurns = CropGeometry.normalizeQuarterTurns(cropRect.quarterTurns)
        let isSwapped = (normalizedTurns == 1 || normalizedTurns == 3)
        let effectiveWidth = isSwapped ? imageSize.height : imageSize.width
        let effectiveHeight = isSwapped ? imageSize.width : imageSize.height

        // クロップ領域のアスペクト比を計算
        let cropAspect = (cropRect.width * effectiveWidth)
            / max(cropRect.height * effectiveHeight, AppConstants.floatingPointTolerance)

        let availableRect = bounds.insetBy(dx: Self.padding, dy: Self.padding)
        guard availableRect.width > 0, availableRect.height > 0 else { return .zero }

        let frameWidth: CGFloat
        let frameHeight: CGFloat
        if cropAspect > availableRect.width / availableRect.height {
            frameWidth = availableRect.width
            frameHeight = frameWidth / cropAspect
        } else {
            frameHeight = availableRect.height
            frameWidth = frameHeight * cropAspect
        }

        return NSRect(
            x: availableRect.midX - frameWidth / 2,
            y: availableRect.midY - frameHeight / 2,
            width: frameWidth,
            height: frameHeight
        )
    }

    /// ズームとオフセットを考慮した画像の描画レクトを計算
    private func calculateImageDrawRect(cropFrame: NSRect) -> NSRect {
        guard let image = displayImage, image.size.width > 0, image.size.height > 0 else {
            return .zero
        }

        // zoom=1.0でクロップ枠にちょうど画像全体が収まるスケールを基準にする
        let baseWidth = cropFrame.width / max(cropRect.width, AppConstants.floatingPointTolerance)
        let baseHeight = cropFrame.height / max(cropRect.height, AppConstants.floatingPointTolerance)

        let drawWidth = baseWidth * imageZoom
        let drawHeight = baseHeight * imageZoom

        // 画像中心 = クロップ枠中心 + オフセット
        let centerX = cropFrame.midX + imageOffset.x
        let centerY = cropFrame.midY + imageOffset.y

        return NSRect(
            x: centerX - drawWidth / 2,
            y: centerY - drawHeight / 2,
            width: drawWidth,
            height: drawHeight
        )
    }

    private func clampImageOffset() {
        let cropFrame = calculateCropFrameRect()
        let imgRect = calculateImageDrawRect(cropFrame: cropFrame)
        imageOffset = CropGeometry.clampOffset(
            offset: imageOffset,
            imageSize: imgRect.size,
            cropFrameSize: cropFrame.size
        )
    }
}

// MARK: - Image Drawing

extension CropEditorCanvasView {

    /// すべての変換（quarterTurns、isFlippedInCrop、straightenAngle）を統合して描画
    private func drawTransformedImage(context: CGContext, imageDrawRect: NSRect) {
        guard let image = displayImage else { return }
        let normalizedTurns = CropGeometry.normalizeQuarterTurns(cropRect.quarterTurns)
        let angle = cropRect.straightenAngle
        let hasQuarterTurns = normalizedTurns != 0
        let hasStraighten = abs(angle) > AppConstants.floatingPointTolerance
        let hasFlip = cropRect.isFlippedInCrop

        guard hasQuarterTurns || hasStraighten || hasFlip else {
            image.draw(in: imageDrawRect)
            return
        }

        context.saveGState()
        let centerX = imageDrawRect.midX
        let centerY = imageDrawRect.midY
        context.translateBy(x: centerX, y: centerY)

        // 1. quarterTurns（90°単位の回転）
        if hasQuarterTurns {
            let quarterRadians = -CGFloat(normalizedTurns) * .pi / 2
            context.rotate(by: quarterRadians)
        }

        // 2. isFlippedInCrop（水平反転）
        if hasFlip {
            context.scaleBy(x: -1, y: 1)
        }

        // 3. straightenAngle（微調整回転のみ、自動ズームなし）
        if hasStraighten {
            context.rotate(by: -angle * .pi / 180)
        }

        // 描画矩形を決定
        // 90°/270° 回転時は元の画像を回転後の座標系で描くため、幅と高さを入れ替える
        let isSwapped = (normalizedTurns == 1 || normalizedTurns == 3)
        let drawRect: NSRect
        if isSwapped {
            drawRect = NSRect(
                x: -imageDrawRect.height / 2,
                y: -imageDrawRect.width / 2,
                width: imageDrawRect.height,
                height: imageDrawRect.width
            )
        } else {
            drawRect = NSRect(
                x: -imageDrawRect.width / 2,
                y: -imageDrawRect.height / 2,
                width: imageDrawRect.width,
                height: imageDrawRect.height
            )
        }

        image.draw(in: drawRect)
        context.restoreGState()
    }
}

// MARK: - Overlay & Grid Drawing

extension CropEditorCanvasView {

    private func drawOverlay(context: CGContext, cropFrame: NSRect) {
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(Self.overlayAlpha).cgColor)

        // bounds全体からクロップ枠を除外して塗る
        // 上
        context.fill(NSRect(x: bounds.minX, y: cropFrame.maxY,
                            width: bounds.width, height: bounds.maxY - cropFrame.maxY))
        // 下
        context.fill(NSRect(x: bounds.minX, y: bounds.minY,
                            width: bounds.width, height: cropFrame.minY - bounds.minY))
        // 左
        context.fill(NSRect(x: bounds.minX, y: cropFrame.minY,
                            width: cropFrame.minX - bounds.minX, height: cropFrame.height))
        // 右
        context.fill(NSRect(x: cropFrame.maxX, y: cropFrame.minY,
                            width: bounds.maxX - cropFrame.maxX, height: cropFrame.height))
        context.restoreGState()
    }

    private func drawCropBorder(context: CGContext, cropFrame: NSRect) {
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.0)
        context.stroke(cropFrame)
    }

    private func drawGrid(context: CGContext, cropFrame: NSRect) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(Self.gridLineWidth)

        for idx in 1...2 {
            let fraction = CGFloat(idx) / 3
            let lineX = cropFrame.minX + cropFrame.width * fraction
            context.move(to: CGPoint(x: lineX, y: cropFrame.minY))
            context.addLine(to: CGPoint(x: lineX, y: cropFrame.maxY))

            let lineY = cropFrame.minY + cropFrame.height * fraction
            context.move(to: CGPoint(x: cropFrame.minX, y: lineY))
            context.addLine(to: CGPoint(x: cropFrame.maxX, y: lineY))
        }
        context.strokePath()
    }
}

// MARK: - Handle Drawing

extension CropEditorCanvasView {

    private func drawHandles(context: CGContext, cropFrame: NSRect) {
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(Self.handleThickness)

        for position in HandlePosition.allCases {
            drawHandle(at: position, cropFrame: cropFrame, context: context)
        }
    }

    private func drawHandle(at position: HandlePosition,
                            cropFrame: NSRect,
                            context: CGContext) {
        let len = Self.handleLength
        let point = handleCornerPoint(for: position, cropFrame: cropFrame)

        switch position {
        case .topLeft:
            drawLHandle(context: context, corner: point,
                        end1: CGPoint(x: point.x, y: point.y - len),
                        end2: CGPoint(x: point.x + len, y: point.y))
        case .topRight:
            drawLHandle(context: context, corner: point,
                        end1: CGPoint(x: point.x - len, y: point.y),
                        end2: CGPoint(x: point.x, y: point.y - len))
        case .bottomLeft:
            drawLHandle(context: context, corner: point,
                        end1: CGPoint(x: point.x, y: point.y + len),
                        end2: CGPoint(x: point.x + len, y: point.y))
        case .bottomRight:
            drawLHandle(context: context, corner: point,
                        end1: CGPoint(x: point.x - len, y: point.y),
                        end2: CGPoint(x: point.x, y: point.y + len))
        case .top, .bottom:
            drawEdgeHandle(context: context, center: point,
                           horizontal: true, length: len)
        case .left, .right:
            drawEdgeHandle(context: context, center: point,
                           horizontal: false, length: len)
        }
    }

    private func drawLHandle(context: CGContext,
                             corner: NSPoint,
                             end1: CGPoint,
                             end2: CGPoint) {
        context.move(to: end1)
        context.addLine(to: CGPoint(x: corner.x, y: corner.y))
        context.addLine(to: end2)
        context.strokePath()
    }

    private func drawEdgeHandle(context: CGContext,
                                center: NSPoint,
                                horizontal: Bool,
                                length: CGFloat) {
        let halfLen = length / 2
        if horizontal {
            context.move(to: CGPoint(x: center.x - halfLen, y: center.y))
            context.addLine(to: CGPoint(x: center.x + halfLen, y: center.y))
        } else {
            context.move(to: CGPoint(x: center.x, y: center.y - halfLen))
            context.addLine(to: CGPoint(x: center.x, y: center.y + halfLen))
        }
        context.strokePath()
    }
}

// MARK: - Mouse Events & Resize

extension CropEditorCanvasView {

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStartPoint = point
        dragStartCropRect = cropRect
        dragStartImageOffset = imageOffset

        let cropFrame = calculateCropFrameRect()

        if let handlePosition = hitTestHandle(point: point, cropFrame: cropFrame) {
            dragState = .resizingHandle(handlePosition)
            return
        }

        // それ以外は画像移動
        dragState = .movingImage
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        switch dragState {
        case .idle:
            break
        case .movingImage:
            let deltaX = point.x - dragStartPoint.x
            let deltaY = point.y - dragStartPoint.y
            imageOffset = CGPoint(
                x: dragStartImageOffset.x + deltaX,
                y: dragStartImageOffset.y + deltaY
            )
            clampImageOffset()
            needsDisplay = true
        case .resizingHandle(let position):
            let cropFrame = calculateCropFrameRect()
            guard cropFrame.width > 0, cropFrame.height > 0 else { return }
            handleResize(position: position, currentPoint: point, cropFrame: cropFrame)
        }
    }

    override func mouseUp(with event: NSEvent) {
        dragState = .idle
    }

    override func scrollWheel(with event: NSEvent) {
        let zoomDelta = event.deltaY * Self.zoomSensitivity
        imageZoom = clamp(imageZoom + zoomDelta, min: Self.minZoom, max: Self.maxZoom)
        clampImageOffset()
        needsDisplay = true
    }

    private func hitTestHandle(point: NSPoint,
                               cropFrame: NSRect) -> HandlePosition? {
        for position in HandlePosition.allCases {
            let handlePoint = handleCornerPoint(for: position, cropFrame: cropFrame)
            let dist = hypot(point.x - handlePoint.x, point.y - handlePoint.y)
            if dist <= Self.handleHitTolerance {
                return position
            }
        }
        return nil
    }

    // MARK: - Handle Resize

    private func handleResize(position: HandlePosition,
                              currentPoint: NSPoint,
                              cropFrame: NSRect) {
        let deltaX = currentPoint.x - dragStartPoint.x
        let deltaY = currentPoint.y - dragStartPoint.y

        // ビュー座標のデルタをクロップ枠の比率に変換
        let normalizedDX = deltaX / cropFrame.width * dragStartCropRect.width
        let normalizedDY = deltaY / cropFrame.height * dragStartCropRect.height

        let start = dragStartCropRect
        let minSize = Self.minCropProportion
        var newW = start.width
        var newH = start.height

        // 水平方向のリサイズ
        switch position {
        case .topLeft, .left, .bottomLeft:
            newW = clamp(start.width - normalizedDX, min: minSize, max: 1.0)
        case .topRight, .right, .bottomRight:
            newW = clamp(start.width + normalizedDX, min: minSize, max: 1.0)
        case .top, .bottom:
            break
        }

        // 垂直方向のリサイズ
        switch position {
        case .bottomLeft, .bottom, .bottomRight:
            newH = clamp(start.height - normalizedDY, min: minSize, max: 1.0)
        case .topLeft, .top, .topRight:
            newH = clamp(start.height + normalizedDY, min: minSize, max: 1.0)
        case .left, .right:
            break
        }

        cropRect = CropRect(
            x: cropRect.x, y: cropRect.y,
            width: newW, height: newH,
            straightenAngle: cropRect.straightenAngle,
            quarterTurns: cropRect.quarterTurns,
            isFlippedInCrop: cropRect.isFlippedInCrop,
            aspectRatioPreset: cropRect.aspectRatioPreset
        )
        clampImageOffset()
        onCropRectChanged?(cropRect)
    }
}
