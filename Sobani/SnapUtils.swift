import Foundation

/// ウィンドウスナップ判定のユーティリティ
enum SnapUtils {
    struct SnapResult: Sendable {
        let deltaX: CGFloat
        let deltaY: CGFloat
    }

    /// ドラッグ中のウィンドウフレームに対して、他ウィンドウおよび画面端へのスナップ補正を計算
    nonisolated static func calculateSnap(
        draggingFrame: NSRect,
        otherFrames: [NSRect],
        screenVisibleFrame: NSRect,
        threshold: CGFloat = AppConstants.snapThreshold
    ) -> SnapResult {
        // X軸・Y軸を独立に判定
        // 各エッジを比較: minX, maxX, midX (X軸), minY, maxY, midY (Y軸)

        var bestDeltaX: CGFloat?
        var bestDistX: CGFloat = threshold
        var bestDeltaY: CGFloat?
        var bestDistY: CGFloat = threshold

        // ターゲットフレーム = 他ウィンドウ + 画面端
        var targetFrames = otherFrames
        targetFrames.append(screenVisibleFrame)

        for target in targetFrames {
            // X軸の比較パターン
            let xPairs: [(CGFloat, CGFloat)] = [
                (draggingFrame.minX, target.minX),  // 左端同士
                (draggingFrame.minX, target.maxX),  // 隣接（左端→右端）
                (draggingFrame.maxX, target.minX),  // 隣接（右端→左端）
                (draggingFrame.maxX, target.maxX),  // 右端同士
                (draggingFrame.midX, target.midX),  // 中心揃え
            ]

            for (dragEdge, targetEdge) in xPairs {
                let dist = abs(dragEdge - targetEdge)
                if dist < bestDistX {
                    bestDistX = dist
                    bestDeltaX = targetEdge - dragEdge
                }
            }

            // Y軸の比較パターン
            let yPairs: [(CGFloat, CGFloat)] = [
                (draggingFrame.minY, target.minY),
                (draggingFrame.minY, target.maxY),
                (draggingFrame.maxY, target.minY),
                (draggingFrame.maxY, target.maxY),
                (draggingFrame.midY, target.midY),
            ]

            for (dragEdge, targetEdge) in yPairs {
                let dist = abs(dragEdge - targetEdge)
                if dist < bestDistY {
                    bestDistY = dist
                    bestDeltaY = targetEdge - dragEdge
                }
            }
        }

        return SnapResult(deltaX: bestDeltaX ?? 0, deltaY: bestDeltaY ?? 0)
    }
}
