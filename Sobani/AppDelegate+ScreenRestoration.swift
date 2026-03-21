import Cocoa
import os.log

// MARK: - Screen Restoration

extension AppDelegate {
    private static let screenRestorationLogger = Logger(category: "ScreenRestoration")

    func setupScreenRestorationObservers() {
        let screenCount = NSScreen.screens.count
        Self.screenRestorationLogger.debug(
            "[ScreenRestoration] observers registered, screens=\(screenCount, privacy: .public)"
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func teardownScreenRestorationObservers() {
        screenChangeDebounceTimer?.invalidate()
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc func handleScreenChange() {
        let isWake = wakeContext.isActive
        let count = NSScreen.screens.count
        Self.screenRestorationLogger.debug(
            "screenChange: isWake=\(isWake, privacy: .public), screens=\(count, privacy: .public)"
        )
        screenChangeDebounceTimer?.invalidate()
        if wakeContext.isActive {
            // Wake 復元中のスクリーン変更 → 復元リトライをトリガー（1.5秒デバウンス）
            screenChangeDebounceTimer = Timer.scheduledTimer(
                withTimeInterval: AppConstants.wakeDebounceInterval,
                repeats: false
            ) { @Sendable [weak self] _ in
                MainActor.assumeIsolated {
                    self?.attemptWakeRestoration()
                }
            }
        } else {
            // 通常時 → ペンディング復元を試行（1秒デバウンス）
            let interval = AppConstants.screenChangeDebounceInterval
            screenChangeDebounceTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: false
            ) { @Sendable [weak self] _ in
                MainActor.assumeIsolated {
                    self?.attemptPendingRestorations()
                }
            }
        }
    }

    @objc func handleWillSleep() {
        // Wake 復元中のタイマーをキャンセル
        wakeContext.clear()
        screenChangeDebounceTimer?.invalidate()

        screenRestorationManager.clearAll()
        for imageWindow in zOrderedWindows {
            let state = WindowStateManager.captureState(from: imageWindow)
            wakeContext.states[imageWindow.windowId] = state
            // ウィンドウフレームの原点を直接保存（captureState のイメージ中心座標変換を回避）
            wakeContext.windowOrigins[imageWindow.windowId] = imageWindow.window.frame.origin
            if let screen = NSScreen.screen(containing: imageWindow.window.frame),
               let displayID = screen.displayID {
                wakeContext.displayIDs[imageWindow.windowId] = displayID
                wakeContext.screenFrames[displayID] = screen.frame
            }
        }
        let savedCount = wakeContext.states.count
        Self.screenRestorationLogger.info(
            "[ScreenRestoration] willSleep: saved \(savedCount, privacy: .public) windows"
        )
        for (wid, origin) in wakeContext.windowOrigins {
            let did = wakeContext.displayIDs[wid] ?? AppConstants.unknownDisplayID
            let sFrame = wakeContext.screenFrames[did]
            let sFrameDesc = sFrame.debugDescription
            let originDesc = NSStringFromPoint(origin)
            let logMsg = "  #\(wid): origin=\(originDesc), displayID=\(did), sf=\(sFrameDesc)"
            Self.screenRestorationLogger.debug("\(logMsg, privacy: .public)")
        }
    }

    @objc func handleDidWake() {
        let restoreCount = wakeContext.states.count
        Self.screenRestorationLogger.info(
            "[ScreenRestoration] didWake: \(restoreCount, privacy: .public) windows to restore"
        )
        // macOS はスリープ復帰時に外部モニター接続中でもウィンドウをメインモニターへ移動する。
        // モニターが完全に登録されるよう、3秒待ってからリトライ付き復元を開始する。
        wakeContext.isActive = true
        wakeContext.retryCount = 0
        screenChangeDebounceTimer?.invalidate()
        screenChangeDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: AppConstants.wakeInitialDelay,
            repeats: false
        ) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.attemptWakeRestoration()
            }
        }
    }

    func attemptWakeRestoration() {
        guard wakeContext.isActive, !wakeContext.states.isEmpty else {
            wakeContext.isActive = false
            wakeContext.retryCount = 0
            return
        }

        let restoredAll = restoreAllPreSleepWindows()
        wakeContext.retryCount += 1
        let retryNum = wakeContext.retryCount
        let screenInfo = NSScreen.screens.map { "\($0.frame)" }.joined(separator: ", ")
        let attemptMsg = "attempt #\(retryNum): restoredAll=\(restoredAll), screens=[\(screenInfo)]"
        Self.screenRestorationLogger.debug("\(attemptMsg, privacy: .public)")

        if restoredAll && wakeContext.retryCount <= AppConstants.wakeRetryCountThreshold {
            // 全復元完了だが、macOS が後から再配置する可能性があるため追加リトライ
            scheduleWakeRetry(interval: AppConstants.wakeRetryInterval)
        } else if restoredAll || wakeContext.retryCount >= AppConstants.wakeRetryMaxAttempts {
            // 確実に全復元完了 or タイムアウト → 残りをペンディングキューに移行
            moveUnrestoredToPendingQueue()
            wakeContext.clear()
        } else {
            // 未復元ウィンドウがある → リトライ
            scheduleWakeRetry(interval: AppConstants.wakeRetryInterval)
        }
    }

    /// 全ウィンドウを相対座標ベースで復元。全ウィンドウ復元できたら true を返す。
    private func restoreAllPreSleepWindows() -> Bool {
        // 注意: wakeContext.states から個別に除去しない。macOS はモニタ復帰時に
        // 全ウィンドウを再配置するため、リトライ毎に全ウィンドウを再復元する必要がある。
        let availableScreens = currentAvailableScreens
        var restoredAll = true

        for imageWindow in zOrderedWindows {
            guard wakeContext.states[imageWindow.windowId] != nil else { continue }
            guard let savedOrigin = wakeContext.windowOrigins[imageWindow.windowId] else { continue }

            let savedDisplayID = wakeContext.displayIDs[imageWindow.windowId]
            let targetScreen = findTargetScreen(
                displayID: savedDisplayID,
                windowId: imageWindow.windowId,
                availableScreens: availableScreens
            )

            if let screen = targetScreen {
                let newOrigin = computeRestoredOrigin(
                    savedOrigin: savedOrigin, savedDisplayID: savedDisplayID, currentScreen: screen
                )
                let windowSize = imageWindow.window.frame.size
                let clamped = ScreenRestorationUtils.clampOrigin(
                    newOrigin, windowSize: windowSize, to: screen.frame
                )
                imageWindow.window.setFrameOrigin(clamped)
                let wid = imageWindow.windowId
                let screenFrame = screen.frame
                let savedDesc = NSStringFromPoint(savedOrigin)
                let computedDesc = NSStringFromPoint(newOrigin)
                let clampedDesc = NSStringFromPoint(clamped)
                let sizeDesc = NSStringFromSize(windowSize)
                let frameDesc = NSStringFromRect(screenFrame)
                let restoreMsg = "restore #\(wid): saved=\(savedDesc)"
                    + " -> \(computedDesc) -> \(clampedDesc)"
                Self.screenRestorationLogger.debug("\(restoreMsg, privacy: .public)")
                let detailMsg = "  winSize=\(sizeDesc), screen=\(frameDesc)"
                Self.screenRestorationLogger.debug("\(detailMsg, privacy: .public)")
            } else {
                restoredAll = false
                let displayIDValue = savedDisplayID ?? AppConstants.unknownDisplayID
                let errMsg = "restore #\(imageWindow.windowId): screen not found"
                    + " (displayID=\(displayIDValue))"
                Self.screenRestorationLogger.error("\(errMsg, privacy: .public)")
            }
        }
        return restoredAll
    }

    /// スリープ前のスクリーン位置を基にウィンドウの相対位置を計算し、
    /// 新しいスクリーン位置に変換する。
    private func computeRestoredOrigin(
        savedOrigin: NSPoint,
        savedDisplayID: CGDirectDisplayID?,
        currentScreen: NSScreen
    ) -> NSPoint {
        let oldFrame = savedDisplayID.flatMap { wakeContext.screenFrames[$0] }
        return ScreenRestorationUtils.computeRestoredOrigin(
            savedOrigin: savedOrigin,
            oldScreenFrame: oldFrame,
            currentScreenFrame: currentScreen.frame
        )
    }

    /// 未復元ウィンドウをペンディングキューに移行
    private func moveUnrestoredToPendingQueue() {
        let availableScreens = currentAvailableScreens
        for windowId in wakeContext.states.keys {
            let savedDisplayID = wakeContext.displayIDs[windowId]
            guard findTargetScreen(
                displayID: savedDisplayID,
                windowId: windowId,
                availableScreens: availableScreens
            ) == nil else { continue }
            guard let savedState = wakeContext.states[windowId] else { continue }

            let screenFrame = savedDisplayID.flatMap { wakeContext.screenFrames[$0] }
            let adjusted = savedState.adjustedToVisibleArea(on: ScreenInfo.current())

            if let imageWindow = zOrderedWindows.first(where: { $0.windowId == windowId }) {
                imageWindow.window.setFrameOrigin(NSPoint(x: adjusted.originX, y: adjusted.originY))
            }
            screenRestorationManager.addPending(
                windowId: windowId, originalState: savedState,
                displayID: savedDisplayID ?? AppConstants.unknownDisplayID,
                adjustedOriginX: adjusted.originX, adjustedOriginY: adjusted.originY,
                preSleepScreenFrame: screenFrame
            )
        }
    }

    private func scheduleWakeRetry(interval: TimeInterval) {
        screenChangeDebounceTimer?.invalidate()
        screenChangeDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.attemptWakeRestoration()
            }
        }
    }

    func attemptPendingRestorations() {
        // フェーズ0: スリープなしのモニター切断対応
        // wakeContext.states が空（スリープ復帰でない）かつ画面外ウィンドウがある場合に対応
        let screens = ScreenInfo.current()
        for imageWindow in zOrderedWindows {
            let currentState = WindowStateManager.captureState(from: imageWindow)
            guard !currentState.isPositionVisible(on: screens) else { continue }
            let adjusted = currentState.adjustedToVisibleArea(on: screens)
            imageWindow.window.setFrameOrigin(NSPoint(x: adjusted.originX, y: adjusted.originY))
            // displayID は切断後には取得不可のため 0 を使用（位置ベースで復元判定）
            screenRestorationManager.addPending(
                windowId: imageWindow.windowId,
                originalState: currentState,
                displayID: AppConstants.unknownDisplayID,
                adjustedOriginX: adjusted.originX,
                adjustedOriginY: adjusted.originY
            )
        }

        // フェーズ2: モニター再接続後の復元（ペンディングキュー）
        let pendingAvailableScreens = currentAvailableScreens
        let restorable = screenRestorationManager.restorableEntries()
        for entry in restorable {
            guard let imageWindow = zOrderedWindows.first(where: { $0.windowId == entry.windowId })
            else {
                screenRestorationManager.removePending(windowId: entry.windowId)
                continue
            }
            // 対象モニタが見つかったら無条件でクランプ位置に復元
            let targetScreen = findTargetScreenForPending(
                entry, availableScreens: pendingAvailableScreens
            )
            if let screen = targetScreen {
                let windowSize = imageWindow.window.frame.size
                let origin = NSPoint(x: entry.originalState.originX, y: entry.originalState.originY)
                let clamped = ScreenRestorationUtils.clampOrigin(
                    origin, windowSize: windowSize, to: screen.frame
                )
                imageWindow.window.setFrameOrigin(clamped)
            }
            screenRestorationManager.removePending(windowId: entry.windowId)
        }
    }

    // MARK: - Private Helpers

    /// 現在接続されているスクリーンの displayID とフレームのリストを返す
    private var currentAvailableScreens: [(displayID: UInt32, frame: NSRect)] {
        NSScreen.screens.compactMap { screen -> (displayID: UInt32, frame: NSRect)? in
            guard let did = screen.displayID else { return nil }
            return (displayID: did, frame: screen.frame)
        }
    }

    /// Wake 復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致
    private func findTargetScreen(
        displayID: CGDirectDisplayID?,
        windowId: Int,
        availableScreens: [(displayID: UInt32, frame: NSRect)]
    ) -> NSScreen? {
        guard let savedID = displayID else { return nil }
        let savedFrame = wakeContext.screenFrames[savedID]
        guard let result = ScreenRestorationUtils.findTargetScreen(
            savedDisplayID: savedID,
            savedScreenFrame: savedFrame,
            availableScreens: availableScreens,
            tolerance: AppConstants.screenMatchTolerance
        ) else { return nil }
        return NSScreen.screen(withDisplayID: result.displayID)
    }

    /// ペンディング復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致 → ③ 元の位置を含むスクリーン
    private func findTargetScreenForPending(
        _ entry: PendingRestoration,
        availableScreens: [(displayID: UInt32, frame: NSRect)]
    ) -> NSScreen? {
        let originalRect = NSRect(
            x: entry.originalState.originX, y: entry.originalState.originY,
            width: entry.originalState.width, height: entry.originalState.height
        )
        let search = ScreenRestorationUtils.PendingScreenSearch(
            displayID: entry.displayID,
            savedScreenFrame: entry.preSleepScreenFrame,
            originalRect: originalRect,
            unknownDisplayID: AppConstants.unknownDisplayID
        )
        guard let result = ScreenRestorationUtils.findTargetScreenForPending(
            search,
            availableScreens: availableScreens,
            tolerance: AppConstants.screenMatchTolerance
        ) else { return nil }
        return NSScreen.screen(withDisplayID: result.displayID)
    }
}

// MARK: - NSScreen Helpers

extension NSScreen {
    /// スクリーンの CGDirectDisplayID を取得
    var displayID: CGDirectDisplayID? {
        deviceDescription[AppConstants.screenNumberKey] as? CGDirectDisplayID
    }

    /// 指定された displayID に一致するスクリーンを検索
    static func screen(withDisplayID displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == displayID }
    }

    /// 指定された矩形と最も大きく重なるスクリーンを返す
    static func screen(containing rect: NSRect) -> NSScreen? {
        screens.max {
            let areaA = $0.frame.intersection(rect)
            let areaB = $1.frame.intersection(rect)
            return areaA.width * areaA.height < areaB.width * areaB.height
        }
    }

    /// 指定されたフレームと位置・サイズが tolerance 以内で一致するスクリーンを返す
    static func screen(matchingFrame savedFrame: NSRect, tolerance: CGFloat) -> NSScreen? {
        screens.first { screen in
            ScreenRestorationUtils.isFrameMatch(screen.frame, savedFrame, tolerance: tolerance)
        }
    }
}
