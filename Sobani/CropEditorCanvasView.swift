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

    // MARK: - Handle Position

    enum HandlePosition: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    // MARK: - Drag State

    private enum DragState {
        case idle
        case movingRect
        case resizingHandle(HandlePosition)
    }

    // MARK: - Properties

    var cropRect: CropRect = .full {
        didSet { needsDisplay = true }
    }
    var onCropRectChanged: ((CropRect) -> Void)?
    private(set) var displayImage: NSImage?
    private(set) var imageRect: NSRect = .zero
    private var dragState: DragState = .idle
    private var dragStartPoint: NSPoint = .zero
    private var dragStartCropRect: CropRect = .full

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

        drawImage(context: context)
        drawOverlay(context: context)
        drawCropBorder(context: context)
        drawGrid(context: context)
        drawHandles(context: context)
    }

    // MARK: - Coordinate Helpers

    func cropRectInViewCoords() -> NSRect {
        NSRect(
            x: imageRect.origin.x + cropRect.x * imageRect.width,
            y: imageRect.origin.y + cropRect.y * imageRect.height,
            width: cropRect.width * imageRect.width,
            height: cropRect.height * imageRect.height
        )
    }

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
}

// MARK: - Image Drawing

extension CropEditorCanvasView {

    private func drawImage(context: CGContext) {
        guard let image = displayImage else { return }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        calculateImageRect(imageSize: imageSize)
        drawTransformedImage(image, context: context)
    }

    private func calculateImageRect(imageSize: NSSize) {
        let availableRect = bounds.insetBy(dx: Self.padding, dy: Self.padding)
        let normalizedTurns = CropGeometry.normalizeQuarterTurns(cropRect.quarterTurns)
        let isQuarterTurnSwapped = (normalizedTurns == 1 || normalizedTurns == 3)

        // quarterTurns が 1 or 3 の場合、画像の幅と高さが入れ替わる
        let effectiveWidth = isQuarterTurnSwapped ? imageSize.height : imageSize.width
        let effectiveHeight = isQuarterTurnSwapped ? imageSize.width : imageSize.height

        let scale = min(
            availableRect.width / effectiveWidth,
            availableRect.height / effectiveHeight
        )
        let drawWidth = effectiveWidth * scale
        let drawHeight = effectiveHeight * scale
        imageRect = NSRect(
            x: availableRect.midX - drawWidth / 2,
            y: availableRect.midY - drawHeight / 2,
            width: drawWidth,
            height: drawHeight
        )
    }

    /// すべての変換（quarterTurns、isFlippedInCrop、straightenAngle）を統合して描画
    private func drawTransformedImage(_ image: NSImage, context: CGContext) {
        let normalizedTurns = CropGeometry.normalizeQuarterTurns(cropRect.quarterTurns)
        let angle = cropRect.straightenAngle
        let hasQuarterTurns = normalizedTurns != 0
        let hasStraighten = abs(angle) > AppConstants.floatingPointTolerance
        let hasFlip = cropRect.isFlippedInCrop

        // 変換が不要な場合はそのまま描画
        guard hasQuarterTurns || hasStraighten || hasFlip else {
            image.draw(in: imageRect)
            return
        }

        context.saveGState()
        let centerX = imageRect.midX
        let centerY = imageRect.midY
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

        // 3. straightenAngle（微調整回転 + 自動ズーム）
        if hasStraighten {
            let aspectRatio = imageRect.width / max(imageRect.height, 1)
            let zoomScale = CropGeometry.zoomScaleForStraighten(
                angleDegrees: angle, aspectRatio: aspectRatio
            )
            context.rotate(by: -angle * .pi / 180)
            context.scaleBy(x: zoomScale, y: zoomScale)
        }

        // 描画矩形を決定
        // imageRect は回転後の見た目に合わせたサイズ（effectiveWidth/Height ベース）
        // 90°/270° 回転時は元の画像を回転後の座標系で描くため、
        // 描画矩形の幅と高さを入れ替える必要がある
        let isSwapped = (normalizedTurns == 1 || normalizedTurns == 3)
        let drawRect: NSRect
        if isSwapped {
            drawRect = NSRect(
                x: -imageRect.height / 2,
                y: -imageRect.width / 2,
                width: imageRect.height,
                height: imageRect.width
            )
        } else {
            drawRect = NSRect(
                x: -imageRect.width / 2,
                y: -imageRect.height / 2,
                width: imageRect.width,
                height: imageRect.height
            )
        }

        image.draw(in: drawRect)
        context.restoreGState()
    }
}

// MARK: - Overlay & Grid Drawing

extension CropEditorCanvasView {

    private func drawOverlay(context: CGContext) {
        let cropFrame = cropRectInViewCoords()
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(Self.overlayAlpha).cgColor)

