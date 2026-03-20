import Cocoa

// MARK: - Image Drawing

extension CropEditorCanvasView {

    /// すべての変換（quarterTurns、isFlippedInCrop、straightenAngle、perspective）を統合して描画
    func drawTransformedImage(context: CGContext, imageDrawRect: NSRect) {
        guard let image = displayImage else { return }
        let normalizedTurns = CropGeometry.normalizeQuarterTurns(cropRect.quarterTurns)
        let angle = cropRect.straightenAngle
        let hasQuarterTurns = normalizedTurns != 0
        let hasStraighten = !GeometryUtils.isApproximatelyZero(angle)
        let hasFlip = cropRect.isFlippedInCrop
        let hasVertPerspective = !GeometryUtils.isApproximatelyZero(cropRect.verticalPerspective)
        let hasHorizPerspective = !GeometryUtils.isApproximatelyZero(cropRect.horizontalPerspective)

        guard hasQuarterTurns || hasStraighten || hasFlip
                || hasVertPerspective || hasHorizPerspective else {
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
    func perspectiveToAffine(_ transform: CATransform3D) -> CGAffineTransform {
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

    func drawGrid(context: CGContext, cropFrame: NSRect) {
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

    func hitTestCornerRadiusHandle(
        point: NSPoint, cropFrame: NSRect
    ) -> CropGeometry.Corner? {
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
