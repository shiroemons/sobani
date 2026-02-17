import XCTest
@testable import Sobani

final class WindowStateManagerTests: XCTestCase {
    var tempDirectory: URL!
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
        imageName: String = "デフォルト",
        originX: CGFloat = 100,
        originY: CGFloat = 200,
        width: CGFloat = 300,
        height: CGFloat = 400,
        isFlippedHorizontally: Bool = false,
        rotationAngle: CGFloat = 0,
        opacityLevel: CGFloat = 1.0
    ) -> WindowState {
        WindowState(
            imageName: imageName,
            originX: originX,
            originY: originY,
            width: width,
            height: height,
            isFlippedHorizontally: isFlippedHorizontally,
            rotationAngle: rotationAngle,
            opacityLevel: opacityLevel
        )
    }

    // MARK: - Encode/Decode Tests

    func testEncodeDecodeRoundTrip() {
        let state = makeState()
        let data = try! JSONEncoder().encode([state])
        let decoded = try! JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded, [state])
    }

    func testEncodeDecodeWithFlip() {
        let state = makeState(isFlippedHorizontally: true)
        let data = try! JSONEncoder().encode([state])
        let decoded = try! JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.isFlippedHorizontally, true)
    }

    // MARK: - Save/Load Tests

    func testSaveAndLoadMultipleStates() {
        let states = [
            makeState(imageName: "image1.png", originX: 10, originY: 20),
            makeState(imageName: "image2.png", originX: 30, originY: 40),
            makeState(imageName: "デフォルト", originX: 50, originY: 60)
        ]
        stateManager.saveStates(states)
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded, states)
    }

    func testLoadStatesWhenFileDoesNotExist() {
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded, [])
    }

    func testLoadStatesWithCorruptedJSON() {
        guard let url = stateManager.statesFileURL else {
            XCTFail("statesFileURL is nil")
            return
        }
        try! "{ invalid json".write(to: url, atomically: true, encoding: .utf8)
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded, [])
    }

    func testSaveAndLoadEmptyArray() {
        stateManager.saveStates([])
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded, [])
    }

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

    func testStatesFileURL() {
        let url = stateManager.statesFileURL
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.path.hasSuffix("window_states.json"))
    }

    // MARK: - Position Visibility Tests

    func testIsPositionVisibleOnScreen() {
        guard let mainScreen = NSScreen.main else { return }
        let frame = mainScreen.frame
        let state = makeState(
            originX: frame.midX - 150,
            originY: frame.midY - 200,
            width: 300,
            height: 400
        )
        XCTAssertTrue(WindowStateManager.isPositionVisible(state))
    }

    func testIsPositionVisibleOffScreen() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400
        )
        XCTAssertFalse(WindowStateManager.isPositionVisible(state))
    }

    func testAdjustToVisibleAreaNoChangeWhenVisible() {
        guard let mainScreen = NSScreen.main else { return }
        let frame = mainScreen.frame
        let state = makeState(
            originX: frame.midX - 150,
            originY: frame.midY - 200,
            width: 300,
            height: 400
        )
        let adjusted = WindowStateManager.adjustToVisibleArea(state)
        XCTAssertEqual(adjusted, state)
    }

    func testAdjustToVisibleAreaMovesToCenter() {
        guard let mainScreen = NSScreen.main else { return }
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400
        )
        let adjusted = WindowStateManager.adjustToVisibleArea(state)
        XCTAssertNotEqual(adjusted.originX, state.originX)
        XCTAssertNotEqual(adjusted.originY, state.originY)

        let expectedX = mainScreen.frame.midX - 150
        let expectedY = mainScreen.frame.midY - 200
        XCTAssertEqual(adjusted.originX, expectedX, accuracy: 1.0)
        XCTAssertEqual(adjusted.originY, expectedY, accuracy: 1.0)
        XCTAssertEqual(adjusted.width, 300)
        XCTAssertEqual(adjusted.height, 400)
    }

    // MARK: - Order Preservation Test

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

    func testJapaneseImageNameEncodeDecode() {
        let state = makeState(imageName: "かわいい画像.png")
        stateManager.saveStates([state])
        let loaded = stateManager.loadStates()
        XCTAssertEqual(loaded.first?.imageName, "かわいい画像.png")
    }

    // MARK: - Rotation Angle Tests

    func testEncodeDecodeWithRotation() {
        let state = makeState(rotationAngle: 45)
        let data = try! JSONEncoder().encode([state])
        let decoded = try! JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.rotationAngle, 45)
    }

    func testBackwardCompatibilityWithoutRotation() {
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
        let data = json.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.rotationAngle, 0)
    }

    func testEncodeDecodeWithFlipAndRotation() {
        let state = makeState(isFlippedHorizontally: true, rotationAngle: 90)
        let data = try! JSONEncoder().encode([state])
        let decoded = try! JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.isFlippedHorizontally, true)
        XCTAssertEqual(decoded.first?.rotationAngle, 90)
    }

    func testAdjustToVisibleAreaPreservesRotation() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400,
            rotationAngle: 180
        )
        let adjusted = WindowStateManager.adjustToVisibleArea(state)
        XCTAssertEqual(adjusted.rotationAngle, 180)
    }

    func testDefaultRotationAngleIsZero() {
        let state = makeState()
        XCTAssertEqual(state.rotationAngle, 0)
    }

    // MARK: - Opacity Tests

    func testOpacityLevelEncodeDecode() throws {
        let state = makeState(opacityLevel: 0.5)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        let decodedOpacity = try XCTUnwrap(decoded.first?.opacityLevel)
        XCTAssertEqual(decodedOpacity, 0.5, accuracy: 0.001)
    }

    func testOpacityLevelBackwardCompatibility() throws {
        let json = """
        [{"imageName":"test.png","originX":100,"originY":200,"width":300,"height":400,"isFlippedHorizontally":false,"rotationAngle":0}]
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        XCTAssertEqual(decoded.first?.opacityLevel, 1.0, "Missing opacityLevel should default to 1.0")
    }

    func testOpacityLevelDefaultValue() {
        let state = makeState()
        XCTAssertEqual(state.opacityLevel, 1.0)
    }

    func testAdjustToVisibleAreaPreservesOpacity() {
        let state = makeState(
            originX: -99999,
            originY: -99999,
            width: 300,
            height: 400,
            opacityLevel: 0.3
        )
        let adjusted = WindowStateManager.adjustToVisibleArea(state)
        XCTAssertEqual(adjusted.opacityLevel, 0.3, accuracy: 0.001)
    }

    func testFlipRotationAndOpacityCombination() throws {
        let state = makeState(isFlippedHorizontally: true, rotationAngle: 90, opacityLevel: 0.7)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data).first!
        XCTAssertTrue(decoded.isFlippedHorizontally)
        XCTAssertEqual(decoded.rotationAngle, 90, accuracy: 0.001)
        XCTAssertEqual(decoded.opacityLevel, 0.7, accuracy: 0.001)
    }
}
