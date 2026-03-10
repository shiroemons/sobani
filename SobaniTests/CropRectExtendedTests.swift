import Foundation
import Testing
@testable import Sobani

/// CropRect構造体の拡張フィールド（straightenAngle, quarterTurns, isFlippedInCrop, aspectRatioPreset）
/// および旧JSONとの後方互換性を検証するテスト
@Suite @MainActor struct CropRectExtendedTests {

    // MARK: - 旧形式JSON後方互換性テスト

    /// 旧形式JSON（x,y,width,heightのみ）のデコードで新フィールドがデフォルト値になることを検証
    @Test func decodeLegacyJSON_newFieldsGetDefaults() throws {
        let json = """
        {
            "x": 0.1,
            "y": 0.2,
            "width": 0.5,
            "height": 0.6
        }
        """
        let data = try #require(json.data(using: .utf8))
        let crop = try JSONDecoder().decode(CropRect.self, from: data)
        #expect(abs(crop.x - 0.1) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.y - 0.2) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.width - 0.5) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.height - 0.6) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.straightenAngle - 0) < AppConstants.floatingPointTolerance)
        #expect(crop.quarterTurns == 0)
        #expect(crop.isFlippedInCrop == false)
        #expect(crop.aspectRatioPreset == nil)
    }

    // MARK: - 新形式JSONラウンドトリップテスト

    /// 全フィールド含む新形式JSONのエンコード・デコードラウンドトリップを検証
    @Test func newFormatJSON_roundTrip() throws {
        let original = CropRect(
            x: 0.1,
            y: 0.2,
            width: 0.6,
            height: 0.5,
            straightenAngle: 15.5,
            quarterTurns: 2,
            isFlippedInCrop: true,
            aspectRatioPreset: "4:3"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CropRect.self, from: data)
        #expect(decoded == original)
        #expect(abs(decoded.straightenAngle - 15.5) < AppConstants.floatingPointTolerance)
        #expect(decoded.quarterTurns == 2)
        #expect(decoded.isFlippedInCrop == true)
        #expect(decoded.aspectRatioPreset == "4:3")
    }

    // MARK: - WindowState経由のラウンドトリップテスト

    /// 新CropRectフィールドを含むWindowStateのラウンドトリップを検証
    @Test func windowState_roundTripWithNewCropRectFields() throws {
        let crop = CropRect(
            x: 0.15,
            y: 0.25,
            width: 0.6,
            height: 0.5,
            straightenAngle: -10.0,
            quarterTurns: 1,
            isFlippedInCrop: true,
            aspectRatioPreset: "16:9"
        )
        let state = WindowState(
            imageName: "test.png",
            originX: 100, originY: 200,
            width: 300, height: 400,
            isFlippedHorizontally: false,
            rotationAngle: 0,
            opacityLevel: 1.0,
            windowId: 1,
            cropRect: crop
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(WindowState.self, from: data)
        let decodedCrop = try #require(decoded.cropRect)
        #expect(abs(decodedCrop.straightenAngle - (-10.0)) < AppConstants.floatingPointTolerance)
        #expect(decodedCrop.quarterTurns == 1)
        #expect(decodedCrop.isFlippedInCrop == true)
        #expect(decodedCrop.aspectRatioPreset == "16:9")
    }

    // MARK: - straightenAngleテスト

    /// straightenAngleの範囲テスト（負の値）
    @Test func straightenAngle_negativeValue() {
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, straightenAngle: -45)
        #expect(abs(crop.straightenAngle - (-45)) < AppConstants.floatingPointTolerance)
    }

    /// straightenAngleの範囲テスト（正の値）
    @Test func straightenAngle_positiveValue() {
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, straightenAngle: 45)
        #expect(abs(crop.straightenAngle - 45) < AppConstants.floatingPointTolerance)
    }

    /// straightenAngleのデフォルト値が0であることを検証
    @Test func straightenAngle_defaultIsZero() {
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1)
        #expect(abs(crop.straightenAngle - 0) < AppConstants.floatingPointTolerance)
    }

    // MARK: - quarterTurnsテスト

    /// quarterTurnsのデフォルト値が0であることを検証
    @Test func quarterTurns_defaultIsZero() {
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1)
        #expect(crop.quarterTurns == 0)
    }

    /// quarterTurnsに各値（0〜3）を設定できることを検証
    @Test func quarterTurns_validValues() {
        for turns in 0...3 {
            let crop = CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: turns)
            #expect(crop.quarterTurns == turns)
        }
    }

    // MARK: - aspectRatioPresetテスト

    /// aspectRatioPresetのデフォルト値がnilであることを検証
    @Test func aspectRatioPreset_defaultIsNil() {
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1)
        #expect(crop.aspectRatioPreset == nil)
    }

    /// aspectRatioPresetに値を設定できることを検証
    @Test func aspectRatioPreset_canBeSet() {
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1, aspectRatioPreset: "1:1")
        #expect(crop.aspectRatioPreset == "1:1")
    }

    // MARK: - isFlippedInCropテスト

    /// isFlippedInCropのデフォルト値がfalseであることを検証
    @Test func isFlippedInCrop_defaultIsFalse() {
        let crop = CropRect(x: 0, y: 0, width: 1, height: 1)
        #expect(crop.isFlippedInCrop == false)
    }

    // MARK: - 等価性テスト

    /// 新フィールドが異なるCropRectが等しくないことを検証
    @Test func equality_differentNewFields() {
        let cropA = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6, straightenAngle: 10)
        let cropB = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6, straightenAngle: 20)
        #expect(cropA != cropB)
    }
}
