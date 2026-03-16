import AppKit

struct MinimapLayout {
    static let minimapFallbackHeight: CGFloat = 150

    let screens: [CGRect]
    let scale: CGFloat
    let offset: CGPoint
    let rawTotalBounds: CGRect

    func windowRect(for originX: CGFloat, originY: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        let scaledX = (originX - rawTotalBounds.origin.x) * scale + offset.x
        let scaledY = (rawTotalBounds.height - (originY - rawTotalBounds.origin.y + height)) * scale + offset.y
        let scaledW = width * scale
        let scaledH = height * scale
        return CGRect(x: scaledX, y: scaledY, width: scaledW, height: scaledH)
    }

    func windowRect(for state: WindowState) -> CGRect {
        windowRect(for: state.originX, originY: state.originY, width: state.width, height: state.height)
    }

    @MainActor
    static func computeTotalBounds(states: [WindowState]) -> CGRect {
        let screenFrames = NSScreen.screens.map(\.frame)
        var totalBounds = screenFrames.reduce(CGRect.null) { $0.union($1) }
        for state in states {
            let windowFrame = CGRect(x: state.originX, y: state.originY, width: state.width, height: state.height)
            totalBounds = totalBounds.union(windowFrame)
        }
        return totalBounds
    }

    @MainActor
    static func calculate(
        in availableSize: CGSize,
        states: [WindowState] = [],
        precomputedBounds: CGRect? = nil
    ) -> Self {
        let screenFrames = NSScreen.screens.map(\.frame)
        guard !screenFrames.isEmpty else {
            return Self(screens: [], scale: 1, offset: .zero, rawTotalBounds: .zero)
        }

        // Use caller-supplied bounds to avoid redundant computation when available
        let totalBounds = precomputedBounds ?? computeTotalBounds(states: states)

        let padding: CGFloat = 16
        let usableWidth = availableSize.width - padding * 2
        let usableHeight = availableSize.height - padding * 2
        let scaleX = usableWidth / totalBounds.width
        let scaleY = usableHeight / totalBounds.height
        let scale = min(scaleX, scaleY)

        let scaledWidth = totalBounds.width * scale
        let scaledHeight = totalBounds.height * scale
        let offsetX = (availableSize.width - scaledWidth) / 2
        let offsetY = (availableSize.height - scaledHeight) / 2

        let scaledScreens = screenFrames.map { frame -> CGRect in
            let scaledX = (frame.origin.x - totalBounds.origin.x) * scale + offsetX
            let scaledY = (totalBounds.height - (frame.origin.y - totalBounds.origin.y + frame.height)) * scale + offsetY
            return CGRect(
                x: scaledX,
                y: scaledY,
                width: frame.width * scale,
                height: frame.height * scale
            )
        }

        return Self(screens: scaledScreens, scale: scale, offset: CGPoint(x: offsetX, y: offsetY), rawTotalBounds: totalBounds)
    }

    @MainActor
    static func idealHeight(for width: CGFloat, states: [WindowState] = []) -> CGFloat {
        let screenFrames = NSScreen.screens.map(\.frame)
        guard !screenFrames.isEmpty else { return Self.minimapFallbackHeight }

        let totalBounds = computeTotalBounds(states: states)

        let padding: CGFloat = 16
        let usableWidth = width - padding * 2
        let aspectRatio = totalBounds.height / totalBounds.width
        return usableWidth * aspectRatio + padding * 2
    }
}
