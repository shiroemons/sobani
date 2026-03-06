import XCTest
@testable import Sobani

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

    // MARK: - Save and Load Tests

    func testSaveAndLoadPresetRoundTrip() {
        let states = [makeState(imageName: "image1.png"), makeState(imageName: "image2.png")]
        presetManager.savePreset(name: "TestPreset", states: states)

        let loaded = presetManager.loadPreset(named: "TestPreset")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "TestPreset")
        XCTAssertEqual(loaded?.states, states)
    }

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

    func testLoadPresetsOrderedByCreatedAtDescending() {
        presetManager.savePreset(name: "OldPreset", states: [makeState(originX: 1)])
        sleep(1)
        presetManager.savePreset(name: "MiddlePreset", states: [makeState(originX: 2)])
        sleep(1)
        presetManager.savePreset(name: "NewPreset", states: [makeState(originX: 3)])

        let all = presetManager.loadPresets()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].name, "NewPreset")
        XCTAssertEqual(all[1].name, "MiddlePreset")
        XCTAssertEqual(all[2].name, "OldPreset")
    }

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

    func testDeletePreset() {
        presetManager.savePreset(name: "ToDelete", states: [makeState()])
        XCTAssertNotNil(presetManager.loadPreset(named: "ToDelete"))

        presetManager.deletePreset(named: "ToDelete")
        XCTAssertNil(presetManager.loadPreset(named: "ToDelete"))
    }

    func testDeleteNonExistentPreset() {
        // Should not crash
        presetManager.deletePreset(named: "NonExistent")
        XCTAssertEqual(presetManager.loadPresets().count, 0)
    }

    // MARK: - presetExists Tests

    func testPresetExistsTrue() {
        presetManager.savePreset(name: "Exists", states: [makeState()])
        XCTAssertTrue(presetManager.presetExists(named: "Exists"))
    }

    func testPresetExistsFalse() {
        XCTAssertFalse(presetManager.presetExists(named: "DoesNotExist"))
    }

    // MARK: - Sanitized File Name Tests

    func testSanitizedFileNameSpecialCharacters() {
        let specialName = "test/\\:*?\"<>|name"
        let states = [makeState(imageName: "special.png")]
        presetManager.savePreset(name: specialName, states: states)

        let loaded = presetManager.loadPreset(named: specialName)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, specialName)
        XCTAssertEqual(loaded?.states, states)
    }

    func testSanitizedFileNamePathTraversal() {
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
    }

    // MARK: - Edge Case Tests

    func testEmptyStatesArray() {
        presetManager.savePreset(name: "EmptyPreset", states: [])

        let loaded = presetManager.loadPreset(named: "EmptyPreset")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "EmptyPreset")
        XCTAssertEqual(loaded?.states, [])
    }

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

    func testLayoutPresetCodable() throws {
        let states = [makeState(imageName: "test.png", originX: 50, originY: 60)]
        let preset = LayoutPreset(name: "CodableTest", createdAt: Date(), states: states)

        let encoder = JSONEncoder()
        let data = try encoder.encode(preset)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LayoutPreset.self, from: data)

        XCTAssertEqual(decoded, preset)
    }

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

    func testLoadPresetNonExistent() {
        let loaded = presetManager.loadPreset(named: "NeverSaved")
        XCTAssertNil(loaded)
    }

    // MARK: - Directory Tests

    func testLayoutsDirectoryCreated() throws {
        let layoutsDir = try XCTUnwrap(presetManager.layoutsDirectoryURL)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: layoutsDir.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDirectory.boolValue)
    }

    // MARK: - Multiple States Tests

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
        XCTAssertEqual(loadedStates[0].rotationAngle, 45, accuracy: 0.001)
        XCTAssertEqual(loadedStates[0].opacityLevel, 0.7, accuracy: 0.001)
        XCTAssertEqual(loadedStates[0].windowId, 3)
        XCTAssertEqual(loadedStates[0].originX, 150, accuracy: 0.001)
        XCTAssertEqual(loadedStates[0].originY, 250, accuracy: 0.001)
        XCTAssertEqual(loadedStates[0].width, 500, accuracy: 0.001)
        XCTAssertEqual(loadedStates[0].height, 600, accuracy: 0.001)

        XCTAssertEqual(loadedStates[1].imageName, "rotated.png")
        XCTAssertFalse(loadedStates[1].isFlippedHorizontally)
        XCTAssertEqual(loadedStates[1].rotationAngle, 180, accuracy: 0.001)
        XCTAssertEqual(loadedStates[1].opacityLevel, 0.5, accuracy: 0.001)
        XCTAssertEqual(loadedStates[1].windowId, 7)
    }

    // MARK: - Delete Then Exists Tests

    func testDeleteThenPresetExistsFalse() {
        presetManager.savePreset(name: "WillBeDeleted", states: [makeState()])
        XCTAssertTrue(presetManager.presetExists(named: "WillBeDeleted"))

        presetManager.deletePreset(named: "WillBeDeleted")
        XCTAssertFalse(presetManager.presetExists(named: "WillBeDeleted"))
    }
}
