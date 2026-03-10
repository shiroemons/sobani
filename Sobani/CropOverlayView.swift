import Cocoa

// MARK: - CropRect

struct CropRect: Codable, Equatable, Sendable {
    let x: CGFloat       // 0.0〜1.0 ratio from left
    let y: CGFloat       // 0.0〜1.0 ratio from bottom
    let width: CGFloat   // 0.0〜1.0 ratio
    let height: CGFloat  // 0.0〜1.0 ratio

    static let full = Self(x: 0, y: 0, width: 1, height: 1)
}

// MARK: - CropOverlayView

@MainActor
final class CropOverlayView: NSView {

    // MARK: - Constants

    private static let handleSize: CGFloat = 8.0
    private static let handleHitTolerance: CGFloat = 12.0
    private static let minProportion: CGFloat = 0.1
    private static let overlayAlpha: CGFloat = 0.5

    // MARK: - Handle Position

    enum HandlePosition: CaseIterable {
        case topLeft, top, topRight
        case left, right
        case bottomLeft, bottom, bottomRight
    }

    // MARK: - Drag State

    private enum DragState {
        case idle
        case movingRect
        case resizingHandle(HandlePosition)
    }

    // MARK: - Properties

    var cropRect: CropRect = .full {
        didSet { needsDisplay = true }
    }

    var onCropRectChanged: ((CropRect) -> Void)?
    var onConfirm: ((CropRect) -> Void)?
    var onCancel: (() -> Void)?

    private var dragState: DragState = .idle
    private var dragStartPoint: NSPoint = .zero
    private var dragStartCropRect: CropRect = .full

    // MARK: - Initializers

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Key Handling

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let cropFrame = cropRectInViewCoords()

        // 1. Fill entire bounds with dark semi-transparent overlay
        context.setFillColor(NSColor.black.withAlphaComponent(Self.overlayAlpha).cgColor)
        context.fill(bounds)

        // 2. Clear the crop rectangle area
        context.setBlendMode(.clear)
        context.fill(cropFrame)

