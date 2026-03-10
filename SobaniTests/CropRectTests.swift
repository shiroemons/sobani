import AppKit
import Foundation
import Testing
@testable import Sobani

/// CropRect構造体およびWindowStateとのCodable互換性を検証するテスト
@Suite @MainActor struct CropRectTests {

    // MARK: - CropRect基本テスト

    /// CropRect.fullの値が(0,0,1,1)であることを検証
    @Test func cropRect_full() {
        let full = CropRect.full
        #expect(abs(full.x - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(full.y - 0) < AppConstants.floatingPointTolerance)
        #expect(abs(full.width - 1) < AppConstants.floatingPointTolerance)
        #expect(abs(full.height - 1) < AppConstants.floatingPointTolerance)
    }

    /// 同じ値のCropRectが等しいことを検証
    @Test func cropRect_equality() {
        let cropRectA = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6)
        let cropRectB = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6)
        #expect(cropRectA == cropRectB)
    }

    /// 異なる値のCropRectが等しくないことを検証
    @Test func cropRect_inequality() {
        let cropRectA = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6)
        let cropRectB = CropRect(x: 0.2, y: 0.2, width: 0.5, height: 0.6)
        #expect(cropRectA != cropRectB)
    }

    /// CropRectのCodableラウンドトリップを検証
    @Test func cropRect_codableRoundTrip() throws {
        let original = CropRect(x: 0.25, y: 0.3, width: 0.5, height: 0.4)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CropRect.self, from: data)
        #expect(original == decoded)
    }

    /// CropRectがSendableに準拠していることを検証（コンパイル時チェック）
    @Test func cropRect_isSendable() {
        let crop = CropRect(x: 0.1, y: 0.2, width: 0.5, height: 0.5)
        let _: any Sendable = crop
        #expect(abs(crop.x - 0.1) < AppConstants.floatingPointTolerance)
    }

    // MARK: - WindowState後方互換性テスト

    /// cropRectフィールドなしの旧JSONでnilが設定されることを検証
    @Test func windowState_decodesWithoutCropRect() throws {
        let json = """
        {
            "imageName": "test",
            "originX": 100,
            "originY": 200,
            "width": 300,
            "height": 400,
            "isFlippedHorizontally": false,
            "rotationAngle": 0,
            "opacityLevel": 1.0,
            "windowId": 1
        }
        """
        let data = try #require(json.data(using: .utf8))
        let state = try JSONDecoder().decode(WindowState.self, from: data)
        #expect(state.cropRect == nil)
        #expect(state.imageName == "test")
    }

    /// cropRectフィールド付きJSONが正しくデコードされることを検証
    @Test func windowState_decodesWithCropRect() throws {
        let json = """
        {
            "imageName": "test",
            "originX": 100,
            "originY": 200,
            "width": 300,
            "height": 400,
            "isFlippedHorizontally": false,
            "rotationAngle": 45,
            "opacityLevel": 0.8,
            "windowId": 2,
            "cropRect": {
                "x": 0.1,
                "y": 0.2,
                "width": 0.6,
                "height": 0.5
            }
        }
        """
        let data = try #require(json.data(using: .utf8))
        let state = try JSONDecoder().decode(WindowState.self, from: data)
        let crop = try #require(state.cropRect)
        #expect(abs(crop.x - 0.1) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.y - 0.2) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.width - 0.6) < AppConstants.floatingPointTolerance)
        #expect(abs(crop.height - 0.5) < AppConstants.floatingPointTolerance)
    }

    /// WindowStateにcropRectを含めてエンコード・デコードできることを検証
    @Test func windowState_encodesWithCropRect() throws {
        let crop = CropRect(x: 0.1, y: 0.2, width: 0.8, height: 0.7)
        let state = WindowState(
            imageName: "test",
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
        #expect(decoded.cropRect == crop)
    }

    /// cropRectがnilの場合にJSONにcropRectフィールドが含まれないことを検証
    @Test func windowState_encodesWithoutCropRect() throws {
        let state = WindowState(
            imageName: "test",
            originX: 100, originY: 200,
            width: 300, height: 400,
            isFlippedHorizontally: false
        )
        let data = try JSONEncoder().encode(state)
        let jsonString = try #require(String(data: data, encoding: .utf8))
        #expect(!jsonString.contains("cropRect"))
    }

    /// cropRect付きWindowStateの完全なラウンドトリップを検証
    @Test func windowState_cropRectRoundTrip() throws {
        let crop = CropRect(x: 0.15, y: 0.25, width: 0.6, height: 0.5)
        let original = WindowState(
            imageName: "roundtrip.png",
            originX: 50, originY: 60,
            width: 200, height: 300,
            isFlippedHorizontally: true,
            rotationAngle: 90,
            opacityLevel: 0.7,
            windowId: 3,
            cropRect: crop
        )
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded == [original])
        let decodedCrop = try #require(decoded.first?.cropRect)
        #expect(abs(decodedCrop.x - 0.15) < AppConstants.floatingPointTolerance)
        #expect(abs(decodedCrop.y - 0.25) < AppConstants.floatingPointTolerance)
    }

    // MARK: - AppConstants Crop/FloatingMenu定数テスト

    /// Crop関連定数が正しい値であることを検証
    @Test func appConstants_cropValues() {
        #expect(abs(AppConstants.cropHandleSize - 8) < AppConstants.floatingPointTolerance)
        #expect(abs(AppConstants.cropMinProportion - 0.1) < AppConstants.floatingPointTolerance)
        #expect(abs(AppConstants.cropOverlayAlpha - 0.5) < AppConstants.floatingPointTolerance)
    }

    /// FloatingMenu関連定数が正しい値であることを検証
    @Test func appConstants_floatingMenuValues() {
        #expect(abs(AppConstants.floatingMenuButtonSize - 32) < AppConstants.floatingPointTolerance)
        #expect(abs(AppConstants.floatingMenuPadding - 8) < AppConstants.floatingPointTolerance)
        #expect(abs(AppConstants.floatingMenuGap - 4) < AppConstants.floatingPointTolerance)
        #expect(abs(AppConstants.floatingMenuCornerRadius - 10) < AppConstants.floatingPointTolerance)
    }

    /// Crop関連定数が正の値であることを検証
    @Test func appConstants_cropValuesPositive() {
        #expect(AppConstants.cropHandleSize > 0)
        #expect(AppConstants.cropMinProportion > 0)
        #expect(AppConstants.cropOverlayAlpha > 0)
        #expect(AppConstants.cropMinProportion <= 1.0)
        #expect(AppConstants.cropOverlayAlpha <= 1.0)
    }

    /// FloatingMenu関連定数が正の値であることを検証
    @Test func appConstants_floatingMenuValuesPositive() {
        #expect(AppConstants.floatingMenuButtonSize > 0)
        #expect(AppConstants.floatingMenuPadding > 0)
        #expect(AppConstants.floatingMenuGap >= 0)
        #expect(AppConstants.floatingMenuCornerRadius > 0)
    }

    // MARK: - MenuItemTagテスト

    /// cropImage MenuItemTagのrawValueが1031であることを検証
    @Test func menuItemTag_cropImage() {
        #expect(MenuItemTag.cropImage.rawValue == 1031)
    }

    /// resetCrop MenuItemTagのrawValueが1032であることを検証
    @Test func menuItemTag_resetCrop() {
        #expect(MenuItemTag.resetCrop.rawValue == 1032)
    }

    /// crop関連タグが他のタグと重複しないことを検証
    @Test func menuItemTag_cropTagsUnique() {
        let allRawValues = MenuItemTag.allCases.map { $0.rawValue }
        let cropImageCount = allRawValues.filter { $0 == MenuItemTag.cropImage.rawValue }.count
        let resetCropCount = allRawValues.filter { $0 == MenuItemTag.resetCrop.rawValue }.count
        #expect(cropImageCount == 1)
        #expect(resetCropCount == 1)
    }

}
