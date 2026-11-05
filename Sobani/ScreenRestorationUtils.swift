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

    /// ディスプレイ基準の相対位置を保ったまま、矩形の原点を新しいスクリーンフレームへ写像する。
    ///
    /// - スクリーンサイズが同じ場合: 平行移動 `p' = S'.origin + (p − S.origin)`。
    ///   ディスプレイ配置やプライマリディスプレイが変わってグローバル座標系がずれても、
    ///   ディスプレイ上の見た目の位置は完全に保たれる。
    /// - サイズが異なる場合（解像度変更など）: 中心点を正規化座標で写像し
    ///   `c' = S'.origin + (c − S.origin) ⊙ (S'.size / S.size)`、ウィンドウサイズは維持する。
    static func mapOrigin(
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

    /// 保存時のスクリーンから復元先スクリーンへ矩形を写像した原点を返す。
    ///
    /// `WindowState.resolvedForRestore`（起動時のアンカー復元）と同じ方針で、スクリーンサイズが
    /// 変わっていれば `mapOrigin` で拡縮し、写像先がどのスクリーンでも見えない場合だけクランプする
    /// （意図的に画面外へはみ出させた配置を保つため）。
    /// - Parameters:
    ///   - rect: 保存時の矩形（グローバル座標）。原点とサイズは同じ座標空間（画像基準 or ウィンドウ基準）で渡す
    ///   - oldScreenFrame: 保存時に属していたスクリーンのフレーム。nil なら写像せず元の原点を使う
    ///   - screenFrame: 復元先スクリーンのフレーム
    ///   - screenFrames: 現在接続されている全スクリーンのフレーム（可視判定用）
    static func restoredOrigin(
        of rect: NSRect,
        from oldScreenFrame: NSRect?,
        to screenFrame: NSRect,
        visibleIn screenFrames: [NSRect]
    ) -> NSPoint {
        let mapped = oldScreenFrame.map { mapOrigin(of: rect, from: $0, to: screenFrame) } ?? rect.origin
        guard !isVisible(NSRect(origin: mapped, size: rect.size), in: screenFrames) else { return mapped }
        return clampOrigin(mapped, windowSize: rect.size, to: screenFrame)
    }

    /// 矩形がいずれかのスクリーンと縦横とも `threshold` 以上重なっているか（`WindowState.isPositionVisible` と同じ基準）
    static func isVisible(
        _ rect: NSRect,
        in screenFrames: [NSRect],
        threshold: CGFloat = AppConstants.screenIntersectionThreshold
    ) -> Bool {
        screenFrames.contains { frame in
            let intersection = rect.intersection(frame)
            return !intersection.isNull && intersection.width >= threshold && intersection.height >= threshold
        }
    }

    /// 矩形との重なり面積が最大のスクリーンのインデックスを返す。どれとも重ならなければ nil。
    static func indexOfLargestOverlap(for rect: NSRect, in screenFrames: [NSRect]) -> Int? {
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

    /// マウス座標（`NSEvent.mouseLocation`）を含むスクリーンのインデックスを返す。
    ///
    /// マウス座標の y はスクリーン最上端の行で `maxY` に一致し、`minY` には一致しない
    /// （`NSMouseInRect` と同じ半開区間 `minX ≤ x < maxX`, `minY < y ≤ maxY`）。
    /// `NSRect.contains` は `maxY` を含まないため、最上端（メニューバー上端）で判定が外れる。
    static func indexOfScreen(containingMouseLocation point: NSPoint, in screenFrames: [NSRect]) -> Int? {
        screenFrames.firstIndex { frame in
            point.x >= frame.minX && point.x < frame.maxX
                && point.y > frame.minY && point.y <= frame.maxY
        }
    }

    /// 2つのフレームが tolerance 以内で一致するか判定
    static func isFrameMatch(_ frameA: NSRect, _ frameB: NSRect, tolerance: CGFloat) -> Bool {
        abs(frameA.origin.x - frameB.origin.x) <= tolerance
            && abs(frameA.origin.y - frameB.origin.y) <= tolerance
            && abs(frameA.size.width - frameB.size.width) <= tolerance
            && abs(frameA.size.height - frameB.size.height) <= tolerance
    }

    /// Wake 復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致
    static func findTargetScreen(
        savedDisplayID: CGDirectDisplayID,
        savedScreenFrame: NSRect?,
        availableScreens: [ScreenInfo],
        tolerance: CGFloat
    ) -> ScreenInfo? {
        // Phase 1: displayID 完全一致
        if let match = availableScreens.first(where: { $0.displayID == savedDisplayID }) {
            return match
        }
        // Phase 2: ジオメトリベースのフォールバック
        guard let savedFrame = savedScreenFrame else { return nil }
        return availableScreens.first { isFrameMatch($0.frame, savedFrame, tolerance: tolerance) }
    }

    /// ペンディング復元時の検索パラメータ
    struct PendingScreenSearch {
        let displayID: CGDirectDisplayID
        let savedScreenFrame: NSRect?
        let originalRect: NSRect
        let unknownDisplayID: CGDirectDisplayID
    }

    /// ペンディング復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致 → ③ 元の位置と最も重なるスクリーン
    static func findTargetScreenForPending(
        _ search: PendingScreenSearch,
        availableScreens: [ScreenInfo],
        tolerance: CGFloat
    ) -> ScreenInfo? {
        let isUnknownDisplay = search.displayID == search.unknownDisplayID
        // Phase 1: displayID 完全一致（unknownDisplayID でない場合のみ）
        if !isUnknownDisplay, let match = availableScreens.first(where: { $0.displayID == search.displayID }) {
            return match
        }
        // Phase 2: ジオメトリベースのフォールバック
        if let savedFrame = search.savedScreenFrame,
           let match = availableScreens.first(where: { isFrameMatch($0.frame, savedFrame, tolerance: tolerance) }) {
            return match
        }
        // Phase 3: 元の位置と最も重なるスクリーン（displayID が不明な場合のみ）
        guard isUnknownDisplay,
              let index = indexOfLargestOverlap(for: search.originalRect, in: availableScreens.map(\.frame))
        else { return nil }
        return availableScreens[index]
    }
}