        // 3. Reset blend mode and draw white border around crop rect
        context.setBlendMode(.normal)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.0)
        context.stroke(cropFrame)

        // 4. Draw 8 handle squares
        context.setFillColor(NSColor.white.cgColor)
        for position in HandlePosition.allCases {
            let rect = handleRect(for: position)
            context.fill(rect)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStartPoint = point
        dragStartCropRect = cropRect

        // Check handles first (with hit tolerance)
        for position in HandlePosition.allCases {
            let rect = handleRect(for: position).insetBy(
                dx: -(Self.handleHitTolerance - Self.handleSize) / 2,
                dy: -(Self.handleHitTolerance - Self.handleSize) / 2
            )
            if rect.contains(point) {
                dragState = .resizingHandle(position)
                return
            }
        }

        // Check if inside crop rect
        let cropFrame = cropRectInViewCoords()
        if cropFrame.contains(point) {
            dragState = .movingRect
            return
        }

        dragState = .idle
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let deltaX = point.x - dragStartPoint.x
        let deltaY = point.y - dragStartPoint.y

        let viewWidth = bounds.width
        let viewHeight = bounds.height
        guard viewWidth > 0, viewHeight > 0 else { return }

        let normalizedDX = deltaX / viewWidth
        let normalizedDY = deltaY / viewHeight

        switch dragState {
        case .idle:
            break

        case .movingRect:
            let newX = clamp(dragStartCropRect.x + normalizedDX,
                             min: 0, max: 1 - dragStartCropRect.width)
            let newY = clamp(dragStartCropRect.y + normalizedDY,
                             min: 0, max: 1 - dragStartCropRect.height)
            cropRect = CropRect(x: newX, y: newY,
                                width: dragStartCropRect.width,
                                height: dragStartCropRect.height)
            onCropRectChanged?(cropRect)

        case .resizingHandle(let position):
            let updated = resizedCropRect(for: position,
                                          normalizedDX: normalizedDX,
                                          normalizedDY: normalizedDY)
            cropRect = updated
            onCropRectChanged?(cropRect)
        }
    }

    override func mouseUp(with event: NSEvent) {
        dragState = .idle
    }

    // MARK: - Handle Resize

    private func resizedCropRect(for position: HandlePosition,
                                 normalizedDX: CGFloat,
                                 normalizedDY: CGFloat) -> CropRect {
        let start = dragStartCropRect
        let minW = Self.minProportion
        let minH = Self.minProportion

        var newX = start.x
        var newY = start.y
        var newW = start.width
        var newH = start.height

        // Horizontal adjustment
        switch position {
        case .topLeft, .left, .bottomLeft:
            // Moving left edge
            let maxDX = start.width - minW
            let clampedDX = clamp(normalizedDX, min: -start.x, max: maxDX)
            newX = start.x + clampedDX
            newW = start.width - clampedDX
        case .topRight, .right, .bottomRight:
            // Moving right edge
            let maxExpand = 1 - start.x - start.width
            let clampedDX = clamp(normalizedDX, min: -(start.width - minW), max: maxExpand)
            newW = start.width + clampedDX
        case .top, .bottom:
            break
        }

        // Vertical adjustment
        switch position {
        case .bottomLeft, .bottom, .bottomRight:
            // Moving bottom edge
            let maxDY = start.height - minH
            let clampedDY = clamp(normalizedDY, min: -start.y, max: maxDY)
            newY = start.y + clampedDY
            newH = start.height - clampedDY
        case .topLeft, .top, .topRight:
            // Moving top edge
            let maxExpand = 1 - start.y - start.height
            let clampedDY = clamp(normalizedDY, min: -(start.height - minH), max: maxExpand)
            newH = start.height + clampedDY
        case .left, .right:
            break
        }

        // Enforce minimums and bounds
        newW = max(newW, minW)
        newH = max(newH, minH)
        newX = clamp(newX, min: 0, max: 1 - newW)
        newY = clamp(newY, min: 0, max: 1 - newH)

        return CropRect(x: newX, y: newY, width: newW, height: newH)
    }

    // MARK: - Coordinate Helpers

    private func cropRectInViewCoords() -> NSRect {
        NSRect(
            x: cropRect.x * bounds.width,
            y: cropRect.y * bounds.height,
            width: cropRect.width * bounds.width,
            height: cropRect.height * bounds.height
        )
    }

    private func viewPointToCropPoint(_ point: NSPoint) -> NSPoint {
        NSPoint(
            x: bounds.width > 0 ? point.x / bounds.width : 0,
            y: bounds.height > 0 ? point.y / bounds.height : 0
        )
    }

    private func handleRect(for position: HandlePosition) -> NSRect {
        let cropFrame = cropRectInViewCoords()
        let size = Self.handleSize
        let halfSize = size / 2

        let centerX: CGFloat
        let centerY: CGFloat

        switch position {
        case .topLeft:
            centerX = cropFrame.minX
            centerY = cropFrame.maxY
        case .top:
            centerX = cropFrame.midX
            centerY = cropFrame.maxY
        case .topRight:
            centerX = cropFrame.maxX
            centerY = cropFrame.maxY
        case .left:
            centerX = cropFrame.minX
            centerY = cropFrame.midY
        case .right:
            centerX = cropFrame.maxX
            centerY = cropFrame.midY
        case .bottomLeft:
            centerX = cropFrame.minX
            centerY = cropFrame.minY
        case .bottom:
            centerX = cropFrame.midX
            centerY = cropFrame.minY
        case .bottomRight:
            centerX = cropFrame.maxX
            centerY = cropFrame.minY
        }

        return NSRect(x: centerX - halfSize, y: centerY - halfSize,
                       width: size, height: size)
    }

    // MARK: - Utility

    private func clamp(_ value: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minVal), maxVal)
    }
}
