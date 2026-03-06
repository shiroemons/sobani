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
            screenChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.wakeDebounceInterval, repeats: false) { [weak self] _ in
                self?.attemptWakeRestoration()
            }
        } else {
            // 通常時 → ペンディング復元を試行（1秒デバウンス）
            screenChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.screenChangeDebounceInterval, repeats: false) { [weak self] _ in
                self?.attemptPendingRestorations()
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
        screenChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.wakeInitialDelay, repeats: false) { [weak self] _ in
            self?.attemptWakeRestoration()
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

        if restoredAll && wakeContext.retryCount <= 2 {
            // 全復元完了だが、macOS が後から再配置する可能性があるため追加リトライ
            scheduleWakeRetry(interval: 3.0)
        } else if restoredAll || wakeContext.retryCount >= 10 {
            // 確実に全復元完了 or タイムアウト → 残りをペンディングキューに移行
            moveUnrestoredToPendingQueue()
            wakeContext.clear()
        } else {
            // 未復元ウィンドウがある → 3秒後にリトライ
            scheduleWakeRetry(interval: 3.0)
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
        guard let displayID = savedDisplayID,
              let oldFrame = wakeContext.screenFrames[displayID] else {
            return savedOrigin
        }
        let relativeX = savedOrigin.x - oldFrame.origin.x
        let relativeY = savedOrigin.y - oldFrame.origin.y
        return NSPoint(
            x: currentScreen.frame.origin.x + relativeX,
            y: currentScreen.frame.origin.y + relativeY
        )
    }

    /// 未復元ウィンドウをペンディングキューに移行
    private func moveUnrestoredToPendingQueue() {
        for windowId in wakeContext.states.keys {
            let savedDisplayID = wakeContext.displayIDs[windowId]
            guard findTargetScreen(displayID: savedDisplayID, windowId: windowId) == nil else { continue }
            guard let savedState = wakeContext.states[windowId] else { continue }

            let screenFrame = savedDisplayID.flatMap { wakeContext.screenFrames[$0] }
            let adjusted = WindowStateManager.adjustToVisibleArea(savedState)

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
        screenChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.attemptWakeRestoration()
        }
    }

    func attemptPendingRestorations() {
        // フェーズ0: スリープなしのモニター切断対応
        // wakeContext.states が空（スリープ復帰でない）かつ画面外ウィンドウがある場合に対応
        for charWindow in characterWindows {
            let currentState = WindowStateManager.captureState(from: charWindow)
            guard !WindowStateManager.isPositionVisible(currentState) else { continue }
            let adjusted = WindowStateManager.adjustToVisibleArea(currentState)
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
        let clampedX = windowSize.width >= screenFrame.width
            ? origin.x
            : max(screenFrame.minX, min(origin.x, screenFrame.maxX - windowSize.width))
        let clampedY = windowSize.height >= screenFrame.height
            ? origin.y
            : max(screenFrame.minY, min(origin.y, screenFrame.maxY - windowSize.height))
        return NSPoint(x: clampedX, y: clampedY)
    }

    /// Wake 復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致
    private func findTargetScreen(displayID: CGDirectDisplayID?, windowId: Int) -> NSScreen? {
        // ① displayID 完全一致
        if let savedID = displayID, let screen = NSScreen.screen(withDisplayID: savedID) {
            return screen
        }
        // ② ジオメトリベースのフォールバック
        if let savedID = displayID, let savedFrame = wakeContext.screenFrames[savedID] {
            return NSScreen.screen(matchingFrame: savedFrame, tolerance: AppConstants.screenMatchTolerance)
        }
        return nil
    }

    /// ペンディング復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致
    private func findTargetScreenForPending(_ entry: PendingRestoration) -> NSScreen? {
        // ① displayID 完全一致
        if entry.displayID != AppConstants.unknownDisplayID, let screen = NSScreen.screen(withDisplayID: entry.displayID) {
            return screen
        }
        // ② ジオメトリベースのフォールバック
        if let savedFrame = entry.preSleepScreenFrame {
            return NSScreen.screen(matchingFrame: savedFrame, tolerance: AppConstants.screenMatchTolerance)
        }
        // ③ displayID: 0（スリープなし切断）の場合、元の位置が含まれるスクリーンを返す
        if entry.displayID == AppConstants.unknownDisplayID {
            let originalRect = NSRect(
                x: entry.originalState.originX, y: entry.originalState.originY,
                width: entry.originalState.width, height: entry.originalState.height
            )
            return NSScreen.screen(containing: originalRect)
        }
        return nil
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
            abs(screen.frame.origin.x - savedFrame.origin.x) <= tolerance
                && abs(screen.frame.origin.y - savedFrame.origin.y) <= tolerance
                && abs(screen.frame.size.width - savedFrame.size.width) <= tolerance
                && abs(screen.frame.size.height - savedFrame.size.height) <= tolerance
        }
    }
}
