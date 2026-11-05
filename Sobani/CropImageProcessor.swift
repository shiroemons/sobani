import Cocoa
import os.log

/// クロップ確定時の画像処理ロジック
///
/// 90° 回転・反転・パース補正・傾き補正・切り出し・形状マスクを、`CropGeometry.imageTransform`
/// （エディタのキャンバスと共通の変換）による 1 回の描画でまとめて適用する。
/// 中間ビットマップを作らず、再サンプリングも 1 回で済む。
enum CropImageProcessor {

    private static let logger = Logger(category: "CropImageProcessor")

    /// 出力画像 1 辺の上限（ピクセル）。壊れた CropRect で巨大なメモリを確保しないようにする
    private static let maxOutputPixelDimension: CGFloat = 32_768
    private static let bitsPerComponent = 8

    /// CropRectの全変換を適用して切り出した画像を返す
    /// - Parameters:
    ///   - image: 元画像のCGImage
    ///   - cropRect: 適用するCropRect
    ///   - maxOutputPixelSize: 指定すると出力の長辺がこの値以下になるよう縮小して描画する（サムネイル用）
    /// - Returns: 処理済みのCGImage、または失敗時nil
    static func applyFullCrop(
        to image: CGImage, cropRect: CropRect, maxOutputPixelSize: CGFloat? = nil
    ) -> CGImage? {
        let sourceSize = CGSize(width: image.width, height: image.height)
        let effectiveSize = CropGeometry.effectiveSize(sourceSize, quarterTurns: cropRect.quarterTurns)
        let cropSize = CGSize(
            width: cropRect.width * effectiveSize.width,
            height: cropRect.height * effectiveSize.height
        )
        let scale = outputScale(cropSize: cropSize, maxOutputPixelSize: maxOutputPixelSize)

        guard let outputWidth = CropGeometry.pixelExtent(
                cropSize.width * scale, limit: maxOutputPixelDimension),
              let outputHeight = CropGeometry.pixelExtent(
                cropSize.height * scale, limit: maxOutputPixelDimension) else {
            logger.error(
                "Invalid crop output size for rect=(\(cropRect.x), \(cropRect.y), \(cropRect.width), \(cropRect.height))"
            )
            return nil
        }

        // 変換なし・矩形・等倍で画像内に収まる場合は再サンプリングせずに切り出す
        if scale >= 1, cropRect.shape == .rectangle, !cropRect.hasImageTransform,
           let cropped = croppedWithoutResampling(image, cropRect: cropRect) {
            return cropped
        }

        guard let context = makeBitmapContext(
            width: outputWidth, height: outputHeight, preferredColorSpace: image.colorSpace
        ) else {
            logger.error("CGContext creation failed for \(outputWidth)x\(outputHeight)")
            return nil
        }

        // 画像外・形状外は透明のまま残す
        let outputRect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
        context.clear(outputRect)
        context.interpolationQuality = .high
        if cropRect.shape != .rectangle {
            context.addPath(
                CropGeometry.shapePath(cropRect.shape, in: outputRect, radii: cropRect.cornerRadii)
            )
            context.clip()
        }

        let imageRect = CropGeometry.outputImageRect(
            for: cropRect, effectiveSize: effectiveSize, scale: scale
        )
        context.concatenate(
            CropGeometry.imageTransform(for: cropRect, sourceSize: sourceSize, imageRect: imageRect)
        )
        context.draw(image, in: CGRect(origin: .zero, size: sourceSize))
        return context.makeImage()
    }

    /// 8bit・premultiplied RGBA のビットマップコンテキストを生成する
    /// 色空間は RGB なら元画像のもの（広色域を保つ）、それ以外や生成に失敗した場合は sRGB を使う
    static func makeBitmapContext(
        width: Int, height: Int, preferredColorSpace: CGColorSpace? = nil
    ) -> CGContext? {
        let candidates = [preferredColorSpace, CGColorSpace(name: CGColorSpace.sRGB)]
            .compactMap { $0 }
            .filter { $0.model == .rgb }
        for colorSpace in candidates {
            if let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: bitsPerComponent, bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                return context
            }
        }
        return nil
    }

    // MARK: - Private

    private static func outputScale(cropSize: CGSize, maxOutputPixelSize: CGFloat?) -> CGFloat {
        guard let maxSize = maxOutputPixelSize, maxSize > 0 else { return 1 }
        let longestSide = max(cropSize.width, cropSize.height)
        guard longestSide.isFinite, longestSide > maxSize else { return 1 }
        return maxSize / longestSide
    }

    /// 変換を伴わない切り出し。クロップ領域が画像内に完全に収まる場合のみ結果を返す
    private static func croppedWithoutResampling(_ image: CGImage, cropRect: CropRect) -> CGImage? {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let cropX = CropGeometry.snappedToPixel(cropRect.x * imageWidth)
        let cropY = CropGeometry.snappedToPixel(cropRect.y * imageHeight)
        let cropW = CropGeometry.snappedToPixel(cropRect.width * imageWidth)
        let cropH = CropGeometry.snappedToPixel(cropRect.height * imageHeight)
        guard cropX >= 0, cropY >= 0,
              CropGeometry.snappedToPixel(cropX + cropW) <= imageWidth,
              CropGeometry.snappedToPixel(cropY + cropH) <= imageHeight else {
            return nil
        }
        // Y軸反転（CropRectはbottom-up、CGImageはtop-down）
        return image.cropping(to: CGRect(
            x: cropX, y: imageHeight - cropY - cropH, width: cropW, height: cropH
        ))
    }
}
