import AppKit
import Foundation
import Testing
@testable import Sobani

/// WindowStateのJSON永続化、画面可視性判定、オフスクリーン位置調整、後方互換性を検証するテスト
@Suite @MainActor struct WindowStateManagerTests {
    let tempDirectory: URL
    let stateManager: WindowStateManager

    init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true
        )
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

    private func fakeScreens() -> [ScreenInfo] {
        [ScreenInfo(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), displayID: 1, isMain: true
        )]
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
        let screens = fakeScreens()
        let frame = screens[0].frame
        let state = makeState(
            originX: frame.midX - 150,
            originY: frame.midY - 200,
            width: 300,
            height: 400
        )
        #expect(state.isPositionVisible(on: screens))
    }

    /// 画面外の位置でisPositionVisibleがfalseを返すことを検証
    @Test func isPositionVisibleOffScreen() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400
        )
        #expect(!state.isPositionVisible(on: fakeScreens()))
    }

    /// 画面内の位置でadjustedToVisibleAreaが変更しないことを検証
    @Test func adjustToVisibleAreaNoChangeWhenVisible() {
        let screens = fakeScreens()
        let frame = screens[0].frame
        let state = makeState(
            originX: frame.midX - 150,
            originY: frame.midY - 200,
            width: 300,
            height: 400
        )
        let adjusted = state.adjustedToVisibleArea(on: screens)
        #expect(adjusted == state)
    }

    /// 画面外の位置がメインスクリーン中央に調整されることを検証
    @Test func adjustToVisibleAreaMovesToCenter() {
        let screens = fakeScreens()
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400
        )
        let adjusted = state.adjustedToVisibleArea(on: screens)
        #expect(adjusted.originX != state.originX)
        #expect(adjusted.originY != state.originY)

        let expectedX = screens[0].frame.midX - 150
        let expectedY = screens[0].frame.midY - 200
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
        let adjusted = state.adjustedToVisibleArea(on: fakeScreens())
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
        let adjusted = state.adjustedToVisibleArea(on: fakeScreens())
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
        let adjusted = state.adjustedToVisibleArea(on: fakeScreens())
        #expect(adjusted.windowId == 7)
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

    // MARK: - Size Validation Tests

    /// width=0のWindowStateでisPositionVisibleがfalseを返すことを検証
    @Test func zeroWidthIsNotVisible() {
        let state = makeState(
            originX: 500,
            originY: 300,
            width: 0,
            height: 400
        )
        #expect(!state.isPositionVisible(on: fakeScreens()))
    }

    /// height=0のWindowStateでisPositionVisibleがfalseを返すことを検証
    @Test func zeroHeightIsNotVisible() {
        let state = makeState(
            originX: 500,
            originY: 300,
            width: 300,
            height: 0
        )
        #expect(!state.isPositionVisible(on: fakeScreens()))
    }

}

/// window_states.json の破損・不正値に対する保護（退避・要素単位の読み飛ばし）を検証するテスト
@Suite @MainActor struct WindowStatePersistenceSafetyTests {
    let tempDirectory: URL
    let stateManager: WindowStateManager

