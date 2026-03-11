import CoreGraphics

/// クロップ関連の幾何学計算ユーティリティ
enum CropGeometry {

    // MARK: - Straighten Zoom

    /// 傾き補正時の自動ズーム倍率を計算
    /// iPhone写真アプリのように、回転後も画像がクロップ領域内に収まるようにズームする
    /// - Parameters:
    ///   - angleDegrees: 傾き角度（度）
    ///   - aspectRatio: クロップ領域のアスペクト比（width / height）
    /// - Returns: 必要なズーム倍率（1.0 = ズームなし）
    static func zoomScaleForStraighten(angleDegrees: CGFloat, aspectRatio: CGFloat) -> CGFloat {
        // 角度0ならズーム不要
        guard abs(angleDegrees) > AppConstants.floatingPointTolerance else { return 1.0 }
        let radians = abs(angleDegrees) * .pi / 180
        let sinA = sin(radians)
        let cosA = cos(radians)
        // 回転後に矩形内に収まるための最小ズーム倍率
        // 幅方向: (w*cos + h*sin) / w = cos + sin/aspectRatio
        // 高さ方向: (w*sin + h*cos) / h = aspectRatio*sin + cos
        let scaleW = cosA + sinA / max(aspectRatio, AppConstants.floatingPointTolerance)
        let scaleH = aspectRatio * sinA + cosA
        return max(scaleW, scaleH)
    }

    // MARK: - Quarter Turn

    /// 90°回転後のクロップ矩形を計算（反時計回り）
    static func cropRectAfterQuarterTurn(cropRect: CropRect, turns: Int) -> CropRect {
        let normalizedTurns = normalizeQuarterTurns(turns)
        var x = cropRect.x
        var y = cropRect.y
        var w = cropRect.width
        var h = cropRect.height

        for _ in 0..<normalizedTurns {
            let newX = y
            let newY = 1 - x - w
            let newW = h
            let newH = w
            x = newX
            y = newY
            w = newW
            h = newH
        }

        return cropRect.with(
            x: x, y: y, width: w, height: h,
            quarterTurns: normalizeQuarterTurns(cropRect.quarterTurns + turns)
        )
    }

    // MARK: - Aspect Ratio

    /// アスペクト比制約に基づくクロップ矩形を計算（中央配置）
    static func cropRectForAspectRatio(
        ratio: CGFloat, within bounds: CGSize, centered: Bool = true
    ) -> CropRect {
        guard ratio > 0, bounds.width > 0, bounds.height > 0 else { return .full }
        let boundsRatio = bounds.width / bounds.height
        let cropW: CGFloat
        let cropH: CGFloat
        if ratio > boundsRatio {
            // 横長：幅を1.0に、高さを調整
            cropW = 1.0
            cropH = boundsRatio / ratio
        } else {
            // 縦長：高さを1.0に、幅を調整
            cropH = 1.0
            cropW = ratio / boundsRatio
        }
        let x = centered ? (1 - cropW) / 2 : 0
        let y = centered ? (1 - cropH) / 2 : 0
        return CropRect(x: x, y: y, width: cropW, height: cropH)
    }

    /// リサイズ時にアスペクト比制約を維持する
    static func constrainCropRect(
        _ rect: CropRect, toAspectRatio ratio: CGFloat, within bounds: CGSize
    ) -> CropRect {
        guard ratio > 0, bounds.width > 0, bounds.height > 0 else { return rect }
        let boundsRatio = bounds.width / bounds.height
        let normalizedRatio = ratio / boundsRatio

        var w = rect.width
        var h = rect.height

        // 高さを基準にして幅を調整
        let targetW = h * normalizedRatio
        if targetW <= 1.0 {
            w = targetW
        } else {
            w = 1.0
            h = w / normalizedRatio
        }

        // 範囲内に収める
        let x = min(max(rect.x, 0), 1 - w)
        let y = min(max(rect.y, 0), 1 - h)

        return rect.with(x: x, y: y, width: w, height: h)
    }

    // MARK: - Constrained Resize

    /// ハンドルの種類（リサイズ方向）
    enum ResizeHandle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right

