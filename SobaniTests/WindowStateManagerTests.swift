import XCTest
@testable import Sobani

/// WindowStateのJSON永続化、画面可視性判定、オフスクリーン位置調整、後方互換性を検証するテスト
final class WindowStateManagerTests: XCTestCase {
    // swiftlint:disable:next implicitly_unwrapped_optional
    var tempDirectory: URL!
    // swiftlint:disable:next implicitly_unwrapped_optional
    var stateManager: WindowStateManager!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        stateManager = WindowStateManager(baseDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        stateManager = nil
        tempDirectory = nil
        super.tearDown()
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
    func testEncodeDecodeRoundTrip() throws {
        let state = makeState()
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded, [state])
    }

    /// 水平反転フラグがJSONラウンドトリップで保持されることを検証
    func testEncodeDecodeWithFlip() throws {
        let state = makeState(isFlippedHorizontally: true)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.isFlippedHorizontally, true)
    }

    // MARK: - Save/Load Tests

    /// 複数WindowStateの保存と読み込みが正しく動作することを検証
    func testSaveAndLoadMultipleStates() {
        let states = [
            makeState(imageName: "image1.png", originX: 10, originY: 20),
            makeState(imageName: "image2.png", originX: 30, originY: 40),
            makeState(imageName: AppConstants.defaultImageName, originX: 50, originY: 60)
        ]
        stateManager.saveStates(states)
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded, states)
    }

    /// ファイル未存在時に空配列が返されることを検証
    func testLoadStatesWhenFileDoesNotExist() {
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded, [])
    }

    /// 破損JSONで空配列が返されクラッシュしないことを検証
    func testLoadStatesWithCorruptedJSON() throws {
        guard let url = stateManager.statesFileURL else {
            XCTFail("statesFileURL is nil")
            return
        }
        try "{ invalid json".write(to: url, atomically: true, encoding: .utf8)
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded, [])
    }

    /// 空配列の保存と読み込みが正しく動作することを検証
    func testSaveAndLoadEmptyArray() {
        stateManager.saveStates([])
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded, [])
    }

    /// 上書き保存で前のデータが置き換えられることを検証
    func testOverwriteSave() {
        let first = [makeState(imageName: "first.png")]
        stateManager.saveStates(first)
        XCTAssertEqual(stateManager.loadStates().first?.imageName, "first.png")

        let second = [makeState(imageName: "second.png")]
        stateManager.saveStates(second)
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.imageName, "second.png")
    }

    // MARK: - File Path Test

    /// statesFileURLがwindow_states.jsonを指すことを検証
    func testStatesFileURL() throws {
        let url = try XCTUnwrap(stateManager.statesFileURL)
        XCTAssertTrue(url.path.hasSuffix("window_states.json"))
    }

    // MARK: - Position Visibility Tests

    /// 画面内の位置でisPositionVisibleがtrueを返すことを検証
    func testIsPositionVisibleOnScreen() {
        guard let mainScreen = NSScreen.main else { return }
        let frame = mainScreen.frame
        let state = makeState(
            originX: frame.midX - 150,
            originY: frame.midY - 200,
            width: 300,
            height: 400
        )
        XCTAssertTrue(state.isPositionVisible())
    }

    /// 画面外の位置でisPositionVisibleがfalseを返すことを検証
    func testIsPositionVisibleOffScreen() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400
        )
        XCTAssertFalse(state.isPositionVisible())
    }

    /// 画面内の位置でadjustedToVisibleAreaが変更しないことを検証
    func testAdjustToVisibleAreaNoChangeWhenVisible() {
        guard let mainScreen = NSScreen.main else { return }
        let frame = mainScreen.frame
        let state = makeState(
            originX: frame.midX - 150,
            originY: frame.midY - 200,
            width: 300,
            height: 400
        )
        let adjusted = state.adjustedToVisibleArea()
        XCTAssertEqual(adjusted, state)
    }

    /// 画面外の位置がメインスクリーン中央に調整されることを検証
    func testAdjustToVisibleAreaMovesToCenter() {
        guard let mainScreen = NSScreen.main else { return }
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400
        )
        let adjusted = state.adjustedToVisibleArea()
        XCTAssertNotEqual(adjusted.originX, state.originX)
        XCTAssertNotEqual(adjusted.originY, state.originY)

        let expectedX = mainScreen.frame.midX - 150
        let expectedY = mainScreen.frame.midY - 200
        // ピクセル位置の丸め誤差を許容するため、精度を意図的に大きく設定
        XCTAssertEqual(adjusted.originX, expectedX, accuracy: 1.0)
        XCTAssertEqual(adjusted.originY, expectedY, accuracy: 1.0)
        XCTAssertEqual(adjusted.width, 300)
        XCTAssertEqual(adjusted.height, 400)
    }

    // MARK: - Order Preservation Test

    /// 保存時にWindowStateの順序が保持されることを検証
    func testSavePreservesOrder() {
        let states = [
            makeState(imageName: "first.png", originX: 1),
            makeState(imageName: "second.png", originX: 2),
            makeState(imageName: "third.png", originX: 3)
        ]
        stateManager.saveStates(states)
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].imageName, "first.png")
        XCTAssertEqual(loaded[1].imageName, "second.png")
        XCTAssertEqual(loaded[2].imageName, "third.png")
    }

    // MARK: - Japanese imageName Test

    /// 日本語ファイル名がJSONラウンドトリップで保持されることを検証
    func testJapaneseImageNameEncodeDecode() {
        let state = makeState(imageName: "かわいい画像.png")
        stateManager.saveStates([state])
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded.first?.imageName, "かわいい画像.png")
    }

    // MARK: - Rotation Angle Tests

    /// 回転角度がJSONラウンドトリップで保持されることを検証
    func testEncodeDecodeWithRotation() throws {
        let state = makeState(rotationAngle: 45)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.rotationAngle, 45)
    }

    /// rotationAngleフィールドなしの旧JSONでデフォルト0が設定されることを検証
    func testBackwardCompatibilityWithoutRotation() throws {
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
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.rotationAngle, 0)
    }

    /// 水平反転と回転角度の組み合わせがJSONラウンドトリップで保持されることを検証
    func testEncodeDecodeWithFlipAndRotation() throws {
        let state = makeState(isFlippedHorizontally: true, rotationAngle: 90)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.isFlippedHorizontally, true)
        XCTAssertEqual(decoded.first?.rotationAngle, 90)
    }

    /// 位置調整時に回転角度が保持されることを検証
    func testAdjustToVisibleAreaPreservesRotation() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400,
            rotationAngle: 180
        )
        let adjusted = state.adjustedToVisibleArea()
        XCTAssertEqual(adjusted.rotationAngle, 180)
    }

    /// デフォルトの回転角度が0であることを検証
    func testDefaultRotationAngleIsZero() {
        let state = makeState()
        XCTAssertEqual(state.rotationAngle, 0)
    }

    // MARK: - Opacity Tests

    /// 透過率がJSONラウンドトリップで保持されることを検証
    func testOpacityLevelEncodeDecode() throws {
        let state = makeState(opacityLevel: 0.5)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        let decodedOpacity = try XCTUnwrap(decoded.first?.opacityLevel)
        XCTAssertEqual(decodedOpacity, 0.5, accuracy: AppConstants.floatingPointTolerance)
    }

    /// opacityLevelフィールドなしの旧JSONでデフォルト1.0が設定されることを検証
    func testOpacityLevelBackwardCompatibility() throws {
        let json = """
        [{"imageName":"test.png","originX":100,"originY":200,"width":300,"height":400,"isFlippedHorizontally":false,"rotationAngle":0}]
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.opacityLevel, 1.0, "Missing opacityLevel should default to 1.0")
    }

    /// デフォルトの透過率が1.0であることを検証
    func testOpacityLevelDefaultValue() {
        let state = makeState()
        XCTAssertEqual(state.opacityLevel, 1.0)
    }

    /// 位置調整時に透過率が保持されることを検証
    func testAdjustToVisibleAreaPreservesOpacity() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400,
            opacityLevel: 0.3
        )
        let adjusted = state.adjustedToVisibleArea()
        XCTAssertEqual(adjusted.opacityLevel, 0.3, accuracy: AppConstants.floatingPointTolerance)
    }

    /// 反転・回転・透過率の組み合わせがJSONラウンドトリップで保持されることを検証
    func testFlipRotationAndOpacityCombination() throws {
        let state = makeState(isFlippedHorizontally: true, rotationAngle: 90, opacityLevel: 0.7)
        let data = try JSONEncoder().encode([state])
        let decoded = try XCTUnwrap(JSONDecoder().decode([WindowState].self, from: data).first)
        XCTAssertTrue(decoded.isFlippedHorizontally)
        XCTAssertEqual(decoded.rotationAngle, 90, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(decoded.opacityLevel, 0.7, accuracy: AppConstants.floatingPointTolerance)
    }

    // MARK: - WindowId Tests

    /// windowIdがJSONラウンドトリップで保持されることを検証
    func testEncodeDecodeWithWindowId() throws {
        let state = makeState(windowId: 42)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.windowId, 42)
    }

    /// windowIdフィールドなしの旧JSONでデフォルト0が設定されることを検証
    func testBackwardCompatibilityWithoutWindowId() throws {
        let json = """
        [{"imageName":"デフォルト","originX":100,"originY":200,"width":300,"height":400,"isFlippedHorizontally":false,"rotationAngle":0,"opacityLevel":1.0}]
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.windowId, 0, "Missing windowId should default to 0")
    }

    /// 位置調整時にwindowIdが保持されることを検証
    func testWindowIdPreservedAfterAdjustToVisibleArea() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400,
            windowId: 7
        )
        let adjusted = state.adjustedToVisibleArea()
        XCTAssertEqual(adjusted.windowId, 7)
    }

    /// レガシー画像名「デフォルト」がAppConstants.defaultImageNameに正規化されることを検証
    func testLoadStatesNormalizesLegacyDefaultImageName() throws {
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
        let jsonData = try XCTUnwrap(legacyJSON.data(using: .utf8))
        try jsonData.write(to: jsonURL)

        let states = stateManager.loadStates()
        XCTAssertEqual(states.first?.imageName, AppConstants.defaultImageName)
    }

    /// windowIdが保存・読み込みで保持されることを検証
    func testWindowIdInSaveAndLoad() {
        let states = [
            makeState(imageName: "image1.png", windowId: 1),
            makeState(imageName: "image2.png", windowId: 5)
        ]
        stateManager.saveStates(states)
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].windowId, 1)
        XCTAssertEqual(loaded[1].windowId, 5)
    }
}
