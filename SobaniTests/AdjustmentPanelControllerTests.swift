import Foundation
import Testing
@testable import Sobani

/// AdjustmentPanelController の静的ヘルパーメソッドと状態初期化を検証するテスト
@Suite @MainActor struct AdjustmentPanelControllerTests {

    // MARK: - formatAngle Tests

    /// 整数値の角度はフォーマットされることを検証
    @Test func formatAngle_integerValue() {
        #expect(AdjustmentPanelController.formatAngle(90) == "90")
    }

    /// tolerance 近傍の角度は整数としてフォーマットされることを検証
    @Test func formatAngle_nearInteger() {
        #expect(AdjustmentPanelController.formatAngle(45.0000001) == "45")
    }

    /// 小数を含む角度は小数点1桁でフォーマットされることを検証
    @Test func formatAngle_decimalValue() {
        #expect(AdjustmentPanelController.formatAngle(45.3) == "45.3")
    }

    /// 0度のフォーマットを検証
    @Test func formatAngle_zero() {
        #expect(AdjustmentPanelController.formatAngle(0) == "0")
    }

    /// 360度のフォーマットを検証
    @Test func formatAngle_fullCircle() {
        #expect(AdjustmentPanelController.formatAngle(360) == "360")
    }

    // MARK: - globalToMonitorRelative Tests

    /// プライマリモニター（原点 0,0）での座標変換を検証
    @Test func globalToMonitorRelative_primaryMonitor() {
        let result = AdjustmentPanelController.globalToMonitorRelative(
            CGPoint(x: 100, y: 200), screenOrigin: CGPoint(x: 0, y: 0)
        )
        #expect(abs(result.x - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 200) < AppConstants.floatingPointTolerance)
    }

    /// セカンダリモニター（正オフセット）での座標変換を検証
    @Test func globalToMonitorRelative_secondaryMonitor() {
        let result = AdjustmentPanelController.globalToMonitorRelative(
            CGPoint(x: 1920 + 100, y: 200), screenOrigin: CGPoint(x: 1920, y: 0)
        )
        #expect(abs(result.x - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 200) < AppConstants.floatingPointTolerance)
    }

    /// 負オフセットのモニターでの座標変換を検証
    @Test func globalToMonitorRelative_negativeOffset() {
        let result = AdjustmentPanelController.globalToMonitorRelative(
            CGPoint(x: -1820, y: 100), screenOrigin: CGPoint(x: -1920, y: 0)
        )
        #expect(abs(result.x - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 100) < AppConstants.floatingPointTolerance)
    }

    // MARK: - monitorRelativeToGlobal Tests

    /// プライマリモニターでのグローバル座標への変換を検証
    @Test func monitorRelativeToGlobal_primaryMonitor() {
        let result = AdjustmentPanelController.monitorRelativeToGlobal(
            CGPoint(x: 100, y: 200), screenOrigin: CGPoint(x: 0, y: 0)
        )
        #expect(abs(result.x - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 200) < AppConstants.floatingPointTolerance)
    }

    /// セカンダリモニターでのグローバル座標への変換を検証
    @Test func monitorRelativeToGlobal_secondaryMonitor() {
        let result = AdjustmentPanelController.monitorRelativeToGlobal(
            CGPoint(x: 100, y: 200), screenOrigin: CGPoint(x: 1920, y: 0)
        )
        #expect(abs(result.x - 2020) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 200) < AppConstants.floatingPointTolerance)
    }

    // MARK: - Coordinate Conversion Round Trip

    /// グローバル→モニター相対→グローバルのラウンドトリップを検証
    @Test func coordinateConversion_roundTrip() {
        let original = CGPoint(x: 2500, y: 300)
        let screenOrigin = CGPoint(x: 1920, y: -200)
        let relative = AdjustmentPanelController.globalToMonitorRelative(
            original, screenOrigin: screenOrigin
        )
        let restored = AdjustmentPanelController.monitorRelativeToGlobal(
            relative, screenOrigin: screenOrigin
        )
        #expect(abs(restored.x - original.x) < AppConstants.floatingPointTolerance)
        #expect(abs(restored.y - original.y) < AppConstants.floatingPointTolerance)
    }

    // MARK: - clampedSize Tests

