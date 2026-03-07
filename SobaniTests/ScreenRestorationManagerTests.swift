import CoreGraphics
import Foundation
import Testing
@preconcurrency @testable import Sobani

/// 保留中のウィンドウ復元エントリの追加・削除・期限切れパージ、JSON永続化のラウンドトリップ、後方互換性、スリープ前画面フレームを検証するテスト
@Suite @MainActor struct ScreenRestorationManagerTests {
    let manager: ScreenRestorationManager
    let tempDirectory: URL
    let ioManager: ScreenRestorationManager

    init() throws {
        manager = ScreenRestorationManager(timeout: 300)
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        ioManager = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
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

    /// 保留エントリが正しく追加されることを検証
    @Test func addPending() {
        let state = makeState()
        manager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        #expect(manager.pendingRestorations.count == 1)
        #expect(manager.pendingRestorations[0].windowId == 1)
        #expect(manager.pendingRestorations[0].originalState == state)
        #expect(manager.pendingRestorations[0].adjustedOriginX == 50)
        #expect(manager.pendingRestorations[0].adjustedOriginY == 60)
    }

    /// 同じwindowIdのエントリが上書きされることを検証
    @Test func addPendingOverwritesSameWindowId() {
        let state1 = makeState(windowId: 1, originX: 100)
        let state2 = makeState(windowId: 1, originX: 999)
        manager.addPending(windowId: 1, originalState: state1, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        manager.addPending(windowId: 1, originalState: state2, displayID: 0, adjustedOriginX: 70, adjustedOriginY: 80)
        #expect(manager.pendingRestorations.count == 1)
        #expect(manager.pendingRestorations[0].originalState.originX == 999)
    }

    // MARK: - removePending

    /// 保留エントリが正しく削除されることを検証
    @Test func removePending() {
        let state = makeState()
        manager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        manager.removePending(windowId: 1)
        #expect(manager.pendingRestorations.isEmpty)
    }

    /// 存在しないwindowIdの削除でクラッシュしないことを検証
    @Test func removePendingNonExistentDoesNotCrash() {
        manager.removePending(windowId: 999)
        #expect(manager.pendingRestorations.isEmpty)
    }

    // MARK: - hasPending

    /// 空の場合にhasPendingがfalseを返すことを検証
    @Test func hasPendingWhenEmpty() {
        #expect(!manager.hasPending)
    }

    /// エントリがある場合にhasPendingがtrueを返すことを検証
    @Test func hasPendingWhenNotEmpty() {
        let state = makeState()
        manager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        #expect(manager.hasPending)
    }

    // MARK: - clearAll

    /// 全エントリがクリアされることを検証
    @Test func clearAll() {
        manager.addPending(windowId: 1, originalState: makeState(windowId: 1), displayID: 0, adjustedOriginX: 10, adjustedOriginY: 20)
        manager.addPending(windowId: 2, originalState: makeState(windowId: 2), displayID: 0, adjustedOriginX: 30, adjustedOriginY: 40)
        manager.clearAll()
        #expect(manager.pendingRestorations.isEmpty)
    }

    // MARK: - purgeExpired

    /// タイムアウト境界値でエントリの保持・パージが正しく動作することを検証
    @Test(arguments: [
        (0.0, true),
        (299.0, true),
        (300.0, true),
        (301.0, false),
        (600.0, false)
    ])
    func purgeExpiredBoundary(elapsed: Double, shouldKeep: Bool) {
        let baseDate = Date()
        manager.currentDate = { baseDate }
        manager.addPending(
            windowId: 1,
            originalState: makeState(),
            displayID: 0,
            adjustedOriginX: 50,
            adjustedOriginY: 60
        )

        manager.currentDate = { baseDate.addingTimeInterval(elapsed) }
        manager.purgeExpired()

        if shouldKeep {
            #expect(manager.pendingRestorations.count == 1)
        } else {
            #expect(manager.pendingRestorations.isEmpty)
        }
    }

    // MARK: - restorableEntries

    /// 一致するスクリーンがない場合に空配列が返されることを検証
    @Test func restorableEntriesReturnsEmptyWhenNoMatchingScreen() {
        // displayID: 999999 は実際のモニターに対応しないため、接続中スクリーンに一致しない
        let state1 = makeState(windowId: 1, originX: 100)
        let state2 = makeState(windowId: 2, originX: 200)
        manager.addPending(windowId: 1, originalState: state1, displayID: 999999, adjustedOriginX: 50, adjustedOriginY: 60)
        manager.addPending(windowId: 2, originalState: state2, displayID: 999999, adjustedOriginX: 70, adjustedOriginY: 80)

        let results = manager.restorableEntries()

        // displayID: 999999 は実スクリーンと一致しないため空になる
        #expect(results.isEmpty)
    }

    /// restorableEntriesが期限切れエントリをパージすることを検証
    @Test func restorableEntriesCallsPurgeExpired() {
        let baseDate = Date()
        manager.currentDate = { baseDate }
        manager.addPending(windowId: 1, originalState: makeState(), displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)

        // Advance time past timeout
        manager.currentDate = { baseDate.addingTimeInterval(301) }
        let results = manager.restorableEntries()

        #expect(results.isEmpty)
        #expect(manager.pendingRestorations.isEmpty)
    }

    /// 実スクリーンに存在しないdisplayIDで空が返されることを検証
    @Test func restorableEntriesWithKnownDisplayIDNotMatching() {
        // displayID が非0で実スクリーンに存在しない場合は空
        let state = makeState(windowId: 1, originX: 100, originY: 200)
        manager.addPending(windowId: 1, originalState: state, displayID: 999999, adjustedOriginX: 50, adjustedOriginY: 60)

        let results = manager.restorableEntries()

        #expect(results.isEmpty)
    }

    /// displayID 0かつ画面外位置で復元対象にならないことを検証
    @Test func restorableEntriesWithZeroDisplayIDAndInvisiblePosition() {
        // displayID: 0（スリープなし切断）かつ画面外の位置 → 空（元の位置がまだ不可視）
        let state = makeState(windowId: 1, originX: -99999, originY: -99999)
        manager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)

        let results = manager.restorableEntries()

        // 元の位置が不可視のため、復元対象にならない
        #expect(results.isEmpty)
    }

    // MARK: - Persistence

    /// 保留ファイルのURLがpending_restorations.jsonであることを検証
    @Test func pendingFileURL() {
        let url = ioManager.pendingFileURL
        #expect(url != nil)
        #expect(url?.lastPathComponent == "pending_restorations.json")
    }

    /// 保存と読み込みのラウンドトリップが正しく動作することを検証
    @Test func saveAndLoadRoundTrip() {
        let state = makeState(windowId: 1, originX: 100, originY: 200)
        ioManager.addPending(windowId: 1, originalState: state, displayID: 42, adjustedOriginX: 50, adjustedOriginY: 60)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        #expect(loader.pendingRestorations.count == 1)
        let entry = loader.pendingRestorations[0]
        #expect(entry.windowId == 1)
        #expect(entry.originalState == state)
        #expect(entry.displayID == 42)
        #expect(entry.adjustedOriginX == 50)
        #expect(entry.adjustedOriginY == 60)
    }

    /// 複数エントリの保存と読み込みが正しく動作することを検証
    @Test func saveAndLoadMultipleEntries() {
        let state1 = makeState(windowId: 1, originX: 100)
        let state2 = makeState(windowId: 2, originX: 200)
        ioManager.addPending(windowId: 1, originalState: state1, displayID: 10, adjustedOriginX: 10, adjustedOriginY: 20)
        ioManager.addPending(windowId: 2, originalState: state2, displayID: 20, adjustedOriginX: 30, adjustedOriginY: 40)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        #expect(loader.pendingRestorations.count == 2)
    }

    /// ファイル未存在時に空キューで読み込めることを検証
    @Test func loadPendingWhenFileDoesNotExist() {
        // ファイルなしでクラッシュせず、空キューになる
        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()
        #expect(loader.pendingRestorations.isEmpty)
    }

    /// 破損JSONで空キューが返されクラッシュしないことを検証
    @Test func loadPendingWithCorruptedJSON() throws {
        let url = try #require(ioManager.pendingFileURL)
        try Data("not valid json".utf8).write(to: url, options: .atomic)

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()
        #expect(loader.pendingRestorations.isEmpty)
    }

    /// 読み込み時に期限切れエントリがパージされることを検証
    @Test func loadPendingPurgesExpiredEntries() {
        let baseDate = Date()
        ioManager.currentDate = { baseDate }
        let state = makeState(windowId: 1)
        ioManager.addPending(windowId: 1, originalState: state, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        ioManager.savePending()

        // タイムアウト超過した時刻でロード
        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.currentDate = { baseDate.addingTimeInterval(301) }
        loader.loadPending()

        #expect(loader.pendingRestorations.isEmpty)
    }

    /// 起動時のaddPendingが読み込み済みエントリを上書きすることを検証
    @Test func startupEntryOverwritesLoadedEntry() {
        // 起動時のaddPendingが読み込んだエントリを上書きする
        let stateOld = makeState(windowId: 1, originX: 100)
        ioManager.addPending(windowId: 1, originalState: stateOld, displayID: 0, adjustedOriginX: 50, adjustedOriginY: 60)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        // 起動時に新しいエントリで上書き
        let stateNew = makeState(windowId: 1, originX: 999)
        loader.addPending(windowId: 1, originalState: stateNew, displayID: 0, adjustedOriginX: 70, adjustedOriginY: 80)

        #expect(loader.pendingRestorations.count == 1)
        #expect(loader.pendingRestorations[0].originalState.originX == 999)
    }

    /// 空キューの保存で空ファイルが生成されることを検証
    @Test func saveEmptyQueueProducesEmptyFile() {
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()
        #expect(loader.pendingRestorations.isEmpty)
    }

    /// displayIDが保存・読み込みで保持されることを検証
    @Test func displayIDPreservedAcrossSaveLoad() {
        let displayID: CGDirectDisplayID = 1234567890
        let state = makeState(windowId: 1)
        ioManager.addPending(windowId: 1, originalState: state, displayID: displayID, adjustedOriginX: 0, adjustedOriginY: 0)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        #expect(loader.pendingRestorations[0].displayID == displayID)
    }

    // MARK: - preSleepScreenFrame

    /// スリープ前画面フレーム付きでエントリが追加されることを検証
    @Test func addPendingWithScreenFrame() {
        let state = makeState()
        let frame = NSRect(x: 1920, y: 0, width: 2560, height: 1440)
        manager.addPending(windowId: 1, originalState: state, displayID: 42,
                          adjustedOriginX: 50, adjustedOriginY: 60,
                          preSleepScreenFrame: frame)
        #expect(manager.pendingRestorations.count == 1)
        #expect(manager.pendingRestorations[0].preSleepScreenFrame == frame)
    }

    /// スリープ前画面フレーム省略時にnilがデフォルトになることを検証
    @Test func addPendingWithoutScreenFrameDefaultsToNil() {
        let state = makeState()
        manager.addPending(windowId: 1, originalState: state, displayID: 42,
                          adjustedOriginX: 50, adjustedOriginY: 60)
        #expect(manager.pendingRestorations[0].preSleepScreenFrame == nil)
    }

    /// スリープ前画面フレームが保存・読み込みで保持されることを検証
    @Test func screenFramePreservedAcrossSaveLoad() {
        let state = makeState(windowId: 1)
        let frame = NSRect(x: 1920, y: 0, width: 2560, height: 1440)
        ioManager.addPending(windowId: 1, originalState: state, displayID: 42,
                            adjustedOriginX: 0, adjustedOriginY: 0,
                            preSleepScreenFrame: frame)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        #expect(loader.pendingRestorations[0].preSleepScreenFrame == frame)
    }

    /// nilのスリープ前画面フレームが保存・読み込みで保持されることを検証
    @Test func nilScreenFramePreservedAcrossSaveLoad() {
        let state = makeState(windowId: 1)
        ioManager.addPending(windowId: 1, originalState: state, displayID: 42,
                            adjustedOriginX: 0, adjustedOriginY: 0)
        ioManager.savePending()

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        #expect(loader.pendingRestorations[0].preSleepScreenFrame == nil)
    }

    /// screenFrameフィールドなしの旧フォーマットJSONが読み込めることを検証
    @Test func loadPendingBackwardCompatibilityWithoutScreenFrame() throws {
        // 古いフォーマット（screenFrame フィールドなし）のJSONを読み込めることを確認
        let oldFormatJSON = """
        [
            {
                "windowId": 1,
                "originalState": {
                    "imageName": "テスト",
                    "originX": 100,
                    "originY": 200,
                    "width": 300,
                    "height": 400,
                    "isFlippedHorizontally": false,
                    "windowId": 1
                },
                "displayID": 42,
                "adjustedOriginX": 50,
                "adjustedOriginY": 60,
                "createdAt": \(Date().timeIntervalSinceReferenceDate)
            }
        ]
        """
        let url = try #require(ioManager.pendingFileURL)
        try Data(oldFormatJSON.utf8).write(to: url, options: .atomic)

        let loader = ScreenRestorationManager(timeout: 300, baseDirectory: tempDirectory)
        loader.loadPending()

        #expect(loader.pendingRestorations.count == 1)
        #expect(loader.pendingRestorations[0].preSleepScreenFrame == nil)
    }
}
