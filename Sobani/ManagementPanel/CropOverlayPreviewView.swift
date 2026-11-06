import SwiftUI

struct CropOverlayPreviewView: View {
    let originalImage: NSImage
    let cropRect: CropRect
    /// クロップ結果のキャッシュキーに使う画像名。nil の場合は画像オブジェクトから生成する
    var imageName: String?

    private static let strokeOpacity: CGFloat = 0.8
    private static let strokeWidth: CGFloat = 1

    // MARK: - Computed Properties

    private var imageAspectRatio: CGFloat {
        let size = originalImage.size
        guard size.height > 0 else { return 1 }
        return size.width / size.height
    }

    private var cacheName: String {
        if let imageName { return imageName }
        let size = originalImage.size
        return "overlay-preview-\(ObjectIdentifier(originalImage))-\(size.width)x\(size.height)"
    }

    // MARK: - Body

    var body: some View {
        if cropRect.hasImageTransform {
            // 回転・反転・傾き補正があると cropRect は変換後の座標系なので、元画像に枠を重ねても位置が合わない。
            // ウィンドウに表示されるのと同じクロップ結果を表示する
            Image(nsImage: CroppedImageHelper.croppedImage(
                from: originalImage, cropRect: cropRect, imageName: cacheName
            ))
            .resizable()
            .scaledToFit()
        } else {
            overlayPreview
        }
    }

    private var overlayPreview: some View {
        ZStack {
            // Base: original image
            Image(nsImage: originalImage)
                .resizable()
                .scaledToFit()

            // Dark overlay with crop area cut out
            Color.black.opacity(AppConstants.cropOverlayAlpha)
                .mask(
                    Rectangle()
                        .fill()
                        .overlay(
                            CropShapeOutline(cropRect: cropRect)
                                .fill()
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )

            // Thin border around crop area
            CropShapeOutline(cropRect: cropRect)
                .stroke(Color.white.opacity(Self.strokeOpacity), lineWidth: Self.strokeWidth)
        }
        .aspectRatio(imageAspectRatio, contentMode: .fit)
        // 画像外まで広がるクロップ枠がはみ出さないようにする
        .clipped()
    }
}

// MARK: - Crop Shape Outline

/// クロップ形状（実際の角丸半径を含む）を、エディタ・出力処理と共通のパスで描く Shape
private struct CropShapeOutline: Shape {
    let cropRect: CropRect

    func path(in rect: CGRect) -> Path {
        // CropRect と CropGeometry は y 軸上向き（原点左下）なので、SwiftUI の座標系（原点左上）へ上下反転して写す
        let frame = CGRect(
            x: cropRect.x * rect.width,
            y: cropRect.y * rect.height,
            width: cropRect.width * rect.width,
            height: cropRect.height * rect.height
        )
        let shapePath = CropGeometry.shapePath(cropRect.shape, in: frame, radii: cropRect.cornerRadii)
        let flipToTopLeftOrigin = CGAffineTransform(
            a: 1, b: 0, c: 0, d: -1, tx: rect.minX, ty: rect.maxY
        )
        return Path(shapePath).applying(flipToTopLeftOrigin)
    }
}
