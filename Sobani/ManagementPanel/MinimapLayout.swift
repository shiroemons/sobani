import AppKit

struct MinimapLayout {
    static let minimapFallbackHeight: CGFloat = 150
    private static var padding: CGFloat { AppConstants.managementMinimapPadding }

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

    /// ミニマップ上のドラッグ差分をmacOS座標系の差分に変換
    func macOSDelta(from minimapDelta: CGSize) -> CGPoint {
        CGPoint(
            x: minimapDelta.width / scale,
            y: -(minimapDelta.height / scale)
        )
    }

    @MainActor
    static func computeTotalBounds(states: [WindowState], screenFrames: [CGRect]? = nil) -> CGRect {
        let screenFrames = screenFrames ?? NSScreen.screens.map(\.frame)
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
        precomputedBounds: CGRect? = nil,
        screenFrames: [CGRect]? = nil
    ) -> Self {
        let screenFrames = screenFrames ?? NSScreen.screens.map(\.frame)
        guard !screenFrames.isEmpty else {
            return Self(screens: [], scale: 1, offset: .zero, rawTotalBounds: .zero)
        }

        // Use caller-supplied bounds to avoid redundant computation when available
        let totalBounds = precomputedBounds ?? computeTotalBounds(states: states, screenFrames: screenFrames)

        let usableWidth = availableSize.width - Self.padding * 2
        let usableHeight = availableSize.height - Self.padding * 2
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
    static func idealHeight(
        for width: CGFloat,
        states: [WindowState] = [],
        precomputedBounds: CGRect? = nil
    ) -> CGFloat {
        let screenFrames = NSScreen.screens.map(\.frame)
        guard !screenFrames.isEmpty else { return Self.minimapFallbackHeight }

        // Use caller-supplied bounds to avoid redundant computation when available
        let totalBounds = precomputedBounds ?? computeTotalBounds(states: states)

        let usableWidth = width - Self.padding * 2
        let aspectRatio = totalBounds.height / totalBounds.width
        return usableWidth * aspectRatio + Self.padding * 2
    }
}
