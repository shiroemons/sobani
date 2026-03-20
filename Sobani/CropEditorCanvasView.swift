import Cocoa
import QuartzCore

// MARK: - Crop Editor Canvas View

@MainActor
final class CropEditorCanvasView: NSView {

    // MARK: - Constants

    static let handleHitTolerance: CGFloat = 14
    static let minZoom: CGFloat = 1.0
    static let maxZoom: CGFloat = 10.0
    static let zoomSensitivity: CGFloat = 0.02
    static let perspectiveDepth: CGFloat = -1.0 / 500.0

    // MARK: - Handle Position

    enum HandlePosition: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    // MARK: - Drag State

    enum DragState {
        case idle
        case movingImage
        case resizingHandle(HandlePosition)
        case adjustingCornerRadius(CropGeometry.Corner)
    }

    // MARK: - Properties

    var cropRect: CropRect = .full {
        didSet {
            guard cropRect != oldValue else { return }
            needsDisplay = true
        }
    }
    var onCropRectChanged: ((CropRect) -> Void)?
    var onDragEnded: (() -> Void)?
    private(set) var displayImage: NSImage?

    var imageOffset: CGPoint = .zero
    var imageZoom: CGFloat = 1.0
    var dragState: DragState = .idle
    var dragStartPoint: NSPoint = .zero
    var dragStartCropRect: CropRect = .full
    var dragStartImageOffset: CGPoint = .zero
    var dragStartCropFrame: NSRect = .zero
    var activeDragCropFrame: NSRect?
    var dragStartImageDrawRect: NSRect = .zero

    var cropShape: CropShape { cropRect.shape }
    var cornerRadii: CornerRadii { cropRect.cornerRadii }
    var cornersLinked: Bool { cropRect.cornersLinked }

    // MARK: - Setup

    func setImage(_ image: NSImage) {
        displayImage = image
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)

        let cropFrame: NSRect
        let imgDrawRect: NSRect
        if let activeDrag = activeDragCropFrame {
            cropFrame = activeDrag
            imgDrawRect = dragStartImageDrawRect
        } else {
            cropFrame = calculateCropFrameRect()
            imgDrawRect = calculateImageDrawRect(cropFrame: cropFrame)
        }
        guard cropFrame.width > 0, cropFrame.height > 0 else { return }

        // 形状パスを一度だけ計算
        let shapePath: CGPath?
        switch cropShape {
        case .rectangle:
            shapePath = nil
        case .circle:
            let path = CGMutablePath()
            path.addEllipse(in: cropFrame)
            shapePath = path
        case .roundedRectangle:
            let shorterSide = min(cropFrame.width, cropFrame.height)
            shapePath = CropGeometry.roundedRectPath(
                rect: cropFrame, radii: cornerRadii, shorterSide: shorterSide
            )
        }

