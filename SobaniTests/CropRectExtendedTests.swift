import CoreGraphics
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

    // MARK: - 読み込み時のサニタイズ

    private func decode(_ json: String) throws -> CropRect {
        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode(CropRect.self, from: data)
    }

    /// 巨大な値は上限に収める（そのまま画像処理に渡すと Int(ceil(1e303)) でクラッシュしていた）
    @Test func decode_hugeValues_areClamped() throws {
        let crop = try decode("""
        { "x": -1e303, "y": 1e303, "width": 1e303, "height": 1e303 }
        """)
        #expect(abs(crop.x - (-CropRect.maxExtent)) < AppConstants.normalizedTolerance)
        #expect(abs(crop.y - CropRect.maxExtent) < AppConstants.normalizedTolerance)
        #expect(abs(crop.width - CropRect.maxExtent) < AppConstants.normalizedTolerance)
        #expect(abs(crop.height - CropRect.maxExtent) < AppConstants.normalizedTolerance)
    }

    /// 0 以下のサイズは退化しない最小値にする
    @Test func decode_nonPositiveSize_isRaisedToMinimum() throws {
        let crop = try decode("""
        { "x": 0, "y": 0, "width": 0, "height": -2 }
        """)
        #expect(crop.width > 0)
        #expect(crop.height > 0)
    }

    /// 角度は ±45°、quarterTurns は 0〜3、角丸は 0〜1 に収める
    @Test func decode_outOfRangeTransforms_areNormalized() throws {
        let crop = try decode("""
        {
            "x": 0.1, "y": 0.2, "width": 0.5, "height": 0.6,
            "straightenAngle": 400, "quarterTurns": -1,
            "verticalPerspective": -90, "horizontalPerspective": 1e300,
            "shapeType": "roundedRectangle",
            "cornerRadii": { "topLeft": 5, "topRight": -1, "bottomLeft": 0.3, "bottomRight": 1e300 }
        }
        """)
        #expect(abs(crop.straightenAngle - AppConstants.straightenMaxAngle) < AppConstants.floatingPointTolerance)
        #expect(crop.quarterTurns == 3)
        #expect(abs(crop.verticalPerspective - AppConstants.straightenMinAngle) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.horizontalPerspective - AppConstants.straightenMaxAngle) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.cornerRadii.topLeft - 1) < AppConstants.normalizedTolerance)
        #expect(abs(crop.cornerRadii.topRight) < AppConstants.normalizedTolerance)
        #expect(abs(crop.cornerRadii.bottomLeft - 0.3) < AppConstants.normalizedTolerance)
        #expect(abs(crop.cornerRadii.bottomRight - 1) < AppConstants.normalizedTolerance)
    }

    /// 正常な値はそのまま読み込む（画像外へのはみ出しも保持）
    @Test func decode_validValues_areUnchanged() throws {
        let crop = try decode("""
        { "x": -0.2, "y": 0.3, "width": 1.4, "height": 0.5, "straightenAngle": -12.5, "quarterTurns": 2 }
        """)
        #expect(abs(crop.x - (-0.2)) < AppConstants.normalizedTolerance)
        #expect(abs(crop.width - 1.4) < AppConstants.normalizedTolerance)
        #expect(abs(crop.straightenAngle - (-12.5)) < AppConstants.floatingPointTolerance)
        #expect(crop.quarterTurns == 2)
    }

    /// sanitized() は非有限値を既定値に、範囲外の値を許容範囲へ補正し、それ以外の属性を保つ
    @Test func sanitized_replacesNonFiniteAndClampsOutOfRange() throws {
        let crop = CropRect(
            x: .nan, y: -.infinity, width: .infinity, height: 0,
            straightenAngle: .nan, quarterTurns: 5, isFlippedInCrop: true, aspectRatioPreset: "1:1",
            verticalPerspective: 90, horizontalPerspective: -.infinity,
            shape: .roundedRectangle, cornerRadii: CornerRadii(topLeft: .nan, topRight: 2, bottomLeft: 0.4, bottomRight: -1),
            cornersLinked: false
        ).sanitized()

        #expect(abs(crop.x) < AppConstants.normalizedTolerance)
        #expect(abs(crop.y) < AppConstants.normalizedTolerance)
        #expect(abs(crop.width - 1) < AppConstants.normalizedTolerance)
        #expect(crop.height > 0)
        #expect(abs(crop.straightenAngle) < AppConstants.floatingPointTolerance)
        #expect(crop.quarterTurns == 1)
        #expect(abs(crop.verticalPerspective - AppConstants.straightenMaxAngle) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.horizontalPerspective) < AppConstants.floatingPointTolerance)
        #expect(crop.cornerRadii.isEffectivelyEqual(to: CornerRadii(topLeft: 0, topRight: 1, bottomLeft: 0.4, bottomRight: 0)))
        #expect(crop.isFlippedInCrop)
        #expect(crop.aspectRatioPreset == "1:1")
        #expect(crop.shape == .roundedRectangle)
        #expect(!crop.cornersLinked)
        _ = try JSONEncoder().encode(crop)
    }

    /// 範囲内の値は sanitized() で変化しない
    @Test func sanitized_keepsValidValues() {
        let crop = CropRect(
            x: -0.2, y: 0.3, width: 1.4, height: 0.5, straightenAngle: -12.5, quarterTurns: 2,
            verticalPerspective: 10, horizontalPerspective: -5,
            shape: .roundedRectangle, cornerRadii: .uniform(0.25), cornersLinked: true
        )
        #expect(crop.sanitized() == crop)
    }

    /// 壊れた値を読み込んでも画像処理がクラッシュしない
    @Test func decode_hugeValues_canBeProcessedSafely() throws {
        let crop = try decode("""
        { "x": 0, "y": 0, "width": 1e303, "height": 1e303, "straightenAngle": 3 }
        """)
        let context = try #require(CGContext(
            data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let result = try #require(CropImageProcessor.applyFullCrop(to: image, cropRect: crop))
        #expect(result.width == 100)
    }

    // MARK: - hasImageTransform

    @Test func hasImageTransform_detectsTransforms() {
        #expect(!CropRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5).hasImageTransform)
        #expect(!CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: 4).hasImageTransform)
        #expect(CropRect(x: 0, y: 0, width: 1, height: 1, quarterTurns: -1).hasImageTransform)
        #expect(CropRect(x: 0, y: 0, width: 1, height: 1, isFlippedInCrop: true).hasImageTransform)
        #expect(CropRect(x: 0, y: 0, width: 1, height: 1, straightenAngle: 0.5).hasImageTransform)
        #expect(CropRect(x: 0, y: 0, width: 1, height: 1, verticalPerspective: 3).hasImageTransform)
    }

    // MARK: - isEffectivelyEqual の許容誤差

    /// 正規化座標の 0.5%（1000px 画像で 5px）の差は別の状態として扱う
    @Test func isEffectivelyEqual_smallNormalizedDifferenceIsDistinct() {
        let base = CropRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
        #expect(!base.isEffectivelyEqual(to: base.with(width: 0.505)))
        #expect(base.isEffectivelyEqual(to: base.with(width: 0.5 + 1e-7)))
    }
}
