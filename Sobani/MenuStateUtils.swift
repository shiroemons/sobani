import Cocoa

/// メニュー状態判定のユーティリティ
enum MenuStateUtils {
    /// いずれかの角度が tolerance を超えているか判定（一括回転リセット有効判定）
    static func hasRotation(angles: [CGFloat], tolerance: CGFloat = AppConstants.floatingPointTolerance) -> Bool {
        angles.contains { abs($0) > tolerance }
    }

    /// いずれかの不透明度がデフォルト(1.0)から tolerance を超えて異なるか判定（一括不透明度リセット有効判定）
    static func hasNonDefaultOpacity(opacities: [CGFloat], tolerance: CGFloat = AppConstants.floatingPointTolerance) -> Bool {
        opacities.contains { abs($0 - 1.0) > tolerance }
    }

    /// 個別ウィンドウ回転リセット有効判定
    static func isRotationResetEnabled(angle: CGFloat, tolerance: CGFloat = AppConstants.floatingPointTolerance) -> Bool {
        abs(angle) > tolerance
    }

    /// 個別ウィンドウ不透明度リセット有効判定
    static func isOpacityResetEnabled(opacity: CGFloat, tolerance: CGFloat = AppConstants.floatingPointTolerance) -> Bool {
        abs(opacity - 1.0) > tolerance
    }

    /// 一括リセット親メニュー有効判定（いずれかがリセット可能ならtrue）
    static func isBulkResetEnabled(hasRotation: Bool, hasOpacity: Bool, hasGhost: Bool = false) -> Bool {
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

    /// 「表示中: X体」テキストを生成する
    static func formatWindowCountText(
        count: Int,
        isHidden: Bool,
        showingFormat: String,
        showingLabel: String,
        hiddenLabel: String,
        ghostCount: Int = 0,
        ghostFormat: String = "",
        hiddenCount: Int = 0,
        hiddenFormat: String = ""
    ) -> String {
        var base = String(format: showingFormat, "\(count)")
        if isHidden {
            base = base.replacingOccurrences(of: showingLabel, with: hiddenLabel)
        }
        if ghostCount > 0, !ghostFormat.isEmpty {
            base += " " + String(format: ghostFormat, "\(ghostCount)")
        }
        if hiddenCount > 0, !hiddenFormat.isEmpty {
            base += " " + String(format: hiddenFormat, "\(hiddenCount)")
        }
        return base
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
