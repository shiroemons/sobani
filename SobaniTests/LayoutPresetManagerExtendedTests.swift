import XCTest
@testable import Sobani

/// レイアウトプリセットの複数WindowState保存・プロパティ保持・削除後の存在確認を検証するテスト
final class LayoutPresetManagerExtendedTests: XCTestCase {
    // swiftlint:disable:next implicitly_unwrapped_optional
    var tempDirectory: URL!
    // swiftlint:disable:next implicitly_unwrapped_optional
    var presetManager: LayoutPresetManager!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        presetManager = LayoutPresetManager(baseDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        presetManager = nil
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

    // MARK: - Multiple States Tests

    /// 複数WindowStateを持つプリセットが正しく保存・読み込みされることを検証
    func testMultipleStatesInPreset() {
        let states = [
            makeState(imageName: "img1.png", originX: 10, originY: 20, windowId: 1),
            makeState(imageName: "img2.png", originX: 30, originY: 40, windowId: 2),
            makeState(imageName: "img3.png", originX: 50, originY: 60, windowId: 3),
            makeState(imageName: "img4.png", originX: 70, originY: 80, windowId: 4),
            makeState(imageName: "img5.png", originX: 90, originY: 100, windowId: 5)
        ]
        presetManager.savePreset(name: "FiveWindows", states: states)

        let loaded = presetManager.loadPreset(named: "FiveWindows")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.states.count, 5)
        XCTAssertEqual(loaded?.states, states)
    }

    /// WindowStateの全プロパティ(反転・回転・透過率・位置・サイズ)が保持されることを検証
    func testPresetStatesPreserveWindowProperties() throws {
        let states = [
            makeState(
                imageName: "flipped.png",
                originX: 150,
                originY: 250,
                width: 500,
                height: 600,
                isFlippedHorizontally: true,
                rotationAngle: 45,
                opacityLevel: 0.7,
                windowId: 3
            ),
            makeState(
                imageName: "rotated.png",
                originX: 300,
                originY: 400,
                width: 200,
                height: 250,
                isFlippedHorizontally: false,
                rotationAngle: 180,
                opacityLevel: 0.5,
                windowId: 7
            )
        ]
        presetManager.savePreset(name: "PropertiesTest", states: states)

        let loaded = try XCTUnwrap(presetManager.loadPreset(named: "PropertiesTest"))
        let loadedStates = loaded.states

        XCTAssertEqual(loadedStates[0].imageName, "flipped.png")
        XCTAssertTrue(loadedStates[0].isFlippedHorizontally)
        XCTAssertEqual(loadedStates[0].rotationAngle, 45, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(loadedStates[0].opacityLevel, 0.7, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(loadedStates[0].windowId, 3)
        XCTAssertEqual(loadedStates[0].originX, 150, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(loadedStates[0].originY, 250, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(loadedStates[0].width, 500, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(loadedStates[0].height, 600, accuracy: AppConstants.floatingPointTolerance)

        XCTAssertEqual(loadedStates[1].imageName, "rotated.png")
        XCTAssertFalse(loadedStates[1].isFlippedHorizontally)
        XCTAssertEqual(loadedStates[1].rotationAngle, 180, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(loadedStates[1].opacityLevel, 0.5, accuracy: AppConstants.floatingPointTolerance)
        XCTAssertEqual(loadedStates[1].windowId, 7)
    }

    // MARK: - Delete Then Exists Tests

    /// 削除後にpresetExistsがfalseを返すことを検証
    func testDeleteThenPresetExistsFalse() {
        presetManager.savePreset(name: "WillBeDeleted", states: [makeState()])
        XCTAssertTrue(presetManager.presetExists(named: "WillBeDeleted"))

        presetManager.deletePreset(named: "WillBeDeleted")
        XCTAssertFalse(presetManager.presetExists(named: "WillBeDeleted"))
    }

}
