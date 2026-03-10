import Foundation

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

        return CropRect(
            x: x, y: y, width: w, height: h,
            straightenAngle: cropRect.straightenAngle,
            quarterTurns: normalizeQuarterTurns(cropRect.quarterTurns + turns),
            isFlippedInCrop: cropRect.isFlippedInCrop,
            aspectRatioPreset: cropRect.aspectRatioPreset
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

        return CropRect(
            x: x, y: y, width: w, height: h,
            straightenAngle: rect.straightenAngle,
            quarterTurns: rect.quarterTurns,
            isFlippedInCrop: rect.isFlippedInCrop,
            aspectRatioPreset: rect.aspectRatioPreset
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
        min(max(angle, -45), 45)
    }
}
