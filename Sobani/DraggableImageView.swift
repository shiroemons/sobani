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
        let scaleFactor: CGFloat = 1.0 + (delta * 0.01)
        if event.modifierFlags.contains(.option) {
            let allWindows = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.borderless) }
            for w in allWindows {
                guard let iv = w.contentView as? DraggableImageView else { continue }
                resizeWindow(w, imageView: iv, scaleFactor: scaleFactor)
            }
        } else {
            guard let window = window else { return }
            resizeWindow(window, imageView: self, scaleFactor: scaleFactor)
        }
    }

    private func resizeWindow(_ window: NSWindow, imageView: DraggableImageView, scaleFactor: CGFloat) {
        let currentHeight = window.frame.height
        var newHeight = currentHeight * scaleFactor
        newHeight = max(minHeight, min(maxHeight, newHeight))
        let newWidth = newHeight * imageView.aspectRatio
        let centerX = window.frame.midX
        let centerY = window.frame.midY
        let newOriginX = centerX - newWidth / 2
        let newOriginY = centerY - newHeight / 2
        let newFrame = NSRect(x: newOriginX, y: newOriginY, width: newWidth, height: newHeight)
        window.setFrame(newFrame, display: true)
    }

    override func layout() {
        super.layout()
        if isFlippedHorizontally {
            layer?.setAffineTransform(
                CGAffineTransform(translationX: bounds.width, y: 0)
                    .scaledBy(x: -1, y: 1)
            )
        } else {
            layer?.setAffineTransform(.identity)
        }
    }
}
