import XCTest
@testable import Sobani

/// レイアウトプリセットのリネーム機能を検証するテスト
final class LayoutPresetRenameTests: XCTestCase {
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

    private func makeState(
        imageName: String = AppConstants.defaultImageName,
        originX: CGFloat = 100
    ) -> WindowState {
        WindowState(
            imageName: imageName,
            originX: originX,
            originY: 200,
            width: 300,
            height: 400,
            isFlippedHorizontally: false,
            rotationAngle: 0,
            opacityLevel: 1.0,
            windowId: 0
        )
    }

    // MARK: - Rename Tests

    /// プリセットのリネームが正しく動作しcreatedAtが保持されることを検証
    func testRenamePresetSuccess() throws {
        let states = [makeState(imageName: "rename.png", originX: 42)]
        presetManager.savePreset(name: "OldName", states: states)

        let oldPreset = try XCTUnwrap(presetManager.loadPreset(named: "OldName"))
        let result = presetManager.renamePreset(from: "OldName", to: "NewName")

        XCTAssertTrue(result)
        XCTAssertNil(presetManager.loadPreset(named: "OldName"))

        let renamed = try XCTUnwrap(presetManager.loadPreset(named: "NewName"))
        XCTAssertEqual(renamed.name, "NewName")
        XCTAssertEqual(renamed.states, states)
        XCTAssertEqual(renamed.createdAt, oldPreset.createdAt)
    }

    /// 存在しないプリセットのリネームでfalseが返されることを検証
    func testRenameNonExistentPreset() {
        let result = presetManager.renamePreset(from: "DoesNotExist", to: "NewName")
        XCTAssertFalse(result)
    }

    /// 同名へのリネームが成功し内容が保持されることを検証
    func testRenameSameName() throws {
        let states = [makeState(imageName: "same.png")]
        presetManager.savePreset(name: "SameName", states: states)

        let result = presetManager.renamePreset(from: "SameName", to: "SameName")
        XCTAssertTrue(result)

        let loaded = try XCTUnwrap(presetManager.loadPreset(named: "SameName"))
        XCTAssertEqual(loaded.name, "SameName")
        XCTAssertEqual(loaded.states, states)
    }

    /// リネームで既存プリセットが上書きされることを検証
    func testRenameOverwritesExisting() throws {
        presetManager.savePreset(name: "Source", states: [makeState(originX: 100)])
        presetManager.savePreset(name: "Target", states: [makeState(originX: 200)])

        let result = presetManager.renamePreset(from: "Source", to: "Target")
        XCTAssertTrue(result)

        XCTAssertNil(presetManager.loadPreset(named: "Source"))
        let target = try XCTUnwrap(presetManager.loadPreset(named: "Target"))
        XCTAssertEqual(target.states, [makeState(originX: 100)])
    }

    /// Unicode文字を含む名前へのリネームが正しく動作することを検証
    func testRenameWithSpecialCharacters() throws {
        let states = [makeState(imageName: "special.png")]
        presetManager.savePreset(name: "Normal", states: states)

        let result = presetManager.renamePreset(from: "Normal", to: "特殊文字レイアウト")
        XCTAssertTrue(result)

        XCTAssertNil(presetManager.loadPreset(named: "Normal"))
        let renamed = try XCTUnwrap(presetManager.loadPreset(named: "特殊文字レイアウト"))
        XCTAssertEqual(renamed.states, states)
    }
}
