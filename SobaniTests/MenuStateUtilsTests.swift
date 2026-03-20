import Testing
@testable import Sobani

@Suite("MenuStateUtils Tests")
struct MenuStateUtilsTests {

    // MARK: - hasRotation Tests

    @Test("hasRotation: 空配列")
    func hasRotationEmpty() {
        #expect(!MenuStateUtils.hasRotation(angles: []))
    }

    @Test("hasRotation: すべてゼロ")
    func hasRotationAllZero() {
        #expect(!MenuStateUtils.hasRotation(angles: [0, 0, 0]))
    }

    @Test("hasRotation: tolerance以下")
    func hasRotationBelowTolerance() {
        #expect(!MenuStateUtils.hasRotation(angles: [0.005, -0.005]))
    }

    @Test("hasRotation: tolerance超え")
    func hasRotationAboveTolerance() {
        #expect(MenuStateUtils.hasRotation(angles: [0, 45.0, 0]))
    }

    @Test("hasRotation: 負の角度")
    func hasRotationNegative() {
        #expect(MenuStateUtils.hasRotation(angles: [-90.0]))
    }

    @Test("hasRotation: tolerance境界値（ちょうどtolerance）")
    func hasRotationExactTolerance() {
        #expect(!MenuStateUtils.hasRotation(angles: [AppConstants.floatingPointTolerance]))
    }

    @Test("hasRotation: tolerance境界値（わずかに超える）")
    func hasRotationSlightlyAboveTolerance() {
        #expect(MenuStateUtils.hasRotation(angles: [AppConstants.floatingPointTolerance + 0.001]))
    }

    // MARK: - hasNonDefaultOpacity Tests

    @Test("hasNonDefaultOpacity: 空配列")
    func hasNonDefaultOpacityEmpty() {
        #expect(!MenuStateUtils.hasNonDefaultOpacity(opacities: []))
    }

    @Test("hasNonDefaultOpacity: すべてデフォルト")
    func hasNonDefaultOpacityAllDefault() {
        #expect(!MenuStateUtils.hasNonDefaultOpacity(opacities: [1.0, 1.0, 1.0]))
    }

    @Test("hasNonDefaultOpacity: tolerance以下の差")
    func hasNonDefaultOpacityBelowTolerance() {
        #expect(!MenuStateUtils.hasNonDefaultOpacity(opacities: [0.995, 1.005]))
    }

    @Test("hasNonDefaultOpacity: 変更あり")
    func hasNonDefaultOpacityChanged() {
        #expect(MenuStateUtils.hasNonDefaultOpacity(opacities: [1.0, 0.5, 1.0]))
    }

    @Test("hasNonDefaultOpacity: 最小不透明度")
    func hasNonDefaultOpacityMin() {
        #expect(MenuStateUtils.hasNonDefaultOpacity(opacities: [0.1]))
    }

    // MARK: - isRotationResetEnabled Tests

    @Test("isRotationResetEnabled: ゼロ回転")
    func isRotationResetEnabledZero() {
        #expect(!MenuStateUtils.isRotationResetEnabled(angle: 0))
    }

    @Test("isRotationResetEnabled: 回転あり")
    func isRotationResetEnabledWithRotation() {
        #expect(MenuStateUtils.isRotationResetEnabled(angle: 45.0))
    }

    @Test("isRotationResetEnabled: tolerance以下")
    func isRotationResetEnabledBelowTolerance() {
        #expect(!MenuStateUtils.isRotationResetEnabled(angle: 0.005))
    }

    // MARK: - isOpacityResetEnabled Tests

    @Test("isOpacityResetEnabled: デフォルト不透明度")
    func isOpacityResetEnabledDefault() {
        #expect(!MenuStateUtils.isOpacityResetEnabled(opacity: 1.0))
    }

    @Test("isOpacityResetEnabled: 変更あり")
    func isOpacityResetEnabledChanged() {
        #expect(MenuStateUtils.isOpacityResetEnabled(opacity: 0.5))
    }

    @Test("isOpacityResetEnabled: tolerance以下の差")
    func isOpacityResetEnabledBelowTolerance() {
        #expect(!MenuStateUtils.isOpacityResetEnabled(opacity: 0.995))
    }

    // MARK: - isBulkResetEnabled Tests

    @Test("isBulkResetEnabled: 両方false")
    func isBulkResetEnabledBothFalse() {
        #expect(!MenuStateUtils.isBulkResetEnabled(hasRotation: false, hasOpacity: false))
    }

