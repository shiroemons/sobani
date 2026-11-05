import AppKit

struct MinimapLayout {
    static let minimapFallbackHeight: CGFloat = 150
    private static var padding: CGFloat { AppConstants.managementMinimapPadding }

    /// 描画できない場合（範囲が空・表示領域が余白より小さいなど）のレイアウト。何も描かない
    static let empty = Self(screens: [], scale: 1, offset: .zero, rawTotalBounds: .zero)

    let screens: [CGRect]
    let scale: CGFloat
    let offset: CGPoint
    let rawTotalBounds: CGRect

    /// 描画するものがないか。`calculate` はスクリーンがない・計算できない場合に空のレイアウトを返す
    var isEmpty: Bool { screens.isEmpty }

    /// macOS のスクリーン座標（左下原点）の矩形を、ミニマップ上の矩形（左上原点）に変換する。
    func windowRect(for frame: CGRect) -> CGRect {
        let scaledX = (frame.origin.x - rawTotalBounds.origin.x) * scale + offset.x
        let rawY = rawTotalBounds.height - (frame.origin.y - rawTotalBounds.origin.y + frame.size.height)
        let scaledY = rawY * scale + offset.y
        return CGRect(
            x: scaledX, y: scaledY, width: frame.size.width * scale, height: frame.size.height * scale
        )
    }

    func windowRect(for state: WindowState) -> CGRect {
        windowRect(for: state.frame)
    }

    /// ミニマップ上のドラッグ差分をmacOS座標系の差分に変換
    func macOSDelta(from minimapDelta: CGSize) -> CGPoint {
        guard scale > 0 else { return .zero }
        return CGPoint(
            x: minimapDelta.width / scale,
            y: -(minimapDelta.height / scale)
        )
    }

    /// スクリーンとウィンドウをすべて含む範囲（画面外のウィンドウも含める）
    static func totalBounds(screenFrames: [CGRect], windowFrames: [CGRect]) -> CGRect {
        (screenFrames + windowFrames).reduce(CGRect.null) { $0.union($1) }
    }

    @MainActor
    static func computeTotalBounds(states: [WindowState], screenFrames: [CGRect]? = nil) -> CGRect {
        totalBounds(
            screenFrames: screenFrames ?? NSScreen.screens.map(\.frame),
            windowFrames: states.map(\.frame)
        )
    }

    @MainActor
    static func calculate(
        in availableSize: CGSize,
        states: [WindowState] = [],
        precomputedBounds: CGRect? = nil,
        screenFrames: [CGRect]? = nil
    ) -> Self {
        let screenFrames = screenFrames ?? NSScreen.screens.map(\.frame)
        guard !screenFrames.isEmpty else { return .empty }

        // Use caller-supplied bounds to avoid redundant computation when available
        let totalBounds = precomputedBounds
            ?? computeTotalBounds(states: states, screenFrames: screenFrames)

        let usableWidth = availableSize.width - Self.padding * 2
        let usableHeight = availableSize.height - Self.padding * 2
        // 範囲が空だと倍率が無限大・NaN になり、余白より狭いと負の倍率で反転して描かれるため描画しない
        guard !totalBounds.isNull,
              totalBounds.width.isFinite, totalBounds.height.isFinite,
              totalBounds.width > 0, totalBounds.height > 0,
              usableWidth > 0, usableHeight > 0 else { return .empty }

        let scaleX = usableWidth / totalBounds.width
        let scaleY = usableHeight / totalBounds.height
        let scale = min(scaleX, scaleY)

        let scaledWidth = totalBounds.width * scale
        let scaledHeight = totalBounds.height * scale
        let offsetX = (availableSize.width - scaledWidth) / 2
        let offsetY = (availableSize.height - scaledHeight) / 2

        let scaledScreens = screenFrames.map { frame -> CGRect in
            let scaledX = (frame.origin.x - totalBounds.origin.x) * scale + offsetX
            let rawY = totalBounds.height - (frame.origin.y - totalBounds.origin.y + frame.height)
            let scaledY = rawY * scale + offsetY
            return CGRect(
                x: scaledX,
                y: scaledY,
                width: frame.width * scale,
                height: frame.height * scale
            )
        }

        return Self(
            screens: scaledScreens,
            scale: scale,
            offset: CGPoint(x: offsetX, y: offsetY),
            rawTotalBounds: totalBounds
        )
    }
}