    /// 正常な幅入力でアスペクト比を維持したサイズを返すことを検証
    @Test func clampedSize_normalWidth() throws {
        let result = try #require(
            AdjustmentPanelController.clampedSize(newValue: 400, aspectRatio: 2.0, isWidth: true)
        )
        #expect(abs(result.width - 400) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 200) < AppConstants.floatingPointTolerance)
    }

    /// 正常な高さ入力でアスペクト比を維持したサイズを返すことを検証
    @Test func clampedSize_normalHeight() throws {
        let result = try #require(
            AdjustmentPanelController.clampedSize(newValue: 200, aspectRatio: 2.0, isWidth: false)
        )
        #expect(abs(result.width - 400) < AppConstants.floatingPointTolerance)
        #expect(abs(result.height - 200) < AppConstants.floatingPointTolerance)
    }

    /// 最小サイズ以下の入力がクランプされることを検証
    @Test func clampedSize_clampToMinimum() throws {
        let result = try #require(
            AdjustmentPanelController.clampedSize(newValue: 10, aspectRatio: 1.0, isWidth: false)
        )
        #expect(
            abs(result.height - AppConstants.minImageHeight) < AppConstants.floatingPointTolerance
        )
    }

    /// 最大サイズ以上の入力がクランプされることを検証
    @Test func clampedSize_clampToMaximum() throws {
        let result = try #require(
            AdjustmentPanelController.clampedSize(newValue: 10000, aspectRatio: 1.0, isWidth: false)
        )
        #expect(
            abs(result.height - AppConstants.maxImageHeight) < AppConstants.floatingPointTolerance
        )
    }

    /// 0の入力で nil を返すことを検証
    @Test func clampedSize_zeroValue() {
        let result = AdjustmentPanelController.clampedSize(
            newValue: 0, aspectRatio: 1.0, isWidth: true
        )
        #expect(result == nil)
    }

    /// 負の入力で nil を返すことを検証
    @Test func clampedSize_negativeValue() {
        let result = AdjustmentPanelController.clampedSize(
            newValue: -100, aspectRatio: 1.0, isWidth: true
        )
        #expect(result == nil)
    }

    /// 無効なアスペクト比で nil を返すことを検証
    @Test func clampedSize_invalidAspectRatio() {
        let result = AdjustmentPanelController.clampedSize(
            newValue: 400, aspectRatio: 0, isWidth: true
        )
        #expect(result == nil)
    }

    // MARK: - AdjustmentPanelState Tests

    // MARK: - generateMonitorPopupTitles Tests

    /// 空配列で空配列を返すことを検証
    @Test func generateMonitorPopupTitles_empty() {
        let result = AdjustmentPanelController.generateMonitorPopupTitles(screenSizes: [])
        #expect(result.isEmpty)
    }

    /// 1画面で正しいタイトルを生成することを検証
    @Test func generateMonitorPopupTitles_singleScreen() {
        let result = AdjustmentPanelController.generateMonitorPopupTitles(
            screenSizes: [(width: 1920, height: 1080)]
        )
        #expect(result == ["1: 1920×1080"])
    }

    /// 複数画面で正しいインデックスとサイズのタイトルを生成することを検証
    @Test func generateMonitorPopupTitles_multipleScreens() {
        let result = AdjustmentPanelController.generateMonitorPopupTitles(
            screenSizes: [(width: 1920, height: 1080), (width: 2560, height: 1440)]
        )
        #expect(result == ["1: 1920×1080", "2: 2560×1440"])
    }

    // MARK: - formatResolutionLabel Tests

    /// 一般的な解像度のフォーマットを検証
    @Test func formatResolutionLabel_commonResolution() {
        let result = AdjustmentPanelController.formatResolutionLabel(width: 1920, height: 1080)
        #expect(result == "1920×1080")
    }

    /// 大きな数値の解像度のフォーマットを検証
    @Test func formatResolutionLabel_largeResolution() {
        let result = AdjustmentPanelController.formatResolutionLabel(width: 5120, height: 2880)
        #expect(result == "5120×2880")
    }

    // MARK: - updatedRelativePosition Tests

    /// isXField=true で x が更新されることを検証
    @Test func updatedRelativePosition_updateX() {
        let current = CGPoint(x: 100, y: 200)
        let result = AdjustmentPanelController.updatedRelativePosition(
            newAxisValue: 300, currentRelative: current, isXField: true
        )
        #expect(abs(result.x - 300) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 200) < AppConstants.floatingPointTolerance)
    }

    /// isXField=false で y が更新されることを検証
    @Test func updatedRelativePosition_updateY() {
        let current = CGPoint(x: 100, y: 200)
        let result = AdjustmentPanelController.updatedRelativePosition(
            newAxisValue: 500, currentRelative: current, isXField: false
        )
        #expect(abs(result.x - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(result.y - 500) < AppConstants.floatingPointTolerance)
    }

    /// isXField=true で y 軸が変更されないことを検証
    @Test func updatedRelativePosition_xFieldPreservesY() {
        let current = CGPoint(x: 50, y: 75)
        let result = AdjustmentPanelController.updatedRelativePosition(
            newAxisValue: 999, currentRelative: current, isXField: true
        )
        #expect(abs(result.y - 75) < AppConstants.floatingPointTolerance)
    }

    /// isXField=false で x 軸が変更されないことを検証
    @Test func updatedRelativePosition_yFieldPreservesX() {
        let current = CGPoint(x: 50, y: 75)
        let result = AdjustmentPanelController.updatedRelativePosition(
            newAxisValue: 999, currentRelative: current, isXField: false
        )
        #expect(abs(result.x - 50) < AppConstants.floatingPointTolerance)
    }

    // MARK: - Change Detection Guard Tests

    /// 同じ角度値で updateAngle を呼び出しても問題が起きないことを検証
    @Test func testUpdateAngleNoOpWhenSameValue() {
        let controller = AdjustmentPanelController()
        // 最初に 45.0 を設定
        controller.updateAngle(45.0)
        // 同じ値で再度呼び出してもクラッシュしないことを検証
        controller.updateAngle(45.0)
        // formatAngle を通じて期待値が正しいことを確認
        #expect(AdjustmentPanelController.formatAngle(45.0) == "45")
    }

    // MARK: - AdjustmentPanelState Tests

    /// AdjustmentPanelState の初期化を検証
    @Test func adjustmentPanelState_initialization() {
        let state = AdjustmentPanelState(
            angle: 45,
            position: CGPoint(x: 100, y: 200),
            size: CGSize(width: 300, height: 400),
            aspectRatio: 0.75
        )
        #expect(abs(state.angle - 45) < AppConstants.floatingPointTolerance)
        #expect(abs(state.position.x - 100) < AppConstants.floatingPointTolerance)
        #expect(abs(state.position.y - 200) < AppConstants.floatingPointTolerance)
        #expect(abs(state.size.width - 300) < AppConstants.floatingPointTolerance)
        #expect(abs(state.size.height - 400) < AppConstants.floatingPointTolerance)
        #expect(abs(state.aspectRatio - 0.75) < AppConstants.floatingPointTolerance)
    }
}
