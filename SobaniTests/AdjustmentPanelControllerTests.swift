import AppKit
import Foundation
import Testing
@testable import Sobani

/// AdjustmentPanelControllerのロジックを検証するテスト
@Suite @MainActor struct AdjustmentPanelControllerTests {

    // MARK: - formatAngle テスト

    /// 整数角度が小数点なしでフォーマットされることを検証
    @Test(arguments: [
        (0.0, "0"),
        (90.0, "90"),
        (180.0, "180"),
        (360.0, "360"),
        (45.0, "45"),
    ])
    func formatAngle_IntegerValues(angle: Double, expected: String) {
        let result = AdjustmentPanelController.formatAngle(CGFloat(angle))
        #expect(result == expected)
    }

    /// tolerance以内の値が整数としてフォーマットされることを検証
    @Test func formatAngle_NearIntegerRoundsDown() {
        // 0.005 < tolerance(0.01) なので整数扱い
        let result = AdjustmentPanelController.formatAngle(90.005)
        #expect(result == "90")
    }

    /// tolerance超の小数値が1桁でフォーマットされることを検証
    @Test func formatAngle_DecimalValue() {
        let result = AdjustmentPanelController.formatAngle(45.5)
        #expect(result == "45.5")
    }

    /// tolerance超の小数値が1桁でフォーマットされることを検証（0.1刻み）
    @Test func formatAngle_SmallDecimalValue() {
        let result = AdjustmentPanelController.formatAngle(0.1)
        #expect(result == "0.1")
    }

    /// 負の角度もフォーマットされることを検証
    @Test func formatAngle_NegativeValue() {
        let result = AdjustmentPanelController.formatAngle(-45.0)
        #expect(result == "-45")
    }

    // MARK: - formatOpacity テスト

    /// 100%不透明度のフォーマットを検証
    @Test func formatOpacity_Full() {
        let result = AdjustmentPanelController.formatOpacity(1.0)
        #expect(result == "100%")
    }

    /// 50%不透明度のフォーマットを検証
    @Test func formatOpacity_Half() {
        let result = AdjustmentPanelController.formatOpacity(0.5)
        #expect(result == "50%")
    }

    /// 最小不透明度(10%)のフォーマットを検証
    @Test func formatOpacity_Minimum() {
        let result = AdjustmentPanelController.formatOpacity(AppConstants.opacityMin)
        #expect(result == "10%")
    }

    /// 0%不透明度のフォーマットを検証
    @Test func formatOpacity_Zero() {
        let result = AdjustmentPanelController.formatOpacity(0.0)
        #expect(result == "0%")
    }

    /// 小数の不透明度が四捨五入されることを検証
    @Test func formatOpacity_RoundsCorrectly() {
        let result = AdjustmentPanelController.formatOpacity(0.756)
        #expect(result == "76%")
    }

    // MARK: - globalToMonitorRelative テスト

    /// 原点(0,0)のモニターでの座標変換を検証
    @Test func globalToMonitorRelative_PrimaryMonitor() {
        let point = CGPoint(x: 100, y: 200)
        let screenOrigin = CGPoint(x: 0, y: 0)
        let result = AdjustmentPanelController.globalToMonitorRelative(point, screenOrigin: screenOrigin)
        #expect(result.x == 100)
        #expect(result.y == 200)
    }

    /// オフセットのあるモニターでの座標変換を検証
    @Test func globalToMonitorRelative_SecondaryMonitor() {
        let point = CGPoint(x: 2020, y: 300)
        let screenOrigin = CGPoint(x: 1920, y: 0)
        let result = AdjustmentPanelController.globalToMonitorRelative(point, screenOrigin: screenOrigin)
        #expect(result.x == 100)
        #expect(result.y == 300)
    }

    /// 負のオフセットのモニターでの座標変換を検証
    @Test func globalToMonitorRelative_NegativeOrigin() {
        let point = CGPoint(x: -1820, y: 100)
        let screenOrigin = CGPoint(x: -1920, y: 0)
        let result = AdjustmentPanelController.globalToMonitorRelative(point, screenOrigin: screenOrigin)
        #expect(result.x == 100)
        #expect(result.y == 100)
    }

    // MARK: - monitorRelativeToGlobal テスト

    /// プライマリモニター相対→グローバル変換を検証
    @Test func monitorRelativeToGlobal_PrimaryMonitor() {
        let point = CGPoint(x: 100, y: 200)
        let screenOrigin = CGPoint(x: 0, y: 0)
        let result = AdjustmentPanelController.monitorRelativeToGlobal(point, screenOrigin: screenOrigin)
        #expect(result.x == 100)
        #expect(result.y == 200)
    }

