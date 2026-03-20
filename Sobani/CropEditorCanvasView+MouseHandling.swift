import Cocoa

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

    func hitTestHandle(
        point: NSPoint, cropFrame: NSRect
    ) -> HandlePosition? {
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
    func resolveLockedAspectRatio() -> CGFloat? {
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
    func resizeHandle(from position: HandlePosition) -> CropGeometry.ResizeHandle {
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

    func handleResize(
        position: HandlePosition, currentPoint: NSPoint
    ) {
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

    func handleCornerRadiusDrag(corner: CropGeometry.Corner, currentPoint: NSPoint) {
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
    func freeResizeFrame(
        position: HandlePosition, deltaX: CGFloat, deltaY: CGFloat
    ) -> NSRect {
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
