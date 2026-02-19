import XCTest
@testable import Sobani

final class ScreenRestorationManagerTests: XCTestCase {
    var manager: ScreenRestorationManager!
    var tempDirectory: URL!
    var ioManager: ScreenRestorationManager!

    override func setUp() {
        super.setUp()
        manager = ScreenRestorationManager(timeout: 300)
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        ioManager = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        ioManager = nil
        tempDirectory = nil
        manager = nil
        super.tearDown()
    }

    private func makeState(windowId: Int = 1, originX: CGFloat = 100, originY: CGFloat = 200) -> WindowState {
        WindowState(
            imageName: "テスト",
            originX: originX,
            originY: originY,
            width: 300,
            height: 400,
            isFlippedHorizontally: false,
            windowId: windowId
        )
    }

    // MARK: - addPending

    func testAddPending() {
        let state = makeState()
        manager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        XCTAssertEqual(manager.pendingRestorations.count, 1)
        XCTAssertEqual(manager.pendingRestorations[0].windowId, 1)
        XCTAssertEqual(manager.pendingRestorations[0].originalState, state)
        XCTAssertEqual(manager.pendingRestorations[0].adjustedOriginX, 50)
        XCTAssertEqual(manager.pendingRestorations[0].adjustedOriginY, 60)
    }

    func testAddPendingOverwritesSameWindowId() {
        let state1 = makeState(windowId: 1, originX: 100)
        let state2 = makeState(windowId: 1, originX: 999)
        manager.addPending(windowId: 1, originalState: state1, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        manager.addPending(windowId: 1, originalState: state2, displayID: 0, adjustedOriginX: 70, adjustedOriginY: 80)
        XCTAssertEqual(manager.pendingRestorations.count, 1)
        XCTAssertEqual(manager.pendingRestorations[0].originalState.originX, 999)
    }

    // MARK: - removePending

    func testRemovePending() {
        let state = makeState()
        manager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        manager.removePending(windowId: 1)
        XCTAssertTrue(manager.pendingRestorations.isEmpty)
    }

    func testRemovePendingNonExistentDoesNotCrash() {
        manager.removePending(windowId: 999)
        XCTAssertTrue(manager.pendingRestorations.isEmpty)
    }

    // MARK: - hasPending

    func testHasPendingWhenEmpty() {
        XCTAssertFalse(manager.hasPending)
    }

    func testHasPendingWhenNotEmpty() {
        let state = makeState()
        manager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        XCTAssertTrue(manager.hasPending)
    }

    // MARK: - clearAll

    func testClearAll() {
        manager.addPending(windowId: 1, originalState: makeState(windowId: 1), displayID: 0, adjustedOriginX: 10, adjustedOriginY: 20)
        manager.addPending(windowId: 2, originalState: makeState(windowId: 2), displayID: 0, adjustedOriginX: 30, adjustedOriginY: 40)
        manager.clearAll()
        XCTAssertTrue(manager.pendingRestorations.isEmpty)
    }

    // MARK: - purgeExpired

    func testPurgeExpiredRemovesOldEntries() {
        let baseDate = Date()
        manager.currentDate = { baseDate }
        manager.addPending(windowId: 1, originalState: makeState(), displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)

        // Advance time past timeout
        manager.currentDate = { baseDate.addingTimeInterval(301) }
        manager.purgeExpired()

        XCTAssertTrue(manager.pendingRestorations.isEmpty)
    }

    func testPurgeExpiredKeepsRecentEntries() {
        let baseDate = Date()
        manager.currentDate = { baseDate }
        manager.addPending(windowId: 1, originalState: makeState(), displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)

        // Advance time but stay within timeout
        manager.currentDate = { baseDate.addingTimeInterval(299) }
        manager.purgeExpired()

        XCTAssertEqual(manager.pendingRestorations.count, 1)
    }

    // MARK: - restorableEntries

    func testRestorableEntriesReturnsEmptyWhenNoMatchingScreen() {
        // displayID: 999999 は実際のモニターに対応しないため、接続中スクリーンに一致しない
        let state1 = makeState(windowId: 1, originX: 100)
        let state2 = makeState(windowId: 2, originX: 200)
        manager.addPending(windowId: 1, originalState: state1, displayID: 999999, adjustedOriginX: 50, adjustedOriginY: 60)
        manager.addPending(windowId: 2, originalState: state2, displayID: 999999, adjustedOriginX: 70, adjustedOriginY: 80)

        let results = manager.restorableEntries()

        // displayID: 999999 は実スクリーンと一致しないため空になる
        XCTAssertTrue(results.isEmpty)
    }

    func testRestorableEntriesCallsPurgeExpired() {
        let baseDate = Date()
        manager.currentDate = { baseDate }
        manager.addPending(windowId: 1, originalState: makeState(), displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)

        // Advance time past timeout
        manager.currentDate = { baseDate.addingTimeInterval(301) }
        let results = manager.restorableEntries()

        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(manager.pendingRestorations.isEmpty)
    }

    func testRestorableEntriesWithKnownDisplayIDNotMatching() {
        // displayID が非0で実スクリーンに存在しない場合は空
        let state = makeState(windowId: 1, originX: 100, originY: 200)
        manager.addPending(windowId: 1, originalState: state, displayID: 999999, adjustedOriginX: 50, adjustedOriginY: 60)

        let results = manager.restorableEntries()

        XCTAssertTrue(results.isEmpty)
    }

    func testRestorableEntriesWithZeroDisplayIDAndInvisiblePosition() {
        // displayID: 0（スリープなし切断）かつ画面外の位置 → 空（元の位置がまだ不可視）
        let state = makeState(windowId: 1, originX: -99999, originY: -99999)
        manager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)

        let results = manager.restorableEntries()

        // 元の位置が不可視のため、復元対象にならない
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Persistence

    func testPendingFileURL() {
        let url = ioManager.pendingFileURL
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.lastPathComponent, "pending_restorations.json")
    }

