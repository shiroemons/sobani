import Foundation
import Testing
@testable import Sobani

@Suite("CropEditorToolbarView Tests")
struct CropEditorToolbarViewTests {

    // MARK: - resolveModeSwitchAngle Tests

    @Test("同じモードを選択するとリセットされる")
    func resolveModeSwitchAngleSameMode() {
        let angles: [StraightenMode: CGFloat] = [
            .straighten: 15.0, .verticalPerspective: 0, .horizontalPerspective: 0
        ]
        let result = CropEditorToolbarView.resolveModeSwitchAngle(
            targetMode: .straighten, currentMode: .straighten, modeAngles: angles
        )
        #expect(result.shouldReset)
        #expect(abs(result.newAngle) < AppConstants.floatingPointTolerance)
    }

    @Test("異なるモードに切替時、そのモードの角度を返す")
    func resolveModeSwitchAngleDifferentMode() {
        let angles: [StraightenMode: CGFloat] = [
            .straighten: 0, .verticalPerspective: 10.0, .horizontalPerspective: 0
        ]
        let result = CropEditorToolbarView.resolveModeSwitchAngle(
            targetMode: .verticalPerspective, currentMode: .straighten, modeAngles: angles
        )
        #expect(!result.shouldReset)
        #expect(abs(result.newAngle - 10.0) < AppConstants.floatingPointTolerance)
    }

    @Test("存在しないモードの角度はデフォルト0")
    func resolveModeSwitchAngleEmptyAngles() {
        let angles: [StraightenMode: CGFloat] = [:]
        let result = CropEditorToolbarView.resolveModeSwitchAngle(
            targetMode: .horizontalPerspective, currentMode: .straighten, modeAngles: angles
        )
        #expect(!result.shouldReset)
        #expect(abs(result.newAngle) < AppConstants.floatingPointTolerance)
    }

    // MARK: - buildSyncedAngles Tests

    @Test("全モードの角度が正しく設定される")
    func buildSyncedAnglesBasic() {
        let angles = CropEditorToolbarView.buildSyncedAngles(
            straighten: 5.0, verticalPerspective: 10.0, horizontalPerspective: -3.0
        )
        #expect(abs(angles[.straighten, default: 0] - 5.0) < AppConstants.floatingPointTolerance)
        #expect(abs(angles[.verticalPerspective, default: 0] - 10.0) < AppConstants.floatingPointTolerance)
        #expect(abs(angles[.horizontalPerspective, default: 0] - (-3.0)) < AppConstants.floatingPointTolerance)
    }

    @Test("ゼロ値で同期")
    func buildSyncedAnglesAllZero() {
        let angles = CropEditorToolbarView.buildSyncedAngles(
            straighten: 0, verticalPerspective: 0, horizontalPerspective: 0
        )
        for mode in StraightenMode.allCases {
            #expect(abs(angles[mode, default: 0]) < AppConstants.floatingPointTolerance)
        }
    }

    // MARK: - anglesAfterReset Tests

    @Test("指定モードのみリセットされる")
    func anglesAfterResetSpecificMode() {
        let initial: [StraightenMode: CGFloat] = [
            .straighten: 15.0, .verticalPerspective: 10.0, .horizontalPerspective: 5.0
        ]
        let result = CropEditorToolbarView.anglesAfterReset(initial, resettingMode: .straighten)
        #expect(abs(result[.straighten, default: 0]) < AppConstants.floatingPointTolerance)
        #expect(abs(result[.verticalPerspective, default: 0] - 10.0) < AppConstants.floatingPointTolerance)
        #expect(abs(result[.horizontalPerspective, default: 0] - 5.0) < AppConstants.floatingPointTolerance)
    }

