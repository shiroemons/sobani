import AppKit
import Foundation
import Testing
@testable import Sobani

/// 再起動後にウィンドウ位置がずれる問題（ディスプレイアンカー復元・常時保存・終了理由判定）の回帰テスト
@Suite @MainActor struct DisplayAnchorRestorationTests {
    private static let tol = AppConstants.floatingPointTolerance

    // 実ログ（position_log.jsonl / window_states.json）の構成を再現
    private static let mainUUID = "MAIN-32M2V"
    private static let portraitUUID = "PORTRAIT-EV2785"
    private static let smallUUID = "SMALL-1440x900"

    /// 通常時: メイン(0,0) / 縦画面(-1440,-674) / 小画面(1860,-900)
    private static let normalScreens = [
        ScreenInfo(frame: NSRect(x: 0, y: 0, width: 3008, height: 1692), displayID: 1, isMain: true, displayUUID: mainUUID),
        ScreenInfo(frame: NSRect(x: -1440, y: -674, width: 1440, height: 2560), displayID: 4, isMain: false, displayUUID: portraitUUID),
        ScreenInfo(frame: NSRect(x: 1860, y: -900, width: 1440, height: 900), displayID: 5, isMain: false, displayUUID: smallUUID),
    ]

    /// 起動直後の一時構成: メイン未認識で縦画面がプライマリ(0,0)になる（4/13・5/1 のログで観測）
    private static let transientScreens = [
        ScreenInfo(frame: NSRect(x: 0, y: 0, width: 1440, height: 2560), displayID: 6, isMain: true, displayUUID: portraitUUID),
        ScreenInfo(frame: NSRect(x: 1440, y: -32, width: 1440, height: 900), displayID: 7, isMain: false, displayUUID: smallUUID),
    ]

    /// 縦画面に大きく表示し、一部が画面外へはみ出している画像（window #145）
    private static func largePortraitState(anchor: DisplayAnchor?) -> WindowState {
        WindowState(
            imageName: AppConstants.defaultImageName,
            originX: -1638.8348114611422,
            originY: -2394.7866163287017,
            width: 1808.6696229222846,
            height: 4704.573232657403,
            isFlippedHorizontally: false,
            windowId: 145,
            displayAnchor: anchor
        )
    }

    private static let portraitAnchor = DisplayAnchor(
        displayUUID: portraitUUID, screenFrame: NSRect(x: -1440, y: -674, width: 1440, height: 2560)
    )

    private static func makeState(windowId: Int, originX: CGFloat, originY: CGFloat, opacity: CGFloat = 1) -> WindowState {
        WindowState(
            imageName: AppConstants.defaultImageName,
            originX: originX, originY: originY, width: 300, height: 600,
            isFlippedHorizontally: false, opacityLevel: opacity, windowId: windowId
        )
    }

    // MARK: - ScreenRestorationUtils.mapOrigin

    @Test("mapOrigin: 同サイズのスクリーンは平行移動で写像する")
    func mapOriginTranslatesForSameSize() {
        let rect = NSRect(x: -1638.83, y: -2394.79, width: 1808.67, height: 4704.57)
        let result = ScreenRestorationUtils.mapOrigin(
            of: rect,
            from: NSRect(x: -1440, y: -674, width: 1440, height: 2560),
            to: NSRect(x: 0, y: 0, width: 1440, height: 2560)
        )
        #expect(abs(result.x - -198.83) < Self.tol)
        #expect(abs(result.y - -1720.79) < Self.tol)
    }

    @Test("mapOrigin: 解像度が変わった場合は中心を正規化座標で写像しサイズは維持する")
    func mapOriginScalesCenterForDifferentSize() {
        let rect = NSRect(x: 200, y: 450, width: 100, height: 100)  // center (250, 500)
        let result = ScreenRestorationUtils.mapOrigin(
            of: rect,
            from: NSRect(x: 0, y: 0, width: 1000, height: 1000),
            to: NSRect(x: 100, y: 0, width: 2000, height: 1000)
        )
        // center' = (100 + 0.25 * 2000, 0 + 0.5 * 1000) = (600, 500)
        #expect(abs(result.x - 550) < Self.tol)
        #expect(abs(result.y - 450) < Self.tol)
    }

    @Test("mapOrigin: 写像して戻すと元の位置に一致する（往復で誤差が蓄積しない）")
    func mapOriginRoundTrip() {
        let rect = NSRect(x: 123.4, y: -567.8, width: 400, height: 800)
        let frameA = NSRect(x: -1440, y: -674, width: 1440, height: 2560)
        let frameB = NSRect(x: 0, y: 0, width: 1440, height: 2560)
        let mapped = ScreenRestorationUtils.mapOrigin(of: rect, from: frameA, to: frameB)
        let back = ScreenRestorationUtils.mapOrigin(
            of: NSRect(origin: mapped, size: rect.size), from: frameB, to: frameA
        )
        #expect(abs(back.x - rect.minX) < Self.tol)
        #expect(abs(back.y - rect.minY) < Self.tol)
    }