    func testSaveAndLoadRoundTrip() {
        let state = makeState(windowId: 1, originX: 100, originY: 200)
        ioManager.addPending(windowId: 1, originalState: state, displayID: 42, adjustedOriginX: 50, adjustedOriginY: 60)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        XCTAssertEqual(loader.pendingRestorations.count, 1)
        let entry = loader.pendingRestorations[0]
        XCTAssertEqual(entry.windowId, 1)
        XCTAssertEqual(entry.originalState, state)
        XCTAssertEqual(entry.displayID, 42)
        XCTAssertEqual(entry.adjustedOriginX, 50)
        XCTAssertEqual(entry.adjustedOriginY, 60)
    }

    func testSaveAndLoadMultipleEntries() {
        let state1 = makeState(windowId: 1, originX: 100)
        let state2 = makeState(windowId: 2, originX: 200)
        ioManager.addPending(windowId: 1, originalState: state1, displayID: 10, adjustedOriginX: 10, adjustedOriginY: 20)
        ioManager.addPending(windowId: 2, originalState: state2, displayID: 20, adjustedOriginX: 30, adjustedOriginY: 40)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        XCTAssertEqual(loader.pendingRestorations.count, 2)
    }

    func testLoadPendingWhenFileDoesNotExist() {
        // ファイルなしでクラッシュせず、空キューになる
        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()
        XCTAssertTrue(loader.pendingRestorations.isEmpty)
    }

    func testLoadPendingWithCorruptedJSON() {
        let url = ioManager.pendingFileURL!
        try? Data("not valid json".utf8).write(to: url, options: .atomic)

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()
        XCTAssertTrue(loader.pendingRestorations.isEmpty)
    }

    func testLoadPendingPurgesExpiredEntries() {
        let baseDate = Date()
        ioManager.currentDate = { baseDate }
        let state = makeState(windowId: 1)
        ioManager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        ioManager.savePending()

        // タイムアウト超過した時刻でロード
        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.currentDate = { baseDate.addingTimeInterval(301) }
        loader.loadPending()

        XCTAssertTrue(loader.pendingRestorations.isEmpty)
    }

    func testStartupEntryOverwritesLoadedEntry() {
        // 起動時のaddPendingが読み込んだエントリを上書きする
        let stateOld = makeState(windowId: 1, originX: 100)
        ioManager.addPending(windowId: 1, originalState: stateOld, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        // 起動時に新しいエントリで上書き
        let stateNew = makeState(windowId: 1, originX: 999)
        loader.addPending(windowId: 1, originalState: stateNew, displayID: 0, adjustedOriginX: 70, adjustedOriginY: 80)

        XCTAssertEqual(loader.pendingRestorations.count, 1)
        XCTAssertEqual(loader.pendingRestorations[0].originalState.originX, 999)
    }

    func testSaveEmptyQueueProducesEmptyFile() {
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()
        XCTAssertTrue(loader.pendingRestorations.isEmpty)
    }

    func testDisplayIDPreservedAcrossSaveLoad() {
        let displayID: CGDirectDisplayID = 1234567890
        let state = makeState(windowId: 1)
        ioManager.addPending(windowId: 1, originalState: state, displayID: displayID, adjustedOriginX: 0, adjustedOriginY: 0)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        XCTAssertEqual(loader.pendingRestorations[0].displayID, displayID)
    }
}
