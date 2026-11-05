import Cocoa

// MARK: - Mouse Events & Resize

extension CropEditorCanvasView {

    override func mouseDown(with event: NSEvent) {
        // 直前のスクロールズームを先に履歴へ確定させ、操作順を保つ
        scrollEndDebouncer.flush()

        let point = convert(event.locationInWindow, from: nil)
        let target = hitTestDragTarget(point: point, cropFrame: calculateCropFrameRect())

        // ハンドル操作はズーム 1 の cropRect を基準に計算するため、パン・ズームを先に取り込む
        // （取り込まないとズームが二重に掛かったり、パン前の位置からリサイズが始まったりする）
        if !target.isMovingImage {
            commitViewTransformToCropRect()
        }

        dragStartPoint = point
        dragStartCropRect = cropRect
        dragStartImageOffset = imageOffset
        let cropFrame = calculateCropFrameRect()
        dragStartCropFrame = cropFrame
        dragStartImageDrawRect = calculateImageDrawRect(cropFrame: cropFrame)
        dragState = target
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
        let endedState = dragState
        activeDragCropFrame = nil
        dragState = .idle
        switch endedState {
        case .idle:
            return
        case .movingImage:
            // パン結果を cropRect に取り込み、履歴と「戻す」ボタンに反映させる
            commitViewTransformToCropRect()
            onCropRectChanged?(cropRect)
        case .resizingHandle:
            recalculateImageOffset()
        case .adjustingCornerRadius:
            break
        }
        needsDisplay = true
        onDragEnded?()
    }

    override func scrollWheel(with event: NSEvent) {
        guard case .idle = dragState else { return }
        let lines = event.hasPreciseScrollingDeltas
            ? event.scrollingDeltaY / Self.preciseScrollPointsPerLine
            : event.scrollingDeltaY
        let oldZoom = imageZoom
        let newZoom = Swift.min(
            Swift.max(oldZoom + lines * Self.zoomSensitivity, Self.minZoom), Self.maxZoom
        )
        guard abs(newZoom - oldZoom) >= AppConstants.normalizedTolerance else { return }

        // クロップ枠の中心を基準に拡大縮小する（画像中心はクロップ枠中心 + オフセット）
        let factor = newZoom / oldZoom
        imageOffset = CGPoint(x: imageOffset.x * factor, y: imageOffset.y * factor)
        imageZoom = newZoom
        // パンクランプなし: 画像を自由に配置可能
        needsDisplay = true
        onCropRectChanged?(computeFinalCropRect())
        scrollEndDebouncer.schedule { [weak self] in
            self?.onDragEnded?()
        }
    }

    // MARK: - Hit Testing

    /// クリック位置から開始するドラッグ操作を決める
    func hitTestDragTarget(point: NSPoint, cropFrame: NSRect) -> DragState {
        let handleHit = hitTestHandle(point: point, cropFrame: cropFrame)
        let cornerHit = cropShape == .roundedRectangle
            ? hitTestCornerRadiusHandle(point: point, cropFrame: cropFrame)
            : nil

        switch (handleHit, cornerHit) {
        case let (handleHit?, cornerHit?):
            let prefersRadius = CropGeometry.prefersCornerRadiusHandle(
                radiusHandleDistance: cornerHit.distance,
                resizeHandleDistance: handleHit.distance,
                isInsideCropFrame: cropFrame.contains(point)
            )
            return prefersRadius
                ? .adjustingCornerRadius(cornerHit.corner) : .resizingHandle(handleHit.position)
        case let (handleHit?, nil):
            return .resizingHandle(handleHit.position)
        case let (nil, cornerHit?):
            return .adjustingCornerRadius(cornerHit.corner)
        case (nil, nil):
            return .movingImage
        }
    }

    /// ヒット範囲内で最も近いリサイズハンドルとその距離を返す
    func hitTestHandle(
        point: NSPoint, cropFrame: NSRect
    ) -> (position: HandlePosition, distance: CGFloat)? {
        let tolerance = AppConstants.cornerRadiusHandleHitTolerance
        return HandlePosition.allCases
            .map { position -> (position: HandlePosition, distance: CGFloat) in
                let handlePoint = handleCornerPoint(for: position, cropFrame: cropFrame)
                return (position, hypot(point.x - handlePoint.x, point.y - handlePoint.y))
            }
            .filter { $0.distance <= tolerance }
            .min { $0.distance < $1.distance }
    }

    // MARK: - Aspect Ratio Resolution

    /// アスペクト比プリセットから正規化比率を解決する
    /// - Returns: 正規化されたアスペクト比（ratio / boundsRatio）。フリーの場合はnil
    func resolveLockedAspectRatio() -> CGFloat? {
        let imageSize = effectiveImageSize
        guard imageSize.width > 0, imageSize.height > 0,
              let preset = AspectRatioPreset.from(presetName: cropRect.aspectRatioPreset),
              let ratio = preset.ratio(forImageSize: imageSize) else { return nil }
        return ratio / (imageSize.width / imageSize.height)
    }

    // MARK: - Handle Resize

    func handleResize(
        position: HandlePosition, currentPoint: NSPoint
    ) {
        let deltaX = currentPoint.x - dragStartPoint.x
        let deltaY = currentPoint.y - dragStartPoint.y
        let imgRect = dragStartImageDrawRect
        let start = dragStartCropRect

        if let normalizedRatio = resolveLockedAspectRatio() {
            // アスペクト比固定リサイズ（正規化座標ベース）
            let normalizedDX = deltaX / dragStartCropFrame.width * start.width
            let normalizedDY = deltaY / dragStartCropFrame.height * start.height
            var newW = start.width
            var newH = start.height

            switch position {
            case .topLeft, .left, .bottomLeft:
                newW = start.width - normalizedDX
            case .topRight, .right, .bottomRight:
                newW = start.width + normalizedDX
            case .top, .bottom:
                break
            }
            switch position {
            case .bottomLeft, .bottom, .bottomRight:
                newH = start.height - normalizedDY
            case .topLeft, .top, .topRight:
                newH = start.height + normalizedDY
            case .left, .right:
                break
            }

            // 既に最小サイズより小さい（ズームで切り出した）クロップは、その大きさを下限にする
            let minSize = Swift.min(AppConstants.cropMinProportion, start.width, start.height)
            let input = CropGeometry.ConstrainedResizeInput(
                start: start, newWidth: newW, newHeight: newH,
                handle: position, normalizedRatio: normalizedRatio, minSize: minSize,
                bounds: normalizedResizeBounds(imageRect: imgRect)
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
            // フリーリサイズ（ピクセルベース、キャンバス内に制限）
            let minSize = CGSize(
                width: Swift.min(AppConstants.cropMinProportion * imgRect.width, dragStartCropFrame.width),
                height: Swift.min(AppConstants.cropMinProportion * imgRect.height, dragStartCropFrame.height)
            )
            let newFrame = CropGeometry.freeResizedFrame(
                start: dragStartCropFrame, handle: position,
                delta: CGVector(dx: deltaX, dy: deltaY), minSize: minSize, limit: bounds
            )
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

    /// アスペクト比固定リサイズで使える範囲（正規化座標）。画像内かつキャンバス内に収める
    private func normalizedResizeBounds(imageRect: NSRect) -> CGRect {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard imageRect.width > 0, imageRect.height > 0 else { return unit }
        let canvas = CropGeometry.viewRectToNormalizedCrop(cropFrame: bounds, imageRect: imageRect)
        let visible = unit.intersection(
            CGRect(x: canvas.x, y: canvas.y, width: canvas.width, height: canvas.height)
        )
        return visible.isNull ? unit : visible
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
}
