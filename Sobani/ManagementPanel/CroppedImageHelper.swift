import AppKit

enum CroppedImageHelper {
    static func croppedImage(from original: NSImage, cropRect: CropRect?) -> NSImage {
        guard let cropRect else { return original }

        guard let cgImage = original.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return original
        }

        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)

        // Convert normalized coordinates to pixel coordinates
        // CropRect uses macOS coordinate system (origin at bottom-left)
        // CGImage cropping uses top-left origin, so flip Y
        let cropX = cropRect.x * pixelWidth
        let cropW = cropRect.width * pixelWidth
        let cropH = cropRect.height * pixelHeight
        let cropY = (1.0 - cropRect.y - cropRect.height) * pixelHeight

        let pixelRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
            .intersection(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        guard !pixelRect.isEmpty, let croppedCG = cgImage.cropping(to: pixelRect) else {
            return original
        }

        let croppedImage = NSImage(cgImage: croppedCG, size: NSSize(width: croppedCG.width, height: croppedCG.height))

        // Apply crop shape masking
        switch cropRect.shape {
        case .rectangle:
            return croppedImage
        case .circle:
            return applyShapeMask(to: croppedImage) { rect in
                NSBezierPath(ovalIn: rect)
            }
        case .roundedRectangle:
            let radius = cropRect.cornerRadii.topLeft * CGFloat(croppedCG.width)
            return applyShapeMask(to: croppedImage) { rect in
                NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            }
        }
    }

    private static func applyShapeMask(
        to image: NSImage,
        pathBuilder: (NSRect) -> NSBezierPath
    ) -> NSImage {
        let size = image.size
        let result = NSImage(size: size)
        result.lockFocus()
        let path = pathBuilder(NSRect(origin: .zero, size: size))
        path.addClip()
        image.draw(in: NSRect(origin: .zero, size: size))
        result.unlockFocus()
        return result
    }
}
