import Cocoa

// MARK: - Draggable Image View

class DraggableImageView: NSImageView {
    var aspectRatio: CGFloat = 1.0
    let minHeight: CGFloat = 100
    let maxHeight: CGFloat = 6000
    private var dragStartLocation: NSPoint = .zero
    private var isDraggingAll = false
    var isFlippedHorizontally: Bool = false {
        didSet { needsLayout = true }
    }
    var rotationAngle: CGFloat = 0 {
        didSet {
            needsLayout = true
            onRotationChanged?()
        }
    }
    var onRotationChanged: (() -> Void)?
    var scrollRotationHandler: ((CGFloat) -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            isDraggingAll = true
            dragStartLocation = NSEvent.mouseLocation
        } else {
            isDraggingAll = false
            window?.performDrag(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingAll else { return }
        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - dragStartLocation.x
        let deltaY = currentLocation.y - dragStartLocation.y
        dragStartLocation = currentLocation
        let allWindows = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.borderless) }
        for w in allWindows {
            var origin = w.frame.origin
            origin.x += deltaX
            origin.y += deltaY
            w.setFrameOrigin(origin)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        if delta == 0 { return }
        if let handler = scrollRotationHandler {
            handler(delta)
            return
        }
        let scaleFactor: CGFloat = 1.0 + (delta * 0.01)
        if event.modifierFlags.contains(.option) {
            let allWindows = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.borderless) }
            for w in allWindows {
                guard let iv = w.contentView?.subviews.first as? DraggableImageView else { continue }
                resizeWindow(w, imageView: iv, scaleFactor: scaleFactor)
            }
        } else {
            guard let window = window else { return }
            resizeWindow(window, imageView: self, scaleFactor: scaleFactor)
        }
    }

    private func resizeWindow(_ window: NSWindow, imageView: DraggableImageView, scaleFactor: CGFloat) {
        let currentHeight = imageView.frame.height
        var newHeight = currentHeight * scaleFactor
        newHeight = max(minHeight, min(maxHeight, newHeight))
        let newWidth = newHeight * imageView.aspectRatio

        let radians = imageView.rotationAngle * .pi / 180
        let bbWidth = abs(newWidth * cos(radians)) + abs(newHeight * sin(radians))
        let bbHeight = abs(newWidth * sin(radians)) + abs(newHeight * cos(radians))

        let centerX = window.frame.midX
        let centerY = window.frame.midY
        window.setFrame(NSRect(
            x: round(centerX - bbWidth / 2),
            y: round(centerY - bbHeight / 2),
            width: round(bbWidth),
            height: round(bbHeight)
        ), display: true)

        imageView.frame = NSRect(
            x: (bbWidth - newWidth) / 2,
            y: (bbHeight - newHeight) / 2,
            width: newWidth,
            height: newHeight
        )
    }

    override func layout() {
        super.layout()
        var transform = CGAffineTransform.identity
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2

        if rotationAngle != 0 {
            let radians = -rotationAngle * .pi / 180
            transform = transform
                .translatedBy(x: centerX, y: centerY)
                .rotated(by: radians)
                .translatedBy(x: -centerX, y: -centerY)
        }

        if isFlippedHorizontally {
            let flip = CGAffineTransform.identity
                .translatedBy(x: centerX, y: centerY)
                .scaledBy(x: -1, y: 1)
                .translatedBy(x: -centerX, y: -centerY)
            transform = transform.concatenating(flip)
        }

        layer?.setAffineTransform(transform)
    }
}
