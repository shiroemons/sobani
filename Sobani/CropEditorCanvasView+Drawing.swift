import Cocoa

// MARK: - Image Drawing

extension CropEditorCanvasView {

    /// すべての変換（quarterTurns、isFlippedInCrop、パース補正、straightenAngle）を適用して描画する
    /// 変換は `CropImageProcessor` と共通の `CropGeometry.imageTransform` を使うため、確定後の出力と一致する
    func drawTransformedImage(context: CGContext, imageDrawRect: NSRect) {
        guard let image = displayImage else { return }
        context.saveGState()
        context.interpolationQuality = .high
        context.concatenate(CropGeometry.imageTransform(
            for: cropRect, sourceSize: image.size, imageRect: imageDrawRect
        ))
        image.draw(in: NSRect(origin: .zero, size: image.size))
        context.restoreGState()
    }
}

// MARK: - Overlay & Grid Drawing

extension CropEditorCanvasView {

    private static let cropBorderLineWidth: CGFloat = 1
    private static let gridLineAlpha: CGFloat = 0.5

    func drawOverlay(context: CGContext, cropFrame: NSRect, shapePath: CGPath?) {
        context.saveGState()
        context.setFillColor(
            NSColor.black.withAlphaComponent(AppConstants.cropEditorOverlayAlpha).cgColor
        )

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

    func drawCropBorder(context: CGContext, cropFrame: NSRect, shapePath: CGPath?) {
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(Self.cropBorderLineWidth)

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

    func drawGrid(context: CGContext, cropFrame: NSRect) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(Self.gridLineAlpha).cgColor)
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

    func drawHandles(context: CGContext, cropFrame: NSRect) {
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(AppConstants.cropEditorHandleThickness)

        for position in HandlePosition.allCases {
            drawHandle(at: position, cropFrame: cropFrame, context: context)
        }
    }

    func drawHandle(
        at position: HandlePosition, cropFrame: NSRect, context: CGContext
    ) {
        let len = AppConstants.cropEditorHandleLength
        let point = handleCornerPoint(for: position, cropFrame: cropFrame)

        switch position {
        case .topLeft:
            drawLHandle(
                context: context, corner: point,
                end1: CGPoint(x: point.x, y: point.y - len),
                end2: CGPoint(x: point.x + len, y: point.y))
        case .topRight:
            drawLHandle(
                context: context, corner: point,
                end1: CGPoint(x: point.x - len, y: point.y),
                end2: CGPoint(x: point.x, y: point.y - len))
        case .bottomLeft:
            drawLHandle(
                context: context, corner: point,
                end1: CGPoint(x: point.x, y: point.y + len),
                end2: CGPoint(x: point.x + len, y: point.y))
        case .bottomRight:
            drawLHandle(
                context: context, corner: point,
                end1: CGPoint(x: point.x - len, y: point.y),
                end2: CGPoint(x: point.x, y: point.y + len))
        case .top, .bottom:
            drawEdgeHandle(
                context: context, center: point, horizontal: true, length: len)
        case .left, .right:
            drawEdgeHandle(
                context: context, center: point, horizontal: false, length: len)
        }
    }

    func drawLHandle(
        context: CGContext, corner: NSPoint, end1: CGPoint, end2: CGPoint
    ) {
        context.move(to: end1)
        context.addLine(to: CGPoint(x: corner.x, y: corner.y))
        context.addLine(to: end2)
        context.strokePath()
    }

    func drawEdgeHandle(
        context: CGContext, center: NSPoint, horizontal: Bool, length: CGFloat
    ) {
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

    func drawCornerRadiusHandles(context: CGContext, cropFrame: NSRect) {
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

    /// ヒット範囲内で最も近い角丸ハンドルとその距離を返す
    func hitTestCornerRadiusHandle(
        point: NSPoint, cropFrame: NSRect
    ) -> (corner: CropGeometry.Corner, distance: CGFloat)? {
        let tolerance = AppConstants.cornerRadiusHandleHitTolerance
        return CropGeometry.Corner.allCases
            .map { corner -> (corner: CropGeometry.Corner, distance: CGFloat) in
                let pos = CropGeometry.cornerRadiusHandlePosition(
                    corner: corner, cropFrame: cropFrame,
                    normalizedRadius: cornerRadii.radius(for: corner)
                )
                return (corner, hypot(point.x - pos.x, point.y - pos.y))
            }
            .filter { $0.distance <= tolerance }
            .min { $0.distance < $1.distance }
    }
}
