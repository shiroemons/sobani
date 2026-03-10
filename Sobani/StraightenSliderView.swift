import Cocoa

/// 傾き補正スライダー（-45°〜+45°、目盛り付き）
@MainActor
final class StraightenSliderView: NSView {

    // MARK: - Constants

    private static let minAngle: CGFloat = -45
    private static let maxAngle: CGFloat = 45
    private static let majorTickInterval: CGFloat = 15
    private static let minorTickInterval: CGFloat = 5
    private static let tickHeight: CGFloat = 8
    private static let minorTickHeight: CGFloat = 4
    private static let indicatorSize: CGFloat = 12
    private static let trackHeight: CGFloat = 2
    private static let sidePadding: CGFloat = 20

    // MARK: - Properties

    var angle: CGFloat = 0 {
        didSet {
            angle = CropGeometry.clampStraightenAngle(angle)
            needsDisplay = true
        }
    }

    var onAngleChanged: ((CGFloat) -> Void)?
    private var isDragging = false
    private var dragStartAngle: CGFloat = 0
    private var dragStartX: CGFloat = 0

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let trackRect = trackArea()
        let centerY = trackRect.midY

        drawTrack(context: context, trackRect: trackRect, centerY: centerY)
        drawTicks(context: context, trackRect: trackRect, centerY: centerY)
        drawCenterLine(context: context, trackRect: trackRect, centerY: centerY)
        drawIndicator(context: context, trackRect: trackRect, centerY: centerY)
    }

    private func drawTrack(context: CGContext, trackRect: NSRect, centerY: CGFloat) {
        context.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
        context.setLineWidth(Self.trackHeight)
        context.move(to: CGPoint(x: trackRect.minX, y: centerY))
        context.addLine(to: CGPoint(x: trackRect.maxX, y: centerY))
        context.strokePath()
    }

    private func drawTicks(context: CGContext, trackRect: NSRect, centerY: CGFloat) {
        var tickAngle = Self.minAngle
        while tickAngle <= Self.maxAngle {
            let x = xForAngle(tickAngle, in: trackRect)
            let isMajor = abs(tickAngle.truncatingRemainder(dividingBy: Self.majorTickInterval)) < 0.1
            let height = isMajor ? Self.tickHeight : Self.minorTickHeight

            context.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
            context.setLineWidth(isMajor ? 1.0 : 0.5)
            context.move(to: CGPoint(x: x, y: centerY - height))
            context.addLine(to: CGPoint(x: x, y: centerY + height))
            context.strokePath()

            tickAngle += Self.minorTickInterval
        }
    }

    private func drawCenterLine(context: CGContext, trackRect: NSRect, centerY: CGFloat) {
        let zeroX = xForAngle(0, in: trackRect)
        context.setStrokeColor(NSColor.systemYellow.cgColor)
        context.setLineWidth(1.5)
        context.move(to: CGPoint(x: zeroX, y: centerY - Self.tickHeight - 2))
        context.addLine(to: CGPoint(x: zeroX, y: centerY + Self.tickHeight + 2))
        context.strokePath()
    }

    private func drawIndicator(context: CGContext, trackRect: NSRect, centerY: CGFloat) {
        let indicatorX = xForAngle(angle, in: trackRect)
        let halfSize = Self.indicatorSize / 2
        let indicatorRect = NSRect(
            x: indicatorX - halfSize, y: centerY - halfSize,
            width: Self.indicatorSize, height: Self.indicatorSize
        )
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: indicatorRect)

        drawAngleLabel(at: NSPoint(x: indicatorX, y: centerY - halfSize - 16))
    }

    private func drawAngleLabel(at point: NSPoint) {
        let text = String(format: "%.1f\u{00B0}", angle)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let size = attrString.size()
        let drawPoint = NSPoint(x: point.x - size.width / 2, y: point.y)
        attrString.draw(at: drawPoint)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isDragging = true
        dragStartAngle = angle
        dragStartX = point.x
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        let trackRect = trackArea()
        let deltaX = point.x - dragStartX
        let angleRange = Self.maxAngle - Self.minAngle
        let trackWidth = trackRect.width
        guard trackWidth > 0 else { return }
        let deltaAngle = (deltaX / trackWidth) * angleRange
        angle = CropGeometry.clampStraightenAngle(dragStartAngle + deltaAngle)
        onAngleChanged?(angle)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }

    // MARK: - Helpers

    func reset() {
        angle = 0
        onAngleChanged?(0)
    }

    private func trackArea() -> NSRect {
        NSRect(
            x: Self.sidePadding, y: bounds.height / 2 - 15,
            width: bounds.width - Self.sidePadding * 2, height: 30
        )
    }

    private func xForAngle(_ angle: CGFloat, in trackRect: NSRect) -> CGFloat {
        let range = Self.maxAngle - Self.minAngle
        let fraction = (angle - Self.minAngle) / range
        return trackRect.minX + fraction * trackRect.width
    }
}
