import XCTest
@testable import Sobani

final class ScreenRestorationManagerTests: XCTestCase {
    var manager: ScreenRestorationManager!

    override func setUp() {
        super.setUp()
        manager = ScreenRestorationManager(timeout: 300)
    }

    override func tearDown() {
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
        manager.addPending(windowId: 1, originalState: state, adjustedOriginX: 50, adjustedOriginY: 60)
        XCTAssertEqual(manager.pendingRestorations.count, 1)
        XCTAssertEqual(manager.pendingRestorations[0].windowId, 1)
        XCTAssertEqual(manager.pendingRestorations[0].originalState, state)
        XCTAssertEqual(manager.pendingRestorations[0].adjustedOriginX, 50)
        XCTAssertEqual(manager.pendingRestorations[0].adjustedOriginY, 60)
    }

    func testAddPendingOverwritesSameWindowId() {
        let state1 = makeState(windowId: 1, originX: 100)
        let state2 = makeState(windowId: 1, originX: 999)
        manager.addPending(windowId: 1, originalState: state1, adjustedOriginX: 50, adjustedOriginY: 60)
        manager.addPending(windowId: 1, originalState: state2, adjustedOriginX: 70, adjustedOriginY: 80)
        XCTAssertEqual(manager.pendingRestorations.count, 1)
        XCTAssertEqual(manager.pendingRestorations[0].originalState.originX, 999)
    }

    // MARK: - removePending

    func testRemovePending() {
        let state = makeState()
        manager.addPending(windowId: 1, originalState: state, adjustedOriginX: 50, adjustedOriginY: 60)
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
        manager.addPending(windowId: 1, originalState: state, adjustedOriginX: 50, adjustedOriginY: 60)
        XCTAssertTrue(manager.hasPending)
    }

    // MARK: - clearAll

    func testClearAll() {
        manager.addPending(windowId: 1, originalState: makeState(windowId: 1), adjustedOriginX: 10, adjustedOriginY: 20)
        manager.addPending(windowId: 2, originalState: makeState(windowId: 2), adjustedOriginX: 30, adjustedOriginY: 40)
        manager.clearAll()
        XCTAssertTrue(manager.pendingRestorations.isEmpty)
    }

    // MARK: - purgeExpired

    func testPurgeExpiredRemovesOldEntries() {
        let baseDate = Date()
        manager.currentDate = { baseDate }
        manager.addPending(windowId: 1, originalState: makeState(), adjustedOriginX: 50, adjustedOriginY: 60)

        // Advance time past timeout
        manager.currentDate = { baseDate.addingTimeInterval(301) }
        manager.purgeExpired()

        XCTAssertTrue(manager.pendingRestorations.isEmpty)
    }

    func testPurgeExpiredKeepsRecentEntries() {
        let baseDate = Date()
        manager.currentDate = { baseDate }
        manager.addPending(windowId: 1, originalState: makeState(), adjustedOriginX: 50, adjustedOriginY: 60)

        // Advance time but stay within timeout
        manager.currentDate = { baseDate.addingTimeInterval(299) }
        manager.purgeExpired()

        XCTAssertEqual(manager.pendingRestorations.count, 1)
    }

    // MARK: - restorableEntries

    func testRestorableEntriesFiltersVisible() {
        let state1 = makeState(windowId: 1, originX: 100)
        let state2 = makeState(windowId: 2, originX: 200)
        manager.addPending(windowId: 1, originalState: state1, adjustedOriginX: 50, adjustedOriginY: 60)
        manager.addPending(windowId: 2, originalState: state2, adjustedOriginX: 70, adjustedOriginY: 80)

        let results = manager.restorableEntries { state in
            state.originX == 100
        }

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].windowId, 1)
    }

    func testRestorableEntriesCallsPurgeExpired() {
        let baseDate = Date()
        manager.currentDate = { baseDate }
        manager.addPending(windowId: 1, originalState: makeState(), adjustedOriginX: 50, adjustedOriginY: 60)

        // Advance time past timeout
        manager.currentDate = { baseDate.addingTimeInterval(301) }
        let results = manager.restorableEntries { _ in true }

        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(manager.pendingRestorations.isEmpty)
    }
}