        let imgRect = imageRect
        // 上
        context.fill(NSRect(x: imgRect.minX, y: cropFrame.maxY,
                            width: imgRect.width, height: imgRect.maxY - cropFrame.maxY))
        // 下
        context.fill(NSRect(x: imgRect.minX, y: imgRect.minY,
                            width: imgRect.width, height: cropFrame.minY - imgRect.minY))
        // 左
        context.fill(NSRect(x: imgRect.minX, y: cropFrame.minY,
                            width: cropFrame.minX - imgRect.minX, height: cropFrame.height))
        // 右
        context.fill(NSRect(x: cropFrame.maxX, y: cropFrame.minY,
                            width: imgRect.maxX - cropFrame.maxX, height: cropFrame.height))
        context.restoreGState()
    }

    private func drawCropBorder(context: CGContext) {
        let cropFrame = cropRectInViewCoords()
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.0)
        context.stroke(cropFrame)
    }

    private func drawGrid(context: CGContext) {
        let cropFrame = cropRectInViewCoords()
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

    private func drawHandles(context: CGContext) {
        let cropFrame = cropRectInViewCoords()
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

        let cropFrame = cropRectInViewCoords()

        if let handlePosition = hitTestHandle(point: point, cropFrame: cropFrame) {
            dragState = .resizingHandle(handlePosition)
            return
        }

        if cropFrame.contains(point) {
            dragState = .movingRect
            return
        }

        dragState = .idle
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard imageRect.width > 0, imageRect.height > 0 else { return }

        let deltaX = point.x - dragStartPoint.x
        let deltaY = point.y - dragStartPoint.y
        let normalizedDX = deltaX / imageRect.width
        let normalizedDY = deltaY / imageRect.height

        switch dragState {
        case .idle:
            break
        case .movingRect:
            handleMoveRect(normalizedDX: normalizedDX, normalizedDY: normalizedDY)
        case .resizingHandle(let position):
            cropRect = resizedCropRect(for: position,
                                       normalizedDX: normalizedDX,
                                       normalizedDY: normalizedDY)
            onCropRectChanged?(cropRect)
        }
    }

    override func mouseUp(with event: NSEvent) {
        dragState = .idle
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

    private func handleMoveRect(normalizedDX: CGFloat, normalizedDY: CGFloat) {
        let newX = clamp(dragStartCropRect.x + normalizedDX,
                         min: 0, max: 1 - dragStartCropRect.width)
        let newY = clamp(dragStartCropRect.y + normalizedDY,
                         min: 0, max: 1 - dragStartCropRect.height)
        cropRect = CropRect(
            x: newX, y: newY,
            width: dragStartCropRect.width, height: dragStartCropRect.height,
            straightenAngle: cropRect.straightenAngle,
            quarterTurns: cropRect.quarterTurns,
            isFlippedInCrop: cropRect.isFlippedInCrop,
            aspectRatioPreset: cropRect.aspectRatioPreset
        )
        onCropRectChanged?(cropRect)
    }

    private func resizedCropRect(
        for position: HandlePosition,
        normalizedDX: CGFloat,
        normalizedDY: CGFloat
    ) -> CropRect {
        let start = dragStartCropRect
        let minSize = Self.minCropProportion
        var newX = start.x
        var newY = start.y
        var newW = start.width
        var newH = start.height

        applyHorizontalResize(position: position, delta: normalizedDX,
                              start: start, minSize: minSize, outX: &newX, outW: &newW)
        applyVerticalResize(position: position, delta: normalizedDY,
                            start: start, minSize: minSize, outY: &newY, outH: &newH)

        newW = max(newW, minSize)
        newH = max(newH, minSize)
        newX = clamp(newX, min: 0, max: 1 - newW)
        newY = clamp(newY, min: 0, max: 1 - newH)

        return CropRect(
            x: newX, y: newY, width: newW, height: newH,
            straightenAngle: cropRect.straightenAngle,
            quarterTurns: cropRect.quarterTurns,
            isFlippedInCrop: cropRect.isFlippedInCrop,
            aspectRatioPreset: cropRect.aspectRatioPreset
        )
    }

    // swiftlint:disable function_parameter_count
    private func applyHorizontalResize(position: HandlePosition,
                                       delta: CGFloat,
                                       start: CropRect,
                                       minSize: CGFloat,
                                       outX: inout CGFloat,
                                       outW: inout CGFloat) {
        switch position {
        case .topLeft, .left, .bottomLeft:
            let maxDX = start.width - minSize
            let clampedDX = clamp(delta, min: -start.x, max: maxDX)
            outX = start.x + clampedDX
            outW = start.width - clampedDX
        case .topRight, .right, .bottomRight:
            let maxExpand = 1 - start.x - start.width
            let clampedDX = clamp(delta, min: -(start.width - minSize), max: maxExpand)
            outW = start.width + clampedDX
        case .top, .bottom:
            break
        }
    }

    private func applyVerticalResize(position: HandlePosition,
                                     delta: CGFloat,
                                     start: CropRect,
                                     minSize: CGFloat,
                                     outY: inout CGFloat,
                                     outH: inout CGFloat) {
        switch position {
        case .bottomLeft, .bottom, .bottomRight:
            let maxDY = start.height - minSize
            let clampedDY = clamp(delta, min: -start.y, max: maxDY)
            outY = start.y + clampedDY
            outH = start.height - clampedDY
        case .topLeft, .top, .topRight:
            let maxExpand = 1 - start.y - start.height
            let clampedDY = clamp(delta, min: -(start.height - minSize), max: maxExpand)
            outH = start.height + clampedDY
        case .left, .right:
            break
        }
    }
    // swiftlint:enable function_parameter_count
}
