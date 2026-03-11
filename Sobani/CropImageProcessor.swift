import Cocoa
import os.log

/// クロップ確定時の画像処理ロジック
/// 処理順序: quarterTurns回転 → isFlippedInCrop反転 → (傾き補正+クロップ統合 or クロップのみ)
enum CropImageProcessor {

    private static let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: "CropImageProcessor")

    // MARK: - Context Helpers

    /// CGImage から安全に CGContext を生成する
    /// image.colorSpace が nil の場合は sRGB にフォールバックし、
    /// bitmapInfo の互換性問題も premultiplied RGBA で回避する
    private static func createContext(
        width: Int, height: Int, source image: CGImage
    ) -> CGContext? {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        // 元画像の bitmapInfo をそのまま使うと CGContext 生成に失敗する場合がある
        // (例: indexed color, unusual alpha configurations)
        // まず元画像の設定で試し、失敗したら安全な設定にフォールバック
        if let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0, space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) {
            return ctx
        }
        logger.warning("CGContext creation failed with original bitmapInfo \(image.bitmapInfo.rawValue), falling back to premultiplied RGBA")
        return CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    /// CropRectの全変換を適用して切り出した画像を返す
    /// - Parameters:
    ///   - image: 元画像のCGImage
    ///   - cropRect: 適用するCropRect
    /// - Returns: 処理済みのCGImage、または失敗時nil
    static func applyFullCrop(to image: CGImage, cropRect: CropRect) -> CGImage? {
        var current = image

        // 1. quarterTurns回転（90°単位）
        if cropRect.quarterTurns > 0 {
            guard let rotated = applyQuarterTurns(to: current, turns: cropRect.quarterTurns) else {
                logger.error("applyQuarterTurns failed for turns=\(cropRect.quarterTurns)")
                return nil
            }
            current = rotated
        }

        // 2. isFlippedInCrop反転
        if cropRect.isFlippedInCrop {
            guard let flipped = applyHorizontalFlip(to: current) else {
                logger.error("applyHorizontalFlip failed")
                return nil
            }
            current = flipped
        }

        // 3+4. 傾き補正 + クロップ（統合処理）
        if abs(cropRect.straightenAngle) > AppConstants.floatingPointTolerance {
            let result = applyStraightenAndCrop(
                to: current, angleDegrees: cropRect.straightenAngle, cropRect: cropRect
            )
            if result == nil {
                logger.error("applyStraightenAndCrop failed")
            }
            return result
        }

        // 傾き補正なし: クロップのみ
        let result = applyCropRect(to: current, cropRect: cropRect)
        if result == nil {
            logger.error("applyCropRect failed for rect=(\(cropRect.x), \(cropRect.y), \(cropRect.width), \(cropRect.height))")
        }
        return result
    }

    /// 90°単位の回転を適用
    static func applyQuarterTurns(to image: CGImage, turns: Int) -> CGImage? {
        let normalizedTurns = CropGeometry.normalizeQuarterTurns(turns)
        guard normalizedTurns > 0 else { return image }

        let width = image.width
        let height = image.height

        let newWidth: Int
        let newHeight: Int
        if normalizedTurns % 2 == 1 {
            newWidth = height
            newHeight = width
        } else {
            newWidth = width
            newHeight = height
        }

        guard let context = createContext(width: newWidth, height: newHeight, source: image) else {
            return nil
        }

        // 回転変換を適用
        switch normalizedTurns {
        case 1: // 90° 反時計回り (CGContext座標系では時計回り)
            context.translateBy(x: 0, y: CGFloat(newHeight))
            context.rotate(by: -.pi / 2)
        case 2: // 180°
            context.translateBy(x: CGFloat(newWidth), y: CGFloat(newHeight))
            context.rotate(by: .pi)
        case 3: // 270° 反時計回り
            context.translateBy(x: CGFloat(newWidth), y: 0)
            context.rotate(by: .pi / 2)
        default:
            break
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// 水平反転を適用
    static func applyHorizontalFlip(to image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height

        guard let context = createContext(width: width, height: height, source: image) else {
            return nil
        }

        context.translateBy(x: CGFloat(width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// 傾き補正（回転のみ、空白部分は透過）を適用
    static func applyStraighten(to image: CGImage, angleDegrees: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        let radians = angleDegrees * .pi / 180
        let boundingBox = GeometryUtils.rotatedBoundingBox(
            width: width, height: height, angleDegrees: angleDegrees
        )

        let bbWidth = Int(ceil(boundingBox.width))
        let bbHeight = Int(ceil(boundingBox.height))

        // アルファチャンネル付きコンテキストで透過背景を確保する
        guard let context = CGContext(
            data: nil, width: bbWidth, height: bbHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // 背景を透明にクリア
        let rect = CGRect(x: 0, y: 0, width: bbWidth, height: bbHeight)
        context.clear(rect)

        let centerX = CGFloat(bbWidth) / 2
        let centerY = CGFloat(bbHeight) / 2

        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: -radians)
        context.translateBy(x: -width / 2, y: -height / 2)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 中央からオリジナルサイズで切り出し（空白部分は透過）
        guard let fullImage = context.makeImage() else { return nil }
        let intWidth = Int(width)
        let intHeight = Int(height)
        let cropX = (bbWidth - intWidth) / 2
        let cropY = (bbHeight - intHeight) / 2
        let cropCGRect = CGRect(x: cropX, y: cropY, width: intWidth, height: intHeight)
        return fullImage.cropping(to: cropCGRect)
    }

    /// 傾き補正とクロップを統合して実行
    /// エディタのプレビューと同じ結果を生成するため、回転と切り出しを1ステップで処理
    static func applyStraightenAndCrop(
        to image: CGImage, angleDegrees: CGFloat, cropRect: CropRect
    ) -> CGImage? {
        let imgW = CGFloat(image.width)
        let imgH = CGFloat(image.height)

        let cropPixelW = cropRect.width * imgW
        let cropPixelH = cropRect.height * imgH
        let intW = Int(ceil(cropPixelW))
        let intH = Int(ceil(cropPixelH))
        guard intW > 0, intH > 0 else { return nil }

        guard let context = CGContext(
            data: nil, width: intW, height: intH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.clear(CGRect(x: 0, y: 0, width: intW, height: intH))

        // クロップ領域の中心（画像ピクセル座標）
        let cropCenterX = cropRect.x * imgW + cropPixelW / 2
        let cropCenterY = cropRect.y * imgH + cropPixelH / 2

        // 画像の中心
        let imgCenterX = imgW / 2
        let imgCenterY = imgH / 2

        // エディタと同じ変換を再現:
        // 1. コンテキストの原点をクロップ領域の中心に設定
        context.translateBy(x: CGFloat(intW) / 2, y: CGFloat(intH) / 2)

        // 2. 画像中心をクロップ中心からの相対位置に移動
        context.translateBy(x: imgCenterX - cropCenterX, y: imgCenterY - cropCenterY)

        // 3. 画像中心を軸に回転
        let radians = angleDegrees * .pi / 180
        context.rotate(by: -radians)

        // 4. 画像を中心基準で描画
        context.draw(image, in: CGRect(x: -imgW / 2, y: -imgH / 2, width: imgW, height: imgH))

        return context.makeImage()
    }

    /// 正規化座標のクロップ矩形で切り出し
    /// クロップ領域が画像外にはみ出す場合、空白部分は透過（alpha=0）になる
    static func applyCropRect(to image: CGImage, cropRect: CropRect) -> CGImage? {
        let imgWidth = CGFloat(image.width)
        let imgHeight = CGFloat(image.height)
        let cropX = cropRect.x * imgWidth
        let cropY = cropRect.y * imgHeight
        let cropW = cropRect.width * imgWidth
        let cropH = cropRect.height * imgHeight

        let intCropW = Int(ceil(cropW))
        let intCropH = Int(ceil(cropH))
        guard intCropW > 0, intCropH > 0 else { return nil }

        // クロップ領域が完全に画像内に収まる場合は高速パスを使用
        let isFullyInside = cropX >= 0
            && cropY >= 0
            && (cropX + cropW) <= imgWidth
            && (cropY + cropH) <= imgHeight

        if isFullyInside {
            // Y軸反転（CropRectはbottom-up、CGImageはtop-down）
            let cropCGRect = CGRect(
                x: cropX, y: imgHeight - cropY - cropH,
                width: cropW, height: cropH
            )
            return image.cropping(to: cropCGRect)
        }

        // クロップ領域が画像外にはみ出す場合：透過背景のコンテキストに描画
        guard let context = CGContext(
            data: nil, width: intCropW, height: intCropH,
            bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // 背景を透明にクリア
        context.clear(CGRect(x: 0, y: 0, width: intCropW, height: intCropH))

        // 画像をクロップ座標系で配置（Y軸反転を考慮）
        // コンテキスト原点 = クロップ領域の左下
        // 画像の左下 = コンテキスト上で (-cropX, -cropY)
        let drawX = -cropX
        let drawY = -(imgHeight - cropY - cropH)
        context.draw(image, in: CGRect(x: drawX, y: drawY, width: imgWidth, height: imgHeight))

        return context.makeImage()
    }
}
