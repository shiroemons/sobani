import Cocoa

/// スクリーン復元ジオメトリ計算のユーティリティ
enum ScreenRestorationUtils {
    /// ウィンドウ原点をスクリーン範囲内にクランプ。
    /// ウィンドウがスクリーンより大きい場合はクランプしない。
    static func clampOrigin(_ origin: NSPoint, windowSize: NSSize, to screenFrame: NSRect) -> NSPoint {
        let clampedX = windowSize.width >= screenFrame.width
            ? origin.x
            : max(screenFrame.minX, min(origin.x, screenFrame.maxX - windowSize.width))
        let clampedY = windowSize.height >= screenFrame.height
            ? origin.y
            : max(screenFrame.minY, min(origin.y, screenFrame.maxY - windowSize.height))
        return NSPoint(x: clampedX, y: clampedY)
    }

    /// スリープ前のスクリーン位置を基にウィンドウの相対位置を計算し、
    /// 新しいスクリーン位置に変換する。
    static func computeRestoredOrigin(savedOrigin: NSPoint,
                                      oldScreenFrame: NSRect?,
                                      currentScreenFrame: NSRect) -> NSPoint {
        guard let oldFrame = oldScreenFrame else {
            return savedOrigin
        }
        let relativeX = savedOrigin.x - oldFrame.origin.x
        let relativeY = savedOrigin.y - oldFrame.origin.y
        return NSPoint(
            x: currentScreenFrame.origin.x + relativeX,
            y: currentScreenFrame.origin.y + relativeY
        )
    }

    /// 2つのフレームが tolerance 以内で一致するか判定
    static func isFrameMatch(_ frameA: NSRect, _ frameB: NSRect, tolerance: CGFloat) -> Bool {
        abs(frameA.origin.x - frameB.origin.x) <= tolerance
            && abs(frameA.origin.y - frameB.origin.y) <= tolerance
            && abs(frameA.size.width - frameB.size.width) <= tolerance
            && abs(frameA.size.height - frameB.size.height) <= tolerance
    }
}
