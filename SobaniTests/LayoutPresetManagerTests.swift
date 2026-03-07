import XCTest
@testable import Sobani

/// レイアウトプリセットの保存・読み込み・削除・リネーム、ファイル名サニタイズ、エッジケース、Codable/Equatable準拠を検証するテスト
final class LayoutPresetManagerTests: XCTestCase {
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

    private func writePreset(
        name: String, originX: CGFloat, createdAt: Date,
        encoder: JSONEncoder, directory: URL
    ) throws {
        let preset = LayoutPreset(name: name, createdAt: createdAt, states: [makeState(originX: originX)])
        let data = try encoder.encode(preset)
        try data.write(to: directory.appendingPathComponent("\(name).json"), options: .atomic)
    }

    // MARK: - Save and Load Tests

    /// プリセットの保存と読み込みのラウンドトリップが正しく動作することを検証
    func testSaveAndLoadPresetRoundTrip() {
        let states = [makeState(imageName: "image1.png"), makeState(imageName: "image2.png")]
        presetManager.savePreset(name: "TestPreset", states: states)

        let loaded = presetManager.loadPreset(named: "TestPreset")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "TestPreset")
        XCTAssertEqual(loaded?.states, states)
    }

    /// 複数プリセットがすべて読み込まれることを検証
    func testLoadPresetsReturnsAllPresets() {
        presetManager.savePreset(name: "Preset1", states: [makeState(originX: 1)])
        presetManager.savePreset(name: "Preset2", states: [makeState(originX: 2)])
        presetManager.savePreset(name: "Preset3", states: [makeState(originX: 3)])

        let all = presetManager.loadPresets()
        XCTAssertEqual(all.count, 3)

        let names = Set(all.map { $0.name })
        XCTAssertTrue(names.contains("Preset1"))
        XCTAssertTrue(names.contains("Preset2"))
        XCTAssertTrue(names.contains("Preset3"))
    }

    /// プリセットがcreatedAtの降順でソートされることを検証
    func testLoadPresetsOrderedByCreatedAtDescending() throws {
        // Save all presets first, then overwrite JSON to control createdAt
        presetManager.savePreset(name: "OldPreset", states: [makeState(originX: 1)])
        presetManager.savePreset(name: "MiddlePreset", states: [makeState(originX: 2)])
        presetManager.savePreset(name: "NewPreset", states: [makeState(originX: 3)])

        // Overwrite createdAt with controlled dates
        let layoutsDir = try XCTUnwrap(presetManager.layoutsDirectoryURL)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let now = Date()

        try writePreset(name: "OldPreset", originX: 1, createdAt: now.addingTimeInterval(-200),
                       encoder: encoder, directory: layoutsDir)
        try writePreset(name: "MiddlePreset", originX: 2, createdAt: now.addingTimeInterval(-100),
                       encoder: encoder, directory: layoutsDir)
        try writePreset(name: "NewPreset", originX: 3, createdAt: now,
                       encoder: encoder, directory: layoutsDir)

        let all = presetManager.loadPresets()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].name, "NewPreset")
        XCTAssertEqual(all[1].name, "MiddlePreset")
        XCTAssertEqual(all[2].name, "OldPreset")
    }

    /// 同名プリセットの上書き保存が正しく動作することを検証
    func testOverwritePreset() {
        let firstStates = [makeState(imageName: "first.png")]
        presetManager.savePreset(name: "MyPreset", states: firstStates)
        XCTAssertEqual(presetManager.loadPreset(named: "MyPreset")?.states, firstStates)

        let secondStates = [makeState(imageName: "second.png"), makeState(imageName: "third.png")]
        presetManager.savePreset(name: "MyPreset", states: secondStates)

        let loaded = presetManager.loadPreset(named: "MyPreset")
        XCTAssertEqual(loaded?.states, secondStates)
        XCTAssertEqual(loaded?.states.count, 2)
    }

    // MARK: - Delete Tests

    /// プリセットの削除が正しく動作することを検証
    func testDeletePreset() {
        presetManager.savePreset(name: "ToDelete", states: [makeState()])
        XCTAssertNotNil(presetManager.loadPreset(named: "ToDelete"))

        presetManager.deletePreset(named: "ToDelete")
        XCTAssertNil(presetManager.loadPreset(named: "ToDelete"))
    }

    /// 存在しないプリセットの削除でクラッシュしないことを検証
    func testDeleteNonExistentPreset() {
        // Should not crash
        presetManager.deletePreset(named: "NonExistent")
        XCTAssertEqual(presetManager.loadPresets().count, 0)
    }

    // MARK: - presetExists Tests

    /// 存在するプリセットに対してtrueが返されることを検証
    func testPresetExistsTrue() {
        presetManager.savePreset(name: "Exists", states: [makeState()])
        XCTAssertTrue(presetManager.presetExists(named: "Exists"))
    }

    /// 存在しないプリセットに対してfalseが返されることを検証
    func testPresetExistsFalse() {
        XCTAssertFalse(presetManager.presetExists(named: "DoesNotExist"))
    }

    // MARK: - Sanitized File Name Tests

    /// 特殊文字を含むプリセット名の保存と読み込みが正しく動作することを検証
    func testSanitizedFileNameSpecialCharacters() {
        let specialName = "test/\\:*?\"<>|name"
        let states = [makeState(imageName: "special.png")]
        presetManager.savePreset(name: specialName, states: states)

        let loaded = presetManager.loadPreset(named: specialName)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, specialName)
        XCTAssertEqual(loaded?.states, states)
    }

    /// パストラバーサルを含む名前でlayoutsディレクトリ外に保存されないことを検証
    func testSanitizedFileNamePathTraversal() throws {
        let dangerousName = "../../../etc/passwd"
        let states = [makeState(imageName: "safe.png")]
        presetManager.savePreset(name: dangerousName, states: states)

        let loaded = presetManager.loadPreset(named: dangerousName)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, dangerousName)
        XCTAssertEqual(loaded?.states, states)

        // Verify the file was saved inside the layouts directory, not at a traversed path
        let layoutsDir = presetManager.layoutsDirectoryURL
        XCTAssertNotNil(layoutsDir)

        // ファイルがlayoutsディレクトリ内に保存されたことを検証
        let layoutsDirUnwrapped = try XCTUnwrap(presetManager.layoutsDirectoryURL)
        let resolvedLayoutsDir = layoutsDirUnwrapped.standardizedFileURL.path
        let files = try FileManager.default.contentsOfDirectory(at: layoutsDirUnwrapped, includingPropertiesForKeys: nil)
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        XCTAssertFalse(jsonFiles.isEmpty, "Preset file should exist in layouts directory")
        for file in jsonFiles {
            XCTAssertTrue(file.standardizedFileURL.path.hasPrefix(resolvedLayoutsDir),
                          "Preset file must be inside layouts directory: \(file.path)")
        }
    }

    // MARK: - Edge Case Tests

    /// 空のWindowState配列を持つプリセットが正しく保存・読み込みされることを検証
    func testEmptyStatesArray() {
        presetManager.savePreset(name: "EmptyPreset", states: [])

        let loaded = presetManager.loadPreset(named: "EmptyPreset")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "EmptyPreset")
        XCTAssertEqual(loaded?.states, [])
    }

    /// 不正なJSONファイルがスキップされ有効なプリセットのみ読み込まれることを検証
    func testInvalidJSONSkipped() throws {
        // Write invalid JSON file directly into the layouts directory
        let layoutsDir = try XCTUnwrap(presetManager.layoutsDirectoryURL)

        let invalidFile = layoutsDir.appendingPathComponent("invalid.json")
        try "{ not valid json }}}".write(to: invalidFile, atomically: true, encoding: .utf8)

        // Also save a valid preset
        presetManager.savePreset(name: "ValidPreset", states: [makeState()])

        let all = presetManager.loadPresets()
        // Should load at least the valid preset without crashing
        XCTAssertTrue(all.contains(where: { $0.name == "ValidPreset" }))
    }

    /// Unicode(日本語)プリセット名の保存と読み込みが正しく動作することを検証
    func testUnicodePresetName() {
        let japaneseName = "お気に入りレイアウト"
        let states = [makeState(imageName: "character.png")]
        presetManager.savePreset(name: japaneseName, states: states)

        let loaded = presetManager.loadPreset(named: japaneseName)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, japaneseName)
        XCTAssertEqual(loaded?.states, states)
    }

    // MARK: - LayoutPreset Codable/Equatable Tests

    /// LayoutPresetのCodableエンコード・デコードが正しく動作することを検証
    func testLayoutPresetCodable() throws {
        let states = [makeState(imageName: "test.png", originX: 50, originY: 60)]
        let preset = LayoutPreset(name: "CodableTest", createdAt: Date(), states: states)

        let encoder = JSONEncoder()
        let data = try encoder.encode(preset)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LayoutPreset.self, from: data)

        XCTAssertEqual(decoded, preset)
    }

    /// LayoutPresetのEquatable比較が正しく動作することを検証
    func testLayoutPresetEquatable() {
        let date = Date()
        let states = [makeState(imageName: "eq.png")]

        let preset1 = LayoutPreset(name: "Same", createdAt: date, states: states)
        let preset2 = LayoutPreset(name: "Same", createdAt: date, states: states)
        XCTAssertEqual(preset1, preset2)

        let preset3 = LayoutPreset(name: "Different", createdAt: date, states: states)
        XCTAssertNotEqual(preset1, preset3)

        let differentStates = [makeState(imageName: "other.png")]
        let preset4 = LayoutPreset(name: "Same", createdAt: date, states: differentStates)
        XCTAssertNotEqual(preset1, preset4)
    }

    // MARK: - Load Non-Existent Tests

    /// 存在しないプリセットの読み込みでnilが返されることを検証
    func testLoadPresetNonExistent() {
        let loaded = presetManager.loadPreset(named: "NeverSaved")
        XCTAssertNil(loaded)
    }

    // MARK: - Directory Tests

    /// layoutsディレクトリが自動作成されることを検証
    func testLayoutsDirectoryCreated() throws {
        let layoutsDir = try XCTUnwrap(presetManager.layoutsDirectoryURL)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: layoutsDir.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDirectory.boolValue)
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
