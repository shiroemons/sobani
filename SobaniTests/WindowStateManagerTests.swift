import AppKit
import Foundation
import Testing
@preconcurrency @testable import Sobani

/// WindowStateのJSON永続化、画面可視性判定、オフスクリーン位置調整、後方互換性を検証するテスト
@Suite @MainActor struct WindowStateManagerTests {
    let tempDirectory: URL
    let stateManager: WindowStateManager

    init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        stateManager = WindowStateManager(baseDirectory: tempDirectory)
    }

    // MARK: - Helpers

    private func makeState(
        imageName: String = AppConstants.defaultImageName,
        originX: CGFloat = 100,
        originY: CGFloat = 200,
        width: CGFloat = 300,
        height: CGFloat = 400,
        isFlippedHorizontally: Bool = false,
        rotationAngle: CGFloat = 0,
        opacityLevel: CGFloat = 1.0,
        windowId: Int = 0
    ) -> WindowState {
        WindowState(
            imageName: imageName,
            originX: originX,
            originY: originY,
            width: width,
            height: height,
            isFlippedHorizontally: isFlippedHorizontally,
            rotationAngle: rotationAngle,
            opacityLevel: opacityLevel,
            windowId: windowId
        )
    }

    // MARK: - Encode/Decode Tests

    /// WindowStateのJSONエンコード・デコードのラウンドトリップを検証
    @Test func encodeDecodeRoundTrip() throws {
        let state = makeState()
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded == [state])
    }

    /// 水平反転フラグがJSONラウンドトリップで保持されることを検証
    @Test func encodeDecodeWithFlip() throws {
        let state = makeState(isFlippedHorizontally: true)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.isFlippedHorizontally == true)
    }

    // MARK: - Save/Load Tests

    /// 複数WindowStateの保存と読み込みが正しく動作することを検証
    @Test func saveAndLoadMultipleStates() {
        let states = [
            makeState(imageName: "image1.png", originX: 10, originY: 20),
            makeState(imageName: "image2.png", originX: 30, originY: 40),
            makeState(imageName: AppConstants.defaultImageName, originX: 50, originY: 60)
        ]
        stateManager.saveStates(states)
        let loaded = stateManager.loadStates()
        #expect(loaded == states)
    }

    /// ファイル未存在時に空配列が返されることを検証
    @Test func loadStatesWhenFileDoesNotExist() {
        let loaded = stateManager.loadStates()
        #expect(loaded == [])
    }

    /// 破損JSONで空配列が返されクラッシュしないことを検証
    @Test func loadStatesWithCorruptedJSON() throws {
        let url = try #require(stateManager.statesFileURL)
        try "{ invalid json".write(to: url, atomically: true, encoding: .utf8)
        let loaded = stateManager.loadStates()
        #expect(loaded == [])
    }

    /// 空配列の保存と読み込みが正しく動作することを検証
    @Test func saveAndLoadEmptyArray() {
        stateManager.saveStates([])
        let loaded = stateManager.loadStates()
        #expect(loaded == [])
    }

    /// 上書き保存で前のデータが置き換えられることを検証
    @Test func overwriteSave() {
        let first = [makeState(imageName: "first.png")]
        stateManager.saveStates(first)
        #expect(stateManager.loadStates().first?.imageName == "first.png")

        let second = [makeState(imageName: "second.png")]
        stateManager.saveStates(second)
        let loaded = stateManager.loadStates()
        #expect(loaded.count == 1)
        #expect(loaded.first?.imageName == "second.png")
    }

    // MARK: - File Path Test

    /// statesFileURLがwindow_states.jsonを指すことを検証
    @Test func statesFileURL() throws {
        let url = try #require(stateManager.statesFileURL)
        #expect(url.path.hasSuffix("window_states.json"))
    }

    // MARK: - Position Visibility Tests

    /// 画面内の位置でisPositionVisibleがtrueを返すことを検証
    @Test func isPositionVisibleOnScreen() {
        guard let mainScreen = NSScreen.main else { return }
        let frame = mainScreen.frame
        let state = makeState(
            originX: frame.midX - 150,
            originY: frame.midY - 200,
            width: 300,
            height: 400
        )
        #expect(state.isPositionVisible())
    }

    /// 画面外の位置でisPositionVisibleがfalseを返すことを検証
    @Test func isPositionVisibleOffScreen() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400
        )
        #expect(!state.isPositionVisible())
    }

    /// 画面内の位置でadjustedToVisibleAreaが変更しないことを検証
    @Test func adjustToVisibleAreaNoChangeWhenVisible() {
        guard let mainScreen = NSScreen.main else { return }
        let frame = mainScreen.frame
        let state = makeState(
            originX: frame.midX - 150,
            originY: frame.midY - 200,
            width: 300,
            height: 400
        )
        let adjusted = state.adjustedToVisibleArea()
        #expect(adjusted == state)
    }

    /// 画面外の位置がメインスクリーン中央に調整されることを検証
    @Test func adjustToVisibleAreaMovesToCenter() {
        guard let mainScreen = NSScreen.main else { return }
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400
        )
        let adjusted = state.adjustedToVisibleArea()
        #expect(adjusted.originX != state.originX)
        #expect(adjusted.originY != state.originY)

        let expectedX = mainScreen.frame.midX - 150
        let expectedY = mainScreen.frame.midY - 200
        // ピクセル位置の丸め誤差を許容するため、精度を意図的に大きく設定
        #expect(abs(adjusted.originX - expectedX) < 1.0)
        #expect(abs(adjusted.originY - expectedY) < 1.0)
        #expect(adjusted.width == 300)
        #expect(adjusted.height == 400)
    }

    // MARK: - Order Preservation Test

    /// 保存時にWindowStateの順序が保持されることを検証
    @Test func savePreservesOrder() {
        let states = [
            makeState(imageName: "first.png", originX: 1),
            makeState(imageName: "second.png", originX: 2),
            makeState(imageName: "third.png", originX: 3)
        ]
        stateManager.saveStates(states)
        let loaded = stateManager.loadStates()
        #expect(loaded.count == 3)
        #expect(loaded[0].imageName == "first.png")
        #expect(loaded[1].imageName == "second.png")
        #expect(loaded[2].imageName == "third.png")
    }

    // MARK: - Japanese imageName Test

    /// 日本語ファイル名がJSONラウンドトリップで保持されることを検証
    @Test func japaneseImageNameEncodeDecode() {
        let state = makeState(imageName: "かわいい画像.png")
        stateManager.saveStates([state])
        let loaded = stateManager.loadStates()
        #expect(loaded.first?.imageName == "かわいい画像.png")
    }

    // MARK: - Rotation Angle Tests

    /// 回転角度がJSONラウンドトリップで保持されることを検証
    @Test func encodeDecodeWithRotation() throws {
        let state = makeState(rotationAngle: 45)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.rotationAngle == 45)
    }

    /// rotationAngleフィールドなしの旧JSONでデフォルト0が設定されることを検証
    @Test func backwardCompatibilityWithoutRotation() throws {
        // Simulate old JSON without rotationAngle field
        let json = """
        [{
            "imageName": "デフォルト",
            "originX": 100,
            "originY": 200,
            "width": 300,
            "height": 400,
            "isFlippedHorizontally": false
        }]
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.rotationAngle == 0)
    }

    /// 水平反転と回転角度の組み合わせがJSONラウンドトリップで保持されることを検証
    @Test func encodeDecodeWithFlipAndRotation() throws {
        let state = makeState(isFlippedHorizontally: true, rotationAngle: 90)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.isFlippedHorizontally == true)
        #expect(decoded.first?.rotationAngle == 90)
    }

    /// 位置調整時に回転角度が保持されることを検証
    @Test func adjustToVisibleAreaPreservesRotation() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400,
            rotationAngle: 180
        )
        let adjusted = state.adjustedToVisibleArea()
        #expect(adjusted.rotationAngle == 180)
    }

    /// デフォルトの回転角度が0であることを検証
    @Test func defaultRotationAngleIsZero() {
        let state = makeState()
        #expect(state.rotationAngle == 0)
    }

    // MARK: - Opacity Tests

    /// 透過率がJSONラウンドトリップで保持されることを検証
    @Test func opacityLevelEncodeDecode() throws {
        let state = makeState(opacityLevel: 0.5)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        let decodedOpacity = try #require(decoded.first?.opacityLevel)
        #expect(abs(decodedOpacity - 0.5) < AppConstants.floatingPointTolerance)
    }

    /// opacityLevelフィールドなしの旧JSONでデフォルト1.0が設定されることを検証
    @Test func opacityLevelBackwardCompatibility() throws {
        let json = """
        [{"imageName":"test.png","originX":100,"originY":200,"width":300,"height":400,"isFlippedHorizontally":false,"rotationAngle":0}]
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.opacityLevel == 1.0)
    }

    /// デフォルトの透過率が1.0であることを検証
    @Test func opacityLevelDefaultValue() {
        let state = makeState()
        #expect(state.opacityLevel == 1.0)
    }

    /// 位置調整時に透過率が保持されることを検証
    @Test func adjustToVisibleAreaPreservesOpacity() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400,
            opacityLevel: 0.3
        )
        let adjusted = state.adjustedToVisibleArea()
        #expect(abs(adjusted.opacityLevel - 0.3) < AppConstants.floatingPointTolerance)
    }

    /// 反転・回転・透過率の組み合わせがJSONラウンドトリップで保持されることを検証
    @Test func flipRotationAndOpacityCombination() throws {
        let state = makeState(isFlippedHorizontally: true, rotationAngle: 90, opacityLevel: 0.7)
        let data = try JSONEncoder().encode([state])
        let decoded = try #require(JSONDecoder().decode([WindowState].self, from: data).first)
        #expect(decoded.isFlippedHorizontally)
        #expect(abs(decoded.rotationAngle - 90) < AppConstants.floatingPointTolerance)
        #expect(abs(decoded.opacityLevel - 0.7) < AppConstants.floatingPointTolerance)
    }

    // MARK: - WindowId Tests

    /// windowIdがJSONラウンドトリップで保持されることを検証
    @Test func encodeDecodeWithWindowId() throws {
        let state = makeState(windowId: 42)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.windowId == 42)
    }

    /// windowIdフィールドなしの旧JSONでデフォルト0が設定されることを検証
    @Test func backwardCompatibilityWithoutWindowId() throws {
        let json = """
        [{"imageName":"デフォルト","originX":100,"originY":200,"width":300,"height":400,"isFlippedHorizontally":false,"rotationAngle":0,"opacityLevel":1.0}]
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded.first?.windowId == 0)
    }

    /// 位置調整時にwindowIdが保持されることを検証
    @Test func windowIdPreservedAfterAdjustToVisibleArea() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400,
            windowId: 7
        )
        let adjusted = state.adjustedToVisibleArea()
        #expect(adjusted.windowId == 7)
    }

    /// レガシー画像名「デフォルト」がAppConstants.defaultImageNameに正規化されることを検証
    @Test func loadStatesNormalizesLegacyDefaultImageName() throws {
        // Write JSON with legacy "デフォルト" imageName
        let legacyJSON = """
        [{\
        "imageName":"デフォルト",\
        "originX":100,"originY":200,\
        "width":300,"height":400,\
        "isFlippedHorizontally":false,\
        "rotationAngle":0,\
        "opacityLevel":1.0,\
        "windowId":1\
        }]
        """
        let jsonURL = tempDirectory.appendingPathComponent("window_states.json")
        let jsonData = try #require(legacyJSON.data(using: .utf8))
        try jsonData.write(to: jsonURL)

        let states = stateManager.loadStates()
        #expect(states.first?.imageName == AppConstants.defaultImageName)
    }

    /// windowIdが保存・読み込みで保持されることを検証
    @Test func windowIdInSaveAndLoad() {
        let states = [
            makeState(imageName: "image1.png", windowId: 1),
            makeState(imageName: "image2.png", windowId: 5)
        ]
        stateManager.saveStates(states)
        let loaded = stateManager.loadStates()
        #expect(loaded.count == 2)
        #expect(loaded[0].windowId == 1)
        #expect(loaded[1].windowId == 5)
    }
}
