import AppKit

// MARK: - Window Info

extension ManagementPanelViewModel {

    /// 管理パネルに表示するウィンドウ情報。位置・サイズは画像（imageView）基準。
    ///
    /// 浮動小数点を許容誤差で比較するため `Hashable` にはしない（ハッシュと `==` の整合が取れないため）。
    struct WindowInfo: Identifiable, Equatable {
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
        let rotationAngle: CGFloat

        static func == (lhs: Self, rhs: Self) -> Bool {
            let tol = AppConstants.floatingPointTolerance
            return lhs.windowId == rhs.windowId
                && lhs.isHidden == rhs.isHidden
                && lhs.isGhostMode == rhs.isGhostMode
                && abs(lhs.opacityLevel - rhs.opacityLevel) < tol
                && lhs.displayName == rhs.displayName
                && lhs.subtitle == rhs.subtitle
                // 画像の差し替え（背景除去・画像変更など）を検出するため、画像は同一性で比較する
                && lhs.thumbnail === rhs.thumbnail
                && lhs.originalImage === rhs.originalImage
                && {
                    switch (lhs.customGhostAlpha, rhs.customGhostAlpha) {
                    case (nil, nil): return true
                    case let (lhs?, rhs?): return abs(lhs - rhs) < tol
                    default: return false
                    }
                }()
                && abs(lhs.effectiveGhostAlpha - rhs.effectiveGhostAlpha) < tol
                && lhs.cropRect == rhs.cropRect
                && lhs.isRemoveBackgroundEnabled == rhs.isRemoveBackgroundEnabled
                && abs(lhs.originX - rhs.originX) < tol
                && abs(lhs.originY - rhs.originY) < tol
                && abs(lhs.width - rhs.width) < tol
                && abs(lhs.height - rhs.height) < tol
                && lhs.imageName == rhs.imageName
                && lhs.isFlippedHorizontally == rhs.isFlippedHorizontally
                && abs(lhs.rotationAngle - rhs.rotationAngle) < tol
        }

        func toWindowState() -> WindowState {
            WindowState(
                imageName: imageName,
                originX: originX,
                originY: originY,
                width: width,
                height: height,
                isFlippedHorizontally: isFlippedHorizontally,
                rotationAngle: rotationAngle,
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
