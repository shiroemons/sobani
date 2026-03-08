import Cocoa
import os.log

private let screenRestorationLog = Logger(subsystem: "com.shiroemons.Sobani", category: "ScreenRestoration")

// MARK: - Screen Restoration

extension AppDelegate {
    func setupScreenRestorationObservers() {
        screenRestorationLog.debug("[ScreenRestoration] observers registered, screens=\(NSScreen.screens.count, privacy: .public)")
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
        screenRestorationLog.debug(
            "screenChange: isWake=\(isWake, privacy: .public), screens=\(count, privacy: .public)"
        )
        screenChangeDebounceTimer?.invalidate()
        if wakeContext.isActive {
            // Wake 復元中のスクリーン変更 → 復元リトライをトリガー（1.5秒デバウンス）
            screenChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.wakeDebounceInterval, repeats: false) { @Sendable [weak self] _ in
                MainActor.assumeIsolated {
                    self?.attemptWakeRestoration()
                }
            }
        } else {
            // 通常時 → ペンディング復元を試行（1秒デバウンス）
            let interval = AppConstants.screenChangeDebounceInterval
            screenChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { @Sendable [weak self] _ in
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
        for charWindow in characterWindows {
            let state = WindowStateManager.captureState(from: charWindow)
            wakeContext.states[charWindow.windowId] = state
            // ウィンドウフレームの原点を直接保存（captureState のイメージ中心座標変換を回避）
            wakeContext.windowOrigins[charWindow.windowId] = charWindow.window.frame.origin
            if let screen = NSScreen.screen(containing: charWindow.window.frame),
               let displayID = screen.displayID {
                wakeContext.displayIDs[charWindow.windowId] = displayID
                wakeContext.screenFrames[displayID] = screen.frame
            }
        }
        let savedCount = wakeContext.states.count
        screenRestorationLog.info("[ScreenRestoration] willSleep: saved \(savedCount, privacy: .public) windows")
        for (wid, origin) in wakeContext.windowOrigins {
            let did = wakeContext.displayIDs[wid] ?? AppConstants.unknownDisplayID
            let sFrame = wakeContext.screenFrames[did]
            let sFrameDesc = sFrame.debugDescription
            let originDesc = NSStringFromPoint(origin)
            screenRestorationLog.debug(
                "  #\(wid, privacy: .public): origin=\(originDesc, privacy: .public), displayID=\(did, privacy: .public), sf=\(sFrameDesc, privacy: .public)"
            )
        }
    }

    @objc func handleDidWake() {
        let restoreCount = wakeContext.states.count
        screenRestorationLog.info("[ScreenRestoration] didWake: \(restoreCount, privacy: .public) windows to restore")
        // macOS はスリープ復帰時に外部モニター接続中でもウィンドウをメインモニターへ移動する。
        // モニターが完全に登録されるよう、3秒待ってからリトライ付き復元を開始する。
        wakeContext.isActive = true
        wakeContext.retryCount = 0
        screenChangeDebounceTimer?.invalidate()
        screenChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.wakeInitialDelay, repeats: false) { @Sendable [weak self] _ in
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
        screenRestorationLog.debug(
            "attempt #\(retryNum, privacy: .public): restoredAll=\(restoredAll, privacy: .public), screens=[\(screenInfo, privacy: .public)]"
        )

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
        var restoredAll = true

        for charWindow in characterWindows {
            guard wakeContext.states[charWindow.windowId] != nil else { continue }
            guard let savedOrigin = wakeContext.windowOrigins[charWindow.windowId] else { continue }

            let savedDisplayID = wakeContext.displayIDs[charWindow.windowId]
            let targetScreen = findTargetScreen(displayID: savedDisplayID, windowId: charWindow.windowId)

            if let screen = targetScreen {
                let newOrigin = computeRestoredOrigin(
                    savedOrigin: savedOrigin, savedDisplayID: savedDisplayID, currentScreen: screen
                )
                let windowSize = charWindow.window.frame.size
                let clamped = clampOrigin(newOrigin, windowSize: windowSize, to: screen.frame)
                charWindow.window.setFrameOrigin(clamped)
                let wid = charWindow.windowId
                let screenFrame = screen.frame
                let savedDesc = NSStringFromPoint(savedOrigin)
                let computedDesc = NSStringFromPoint(newOrigin)
                let clampedDesc = NSStringFromPoint(clamped)
                let sizeDesc = NSStringFromSize(windowSize)
                let frameDesc = NSStringFromRect(screenFrame)
                let restoreMsg = "restore #\(wid): saved=\(savedDesc) -> \(computedDesc) -> \(clampedDesc)"
                screenRestorationLog.debug("\(restoreMsg, privacy: .public)")
                let detailMsg = "  winSize=\(sizeDesc), screen=\(frameDesc)"
                screenRestorationLog.debug("\(detailMsg, privacy: .public)")
            } else {
                restoredAll = false
                let displayIDValue = savedDisplayID ?? AppConstants.unknownDisplayID
                screenRestorationLog.error(
                    "restore #\(charWindow.windowId, privacy: .public): screen not found (displayID=\(displayIDValue, privacy: .public))"
                )
            }
        }
        return restoredAll
    }

    /// スリープ前のスクリーン位置を基にウィンドウの相対位置を計算し、
    /// 新しいスクリーン位置に変換する。
    private func computeRestoredOrigin(savedOrigin: NSPoint, savedDisplayID: CGDirectDisplayID?,
                                       currentScreen: NSScreen) -> NSPoint {
        let oldFrame = savedDisplayID.flatMap { wakeContext.screenFrames[$0] }
        return ScreenRestorationUtils.computeRestoredOrigin(
            savedOrigin: savedOrigin, oldScreenFrame: oldFrame, currentScreenFrame: currentScreen.frame
        )
    }

    /// 未復元ウィンドウをペンディングキューに移行
    private func moveUnrestoredToPendingQueue() {
        for windowId in wakeContext.states.keys {
            let savedDisplayID = wakeContext.displayIDs[windowId]
            guard findTargetScreen(displayID: savedDisplayID, windowId: windowId) == nil else { continue }
            guard let savedState = wakeContext.states[windowId] else { continue }

            let screenFrame = savedDisplayID.flatMap { wakeContext.screenFrames[$0] }
            let adjusted = savedState.adjustedToVisibleArea()

            if let charWindow = characterWindows.first(where: { $0.windowId == windowId }) {
                charWindow.window.setFrameOrigin(NSPoint(x: adjusted.originX, y: adjusted.originY))
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
        screenChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.attemptWakeRestoration()
            }
        }
    }

    func attemptPendingRestorations() {
        // フェーズ0: スリープなしのモニター切断対応
        // wakeContext.states が空（スリープ復帰でない）かつ画面外ウィンドウがある場合に対応
        for charWindow in characterWindows {
            let currentState = WindowStateManager.captureState(from: charWindow)
            guard !currentState.isPositionVisible() else { continue }
            let adjusted = currentState.adjustedToVisibleArea()
            charWindow.window.setFrameOrigin(NSPoint(x: adjusted.originX, y: adjusted.originY))
            // displayID は切断後には取得不可のため 0 を使用（位置ベースで復元判定）
            screenRestorationManager.addPending(
                windowId: charWindow.windowId,
                originalState: currentState,
                displayID: AppConstants.unknownDisplayID,
                adjustedOriginX: adjusted.originX,
                adjustedOriginY: adjusted.originY
            )
        }

        // フェーズ2: モニター再接続後の復元（ペンディングキュー）
        let restorable = screenRestorationManager.restorableEntries()
        for entry in restorable {
            guard let charWindow = characterWindows.first(where: { $0.windowId == entry.windowId }) else {
                screenRestorationManager.removePending(windowId: entry.windowId)
                continue
            }
            // 対象モニタが見つかったら無条件でクランプ位置に復元
            let targetScreen = findTargetScreenForPending(entry)
            if let screen = targetScreen {
                let windowWidth = charWindow.window.frame.width
                let windowHeight = charWindow.window.frame.height
                let clampedX = max(screen.frame.minX,
                    min(entry.originalState.originX, screen.frame.maxX - windowWidth))
                let clampedY = max(screen.frame.minY,
                    min(entry.originalState.originY, screen.frame.maxY - windowHeight))
                charWindow.window.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
            }
            screenRestorationManager.removePending(windowId: entry.windowId)
        }
    }

    // MARK: - Private Helpers

    /// ウィンドウ原点をスクリーン内にクランプ
    private func clampOrigin(_ origin: NSPoint, windowSize: NSSize, to screenFrame: NSRect) -> NSPoint {
        ScreenRestorationUtils.clampOrigin(origin, windowSize: windowSize, to: screenFrame)
    }

    /// Wake 復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致
    private func findTargetScreen(displayID: CGDirectDisplayID?, windowId: Int) -> NSScreen? {
        guard let savedID = displayID else { return nil }
        let savedFrame = wakeContext.screenFrames[savedID]
        let availableScreens = NSScreen.screens.compactMap { screen -> (displayID: UInt32, frame: NSRect)? in
            guard let did = screen.displayID else { return nil }
            return (displayID: did, frame: screen.frame)
        }
        guard let result = ScreenRestorationUtils.findTargetScreen(
            savedDisplayID: savedID,
            savedScreenFrame: savedFrame,
            availableScreens: availableScreens,
            tolerance: AppConstants.screenMatchTolerance
        ) else { return nil }
        return NSScreen.screen(withDisplayID: result.displayID)
    }

    /// ペンディング復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致 → ③ 元の位置を含むスクリーン
    private func findTargetScreenForPending(_ entry: PendingRestoration) -> NSScreen? {
        let originalRect = NSRect(
            x: entry.originalState.originX, y: entry.originalState.originY,
            width: entry.originalState.width, height: entry.originalState.height
        )
        let availableScreens = NSScreen.screens.compactMap { screen -> (displayID: UInt32, frame: NSRect)? in
            guard let did = screen.displayID else { return nil }
            return (displayID: did, frame: screen.frame)
        }
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
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
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
