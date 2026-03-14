import Cocoa
import QuartzCore

// MARK: - Crop Editor Canvas View

@MainActor
final class CropEditorCanvasView: NSView {

    // MARK: - Constants

    private static let handleHitTolerance: CGFloat = 14
    private static let minZoom: CGFloat = 1.0
    private static let maxZoom: CGFloat = 10.0
    private static let zoomSensitivity: CGFloat = 0.02
    private static let perspectiveDepth: CGFloat = -1.0 / 500.0

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
        case adjustingCornerRadius(CropGeometry.Corner)
    }

    // MARK: - Properties

    var cropRect: CropRect = .full {
        didSet {
            guard cropRect != oldValue else { return }
            needsDisplay = true
        }
    }
    var onCropRectChanged: ((CropRect) -> Void)?
    var onDragEnded: (() -> Void)?
    private(set) var displayImage: NSImage?

    private var imageOffset: CGPoint = .zero
    private var imageZoom: CGFloat = 1.0
    private var dragState: DragState = .idle
    private var dragStartPoint: NSPoint = .zero
    private var dragStartCropRect: CropRect = .full
    private var dragStartImageOffset: CGPoint = .zero
    private var dragStartCropFrame: NSRect = .zero
    private var activeDragCropFrame: NSRect?
    private var dragStartImageDrawRect: NSRect = .zero

    var cropShape: CropShape { cropRect.shape }
    var cornerRadii: CornerRadii { cropRect.cornerRadii }
    var cornersLinked: Bool { cropRect.cornersLinked }

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

        let cropFrame: NSRect
        let imgDrawRect: NSRect
        if let activeDrag = activeDragCropFrame {
            cropFrame = activeDrag
            imgDrawRect = dragStartImageDrawRect
        } else {
            cropFrame = calculateCropFrameRect()
            imgDrawRect = calculateImageDrawRect(cropFrame: cropFrame)
        }
        guard cropFrame.width > 0, cropFrame.height > 0 else { return }

        // 形状パスを一度だけ計算
        let shapePath: CGPath?
        switch cropShape {
        case .rectangle:
            shapePath = nil
        case .circle:
            let path = CGMutablePath()
            path.addEllipse(in: cropFrame)
            shapePath = path
        case .roundedRectangle:
            let shorterSide = min(cropFrame.width, cropFrame.height)
            shapePath = CropGeometry.roundedRectPath(rect: cropFrame, radii: cornerRadii, shorterSide: shorterSide)
        }

        // 画像がキャンバス領域外に描画されないようクリッピング
        context.saveGState()
        context.clip(to: bounds)
        drawTransformedImage(context: context, imageDrawRect: imgDrawRect)
        context.restoreGState()
        drawOverlay(context: context, cropFrame: cropFrame, shapePath: shapePath)
        drawCropBorder(context: context, cropFrame: cropFrame, shapePath: shapePath)
        drawGrid(context: context, cropFrame: cropFrame)
        drawHandles(context: context, cropFrame: cropFrame)
        if cropShape == .roundedRectangle {
            drawCornerRadiusHandles(context: context, cropFrame: cropFrame)
        }
    }

    // MARK: - Coordinate Helpers

    private func handleCornerPoint(for position: HandlePosition,
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

        return cropRect.with(
            x: normalized.x, y: normalized.y,
            width: normalized.width, height: normalized.height
        )
    }

    // MARK: - State Initialization

    /// 既存の CropRect からズーム/オフセットの初期状態を復元する
    func initializeFromCropRect(_ rect: CropRect) {
        cropRect = rect
        imageZoom = Self.minZoom
        recalculateImageOffset()
        needsDisplay = true
    }

    /// cropRect変更後に imageOffset を再計算（ズームは維持）
    private func recalculateImageOffset() {
        let cropFrame = calculateCropFrameRect()
        guard cropFrame.width > 0, cropFrame.height > 0,
              cropRect.width > AppConstants.floatingPointTolerance,
              cropRect.height > AppConstants.floatingPointTolerance else {
            imageOffset = .zero
            return
        }
        let baseWidth = cropFrame.width / cropRect.width
        let baseHeight = cropFrame.height / cropRect.height
        let offsetX = baseWidth * (0.5 - cropRect.x) - cropFrame.width / 2
        let offsetY = baseHeight * (0.5 - cropRect.y) - cropFrame.height / 2
        imageOffset = CGPoint(x: offsetX, y: offsetY)
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

        let availableRect = bounds.insetBy(dx: AppConstants.cropEditorCanvasPadding, dy: AppConstants.cropEditorCanvasPadding)
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

}