    @Test("isBulkResetEnabled: 回転のみ")
    func isBulkResetEnabledRotationOnly() {
        #expect(MenuStateUtils.isBulkResetEnabled(hasRotation: true, hasOpacity: false))
    }

    @Test("isBulkResetEnabled: 不透明度のみ")
    func isBulkResetEnabledOpacityOnly() {
        #expect(MenuStateUtils.isBulkResetEnabled(hasRotation: false, hasOpacity: true))
    }

    @Test("isBulkResetEnabled: 両方true")
    func isBulkResetEnabledBothTrue() {
        #expect(MenuStateUtils.isBulkResetEnabled(hasRotation: true, hasOpacity: true))
    }

    @Test("isBulkResetEnabled: ゴーストのみ")
    func isBulkResetEnabledGhostOnly() {
        #expect(
            MenuStateUtils.isBulkResetEnabled(hasRotation: false, hasOpacity: false, hasGhost: true)
        )
    }

    // MARK: - canMoveForward Tests

    @Test("canMoveForward: 先頭要素（移動不可）")
    func canMoveForwardAtFront() {
        #expect(!MenuStateUtils.canMoveForward(index: 0, canReorder: true))
    }

    @Test("canMoveForward: 中間要素（移動可）")
    func canMoveForwardMiddle() {
        #expect(MenuStateUtils.canMoveForward(index: 1, canReorder: true))
    }

    @Test("canMoveForward: 末尾要素（移動可）")
    func canMoveForwardAtBack() {
        #expect(MenuStateUtils.canMoveForward(index: 2, canReorder: true))
    }

    @Test("canMoveForward: 並び替え不可")
    func canMoveForwardCannotReorder() {
        #expect(!MenuStateUtils.canMoveForward(index: 1, canReorder: false))
    }

    // MARK: - canMoveBackward Tests

    @Test("canMoveBackward: 末尾要素（移動不可）")
    func canMoveBackwardAtBack() {
        #expect(!MenuStateUtils.canMoveBackward(index: 2, count: 3, canReorder: true))
    }

    @Test("canMoveBackward: 中間要素（移動可）")
    func canMoveBackwardMiddle() {
        #expect(MenuStateUtils.canMoveBackward(index: 1, count: 3, canReorder: true))
    }

    @Test("canMoveBackward: 先頭要素（移動可）")
    func canMoveBackwardAtFront() {
        #expect(MenuStateUtils.canMoveBackward(index: 0, count: 3, canReorder: true))
    }

    @Test("canMoveBackward: 並び替え不可")
    func canMoveBackwardCannotReorder() {
        #expect(!MenuStateUtils.canMoveBackward(index: 0, count: 3, canReorder: false))
    }

    // MARK: - canReorder Tests

    @Test("canReorder: ウィンドウ非表示")
    func canReorderHidden() {
        #expect(!MenuStateUtils.canReorder(areWindowsHidden: true, windowCount: 3))
    }

    @Test("canReorder: 1ウィンドウ")
    func canReorderSingleWindow() {
        #expect(!MenuStateUtils.canReorder(areWindowsHidden: false, windowCount: 1))
    }

    @Test("canReorder: 0ウィンドウ")
    func canReorderNoWindows() {
        #expect(!MenuStateUtils.canReorder(areWindowsHidden: false, windowCount: 0))
    }

    @Test("canReorder: 複数ウィンドウ表示中")
    func canReorderMultipleVisible() {
        #expect(MenuStateUtils.canReorder(areWindowsHidden: false, windowCount: 3))
    }

    @Test("canReorder: 2ウィンドウ（最小並び替え可能数）")
    func canReorderTwoWindows() {
        #expect(MenuStateUtils.canReorder(areWindowsHidden: false, windowCount: 2))
    }

    // MARK: - formatWindowCountText Tests

    @Test("formatWindowCountText: 非表示でない場合、showingFormatを使用")
    func formatWindowCountTextShowing() {
        let result = MenuStateUtils.formatWindowCountText(
            count: 3,
            isHidden: false,
            showingFormat: "表示中: %@体",
            showingLabel: "表示中",
            hiddenLabel: "非表示"
        )
        #expect(result == "表示中: 3体")
    }

    @Test("formatWindowCountText: 非表示の場合、hiddenLabelで置換")
    func formatWindowCountTextHidden() {
        let result = MenuStateUtils.formatWindowCountText(
            count: 3,
            isHidden: true,
            showingFormat: "表示中: %@体",
            showingLabel: "表示中",
            hiddenLabel: "非表示"
        )
        #expect(result == "非表示: 3体")
    }

    @Test("formatWindowCountText: count=0の場合")
    func formatWindowCountTextZero() {
        let result = MenuStateUtils.formatWindowCountText(
            count: 0,
            isHidden: false,
            showingFormat: "表示中: %@体",
            showingLabel: "表示中",
            hiddenLabel: "非表示"
        )
        #expect(result == "表示中: 0体")
    }

    @Test("formatWindowCountText: count=5の場合")
    func formatWindowCountTextFive() {
        let result = MenuStateUtils.formatWindowCountText(
            count: 5,
            isHidden: false,
            showingFormat: "Showing: %@ windows",
            showingLabel: "Showing",
            hiddenLabel: "Hidden"
        )
        #expect(result == "Showing: 5 windows")
    }

    @Test("formatWindowCountText: バッジ付き（ゴースト）")
    func formatWindowCountTextWithGhostBadge() {
        let result = MenuStateUtils.formatWindowCountText(
            count: 5,
            isHidden: false,
            showingFormat: "表示中: %@体",
            showingLabel: "表示中",
            hiddenLabel: "非表示",
            badges: [StatusBadge(value: 2, format: "👻%@")]
        )
        #expect(result == "表示中: 5体 👻2")
    }

    @Test("formatWindowCountText: 複数バッジ")
    func formatWindowCountTextWithMultipleBadges() {
        let result = MenuStateUtils.formatWindowCountText(
            count: 5,
            isHidden: false,
            showingFormat: "表示中: %@体",
            showingLabel: "表示中",
            hiddenLabel: "非表示",
            badges: [
                StatusBadge(value: 2, format: "👻%@"),
                StatusBadge(value: 1, format: "🙈%@")
            ]
        )
        #expect(result == "表示中: 5体 👻2 🙈1")
    }

    @Test("formatWindowCountText: バッジvalue=0はスキップ")
    func formatWindowCountTextBadgeZeroSkipped() {
        let result = MenuStateUtils.formatWindowCountText(
            count: 3,
            isHidden: false,
            showingFormat: "表示中: %@体",
            showingLabel: "表示中",
            hiddenLabel: "非表示",
            badges: [StatusBadge(value: 0, format: "👻%@")]
        )
        #expect(result == "表示中: 3体")
    }

    // MARK: - buildWindowInfoText Tests

    @Test("buildWindowInfoText: 基本的なテキスト生成")
    func buildWindowInfoTextBasic() {
        let info = MenuStateUtils.buildWindowInfoText(
            index: 0,
            displayName: "character",
            windowId: 1,
            imageSize: (1920, 1080),
            screenName: "Built-in Display"
        )
        #expect(info.leftText == "1: character (#1)")
        #expect(info.rightText == "[1920\u{00d7}1080] Built-in Display")
    }

    @Test("buildWindowInfoText: 異なるパラメータでの生成")
    func buildWindowInfoTextDifferent() {
        let info = MenuStateUtils.buildWindowInfoText(
            index: 2,
            displayName: "zundamon",
            windowId: 5,
            imageSize: (800, 600),
            screenName: "外部ディスプレイ"
        )
        #expect(info.leftText == "3: zundamon (#5)")
        #expect(info.rightText == "[800\u{00d7}600] 外部ディスプレイ")
    }

    @Test("buildWindowInfoText: 特殊文字を含むdisplayName")
    func buildWindowInfoTextSpecialChars() {
        let info = MenuStateUtils.buildWindowInfoText(
            index: 0,
            displayName: "キャラ (2024)",
            windowId: 1,
            imageSize: (500, 500),
            screenName: "画面1"
        )
        #expect(info.leftText == "1: キャラ (2024) (#1)")
        #expect(info.rightText == "[500\u{00d7}500] 画面1")
    }

    @Test("buildWindowInfoText: 大きなwindowId")
    func buildWindowInfoTextLargeId() {
        let info = MenuStateUtils.buildWindowInfoText(
            index: 99,
            displayName: "test",
            windowId: 9999,
            imageSize: (3840, 2160),
            screenName: "Monitor"
        )
        #expect(info.leftText == "100: test (#9999)")
        #expect(info.rightText == "[3840\u{00d7}2160] Monitor")
    }
}