    @Test("他のモードは影響を受けない")
    func anglesAfterResetOtherModesUnchanged() {
        let initial: [StraightenMode: CGFloat] = [
            .straighten: 0, .verticalPerspective: 20.0, .horizontalPerspective: 0
        ]
        let result = CropEditorToolbarView.anglesAfterReset(
            initial, resettingMode: .verticalPerspective
        )
        #expect(abs(result[.verticalPerspective, default: 0]) < AppConstants.floatingPointTolerance)
        #expect(abs(result[.straighten, default: 0]) < AppConstants.floatingPointTolerance)
    }

    // MARK: - anglesAfterFullReset Tests

    @Test("全モードがゼロにリセットされる")
    func anglesAfterFullResetAllZero() {
        let result = CropEditorToolbarView.anglesAfterFullReset()
        for mode in StraightenMode.allCases {
            #expect(abs(result[mode, default: 0]) < AppConstants.floatingPointTolerance)
        }
    }

    @Test("全モードが含まれる")
    func anglesAfterFullResetContainsAllModes() {
        let result = CropEditorToolbarView.anglesAfterFullReset()
        #expect(result.count == StraightenMode.allCases.count)
    }

    // MARK: - anglesAfterSliderChange Tests

    @Test("現在のモードの角度のみ更新される")
    func anglesAfterSliderChangeUpdatesCurrentMode() {
        let initial: [StraightenMode: CGFloat] = [
            .straighten: 0, .verticalPerspective: 0, .horizontalPerspective: 0
        ]
        let result = CropEditorToolbarView.anglesAfterSliderChange(
            initial, currentMode: .straighten, newAngle: 12.5
        )
        #expect(abs(result[.straighten, default: 0] - 12.5) < AppConstants.floatingPointTolerance)
        #expect(abs(result[.verticalPerspective, default: 0]) < AppConstants.floatingPointTolerance)
        #expect(abs(result[.horizontalPerspective, default: 0]) < AppConstants.floatingPointTolerance)
    }

    @Test("負の角度も正しく設定される")
    func anglesAfterSliderChangeNegativeAngle() {
        let initial: [StraightenMode: CGFloat] = [
            .straighten: 0, .verticalPerspective: 5.0, .horizontalPerspective: 0
        ]
        let result = CropEditorToolbarView.anglesAfterSliderChange(
            initial, currentMode: .verticalPerspective, newAngle: -7.5
        )
        #expect(abs(result[.verticalPerspective, default: 0] - (-7.5)) < AppConstants.floatingPointTolerance)
        #expect(abs(result[.straighten, default: 0]) < AppConstants.floatingPointTolerance)
    }

    @Test("既存の角度を上書きする")
    func anglesAfterSliderChangeOverwritesExisting() {
        let initial: [StraightenMode: CGFloat] = [
            .straighten: 10.0, .verticalPerspective: 0, .horizontalPerspective: 0
        ]
        let result = CropEditorToolbarView.anglesAfterSliderChange(
            initial, currentMode: .straighten, newAngle: 20.0
        )
        #expect(abs(result[.straighten, default: 0] - 20.0) < AppConstants.floatingPointTolerance)
    }

    // MARK: - StraightenMode Properties Tests

    @Test("各モードのシンボル名が正しい")
    func straightenModeSymbolNames() {
        #expect(StraightenMode.straighten.symbolName == "circle.and.line.horizontal")
        #expect(StraightenMode.verticalPerspective.symbolName == "trapezoid.and.line.vertical")
        #expect(StraightenMode.horizontalPerspective.symbolName == "trapezoid.and.line.horizontal")
    }

    @Test("各モードのローカリゼーションキーが正しい")
    func straightenModeLocalizationKeys() {
        #expect(StraightenMode.straighten.localizationKey == "crop_editor.straighten")
        #expect(StraightenMode.verticalPerspective.localizationKey == "crop_editor.vertical_perspective")
        #expect(
            StraightenMode.horizontalPerspective.localizationKey
                == "crop_editor.horizontal_perspective"
        )
    }

    @Test("全モードが3つ存在する")
    func straightenModeAllCasesCount() {
        #expect(StraightenMode.allCases.count == 3)
    }
}