    /// セカンダリモニター相対→グローバル変換を検証
    @Test func monitorRelativeToGlobal_SecondaryMonitor() {
        let point = CGPoint(x: 100, y: 300)
        let screenOrigin = CGPoint(x: 1920, y: 0)
        let result = AdjustmentPanelController.monitorRelativeToGlobal(point, screenOrigin: screenOrigin)
        #expect(result.x == 2020)
        #expect(result.y == 300)
    }

    /// globalToMonitorRelative と monitorRelativeToGlobal のラウンドトリップを検証
    @Test func coordinateConversion_RoundTrip() {
        let original = CGPoint(x: 500, y: 750)
        let screenOrigin = CGPoint(x: 1920, y: -200)
        let relative = AdjustmentPanelController.globalToMonitorRelative(original, screenOrigin: screenOrigin)
        let backToGlobal = AdjustmentPanelController.monitorRelativeToGlobal(relative, screenOrigin: screenOrigin)
        #expect(abs(backToGlobal.x - original.x) < AppConstants.floatingPointTolerance)
        #expect(abs(backToGlobal.y - original.y) < AppConstants.floatingPointTolerance)
    }

    // MARK: - clampedSize テスト

    /// 正常な幅入力でアスペクト比が維持されることを検証
    @Test func clampedSize_WidthInput_MaintainsAspectRatio() {
        let size = AdjustmentPanelController.clampedSize(newValue: 400, aspectRatio: 2.0, isWidth: true)
        #expect(size != nil)
        #expect(size!.height == 200)
        #expect(size!.width == 400)
    }

    /// 正常な高さ入力でアスペクト比が維持されることを検証
    @Test func clampedSize_HeightInput_MaintainsAspectRatio() {
        let size = AdjustmentPanelController.clampedSize(newValue: 300, aspectRatio: 1.5, isWidth: false)
        #expect(size != nil)
        #expect(size!.height == 300)
        #expect(size!.width == 450)
    }

    /// 最小高さ以下の入力がクランプされることを検証
    @Test func clampedSize_ClampsToMinHeight() {
        let size = AdjustmentPanelController.clampedSize(newValue: 10, aspectRatio: 1.0, isWidth: false)
        #expect(size != nil)
        #expect(size!.height == AppConstants.minImageHeight)
    }

    /// 最大高さ以上の入力がクランプされることを検証
    @Test func clampedSize_ClampsToMaxHeight() {
        let size = AdjustmentPanelController.clampedSize(newValue: 10000, aspectRatio: 1.0, isWidth: false)
        #expect(size != nil)
        #expect(size!.height == AppConstants.maxImageHeight)
    }

    /// 幅入力で最小高さにクランプされることを検証
    @Test func clampedSize_WidthInput_ClampsToMinHeight() {
        // aspectRatio=2.0, width=50 → height=25, clamped to minImageHeight(100)
        let size = AdjustmentPanelController.clampedSize(newValue: 50, aspectRatio: 2.0, isWidth: true)
        #expect(size != nil)
        #expect(size!.height == AppConstants.minImageHeight)
        #expect(size!.width == AppConstants.minImageHeight * 2.0)
    }

    /// 0以下の入力がnilを返すことを検証
    @Test func clampedSize_ZeroValue_ReturnsNil() {
        let size = AdjustmentPanelController.clampedSize(newValue: 0, aspectRatio: 1.0, isWidth: true)
        #expect(size == nil)
    }

    /// 負の入力がnilを返すことを検証
    @Test func clampedSize_NegativeValue_ReturnsNil() {
        let size = AdjustmentPanelController.clampedSize(newValue: -100, aspectRatio: 1.0, isWidth: false)
        #expect(size == nil)
    }

    /// アスペクト比が0の場合にnilを返すことを検証
    @Test func clampedSize_ZeroAspectRatio_ReturnsNil() {
        let size = AdjustmentPanelController.clampedSize(newValue: 300, aspectRatio: 0, isWidth: true)
        #expect(size == nil)
    }

    /// 負のアスペクト比がnilを返すことを検証
    @Test func clampedSize_NegativeAspectRatio_ReturnsNil() {
        let size = AdjustmentPanelController.clampedSize(newValue: 300, aspectRatio: -1.0, isWidth: false)
        #expect(size == nil)
    }

    // MARK: - AdjustmentPanelState テスト

    /// AdjustmentPanelStateの初期化が正しいことを検証
    @Test func adjustmentPanelState_Initialization() {
        let state = AdjustmentPanelState(
            angle: 45.0,
            opacity: 0.8,
            position: CGPoint(x: 100, y: 200),
            size: CGSize(width: 300, height: 400),
            aspectRatio: 0.75
        )
        #expect(state.angle == 45.0)
        #expect(state.opacity == 0.8)
        #expect(state.position == CGPoint(x: 100, y: 200))
        #expect(state.size == CGSize(width: 300, height: 400))
        #expect(state.aspectRatio == 0.75)
    }
}