// MARK: - Image Drawing

extension CropEditorCanvasView {

    /// すべての変換（quarterTurns、isFlippedInCrop、straightenAngle、perspective）を統合して描画
    private func drawTransformedImage(context: CGContext, imageDrawRect: NSRect) {
        guard let image = displayImage else { return }
        let normalizedTurns = CropGeometry.normalizeQuarterTurns(cropRect.quarterTurns)
        let angle = cropRect.straightenAngle
        let hasQuarterTurns = normalizedTurns != 0
        let hasStraighten = !GeometryUtils.isApproximatelyZero(angle)
        let hasFlip = cropRect.isFlippedInCrop
        let hasVertPerspective = !GeometryUtils.isApproximatelyZero(cropRect.verticalPerspective)
        let hasHorizPerspective = !GeometryUtils.isApproximatelyZero(cropRect.horizontalPerspective)

        guard hasQuarterTurns || hasStraighten || hasFlip || hasVertPerspective || hasHorizPerspective else {
            image.draw(in: imageDrawRect)
            return
        }

        context.saveGState()
        let centerX = imageDrawRect.midX
        let centerY = imageDrawRect.midY
        context.translateBy(x: centerX, y: centerY)

        // 1. quarterTurns（90°単位の回転）
        if hasQuarterTurns {
            let quarterRadians = CGFloat(normalizedTurns) * .pi / 2
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

        // 4. verticalPerspective（垂直方向パース補正）
        if hasVertPerspective {
            let perspAngle = cropRect.verticalPerspective * .pi / 180
            var transform = CATransform3DIdentity
            transform.m34 = Self.perspectiveDepth
            transform = CATransform3DRotate(transform, perspAngle, 1, 0, 0)  // rotate around X axis
            let affine = perspectiveToAffine(transform)
            context.concatenate(affine)
        }

        // 5. horizontalPerspective（水平方向パース補正）
        if hasHorizPerspective {
            let perspAngle = cropRect.horizontalPerspective * .pi / 180
            var transform = CATransform3DIdentity
            transform.m34 = Self.perspectiveDepth
            transform = CATransform3DRotate(transform, perspAngle, 0, 1, 0)  // rotate around Y axis
            let affine = perspectiveToAffine(transform)
            context.concatenate(affine)
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

    /// CATransform3Dの2Dアフィン近似変換を計算する
    private func perspectiveToAffine(_ transform: CATransform3D) -> CGAffineTransform {
        // CATransform3Dから2Dアフィン変換への簡易的な射影
        // m34がパース深度、m11/m12/m21/m22が回転成分
        return CGAffineTransform(
            a: transform.m11, b: transform.m12,
            c: transform.m21, d: transform.m22,
            tx: 0, ty: 0
        )
    }
}

// MARK: - Overlay & Grid Drawing

extension CropEditorCanvasView {

    private func drawOverlay(context: CGContext, cropFrame: NSRect, shapePath: CGPath?) {
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(AppConstants.cropEditorOverlayAlpha).cgColor)

        switch cropShape {
        case .rectangle:
            // 既存: bounds全体からクロップ枠を除外して塗る
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

        case .circle, .roundedRectangle:
            // Even-Odd: bounds全体 - 形状 → 外側のみ塗る
            if let path = shapePath {
                let outerPath = CGMutablePath()
                outerPath.addRect(bounds)
                outerPath.addPath(path)
                context.addPath(outerPath)
                context.fillPath(using: .evenOdd)
            }
        }
        context.restoreGState()
    }

    private func drawCropBorder(context: CGContext, cropFrame: NSRect, shapePath: CGPath?) {
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.0)

        switch cropShape {
        case .rectangle:
            context.stroke(cropFrame)
        case .circle, .roundedRectangle:
            if let path = shapePath {
                context.addPath(path)
                context.strokePath()
            }
        }
    }

    private func drawGrid(context: CGContext, cropFrame: NSRect) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(AppConstants.cropEditorGridLineWidth)

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
        context.setLineWidth(AppConstants.cropEditorHandleThickness)

        for position in HandlePosition.allCases {
            drawHandle(at: position, cropFrame: cropFrame, context: context)
        }
    }