        // 画像がキャンバス領域外に描画されないようクリッピング
        context.saveGState()
        context.clip(to: bounds)
        drawTransformedImage(context: context, imageDrawRect: imgDrawRect)
        context.restoreGState()
        drawOverlay(context: context, cropFrame: cropFrame, shapePath: shapePath)
        drawCropBorder(context: context, cropFrame: cropFrame, shapePath: shapePath)
        drawGrid(context: context, cropFrame: cropFrame)
        drawHandles(context: context, cropFrame: cropFrame)
        if cropShape == .roundedRectangle {
            drawCornerRadiusHandles(context: context, cropFrame: cropFrame)
        }
    }

    // MARK: - Coordinate Helpers

    func handleCornerPoint(
        for position: HandlePosition, cropFrame: NSRect
    ) -> NSPoint {
        switch position {
        case .topLeft: return NSPoint(x: cropFrame.minX, y: cropFrame.maxY)
        case .topRight: return NSPoint(x: cropFrame.maxX, y: cropFrame.maxY)
        case .bottomLeft: return NSPoint(x: cropFrame.minX, y: cropFrame.minY)
        case .bottomRight: return NSPoint(x: cropFrame.maxX, y: cropFrame.minY)
        case .top: return NSPoint(x: cropFrame.midX, y: cropFrame.maxY)
        case .bottom: return NSPoint(x: cropFrame.midX, y: cropFrame.minY)
        case .left: return NSPoint(x: cropFrame.minX, y: cropFrame.midY)
        case .right: return NSPoint(x: cropFrame.maxX, y: cropFrame.midY)
        }
    }

    // MARK: - Final Crop Rect

    /// 現在のズーム/オフセット状態から最終的な正規化 CropRect を計算
    func computeFinalCropRect() -> CropRect {
        let cropFrame = calculateCropFrameRect()
        let imgRect = calculateImageDrawRect(cropFrame: cropFrame)
        guard imgRect.width > 0, imgRect.height > 0 else { return cropRect }

        let normalized = CropGeometry.viewRectToNormalizedCrop(
            cropFrame: cropFrame, imageRect: imgRect
        )

        return cropRect.with(
            x: normalized.x, y: normalized.y,
            width: normalized.width, height: normalized.height
        )
    }

    // MARK: - State Initialization

    /// 既存の CropRect からズーム/オフセットの初期状態を復元する
    func initializeFromCropRect(_ rect: CropRect) {
        cropRect = rect
        imageZoom = Self.minZoom
        recalculateImageOffset()
        needsDisplay = true
    }

    /// cropRect変更後に imageOffset を再計算（ズームは維持）
    func recalculateImageOffset() {
        let cropFrame = calculateCropFrameRect()
        guard cropFrame.width > 0, cropFrame.height > 0,
              cropRect.width > AppConstants.floatingPointTolerance,
              cropRect.height > AppConstants.floatingPointTolerance else {
            imageOffset = .zero
            return
        }
        let baseWidth = cropFrame.width / cropRect.width
        let baseHeight = cropFrame.height / cropRect.height
        let offsetX = baseWidth * (0.5 - cropRect.x) - cropFrame.width / 2
        let offsetY = baseHeight * (0.5 - cropRect.y) - cropFrame.height / 2
        imageOffset = CGPoint(x: offsetX, y: offsetY)
    }

    /// ズーム/オフセットをリセットする
    func resetZoomAndOffset() {
        imageZoom = Self.minZoom
        imageOffset = .zero
        needsDisplay = true
    }
}

// MARK: - Crop Frame & Image Rect Calculation

extension CropEditorCanvasView {

    /// クロップ枠をキャンバス中央に配置
    func calculateCropFrameRect() -> NSRect {
        guard let image = displayImage, image.size.width > 0, image.size.height > 0 else {
            return .zero
        }
        let imageSize = image.size
        let normalizedTurns = CropGeometry.normalizeQuarterTurns(cropRect.quarterTurns)
        let isSwapped = (normalizedTurns == 1 || normalizedTurns == 3)
        let effectiveWidth = isSwapped ? imageSize.height : imageSize.width
        let effectiveHeight = isSwapped ? imageSize.width : imageSize.height

        // クロップ領域のアスペクト比を計算
        let cropAspect = (cropRect.width * effectiveWidth)
            / max(cropRect.height * effectiveHeight, AppConstants.floatingPointTolerance)

        let availableRect = bounds.insetBy(
            dx: AppConstants.cropEditorCanvasPadding, dy: AppConstants.cropEditorCanvasPadding
        )
        guard availableRect.width > 0, availableRect.height > 0 else { return .zero }

        let frameWidth: CGFloat
        let frameHeight: CGFloat
        if cropAspect > availableRect.width / availableRect.height {
            frameWidth = availableRect.width
            frameHeight = frameWidth / cropAspect
        } else {
            frameHeight = availableRect.height
            frameWidth = frameHeight * cropAspect
        }

        return NSRect(
            x: availableRect.midX - frameWidth / 2,
            y: availableRect.midY - frameHeight / 2,
            width: frameWidth,
            height: frameHeight
        )
    }

    /// ズームとオフセットを考慮した画像の描画レクトを計算
    func calculateImageDrawRect(cropFrame: NSRect) -> NSRect {
        guard let image = displayImage, image.size.width > 0, image.size.height > 0 else {
            return .zero
        }

        // zoom=1.0でクロップ枠にちょうど画像全体が収まるスケールを基準にする
        let baseWidth = cropFrame.width / max(cropRect.width, AppConstants.floatingPointTolerance)
        let baseHeight = cropFrame.height
            / max(cropRect.height, AppConstants.floatingPointTolerance)

        let drawWidth = baseWidth * imageZoom
        let drawHeight = baseHeight * imageZoom

        // 画像中心 = クロップ枠中心 + オフセット
        let centerX = cropFrame.midX + imageOffset.x
        let centerY = cropFrame.midY + imageOffset.y

        return NSRect(
            x: centerX - drawWidth / 2,
            y: centerY - drawHeight / 2,
            width: drawWidth,
            height: drawHeight
        )
    }

}
