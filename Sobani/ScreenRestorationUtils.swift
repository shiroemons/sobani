import Cocoa

/// スクリーン復元ジオメトリ計算のユーティリティ
enum ScreenRestorationUtils {
    /// ウィンドウ原点をスクリーン範囲内にクランプ。
    /// ウィンドウがスクリーンより大きい場合は、ウィンドウがスクリーン全体を覆うようにクランプする。
    static func clampOrigin(
        _ origin: NSPoint, windowSize: NSSize,
        to screenFrame: NSRect
    ) -> NSPoint {
        let clampedX: CGFloat
        if windowSize.width >= screenFrame.width {
            clampedX = max(screenFrame.maxX - windowSize.width, min(origin.x, screenFrame.minX))
        } else {
            clampedX = max(screenFrame.minX, min(origin.x, screenFrame.maxX - windowSize.width))
        }
        let clampedY: CGFloat
        if windowSize.height >= screenFrame.height {
            clampedY = max(screenFrame.maxY - windowSize.height, min(origin.y, screenFrame.minY))
        } else {
            clampedY = max(screenFrame.minY, min(origin.y, screenFrame.maxY - windowSize.height))
        }
        return NSPoint(x: clampedX, y: clampedY)
    }

    /// スリープ前のスクリーン位置を基にウィンドウの相対位置を計算し、
    /// 新しいスクリーン位置に変換する。
    static func computeRestoredOrigin(
        savedOrigin: NSPoint,
        oldScreenFrame: NSRect?,
        currentScreenFrame: NSRect
    ) -> NSPoint {
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

    /// Wake 復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致
    /// NSScreen に依存しないデータ型で引数・戻り値を定義
    nonisolated static func findTargetScreen(
        savedDisplayID: UInt32,
        savedScreenFrame: NSRect?,
        availableScreens: [(displayID: UInt32, frame: NSRect)],
        tolerance: CGFloat
    ) -> (displayID: UInt32, frame: NSRect)? {
        // Phase 1: displayID 完全一致
        if let match = availableScreens.first(where: { $0.displayID == savedDisplayID }) {
            return match
        }
        // Phase 2: ジオメトリベースのフォールバック
        if let savedFrame = savedScreenFrame {
            if let match = availableScreens.first(where: {
                isFrameMatch($0.frame, savedFrame, tolerance: tolerance)
            }) {
                return match
            }
        }
        return nil
    }

    /// ペンディング復元時の検索パラメータ
    struct PendingScreenSearch {
        let displayID: UInt32
        let savedScreenFrame: NSRect?
        let originalRect: NSRect
        let unknownDisplayID: UInt32
    }

    /// ペンディング復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致 → ③ 元の位置を含むスクリーン
    /// NSScreen に依存しないデータ型で引数・戻り値を定義
    nonisolated static func findTargetScreenForPending(
        _ search: PendingScreenSearch,
        availableScreens: [(displayID: UInt32, frame: NSRect)],
        tolerance: CGFloat
    ) -> (displayID: UInt32, frame: NSRect)? {
        let displayID = search.displayID
        let savedScreenFrame = search.savedScreenFrame
        let originalRect = search.originalRect
        let unknownDisplayID = search.unknownDisplayID
        // Phase 1: displayID 完全一致（unknownDisplayID でない場合のみ）
        if displayID != unknownDisplayID {
            if let match = availableScreens.first(where: { $0.displayID == displayID }) {
                return match
            }
        }
        // Phase 2: ジオメトリベースのフォールバック
        if let savedFrame = savedScreenFrame {
            if let match = availableScreens.first(where: {
                isFrameMatch($0.frame, savedFrame, tolerance: tolerance)
            }) {
                return match
            }
        }
        // Phase 3: 元の位置が含まれるスクリーンを検索（最大重複面積）
        if displayID == unknownDisplayID {
            return availableScreens.max(by: { screenA, screenB in
                let areaA = screenA.frame.intersection(originalRect)
                let areaB = screenB.frame.intersection(originalRect)
                return areaA.width * areaA.height < areaB.width * areaB.height
            })
        }
        return nil
    }
}
