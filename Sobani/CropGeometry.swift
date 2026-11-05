import CoreGraphics

// swiftlint:disable type_body_length
/// クロップ関連の幾何学計算ユーティリティ
enum CropGeometry {

    // MARK: - Image Transform

    /// 浮動小数点誤差でピクセル数が 1 増えるのを防ぐためのスナップ許容誤差（例: 300.00000000000006 → 300）
    private static let pixelSnapTolerance: CGFloat = 1e-6

    /// quarterTurns を考慮した表示上の画像サイズ（奇数回の 90° 回転で幅と高さを入れ替える）
    static func effectiveSize(_ size: CGSize, quarterTurns: Int) -> CGSize {
        guard normalizeQuarterTurns(quarterTurns) % 2 == 1 else { return size }
        return CGSize(width: size.height, height: size.width)
    }

    /// 元画像の中心を原点とする座標を、表示空間（y 軸上向き）へ写す線形変換
    ///
    /// 適用順は 90° 単位の時計回り回転 → 水平反転 → パース補正（cos による縮小）→ 傾き補正（正の角度で時計回り）。
    /// エディタのキャンバスと `CropImageProcessor` の両方がこの変換を使うため、プレビューと出力は常に一致する。
    static func contentTransform(for cropRect: CropRect) -> CGAffineTransform {
        var transform = quarterTurnTransform(cropRect.quarterTurns)
        if cropRect.isFlippedInCrop {
            transform = transform.concatenating(CGAffineTransform(scaleX: -1, y: 1))
        }
        transform = transform.concatenating(CGAffineTransform(
            scaleX: perspectiveScale(degrees: cropRect.horizontalPerspective),
            y: perspectiveScale(degrees: cropRect.verticalPerspective)
        ))
        if !GeometryUtils.isApproximatelyZero(cropRect.straightenAngle) {
            transform = transform.concatenating(
                CGAffineTransform(rotationAngle: -radians(fromDegrees: cropRect.straightenAngle))
            )
        }
        return transform
    }

    /// 元画像の座標（原点左下、`sourceSize` 単位）を、`imageRect` に配置した表示上の座標へ写す変換
    /// - Parameters:
    ///   - cropRect: 適用する変換（quarterTurns・反転・パース・傾き）を持つ CropRect
    ///   - sourceSize: 元画像のサイズ（ピクセルでもポイントでもよい）
    ///   - imageRect: 傾き補正・パース補正を除いた（90° 回転後の）画像全体が占める矩形。
    ///     傾き補正とパース補正はこの矩形の中心を基準に適用される
    static func imageTransform(
        for cropRect: CropRect, sourceSize: CGSize, imageRect: CGRect
    ) -> CGAffineTransform {
        let effective = effectiveSize(sourceSize, quarterTurns: cropRect.quarterTurns)
        guard effective.width > 0, effective.height > 0 else { return .identity }
        return CGAffineTransform(translationX: -sourceSize.width / 2, y: -sourceSize.height / 2)
            .concatenating(contentTransform(for: cropRect))
            .concatenating(CGAffineTransform(
                scaleX: imageRect.width / effective.width, y: imageRect.height / effective.height
            ))
            .concatenating(CGAffineTransform(translationX: imageRect.midX, y: imageRect.midY))
    }

    /// 出力画像の座標系（原点 = クロップ領域の左下、`scale` 倍）で、画像全体が占める矩形
    static func outputImageRect(
        for cropRect: CropRect, effectiveSize: CGSize, scale: CGFloat = 1
    ) -> CGRect {
        CGRect(
            x: -cropRect.x * effectiveSize.width * scale,
            y: -cropRect.y * effectiveSize.height * scale,
            width: effectiveSize.width * scale,
            height: effectiveSize.height * scale
        )
    }

    /// 整数にごく近い値を整数に丸める（それ以外はそのまま）
    static func snappedToPixel(_ value: CGFloat) -> CGFloat {
        let rounded = value.rounded()
        return abs(value - rounded) < pixelSnapTolerance ? rounded : value
    }

