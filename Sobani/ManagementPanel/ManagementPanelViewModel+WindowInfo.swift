import AppKit

// MARK: - Window Info

extension ManagementPanelViewModel {

    struct WindowInfo: Identifiable, Hashable {
        let windowId: Int
        var id: Int { windowId }
        let displayName: String
        let subtitle: String
        let isHidden: Bool
        let isGhostMode: Bool
        let opacityLevel: CGFloat
        let thumbnail: NSImage?
        let originalImage: NSImage?
        let cropRect: CropRect?
        let customGhostAlpha: CGFloat?
        let effectiveGhostAlpha: CGFloat
        let isRemoveBackgroundEnabled: Bool
        let originX: CGFloat
        let originY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let imageName: String
        let isFlippedHorizontally: Bool

        func hash(into hasher: inout Hasher) {
            hasher.combine(windowId)
            hasher.combine(isHidden)
            hasher.combine(isGhostMode)
            hasher.combine(opacityLevel)
            hasher.combine(subtitle)
            hasher.combine(customGhostAlpha)
            hasher.combine(effectiveGhostAlpha)
            hasher.combine(isRemoveBackgroundEnabled)
            hasher.combine(originX)
            hasher.combine(originY)
            hasher.combine(width)
            hasher.combine(height)
            hasher.combine(imageName)
            hasher.combine(isFlippedHorizontally)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.windowId == rhs.windowId
                && lhs.isHidden == rhs.isHidden
                && lhs.isGhostMode == rhs.isGhostMode
                && lhs.opacityLevel == rhs.opacityLevel
                && lhs.displayName == rhs.displayName
                && lhs.customGhostAlpha == rhs.customGhostAlpha
                && lhs.effectiveGhostAlpha == rhs.effectiveGhostAlpha
                && lhs.cropRect == rhs.cropRect
                && lhs.isRemoveBackgroundEnabled == rhs.isRemoveBackgroundEnabled
                && lhs.originX == rhs.originX
                && lhs.originY == rhs.originY
                && lhs.width == rhs.width
                && lhs.height == rhs.height
                && lhs.imageName == rhs.imageName
                && lhs.isFlippedHorizontally == rhs.isFlippedHorizontally
        }

        func toWindowState() -> WindowState {
            WindowState(
                imageName: imageName,
                originX: originX,
                originY: originY,
                width: width,
                height: height,
                isFlippedHorizontally: isFlippedHorizontally,
                opacityLevel: opacityLevel,
                windowId: windowId,
                cropRect: cropRect,
                isGhostMode: isGhostMode,
                customGhostAlpha: customGhostAlpha,
                isHidden: isHidden
            )
        }
    }
}
