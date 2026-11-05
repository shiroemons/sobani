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
    nonisolated static func computeRestoredOrigin(
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

    /// ディスプレイ基準の相対位置を保ったまま、矩形の原点を新しいスクリーンフレームへ写像する。
    ///
    /// - スクリーンサイズが同じ場合: 平行移動 `p' = S'.origin + (p − S.origin)`。
    ///   ディスプレイ配置やプライマリディスプレイが変わってグローバル座標系がずれても、
    ///   ディスプレイ上の見た目の位置は完全に保たれる。
    /// - サイズが異なる場合（解像度変更など）: 中心点を正規化座標で写像し
    ///   `c' = S'.origin + (c − S.origin) ⊙ (S'.size / S.size)`、ウィンドウサイズは維持する。
    nonisolated static func mapOrigin(
        of rect: NSRect,
        from oldScreenFrame: NSRect,
        to newScreenFrame: NSRect,
        tolerance: CGFloat = AppConstants.floatingPointTolerance
    ) -> NSPoint {
        let sameSize = abs(oldScreenFrame.width - newScreenFrame.width) < tolerance
            && abs(oldScreenFrame.height - newScreenFrame.height) < tolerance
        guard !sameSize, oldScreenFrame.width > 0, oldScreenFrame.height > 0 else {
            return computeRestoredOrigin(
                savedOrigin: rect.origin, oldScreenFrame: oldScreenFrame, currentScreenFrame: newScreenFrame
            )
        }
        let normalizedX = (rect.midX - oldScreenFrame.minX) / oldScreenFrame.width
        let normalizedY = (rect.midY - oldScreenFrame.minY) / oldScreenFrame.height
        let centerX = newScreenFrame.minX + normalizedX * newScreenFrame.width
        let centerY = newScreenFrame.minY + normalizedY * newScreenFrame.height
        return NSPoint(x: centerX - rect.width / 2, y: centerY - rect.height / 2)
    }

    /// 矩形との重なり面積が最大のスクリーンのインデックスを返す。どれとも重ならなければ nil。
    nonisolated static func indexOfLargestOverlap(for rect: NSRect, in screenFrames: [NSRect]) -> Int? {
        var best: (index: Int, area: CGFloat)?
        for (index, frame) in screenFrames.enumerated() {
            let intersection = frame.intersection(rect)
            guard !intersection.isNull else { continue }
            let area = intersection.width * intersection.height
            guard area > 0 else { continue }
            if best == nil || area > (best?.area ?? 0) {
                best = (index, area)
            }
        }
        return best?.index
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