        var isCorner: Bool {
            switch self {
            case .topLeft, .topRight, .bottomLeft, .bottomRight: return true
            default: return false
            }
        }
    }

    /// アスペクト比制約付きリサイズの結果
    struct ConstrainedResizeResult {
        let width: CGFloat
        let height: CGFloat
        let originX: CGFloat
        let originY: CGFloat
    }

    /// アスペクト比制約付きリサイズ計算
    /// - Parameters:
    ///   - input: リサイズ入力パラメータ
    /// - Returns: 制約適用後の結果
    static func constrainedResize(input: ConstrainedResizeInput) -> ConstrainedResizeResult {
        var size = constrainedSize(
            newWidth: input.newWidth, newHeight: input.newHeight,
            handle: input.handle, normalizedRatio: input.normalizedRatio,
            minSize: input.minSize
        )
        var origin = anchorOrigin(
            start: input.start, handle: input.handle,
            width: size.width, height: size.height
        )
        clampToBounds(
            origin: &origin, size: &size,
            normalizedRatio: input.normalizedRatio, minSize: input.minSize
        )
        return ConstrainedResizeResult(
            width: size.width, height: size.height,
            originX: origin.x, originY: origin.y
        )
    }

    /// リサイズ入力パラメータ
    struct ConstrainedResizeInput {
        let start: CropRect
        let newWidth: CGFloat
        let newHeight: CGFloat
        let handle: ResizeHandle
        let normalizedRatio: CGFloat
        let minSize: CGFloat
    }

    // MARK: - Constrained Resize Helpers

    private static func constrainedSize(
        newWidth: CGFloat, newHeight: CGFloat,
        handle: ResizeHandle, normalizedRatio: CGFloat, minSize: CGFloat
    ) -> (width: CGFloat, height: CGFloat) {
        var width: CGFloat
        var height: CGFloat

        if handle.isCorner {
            let widthBasedArea = newWidth * (newWidth / normalizedRatio)
            let heightBasedArea = (newHeight * normalizedRatio) * newHeight
            if widthBasedArea <= heightBasedArea {
                width = newWidth
                height = newWidth / normalizedRatio
            } else {
                width = newHeight * normalizedRatio
                height = newHeight
            }
        } else {
            switch handle {
            case .top, .bottom:
                height = newHeight
                width = newHeight * normalizedRatio
            case .left, .right:
                width = newWidth
                height = newWidth / normalizedRatio
            default:
                width = newWidth
                height = newHeight
            }
        }

        width = max(width, minSize)
        height = max(height, minSize)

        // 最小サイズ適用後もアスペクト比を維持
        if width / normalizedRatio > height {
            height = width / normalizedRatio
        } else {
            width = height * normalizedRatio
        }
        return (width, height)
    }

    private static func anchorOrigin(
        start: CropRect, handle: ResizeHandle,
        width: CGFloat, height: CGFloat
    ) -> (x: CGFloat, y: CGFloat) {
        let originX: CGFloat
        switch handle {
        case .topRight, .right, .bottomRight:
            originX = start.x
        case .topLeft, .left, .bottomLeft:
            originX = start.x + start.width - width
        case .top, .bottom:
            originX = start.x + start.width / 2 - width / 2
        }

        let originY: CGFloat
        switch handle {
        case .topLeft, .top, .topRight:
            originY = start.y
        case .bottomLeft, .bottom, .bottomRight:
            originY = start.y + start.height - height
        case .left, .right:
            originY = start.y + start.height / 2 - height / 2
        }
        return (originX, originY)
    }

    private static func clampToBounds(
        origin: inout (x: CGFloat, y: CGFloat),
        size: inout (width: CGFloat, height: CGFloat),
        normalizedRatio: CGFloat, minSize: CGFloat
    ) {
        if origin.x < 0 {
            size.width += origin.x
            origin.x = 0
            size.height = size.width / normalizedRatio
        }
        if origin.y < 0 {
            size.height += origin.y
            origin.y = 0
            size.width = size.height * normalizedRatio
        }
        if origin.x + size.width > 1 {
            size.width = 1 - origin.x
            size.height = size.width / normalizedRatio
        }
        if origin.y + size.height > 1 {
            size.height = 1 - origin.y
            size.width = size.height * normalizedRatio
        }
        size.width = max(size.width, minSize)
        size.height = max(size.height, minSize)
    }

    // MARK: - View Coordinate Conversion

    /// 正規化されたクロップ座標（0〜1）
    struct NormalizedCrop {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    /// Converts a crop frame in view coordinates to normalized crop coordinates.
    /// Coordinates may exceed the 0–1 range when the image is freely positioned.
    /// - Parameters:
    ///   - cropFrame: The crop rectangle in view coordinate space
    ///   - imageRect: The image rectangle in view coordinate space
    /// - Returns: Normalized (x, y, width, height) — unclamped for free positioning
    static func viewRectToNormalizedCrop(
        cropFrame: CGRect, imageRect: CGRect
    ) -> NormalizedCrop {
        let x = (cropFrame.minX - imageRect.minX) / imageRect.width
        let y = (cropFrame.minY - imageRect.minY) / imageRect.height
        let w = cropFrame.width / imageRect.width
        let h = cropFrame.height / imageRect.height
        return NormalizedCrop(
            x: x, y: y, width: w, height: h
        )
    }

    // MARK: - Pan Offset Clamping

    /// Clamps a pan offset so that the image fully covers the crop frame.
    /// If the image is smaller than the crop frame on an axis, that axis is locked to zero.
    /// - Parameters:
    ///   - offset: The current pan offset
    ///   - imageSize: The rendered image size (post-zoom)
    ///   - cropFrameSize: The crop frame size
    /// - Returns: Clamped offset
    static func clampOffset(offset: CGPoint, imageSize: CGSize, cropFrameSize: CGSize) -> CGPoint {
        let maxOffsetX = max(0, (imageSize.width - cropFrameSize.width) / 2)
        let maxOffsetY = max(0, (imageSize.height - cropFrameSize.height) / 2)
        return CGPoint(
            x: max(-maxOffsetX, min(maxOffsetX, offset.x)),
            y: max(-maxOffsetY, min(maxOffsetY, offset.y))
        )
    }

    // MARK: - Editor State Reconstruction

    /// Reconstructs the zoom and pan offset from a persisted CropRect so the editor can resume
    /// a previous crop session at the correct view state.
    /// - Parameters:
    ///   - cropRect: The persisted normalized crop rect
    ///   - canvasSize: The visible canvas size in the editor
    ///   - imageSize: The original image size (pixels or points)
    /// - Returns: The zoom scale and pan offset that reproduce the crop rect in the editor
    static func initialStateFromCropRect(
        cropRect: CropRect, canvasSize: CGSize, imageSize: CGSize
    ) -> (offset: CGPoint, zoom: CGFloat) {
        guard cropRect.width > AppConstants.floatingPointTolerance,
              cropRect.height > AppConstants.floatingPointTolerance else {
            return (offset: .zero, zoom: 1.0)
        }

        let imageAspect = imageSize.width / max(imageSize.height, AppConstants.floatingPointTolerance)
        let canvasAspect = canvasSize.width / max(canvasSize.height, AppConstants.floatingPointTolerance)

        // Zoom is the reciprocal of the crop fraction that fills the smaller canvas dimension.
        let zoom = 1.0 / max(cropRect.width, cropRect.height)

        // Compute the fitted image size on the canvas at zoom = 1.0.
        let fitSize: CGSize
        if imageAspect > canvasAspect {
            fitSize = CGSize(width: canvasSize.width, height: canvasSize.width / imageAspect)
        } else {
            fitSize = CGSize(width: canvasSize.height * imageAspect, height: canvasSize.height)
        }

        // Offset is the displacement from the image center to the crop center, in canvas points.
        let cropCenterX = cropRect.x + cropRect.width / 2
        let cropCenterY = cropRect.y + cropRect.height / 2
        let imageCenterX: CGFloat = 0.5
        let imageCenterY: CGFloat = 0.5

        let offsetX = (imageCenterX - cropCenterX) * fitSize.width * zoom
        let offsetY = (imageCenterY - cropCenterY) * fitSize.height * zoom

        return (offset: CGPoint(x: offsetX, y: offsetY), zoom: zoom)
    }

    // MARK: - Normalization / Clamping

    /// quarterTurnsを0〜3に正規化
    static func normalizeQuarterTurns(_ turns: Int) -> Int {
        var result = turns % 4
        if result < 0 { result += 4 }
        return result
    }

    /// straightenAngleを-45〜+45にクランプ
    static func clampStraightenAngle(_ angle: CGFloat) -> CGFloat {
        min(max(angle, AppConstants.straightenMinAngle), AppConstants.straightenMaxAngle)
    }
}