    /// 長さ（ピクセル）を、浮動小数点誤差を吸収したうえで切り上げた整数ピクセル数に変換する
    /// - Returns: 有限かつ 0 より大きく `limit` 以下ならピクセル数、それ以外は nil
    static func pixelExtent(_ value: CGFloat, limit: CGFloat) -> Int? {
        guard value.isFinite, value > 0 else { return nil }
        let extent = ceil(snappedToPixel(value))
        guard extent <= limit else { return nil }
        return max(Int(extent), 1)
    }

    private static func quarterTurnTransform(_ turns: Int) -> CGAffineTransform {
        // 誤差を出さないよう 90° 単位の回転行列を直接組み立てる（いずれも時計回り）
        switch normalizeQuarterTurns(turns) {
        case 1: return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0)   // (x, y) → (y, −x)
        case 2: return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0)  // (x, y) → (−x, −y)
        case 3: return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)   // (x, y) → (−y, x)
        default: return .identity
        }
    }

    /// パース補正角（度）を縮小率に変換する。CropRect のパース補正は奥行きを持たない cos スケールとして扱う
    private static func perspectiveScale(degrees: CGFloat) -> CGFloat {
        GeometryUtils.isApproximatelyZero(degrees) ? 1 : cos(radians(fromDegrees: degrees))
    }

    private static func radians(fromDegrees degrees: CGFloat) -> CGFloat {
        degrees * .pi / 180
    }

    // MARK: - Quarter Turn / Flip

    /// 表示上でクロップ領域ごと時計回りに 90° × turns 回転した CropRect を返す
    ///
    /// 反転中に quarterTurns を増やすと表示は反時計回りに回るため、反転中は quarterTurns を逆向きに進める。
    /// 奇数回の回転ではパース補正の縦横も入れ替え、表示内容がそのまま回転するようにする。
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

        let turnDelta = cropRect.isFlippedInCrop ? -turns : turns
        let swapsAxes = normalizedTurns % 2 == 1
        return cropRect.with(
            x: x, y: y, width: w, height: h,
            quarterTurns: normalizeQuarterTurns(cropRect.quarterTurns + turnDelta),
            verticalPerspective: swapsAxes ? cropRect.horizontalPerspective : cropRect.verticalPerspective,
            horizontalPerspective: swapsAxes ? cropRect.verticalPerspective : cropRect.horizontalPerspective
        )
    }

    /// 表示を左右反転した CropRect を返す
    ///
    /// 反転は傾き補正より内側で適用されるため、傾き角とクロップ位置・角丸も鏡像にして、
    /// クロップ結果がそのまま左右反転するようにする。
    static func cropRectAfterFlip(_ cropRect: CropRect) -> CropRect {
        let radii = cropRect.cornerRadii
        return cropRect.with(
            x: 1 - cropRect.x - cropRect.width,
            straightenAngle: -cropRect.straightenAngle,
            isFlippedInCrop: !cropRect.isFlippedInCrop,
            cornerRadii: CornerRadii(
                topLeft: radii.topRight, topRight: radii.topLeft,
                bottomLeft: radii.bottomRight, bottomRight: radii.bottomLeft
            )
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
    enum ResizeHandle: CaseIterable {
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

    /// リサイズ入力パラメータ
    struct ConstrainedResizeInput {
        let start: CropRect
        let newWidth: CGFloat
        let newHeight: CGFloat
        let handle: ResizeHandle
        /// 正規化座標での幅 / 高さ
        let normalizedRatio: CGFloat
        let minSize: CGFloat
        /// クロップ領域を収める範囲（正規化座標）。開始時の矩形がはみ出している分は常に許容する
        let bounds: CGRect

        init(
            start: CropRect, newWidth: CGFloat, newHeight: CGFloat,
            handle: ResizeHandle, normalizedRatio: CGFloat, minSize: CGFloat,
            bounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        ) {
            self.start = start
            self.newWidth = newWidth
            self.newHeight = newHeight
            self.handle = handle
            self.normalizedRatio = normalizedRatio
            self.minSize = minSize
            self.bounds = bounds
        }
    }

    /// アスペクト比制約付きリサイズ計算
    ///
    /// ドラッグ中のハンドルの反対側（辺ハンドルなら反対の辺と中心線）を固定したまま、
    /// 比率を保って拡大縮小する。範囲に収まらない場合も固定側は動かさず、全体を同じ倍率で縮める。
    static func constrainedResize(input: ConstrainedResizeInput) -> ConstrainedResizeResult {
        let start = input.start
        guard input.normalizedRatio.isFinite, input.normalizedRatio > 0 else {
            return ConstrainedResizeResult(
                width: start.width, height: start.height, originX: start.x, originY: start.y
            )
        }
        var size = proportionalSize(input: input)

        // 最小サイズ（比率を保ったまま拡大）
        let growScale = max(1, input.minSize / size.width, input.minSize / size.height)
        // 固定側から使える範囲に収める（比率を保ったまま縮小）
        let available = availableSize(start: start, handle: input.handle, bounds: input.bounds)
        let grown = CGSize(width: size.width * growScale, height: size.height * growScale)
        let fitScale = min(1, available.width / grown.width, available.height / grown.height)
        size = CGSize(width: grown.width * fitScale, height: grown.height * fitScale)

        let origin = anchorOrigin(start: start, handle: input.handle, size: size)
        return ConstrainedResizeResult(
            width: size.width, height: size.height, originX: origin.x, originY: origin.y
        )
    }

    // MARK: - Constrained Resize Helpers

    /// ハンドルに応じて比率を保ったサイズを求める（角ハンドルは面積の小さい方を採用）
    private static func proportionalSize(input: ConstrainedResizeInput) -> CGSize {
        let ratio = input.normalizedRatio
        let floorSize = max(input.minSize, AppConstants.normalizedTolerance)
        let newWidth = max(input.newWidth, floorSize)
        let newHeight = max(input.newHeight, floorSize)
        let widthBased = CGSize(width: newWidth, height: newWidth / ratio)
        let heightBased = CGSize(width: newHeight * ratio, height: newHeight)

        switch input.handle {
        case .top, .bottom:
            return heightBased
        case .left, .right:
            return widthBased
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            let widthBasedArea = widthBased.width * widthBased.height
            let heightBasedArea = heightBased.width * heightBased.height
            return widthBasedArea <= heightBasedArea ? widthBased : heightBased
        }
    }

    /// 固定側（反対の辺、または辺ハンドルの中心線）から確保できる最大サイズ
    private static func availableSize(
        start: CropRect, handle: ResizeHandle, bounds: CGRect
    ) -> CGSize {
        let lowerX = min(bounds.minX, start.x)
        let upperX = max(bounds.maxX, start.x + start.width)
        let lowerY = min(bounds.minY, start.y)
        let upperY = max(bounds.maxY, start.y + start.height)

        let width: CGFloat
        switch handle {
        case .topLeft, .left, .bottomLeft:
            width = start.x + start.width - lowerX   // 右端固定
        case .topRight, .right, .bottomRight:
            width = upperX - start.x                 // 左端固定
        case .top, .bottom:
            let centerX = start.x + start.width / 2  // 横方向は中心固定
            width = 2 * min(centerX - lowerX, upperX - centerX)
        }

        let height: CGFloat
        switch handle {
        case .bottomLeft, .bottom, .bottomRight:
            height = start.y + start.height - lowerY  // 上端固定
        case .topLeft, .top, .topRight:
            height = upperY - start.y                 // 下端固定
        case .left, .right:
            let centerY = start.y + start.height / 2  // 縦方向は中心固定
            height = 2 * min(centerY - lowerY, upperY - centerY)
        }
        return CGSize(width: max(width, 0), height: max(height, 0))
    }

    private static func anchorOrigin(
        start: CropRect, handle: ResizeHandle, size: CGSize
    ) -> CGPoint {
        let originX: CGFloat
        switch handle {
        case .topRight, .right, .bottomRight:
            originX = start.x
        case .topLeft, .left, .bottomLeft:
            originX = start.x + start.width - size.width
        case .top, .bottom:
            originX = start.x + start.width / 2 - size.width / 2
        }

        let originY: CGFloat
        switch handle {
        case .topLeft, .top, .topRight:
            originY = start.y
        case .bottomLeft, .bottom, .bottomRight:
            originY = start.y + start.height - size.height
        case .left, .right:
            originY = start.y + start.height / 2 - size.height / 2
        }
        return CGPoint(x: originX, y: originY)
    }

    // MARK: - Free Resize

    /// フリーリサイズ後のクロップ枠（ビュー座標）を計算する
    /// - Parameters:
    ///   - start: ドラッグ開始時のクロップ枠
    ///   - handle: ドラッグ中のハンドル
    ///   - delta: ドラッグ開始点からの移動量
    ///   - minSize: クロップ枠の最小サイズ（`limit` より優先）
    ///   - limit: 動かした辺が越えてはいけない範囲（キャンバス）
    static func freeResizedFrame(
        start: CGRect, handle: ResizeHandle, delta: CGVector, minSize: CGSize, limit: CGRect
    ) -> CGRect {
        var minX = start.minX
        var minY = start.minY
        var maxX = start.maxX
        var maxY = start.maxY

        switch handle {
        case .topLeft, .left, .bottomLeft:
            minX = min(max(start.minX + delta.dx, limit.minX), maxX - minSize.width)
        case .topRight, .right, .bottomRight:
            maxX = max(min(start.maxX + delta.dx, limit.maxX), minX + minSize.width)
        case .top, .bottom:
            break
        }

        switch handle {
        case .bottomLeft, .bottom, .bottomRight:
            minY = min(max(start.minY + delta.dy, limit.minY), maxY - minSize.height)
        case .topLeft, .top, .topRight:
            maxY = max(min(start.maxY + delta.dy, limit.maxY), minY + minSize.height)
        case .left, .right:
            break
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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

    // MARK: - Shape Path

    /// クロップ形状のパスを返す（y 軸上向き。`.rectangle` は矩形そのもの）
    static func shapePath(_ shape: CropShape, in rect: CGRect, radii: CornerRadii) -> CGPath {
        switch shape {
        case .rectangle:
            return CGPath(rect: rect, transform: nil)
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case .roundedRectangle:
            return roundedRectPath(rect: rect, radii: radii, shorterSide: min(rect.width, rect.height))
        }
    }

    // MARK: - Corner Radius

    /// 角丸ハンドルの角
    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    /// 4隅個別の角丸矩形パスを構築
    static func roundedRectPath(rect: CGRect, radii: CornerRadii, shorterSide: CGFloat) -> CGPath {
        let radiusTopLeft = pixelCornerRadius(normalized: radii.topLeft, shorterSide: shorterSide)
        let radiusTopRight = pixelCornerRadius(normalized: radii.topRight, shorterSide: shorterSide)
        let radiusBottomLeft = pixelCornerRadius(
            normalized: radii.bottomLeft, shorterSide: shorterSide)
        let radiusBottomRight = pixelCornerRadius(
            normalized: radii.bottomRight, shorterSide: shorterSide)

        let path = CGMutablePath()
        // Start from top-left corner, moving clockwise
        // Top edge (from top-left to top-right)
        path.move(to: CGPoint(x: rect.minX + radiusTopLeft, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - radiusTopRight, y: rect.maxY))
        // Top-right corner
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - radiusTopRight),
            radius: radiusTopRight)
        // Right edge (top-right to bottom-right)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + radiusBottomRight))
        // Bottom-right corner
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX - radiusBottomRight, y: rect.minY),
            radius: radiusBottomRight)
        // Bottom edge (bottom-right to bottom-left)
        path.addLine(to: CGPoint(x: rect.minX + radiusBottomLeft, y: rect.minY))
        // Bottom-left corner
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX, y: rect.minY + radiusBottomLeft),
            radius: radiusBottomLeft)
        // Left edge (bottom-left to top-left)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radiusTopLeft))
        // Top-left corner
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX + radiusTopLeft, y: rect.maxY),
            radius: radiusTopLeft)
        path.closeSubpath()
        return path
    }

    /// 正規化された角丸半径をピクセル値に変換
    /// normalizedRadius 1.0 = 短辺の半分（最大丸み）
    static func pixelCornerRadius(normalized: CGFloat, shorterSide: CGFloat) -> CGFloat {
        let clamped = max(
            AppConstants.cornerRadiusMin, min(AppConstants.cornerRadiusMax, normalized))
        return clamped * shorterSide / 2
    }

    /// 角のドラッグハンドル位置を計算（角から対角線方向に内側へオフセット）
    static func cornerRadiusHandlePosition(
        corner: Corner, cropFrame: CGRect, normalizedRadius: CGFloat
    ) -> CGPoint {
        let shorterSide = min(cropFrame.width, cropFrame.height)
        let pixelRadius = pixelCornerRadius(normalized: normalizedRadius, shorterSide: shorterSide)
        switch corner {
        case .topLeft:
            return CGPoint(
                x: cropFrame.minX + pixelRadius,
                y: cropFrame.maxY - pixelRadius
            )
        case .topRight:
            return CGPoint(
                x: cropFrame.maxX - pixelRadius,
                y: cropFrame.maxY - pixelRadius
            )
        case .bottomLeft:
            return CGPoint(
                x: cropFrame.minX + pixelRadius,
                y: cropFrame.minY + pixelRadius
            )
        case .bottomRight:
            return CGPoint(
                x: cropFrame.maxX - pixelRadius,
                y: cropFrame.minY + pixelRadius
            )
        }
    }

    /// ドラッグ操作から正規化された角丸半径を算出
    static func cornerRadiusFromDrag(
        corner: Corner, cropFrame: CGRect, dragPoint: CGPoint
    ) -> CGFloat {
        let shorterSide = min(cropFrame.width, cropFrame.height)
        guard shorterSide > 0 else { return 0 }
        let halfShorter = shorterSide / 2

        let pixelDistance: CGFloat
        switch corner {
        case .topLeft:
            let deltaX = dragPoint.x - cropFrame.minX
            let deltaY = cropFrame.maxY - dragPoint.y
            pixelDistance = min(deltaX, deltaY)
        case .topRight:
            let deltaX = cropFrame.maxX - dragPoint.x
            let deltaY = cropFrame.maxY - dragPoint.y
            pixelDistance = min(deltaX, deltaY)
        case .bottomLeft:
            let deltaX = dragPoint.x - cropFrame.minX
            let deltaY = dragPoint.y - cropFrame.minY
            pixelDistance = min(deltaX, deltaY)
        case .bottomRight:
            let deltaX = cropFrame.maxX - dragPoint.x
            let deltaY = dragPoint.y - cropFrame.minY
            pixelDistance = min(deltaX, deltaY)
        }
        let normalized = pixelDistance / halfShorter
        return max(AppConstants.cornerRadiusMin, min(AppConstants.cornerRadiusMax, normalized))
    }

    /// 角丸ハンドルとリサイズハンドルの両方がヒットしたとき、角丸ハンドルを優先するか
    ///
    /// 近い方を優先する。ほぼ同じ距離（角丸半径がほぼ 0 でハンドルが角に重なる）のときは、
    /// クロップ枠の内側をクリックした場合だけ角丸を選び、外側からはリサイズできるようにする。
    static func prefersCornerRadiusHandle(
        radiusHandleDistance: CGFloat, resizeHandleDistance: CGFloat, isInsideCropFrame: Bool
    ) -> Bool {
        if abs(radiusHandleDistance - resizeHandleDistance) < AppConstants.floatingPointTolerance {
            return isInsideCropFrame
        }
        return radiusHandleDistance < resizeHandleDistance
    }

    /// クロップ領域のアスペクト比の向き
    enum AspectOrientation {
        case square, landscape, portrait
    }
}
// swiftlint:enable type_body_length
