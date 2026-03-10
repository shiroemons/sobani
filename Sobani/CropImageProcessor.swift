import Cocoa
import os.log

/// クロップ確定時の画像処理ロジック
/// 処理順序: quarterTurns回転 → isFlippedInCrop反転 → straightenAngle傾き補正 → クロップ矩形で切り出し
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

        // 3. straightenAngle傾き補正 + 自動ズーム
        if abs(cropRect.straightenAngle) > AppConstants.floatingPointTolerance {
            guard let straightened = applyStraighten(
                to: current, angleDegrees: cropRect.straightenAngle
            ) else {
                logger.error("applyStraighten failed for angle=\(cropRect.straightenAngle)")
                return nil
            }
            current = straightened
        }

        // 4. クロップ矩形で切り出し
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

    /// 傾き補正（回転 + 自動ズーム）を適用
    static func applyStraighten(to image: CGImage, angleDegrees: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let aspectRatio = width / height
        let zoomScale = CropGeometry.zoomScaleForStraighten(
            angleDegrees: angleDegrees, aspectRatio: aspectRatio
        )

        let scaledWidth = width * zoomScale
        let scaledHeight = height * zoomScale

        let radians = angleDegrees * .pi / 180
        let boundingBox = GeometryUtils.rotatedBoundingBox(
            width: scaledWidth, height: scaledHeight, angleDegrees: angleDegrees
        )

        let bbWidth = Int(ceil(boundingBox.width))
        let bbHeight = Int(ceil(boundingBox.height))

        guard let context = createContext(width: bbWidth, height: bbHeight, source: image) else {
            return nil
        }

        let centerX = CGFloat(bbWidth) / 2
        let centerY = CGFloat(bbHeight) / 2

        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: -radians)
        context.scaleBy(x: zoomScale, y: zoomScale)
        context.translateBy(x: -width / 2, y: -height / 2)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 中央からオリジナルサイズで切り出し
        guard let fullImage = context.makeImage() else { return nil }
        let cropX = (CGFloat(bbWidth) - width) / 2
        let cropY = (CGFloat(bbHeight) - height) / 2
        let cropCGRect = CGRect(x: cropX, y: cropY, width: width, height: height)
        return fullImage.cropping(to: cropCGRect)
    }

    /// 正規化座標のクロップ矩形で切り出し
    static func applyCropRect(to image: CGImage, cropRect: CropRect) -> CGImage? {
        let imgWidth = CGFloat(image.width)
        let imgHeight = CGFloat(image.height)
        let cropX = cropRect.x * imgWidth
        let cropY = cropRect.y * imgHeight
        let cropW = cropRect.width * imgWidth
        let cropH = cropRect.height * imgHeight
        // Y軸反転（CropRectはbottom-up、CGImageはtop-down）
        let cropCGRect = CGRect(
            x: cropX, y: imgHeight - cropY - cropH,
            width: cropW, height: cropH
        )
        guard cropW > 0, cropH > 0 else { return nil }
        return image.cropping(to: cropCGRect)
    }
}