    private func drawHandle(at position: HandlePosition,
                            cropFrame: NSRect,
                            context: CGContext) {
        let len = AppConstants.cropEditorHandleLength
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

    private func drawCornerRadiusHandles(context: CGContext, cropFrame: NSRect) {
        let handleSize = AppConstants.cornerRadiusHandleSize
        context.setFillColor(NSColor.systemYellow.cgColor)

        for corner in CropGeometry.Corner.allCases {
            let radius = cornerRadii.radius(for: corner)
            let pos = CropGeometry.cornerRadiusHandlePosition(
                corner: corner, cropFrame: cropFrame, normalizedRadius: radius
            )
            let handleRect = NSRect(
                x: pos.x - handleSize / 2,
                y: pos.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            context.fillEllipse(in: handleRect)
        }
    }

    private func hitTestCornerRadiusHandle(point: NSPoint, cropFrame: NSRect) -> CropGeometry.Corner? {
        let tolerance = AppConstants.cornerRadiusHandleHitTolerance
        for corner in CropGeometry.Corner.allCases {
            let radius = cornerRadii.radius(for: corner)
            let pos = CropGeometry.cornerRadiusHandlePosition(
                corner: corner, cropFrame: cropFrame, normalizedRadius: radius
            )
            let dist = hypot(point.x - pos.x, point.y - pos.y)
            if dist <= tolerance {
                return corner
            }
        }
        return nil
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
        dragStartCropFrame = cropFrame
        dragStartImageDrawRect = calculateImageDrawRect(cropFrame: cropFrame)

        // 角丸ハンドルのヒット判定（roundedRectangle時のみ、通常ハンドルより先に判定）
        if cropShape == .roundedRectangle {
            if let corner = hitTestCornerRadiusHandle(point: point, cropFrame: cropFrame) {
                dragState = .adjustingCornerRadius(corner)
                return
            }
        }

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
            // パンクランプなし: 画像を自由に配置可能
            needsDisplay = true
        case .resizingHandle(let position):
            guard dragStartCropFrame.width > 0, dragStartCropFrame.height > 0 else { return }
            handleResize(position: position, currentPoint: point)
        case .adjustingCornerRadius(let corner):
            handleCornerRadiusDrag(corner: corner, currentPoint: point)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let wasResizing = if case .resizingHandle = dragState { true } else { false }
        let wasIdle = if case .idle = dragState { true } else { false }
        activeDragCropFrame = nil
        dragState = .idle
        if wasResizing {
            recalculateImageOffset()
        }
        if !wasIdle {
            needsDisplay = true
            onDragEnded?()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let zoomDelta = event.deltaY * Self.zoomSensitivity
        imageZoom = Swift.min(Swift.max(imageZoom + zoomDelta, Self.minZoom), Self.maxZoom)
        // パンクランプなし: 画像を自由に配置可能
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

    // MARK: - Aspect Ratio Resolution

    /// アスペクト比プリセットから正規化比率を解決する
    /// - Returns: 正規化されたアスペクト比（ratio / boundsRatio）。フリーの場合はnil
    private func resolveLockedAspectRatio() -> CGFloat? {
        guard let image = displayImage,
              image.size.width > 0, image.size.height > 0 else { return nil }

        guard let preset = AspectRatioPreset.from(presetName: cropRect.aspectRatioPreset),
              preset != .free else { return nil }

        let imageSize = image.size
        let normalizedTurns = CropGeometry.normalizeQuarterTurns(cropRect.quarterTurns)
        let isSwapped = (normalizedTurns == 1 || normalizedTurns == 3)
        let effectiveWidth = isSwapped ? imageSize.height : imageSize.width
        let effectiveHeight = isSwapped ? imageSize.width : imageSize.height
        let boundsRatio = effectiveWidth / effectiveHeight

        let ratio: CGFloat
        if preset == .original {
            ratio = boundsRatio
        } else if let presetRatio = preset.ratio {
            ratio = presetRatio
        } else {
            return nil
        }

        return ratio / boundsRatio
    }

    /// HandlePositionをCropGeometry.ResizeHandleに変換
    private func resizeHandle(from position: HandlePosition) -> CropGeometry.ResizeHandle {
        switch position {
        case .topLeft: return .topLeft
        case .topRight: return .topRight
        case .bottomLeft: return .bottomLeft
        case .bottomRight: return .bottomRight
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .left
        case .right: return .right
        }
    }

    // MARK: - Handle Resize

    private func handleResize(position: HandlePosition,
                              currentPoint: NSPoint) {
        let deltaX = currentPoint.x - dragStartPoint.x
        let deltaY = currentPoint.y - dragStartPoint.y
        let imgRect = dragStartImageDrawRect

        if let normalizedRatio = resolveLockedAspectRatio() {
            // アスペクト比固定リサイズ（正規化座標ベース）
            let normalizedDX = deltaX / dragStartCropFrame.width * dragStartCropRect.width
            let normalizedDY = deltaY / dragStartCropFrame.height * dragStartCropRect.height
            let start = dragStartCropRect
            let minSize = AppConstants.cropMinProportion
            var newW = start.width
            var newH = start.height

            switch position {
            case .topLeft, .left, .bottomLeft:
                newW = Swift.min(Swift.max(start.width - normalizedDX, minSize), 1.0)
            case .topRight, .right, .bottomRight:
                newW = Swift.min(Swift.max(start.width + normalizedDX, minSize), 1.0)
            case .top, .bottom:
                break
            }
            switch position {
            case .bottomLeft, .bottom, .bottomRight:
                newH = Swift.min(Swift.max(start.height - normalizedDY, minSize), 1.0)
            case .topLeft, .top, .topRight:
                newH = Swift.min(Swift.max(start.height + normalizedDY, minSize), 1.0)
            case .left, .right:
                break
            }

            let handle = resizeHandle(from: position)
            let input = CropGeometry.ConstrainedResizeInput(
                start: start, newWidth: newW, newHeight: newH,
                handle: handle, normalizedRatio: normalizedRatio, minSize: minSize
            )
            let result = CropGeometry.constrainedResize(input: input)
            cropRect = cropRect.with(
                x: result.originX, y: result.originY,
                width: result.width, height: result.height
            )

            // ピクセルベースのcropFrameを計算（リフィット防止）
            activeDragCropFrame = NSRect(
                x: imgRect.minX + cropRect.x * imgRect.width,
                y: imgRect.minY + cropRect.y * imgRect.height,
                width: cropRect.width * imgRect.width,
                height: cropRect.height * imgRect.height
            )
        } else {
            // フリーリサイズ（ピクセルベース）
            let newFrame = freeResizeFrame(position: position, deltaX: deltaX, deltaY: deltaY)
            activeDragCropFrame = newFrame

            let normalized = CropGeometry.viewRectToNormalizedCrop(
                cropFrame: newFrame, imageRect: imgRect
            )
            cropRect = cropRect.with(
                x: normalized.x, y: normalized.y,
                width: normalized.width, height: normalized.height
            )
        }
        onCropRectChanged?(cropRect)
    }

    // MARK: - Corner Radius Drag

    private func handleCornerRadiusDrag(corner: CropGeometry.Corner, currentPoint: NSPoint) {
        let cropFrame = dragStartCropFrame
        let newRadius = CropGeometry.cornerRadiusFromDrag(
            corner: corner, cropFrame: cropFrame, dragPoint: currentPoint
        )

        let newRadii: CornerRadii
        if cornersLinked {
            newRadii = CornerRadii.uniform(newRadius)
        } else {
            newRadii = cornerRadii.with(corner: corner, radius: newRadius)
        }
        cropRect = cropRect.with(cornerRadii: newRadii)
        onCropRectChanged?(cropRect)
    }

    /// フリーリサイズ時のピクセルベースcropFrame計算
    private func freeResizeFrame(position: HandlePosition,
                                 deltaX: CGFloat, deltaY: CGFloat) -> NSRect {
        let startFrame = dragStartCropFrame
        let imgRect = dragStartImageDrawRect
        let minPixelW = AppConstants.cropMinProportion * imgRect.width
        let minPixelH = AppConstants.cropMinProportion * imgRect.height

        var minX = startFrame.minX
        var minY = startFrame.minY
        var maxX = startFrame.maxX
        var maxY = startFrame.maxY

        // 水平方向
        switch position {
        case .topLeft, .left, .bottomLeft:
            minX = min(startFrame.minX + deltaX, maxX - minPixelW)
        case .topRight, .right, .bottomRight:
            maxX = max(startFrame.maxX + deltaX, minX + minPixelW)
        case .top, .bottom:
            break
        }

        // 垂直方向
        switch position {
        case .bottomLeft, .bottom, .bottomRight:
            minY = min(startFrame.minY + deltaY, maxY - minPixelH)
        case .topLeft, .top, .topRight:
            maxY = max(startFrame.maxY + deltaY, minY + minPixelH)
        case .left, .right:
            break
        }

        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
