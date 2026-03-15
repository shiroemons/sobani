import SwiftUI

struct CropOverlayPreviewView: View {
    let originalImage: NSImage
    let cropRect: CropRect

    // MARK: - Computed Properties

    private var imageAspectRatio: CGFloat {
        let size = originalImage.size
        guard size.height > 0 else { return 1 }
        return size.width / size.height
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let imageSize = geometry.size
            let frame = cropFrame(in: imageSize)
            ZStack {
                // Base: original image
                Image(nsImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Dark overlay with crop area cut out
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .fill()
                            .overlay(
                                cropShapeView(frame: frame)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )

                // Thin border around crop area
                cropShapeView(frame: frame, stroke: true)
            }
        }
        .aspectRatio(imageAspectRatio, contentMode: .fit)
    }

    // MARK: - Crop Frame

    private func cropFrame(in size: CGSize) -> CGRect {
        let swiftUIY = 1.0 - cropRect.y - cropRect.height
        return CGRect(
            x: cropRect.x * size.width,
            y: swiftUIY * size.height,
            width: cropRect.width * size.width,
            height: cropRect.height * size.height
        )
    }

    // MARK: - Crop Shape

    @ViewBuilder
    private func cropShapeView(frame: CGRect, stroke: Bool = false) -> some View {
        Group {
            switch cropRect.shape {
            case .rectangle:
                if stroke {
                    Rectangle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                } else {
                    Rectangle()
                }
            case .circle:
                if stroke {
                    Ellipse()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                } else {
                    Ellipse()
                }
            case .roundedRectangle:
                if stroke {
                    RoundedRectangle(cornerRadius: cropRect.cornerRadii.topLeft)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: cropRect.cornerRadii.topLeft)
                }
            }
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
    }
}
