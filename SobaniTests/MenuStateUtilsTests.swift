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

    // MARK: - canMoveForward Tests

    @Test("canMoveForward: 先頭要素（移動不可）")
    func canMoveForwardAtFront() {
        #expect(!MenuStateUtils.canMoveForward(index: 0, count: 3, canReorder: true))
    }

    @Test("canMoveForward: 中間要素（移動可）")
    func canMoveForwardMiddle() {
        #expect(MenuStateUtils.canMoveForward(index: 1, count: 3, canReorder: true))
    }

    @Test("canMoveForward: 末尾要素（移動可）")
    func canMoveForwardAtBack() {
        #expect(MenuStateUtils.canMoveForward(index: 2, count: 3, canReorder: true))
    }

    @Test("canMoveForward: 並び替え不可")
    func canMoveForwardCannotReorder() {
        #expect(!MenuStateUtils.canMoveForward(index: 1, count: 3, canReorder: false))
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
}