    @Test("indexOfLargestOverlap: 重なり面積が最大のスクリーンを選ぶ")
    func indexOfLargestOverlapPicksLargest() {
        let rect = Self.largePortraitState(anchor: nil).frame
        let index = ScreenRestorationUtils.indexOfLargestOverlap(
            for: rect, in: Self.normalScreens.map(\.frame)
        )
        #expect(index == 1)  // 縦画面
    }

    @Test("indexOfLargestOverlap: どのスクリーンとも重ならなければ nil")
    func indexOfLargestOverlapReturnsNilWhenNoOverlap() {
        let index = ScreenRestorationUtils.indexOfLargestOverlap(
            for: NSRect(x: 99_999, y: 99_999, width: 10, height: 10),
            in: Self.normalScreens.map(\.frame)
        )
        #expect(index == nil)
    }

    // MARK: - DisplayAnchor

    @Test("DisplayAnchor.make: 大きくはみ出した画像は最も重なる縦画面にアンカーされる")
    func anchorMakeUsesLargestOverlap() throws {
        let anchor = try #require(
            DisplayAnchor.make(for: Self.largePortraitState(anchor: nil).frame, screens: Self.normalScreens)
        )
        #expect(anchor == Self.portraitAnchor)
    }

    @Test("DisplayAnchor.make: UUID が取れないスクリーンではアンカーを作らない")
    func anchorMakeReturnsNilWithoutUUID() {
        let screens = [ScreenInfo(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), displayID: 1, isMain: true)]
        #expect(DisplayAnchor.make(for: NSRect(x: 0, y: 0, width: 100, height: 100), screens: screens) == nil)
    }

    // MARK: - WindowState Codable

    @Test("WindowState: アンカー付きで JSON ラウンドトリップできる")
    func encodeDecodeWithAnchor() throws {
        let state = Self.largePortraitState(anchor: Self.portraitAnchor)
        let data = try JSONEncoder().encode([state])
        let decoded = try JSONDecoder().decode([WindowState].self, from: data)
        #expect(decoded == [state])
    }

    @Test("WindowState: アンカーのない旧形式 JSON も読み込める")
    func decodeLegacyWithoutAnchor() throws {
        let json = """
        [{"imageName":"default","originX":10,"originY":20,"width":300,"height":600,
          "isFlippedHorizontally":false,"windowId":3}]
        """
        let decoded = try JSONDecoder().decode([WindowState].self, from: Data(json.utf8))
        let state = try #require(decoded.first)
        #expect(state.displayAnchor == nil)
        #expect(state.windowId == 3)
    }

    // MARK: - resolvedForRestore

    @Test("旧形式（アンカーなし）: 一時構成では細い帯だけ見える位置でも補正されない（不具合の再現）")
    func legacyRestoreKeepsMostlyOffscreenPosition() {
        let resolution = Self.largePortraitState(anchor: nil).resolvedForRestore(on: Self.transientScreens)
        #expect(resolution.anchor == .unanchored)
        #expect(!resolution.wasAdjusted)
        // 縦画面(0,0)との重なりは x: 0…169.8 の細い帯だけ
        let visible = resolution.state.frame.intersection(Self.transientScreens[0].frame)
        #expect(visible.width < 200)
    }

    @Test("アンカー復元: 起動直後の一時構成でも縦画面上の見た目の位置を保つ")
    func anchoredRestoreKeepsPositionOnTransientLayout() {
        let resolution = Self.largePortraitState(anchor: Self.portraitAnchor)
            .resolvedForRestore(on: Self.transientScreens)
        #expect(resolution.anchor == .matched)
        #expect(!resolution.wasAdjusted)
        #expect(abs(resolution.state.originX - -198.8348114611422) < Self.tol)
        #expect(abs(resolution.state.originY - -1720.7866163287017) < Self.tol)
        // 縦画面を幅いっぱいに覆う（元の見た目と同じ）
        let visible = resolution.state.frame.intersection(Self.transientScreens[0].frame)
        #expect(abs(visible.width - 1440) < Self.tol)
        #expect(abs(visible.height - 2560) < Self.tol)
        // アンカーは現在のスクリーンフレームに更新される
        #expect(resolution.state.displayAnchor?.screenFrame == Self.transientScreens[0].frame)
    }

    @Test("アンカー復元: 一時構成→通常構成と2段階で写像しても元の座標に戻る")
    func anchoredRestoreReturnsToOriginalAfterLayoutSettles() {
        let original = Self.largePortraitState(anchor: Self.portraitAnchor)
        let transient = original.resolvedForRestore(on: Self.transientScreens).state
        let settled = transient.resolvedForRestore(on: Self.normalScreens).state
        #expect(abs(settled.originX - original.originX) < Self.tol)
        #expect(abs(settled.originY - original.originY) < Self.tol)
    }

    @Test("アンカー復元: 意図的に画面外へはみ出した配置をクランプしない")
    func anchoredRestoreDoesNotClampIntentionalOverflow() {
        let original = Self.largePortraitState(anchor: Self.portraitAnchor)
        let resolution = original.resolvedForRestore(on: Self.normalScreens)
        #expect(resolution.anchor == .matched)
        #expect(abs(resolution.state.originX - original.originX) < Self.tol)
        #expect(abs(resolution.state.originY - original.originY) < Self.tol)
    }

    @Test("アンカー復元: ディスプレイ未接続なら displayMissing を返しグローバル座標で仮配置する")
    func anchoredRestoreReportsMissingDisplay() {
        let screens = [Self.normalScreens[0]]
        let state = Self.makeState(windowId: 1, originX: -1000, originY: 500)
            .withPosition(originX: -1000, originY: 500, displayAnchor: Self.portraitAnchor)
        let resolution = state.resolvedForRestore(on: screens)
        #expect(resolution.anchor == .displayMissing)
        // 見えない位置なのでメイン画面中央へ退避
        #expect(resolution.wasAdjusted)
        #expect(abs(resolution.state.originX - (1504 - 150)) < Self.tol)
    }

    // MARK: - Persistence

    @Test("preservingPosition: 位置とアンカーだけ意図した値を使い、他の属性は現在値を保つ")
    func preservingPositionMergesOnlyPosition() {
        let current = Self.makeState(windowId: 1, originX: 1354, originY: 546, opacity: 0.5)
        let intended = Self.makeState(windowId: 1, originX: -1300, originY: 1400)
            .withPosition(originX: -1300, originY: 1400, displayAnchor: Self.portraitAnchor)
        let merged = current.preservingPosition(of: intended)
        #expect(abs(merged.originX - -1300) < Self.tol)
        #expect(abs(merged.originY - 1400) < Self.tol)
        #expect(merged.displayAnchor == Self.portraitAnchor)
        #expect(abs(merged.opacityLevel - 0.5) < Self.tol)
    }

    @Test("persistableStates: 一時退避中のウィンドウだけ意図した位置で保存する")
    func persistableStatesUsesIntendedPositions() {
        let current = [
            Self.makeState(windowId: 1, originX: 1354, originY: 546),
            Self.makeState(windowId: 2, originX: 10, originY: 20),
        ]
        let intended = [1: Self.makeState(windowId: 1, originX: -1300, originY: 1400)]
        let result = AppDelegate.persistableStates(current: current, intendedPositions: intended)
        #expect(abs(result[0].originX - -1300) < Self.tol)
        #expect(abs(result[1].originX - 10) < Self.tol)
        #expect(result.map(\.windowId) == [1, 2])
    }

    @Test(
        "isScreenConfigurationSettling: 復元中・画面構成変更直後は保存を見送る",
        arguments: [
            (nil as TimeInterval?, false, false),
            (nil, true, true),
            (3, false, true),
            (10, false, false),
            (60, false, false),
        ]
    )
    func screenConfigurationSettling(secondsSinceChange: TimeInterval?, isRestoring: Bool, expected: Bool) {
        let now = Date()
        let result = AppDelegate.isScreenConfigurationSettling(
            now: now,
            lastScreenChangeAt: secondsSinceChange.map { now.addingTimeInterval(-$0) },
            settleInterval: 10,
            isRestoring: isRestoring
        )
        #expect(result == expected)
    }

    // MARK: - Terminate

    @Test("terminateReply: 通常の終了要求はキャンセルする")
    func terminateReplyCancelsOrdinaryQuit() {
        #expect(AppDelegate.terminateReply(shouldTerminate: false, isInstallingUpdate: false, quitReason: nil) == .terminateCancel)
        #expect(
            AppDelegate.terminateReply(
                shouldTerminate: false, isInstallingUpdate: false, quitReason: OSType(kAEQuitApplication)
            ) == .terminateCancel
        )
    }

    @Test(
        "terminateReply: ログアウト・再起動・システム終了では終了を許可する（状態が保存される）",
        arguments: [kAELogOut, kAEReallyLogOut, kAEShowRestartDialog, kAERestart, kAEShowShutdownDialog, kAEShutDown]
    )
    func terminateReplyAllowsSystemQuit(reason: UInt32) {
        let reply = AppDelegate.terminateReply(
            shouldTerminate: false, isInstallingUpdate: false, quitReason: OSType(reason)
        )
        #expect(reply == .terminateNow)
    }

    @Test("terminateReply: willPowerOff の直後は終了理由が取れない終了要求も許可する")
    func terminateReplyAllowsQuitRightAfterPowerOff() {
        let requestedAt = Date()
        let reply = AppDelegate.terminateReply(
            shouldTerminate: false, isInstallingUpdate: false, quitReason: nil,
            powerOffRequestedAt: requestedAt, now: requestedAt.addingTimeInterval(1)
        )
        #expect(reply == .terminateNow)
    }

    @Test("terminateReply: ログアウトがキャンセルされた後は終了ガードが元に戻る")
    func terminateReplyCancelsLongAfterCancelledPowerOff() {
        let requestedAt = Date()
        let oneHour: TimeInterval = 3600
        let reply = AppDelegate.terminateReply(
            shouldTerminate: false, isInstallingUpdate: false, quitReason: OSType(kAEQuitApplication),
            powerOffRequestedAt: requestedAt, now: requestedAt.addingTimeInterval(oneHour)
        )
        #expect(reply == .terminateCancel)
    }

    @Test("terminateReply: 明示的な終了・アップデート中は従来どおり終了する")
    func terminateReplyAllowsExplicitQuit() {
        #expect(AppDelegate.terminateReply(shouldTerminate: true, isInstallingUpdate: false, quitReason: nil) == .terminateNow)
        #expect(AppDelegate.terminateReply(shouldTerminate: false, isInstallingUpdate: true, quitReason: nil) == .terminateNow)
    }

    // MARK: - Pending / Launch Context

    @Test("restorableEntries: アンカーの UUID が接続されたら displayID が変わっていても復元対象になる")
    func restorableEntriesMatchesByAnchorUUID() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobaniTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ScreenRestorationManager(baseDirectory: directory)
        let state = Self.largePortraitState(anchor: Self.portraitAnchor)
        manager.addPending(
            windowId: 145, originalState: state, displayID: AppConstants.unknownDisplayID,
            adjustedOriginX: 0, adjustedOriginY: 0
        )
        #expect(manager.restorableEntries(screens: [Self.normalScreens[0]]).isEmpty)
        #expect(manager.restorableEntries(screens: Self.normalScreens).map(\.windowId) == [145])
        #expect(manager.isPending(windowId: 145))
        #expect(!manager.isPending(windowId: 1))
    }

    @Test("userGeometryTriggers: 位置・大きさが変わる操作だけが自動復元の対象から外す契機になる")
    func userGeometryTriggersCoverGeometryChangesOnly() {
        let triggers = AppDelegate.userGeometryTriggers
        for trigger: AppConstants.SnapshotTrigger in [.position, .size, .reset, .crop, .rotation] {
            #expect(triggers.contains(trigger))
        }
        for trigger: AppConstants.SnapshotTrigger in [.launch, .opacity, .flip, .ghost, .hidden, .zorder, .windowAdd] {
            #expect(!triggers.contains(trigger))
        }
    }

    @Test("LaunchRestorationContext: 手動で動かしたウィンドウを外し、空になったら非アクティブになる")
    func launchContextRelease() {
        var context = LaunchRestorationContext()
        context.states = [1: Self.makeState(windowId: 1, originX: 0, originY: 0),
                          2: Self.makeState(windowId: 2, originX: 0, originY: 0)]
        #expect(context.isActive)
        context.release(windowId: 1)
        #expect(context.isActive)
        #expect(context.states.keys.sorted() == [2])
        context.release(windowId: 2)
        #expect(!context.isActive)
    }

    @Test("LaunchRestorationContext: アンカーのディスプレイが未接続のウィンドウだけを返す")
    func launchContextWindowIdsWithMissingDisplay() {
        var context = LaunchRestorationContext()
        let mainAnchor = DisplayAnchor(displayUUID: Self.mainUUID, screenFrame: Self.normalScreens[0].frame)
        context.states = [
            145: Self.largePortraitState(anchor: Self.portraitAnchor),
            2: Self.makeState(windowId: 2, originX: 100, originY: 100)
                .withPosition(originX: 100, originY: 100, displayAnchor: mainAnchor),
        ]
        #expect(context.windowIdsWithMissingDisplay(on: Self.normalScreens).isEmpty)
        #expect(context.windowIdsWithMissingDisplay(on: [Self.normalScreens[0]]) == [145])
        #expect(context.windowIdsWithMissingDisplay(on: [Self.normalScreens[1]]) == [2])
    }
}
