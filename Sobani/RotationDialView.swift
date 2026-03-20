import Cocoa

// MARK: - Rotation Dial View

@MainActor
final class RotationDialView: NSView {
    private static let outerPadding: CGFloat = 4
    private static let tickInnerOffset: CGFloat = 6
    private static let tickOuterOffset: CGFloat = 1
    private static let indicatorInset: CGFloat = 8
    private static let centerDotSize: CGFloat = 4
    private static let outerLineWidth: CGFloat = 1.5
    private static let tickLineWidth: CGFloat = 1
    private static let indicatorLineWidth: CGFloat = 2

    private let scrollSensitivity: CGFloat = AppConstants.dialScrollSensitivity
    var angle: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    var onAngleChanged: ((CGFloat) -> Void)?
    private var isTracking = false

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - Self.outerPadding

        // Outer circle
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(Self.outerLineWidth)
        context.addArc(
            center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        context.strokePath()

        // Tick marks every 45 degrees
        context.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
        context.setLineWidth(Self.tickLineWidth)
        for tick in 0..<8 {
            let tickAngle = CGFloat(tick) * .pi / 4
            let innerRadius = radius - Self.tickInnerOffset
            let outerRadius = radius - Self.tickOuterOffset
            let startPoint = CGPoint(
                x: center.x + innerRadius * cos(tickAngle),
                y: center.y + innerRadius * sin(tickAngle)
            )
            let endPoint = CGPoint(
                x: center.x + outerRadius * cos(tickAngle),
                y: center.y + outerRadius * sin(tickAngle)
            )
            context.move(to: startPoint)
            context.addLine(to: endPoint)
        }
        context.strokePath()

        // Indicator line (0° = top, clockwise)
        let drawRadians = (90 - angle) * .pi / 180
        let indicatorEnd = CGPoint(
            x: center.x + (radius - Self.indicatorInset) * cos(drawRadians),
            y: center.y + (radius - Self.indicatorInset) * sin(drawRadians)
        )
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(Self.indicatorLineWidth)
        context.move(to: center)
        context.addLine(to: indicatorEnd)
        context.strokePath()

        // Center dot
        let dotSize: CGFloat = Self.centerDotSize
        context.setFillColor(NSColor.controlAccentColor.cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - dotSize / 2,
            y: center.y - dotSize / 2,
            width: dotSize,
            height: dotSize
        ))
    }

    override func mouseDown(with event: NSEvent) {
        isTracking = true
        updateAngle(from: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isTracking else { return }
        updateAngle(from: event)
    }

    override func mouseUp(with event: NSEvent) {
        isTracking = false
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        if GeometryUtils.isApproximatelyZero(delta) { return }
        let newAngle = GeometryUtils.normalizeAngle(angle + delta * scrollSensitivity)
        angle = newAngle
        onAngleChanged?(angle)
    }

    private func updateAngle(from event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y
        let mathDegrees = atan2(deltaY, deltaX) * 180 / .pi
        // Convert: 0° = top, clockwise
        var degrees = 90 - mathDegrees
        // Snap to 5-degree increments
        degrees = (degrees / 5).rounded() * 5
        degrees = GeometryUtils.normalizeAngle(degrees)
        angle = degrees
        onAngleChanged?(angle)
    }
}