    init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true
        )
        stateManager = WindowStateManager(baseDirectory: tempDirectory)
    }

    private func makeState(imageName: String = "test.png") -> WindowState {
        WindowState(
            imageName: imageName, originX: 100, originY: 200, width: 300, height: 400,
            isFlippedHorizontally: false
        )
    }

    private func corruptBackups() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)
            .filter { $0.hasPrefix("window_states.corrupt-") }
    }

    // MARK: - Corrupt File Backup Tests

    /// 破損JSONで空配列が返され、元ファイルが同じ内容で退避されることを検証
    @Test func corruptedFileIsBackedUp() throws {
        let url = try #require(stateManager.statesFileURL)
        try "{ invalid json".write(to: url, atomically: true, encoding: .utf8)

        #expect(stateManager.loadStates() == [])

        let backups = try corruptBackups()
        #expect(backups.count == 1)
        let backupName = try #require(backups.first)
        let backupContent = try String(contentsOf: tempDirectory.appendingPathComponent(backupName), encoding: .utf8)
        #expect(backupContent == "{ invalid json")
    }

    /// 一部の要素だけが壊れている場合、正常な要素を残し元ファイルを退避することを検証
    @Test func loadStatesSkipsOnlyInvalidElements() throws {
        let url = try #require(stateManager.statesFileURL)
        let json = """
        [
          {"imageName":"ok1.png","originX":1,"originY":2,"width":300,"height":400,"isFlippedHorizontally":false},
          {"imageName":"broken.png","originX":"oops"},
          {"imageName":"ok2.png","originX":5,"originY":6,"width":300,"height":400,"isFlippedHorizontally":false}
        ]
        """
        try json.write(to: url, atomically: true, encoding: .utf8)

        let loaded = stateManager.loadStates()

        #expect(loaded.map(\.imageName) == ["ok1.png", "ok2.png"])
        #expect(try corruptBackups().count == 1)
    }

    /// 正常なファイルの読み込みではバックアップを作らないことを検証
    @Test func loadStatesValidFileDoesNotBackUp() throws {
        stateManager.saveStates([makeState()])
        #expect(stateManager.loadStates().count == 1)
        #expect(try corruptBackups().isEmpty)
    }

    // MARK: - Persistence Sanitization Tests

    private func makeNonFiniteState() -> WindowState {
        WindowState(
            imageName: "nan.png",
            originX: .nan,
            originY: .infinity,
            width: .nan,
            height: -10,
            isFlippedHorizontally: true,
            rotationAngle: -.infinity,
            opacityLevel: .nan,
            windowId: 3,
            cropRect: CropRect(x: .nan, y: 0, width: 1, height: 1),
            isGhostMode: true,
            customGhostAlpha: .nan,
            isHidden: true,
            displayAnchor: DisplayAnchor(
                displayUUID: "uuid", screenFrame: NSRect(x: 0, y: 0, width: CGFloat.nan, height: 1080)
            )
        )
    }

    /// 非有限値・不正値がすべて永続化可能な値に補正されることを検証
    @Test func sanitizedForPersistenceReplacesNonFiniteValues() throws {
        let sanitized = makeNonFiniteState().sanitizedForPersistence()

        #expect(abs(sanitized.originX) < AppConstants.floatingPointTolerance)
        #expect(abs(sanitized.originY) < AppConstants.floatingPointTolerance)
        #expect(abs(sanitized.width - AppConstants.defaultWindowHeight) < AppConstants.floatingPointTolerance)
        #expect(abs(sanitized.height - AppConstants.defaultWindowHeight) < AppConstants.floatingPointTolerance)
        #expect(abs(sanitized.rotationAngle) < AppConstants.floatingPointTolerance)
        #expect(abs(sanitized.opacityLevel - AppConstants.opacityMax) < AppConstants.floatingPointTolerance)
        #expect(sanitized.cropRect == nil)
        #expect(sanitized.customGhostAlpha == nil)
        #expect(sanitized.displayAnchor == nil)
        // 数値以外の属性は保持される
        #expect(sanitized.imageName == "nan.png")
        #expect(sanitized.windowId == 3)
        #expect(sanitized.isFlippedHorizontally)
        #expect(sanitized.isGhostMode)
        #expect(sanitized.isHidden)
        _ = try JSONEncoder().encode(sanitized)
    }

    /// 正常な値は補正されないことを検証
    @Test func sanitizedForPersistenceKeepsValidState() {
        let state = WindowState(
            imageName: "ok.png", originX: -50, originY: 20, width: 300, height: 400,
            isFlippedHorizontally: false, rotationAngle: 30, opacityLevel: 0.5, windowId: 1,
            cropRect: CropRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5),
            customGhostAlpha: 0.4,
            displayAnchor: DisplayAnchor(displayUUID: "uuid", screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        )
        #expect(state.sanitizedForPersistence() == state)
    }

    /// 透過率が範囲外の場合にopacityMin〜opacityMaxへクランプされることを検証
    @Test(arguments: [
        (CGFloat(-1), AppConstants.opacityMin), (CGFloat(0), AppConstants.opacityMin), (CGFloat(5), AppConstants.opacityMax),
    ])
    func sanitizedForPersistenceClampsOpacity(input: CGFloat, expected: CGFloat) {
        let state = WindowState(
            imageName: "a.png", originX: 0, originY: 0, width: 100, height: 100,
            isFlippedHorizontally: false, opacityLevel: input
        )
        #expect(abs(state.sanitizedForPersistence().opacityLevel - expected) < AppConstants.floatingPointTolerance)
    }

    /// 非有限値を含む状態があっても保存が成功し、他のウィンドウも失われないことを検証
    @Test func saveStatesWithNonFiniteValuesSucceeds() {
        let valid = makeState(imageName: "valid.png")
        stateManager.saveStates([valid, makeNonFiniteState()])

        let loaded = stateManager.loadStates()

        #expect(loaded.count == 2)
        #expect(loaded.first == valid)
        #expect(loaded.last?.imageName == "nan.png")
    }
}
