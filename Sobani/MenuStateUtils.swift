import Cocoa

struct StatusBadge {
    let value: Int
    let format: String
}

/// メニュー状態判定のユーティリティ
enum MenuStateUtils {
    /// 不透明度のデフォルト値（完全に不透明）。リセット可否の判定基準
    private static let defaultOpacity: CGFloat = AppConstants.opacityMax

    /// いずれかの角度が tolerance を超えているか判定（一括回転リセット有効判定）
    static func hasRotation(
        angles: [CGFloat],
        tolerance: CGFloat = AppConstants.floatingPointTolerance
    ) -> Bool {
        angles.contains { abs($0) > tolerance }
    }

    /// いずれかの不透明度がデフォルト（完全に不透明）から tolerance を超えて異なるか判定（一括不透明度リセット有効判定）
    static func hasNonDefaultOpacity(
        opacities: [CGFloat],
        tolerance: CGFloat = AppConstants.floatingPointTolerance
    ) -> Bool {
        opacities.contains { abs($0 - defaultOpacity) > tolerance }
    }

    /// 個別ウィンドウ回転リセット有効判定
    static func isRotationResetEnabled(
        angle: CGFloat,
        tolerance: CGFloat = AppConstants.floatingPointTolerance
    ) -> Bool {
        abs(angle) > tolerance
    }

    /// 個別ウィンドウ不透明度リセット有効判定
    static func isOpacityResetEnabled(
        opacity: CGFloat,
        tolerance: CGFloat = AppConstants.floatingPointTolerance
    ) -> Bool {
        abs(opacity - defaultOpacity) > tolerance
    }

    /// 一括リセット親メニュー有効判定（いずれかがリセット可能ならtrue）
    static func isBulkResetEnabled(
        hasRotation: Bool, hasOpacity: Bool,
        hasGhost: Bool = false
    ) -> Bool {
        hasRotation || hasOpacity || hasGhost
    }

    /// 前面/最前面移動の有効判定
    static func canMoveForward(index: Int, canReorder: Bool) -> Bool {
        canReorder && index > 0
    }

    /// 背面/最背面移動の有効判定
    static func canMoveBackward(index: Int, count: Int, canReorder: Bool) -> Bool {
        canReorder && index < count - 1
    }

    /// 並び替え可能判定
    static func canReorder(areWindowsHidden: Bool, windowCount: Int) -> Bool {
        !areWindowsHidden && windowCount > 1
    }

    // MARK: - Text Formatting

    /// 「表示中: X」/「非表示中: X」テキストを生成する
    /// - Parameters:
    ///   - showingFormat: 表示中の書式（`L("status.showing_count")`）
    ///   - hiddenFormat: すべて非表示のときの書式（`L("status.hidden_window_count")`）
    static func formatWindowCountText(
        count: Int,
        isHidden: Bool,
        showingFormat: String,
        hiddenFormat: String,
        badges: [StatusBadge] = []
    ) -> String {
        var text = String(format: isHidden ? hiddenFormat : showingFormat, "\(count)")
        for badge in badges where badge.value > 0 {
            text += " " + String(format: badge.format, "\(badge.value)")
        }
        return text
    }

    /// ウィンドウ情報テキストを生成する（左側テキストと右側テキスト）
    static func buildWindowInfoText(
        index: Int,
        displayName: String,
        windowId: Int,
        imageSize: (width: Int, height: Int),
        screenName: String
    ) -> (leftText: String, rightText: String) {
        let leftText = "\(index + 1): \(displayName) (#\(windowId))"
        let rightText = "[\(imageSize.width)\u{00d7}\(imageSize.height)] \(screenName)"
        return (leftText, rightText)
    }
}
