import Cocoa

// MARK: - Screen Restoration

extension AppDelegate {
    func setupScreenRestorationObservers() {
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
        screenChangeDebounceTimer?.invalidate()
        screenChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.attemptPendingRestorations()
        }
    }

    @objc func handleWillSleep() {
        preSleepStates = [:]
        preSleepDisplayIDs = [:]
        screenRestorationManager.clearAll()
        for charWindow in characterWindows {
            let state = WindowStateManager.captureState(from: charWindow)
            preSleepStates[charWindow.windowId] = state
            if let screen = NSScreen.screen(containing: charWindow.window.frame),
               let displayID = screen.displayID {
                preSleepDisplayIDs[charWindow.windowId] = displayID
            }
        }
    }

    @objc func handleDidWake() {
        // macOS はスリープ復帰時に外部モニター接続中でもウィンドウをメインモニターへ移動する。
        // モニターが完全に登録されるよう、遅延後に全ウィンドウを復元する。
        handleScreenChange()
    }

    func attemptPendingRestorations() {
        // フェーズ0: スリープなしのモニター切断対応
        // preSleepStates が空（スリープ復帰でない）かつ画面外ウィンドウがある場合に対応
        if preSleepStates.isEmpty {
            for charWindow in characterWindows {
                let currentState = WindowStateManager.captureState(from: charWindow)
                guard !WindowStateManager.isPositionVisible(currentState) else { continue }
                let adjusted = WindowStateManager.adjustToVisibleArea(currentState)
                charWindow.window.setFrameOrigin(NSPoint(x: adjusted.originX, y: adjusted.originY))
                // displayID は切断後には取得不可のため 0 を使用（位置ベースで復元判定）
                screenRestorationManager.addPending(
                    windowId: charWindow.windowId,
                    originalState: currentState,
                    displayID: 0,
                    adjustedOriginX: adjusted.originX,
                    adjustedOriginY: adjusted.originY
                )
            }
        }

        // フェーズ1: スリープ復帰後の全ウィンドウ復元（displayIDベース）
        if !preSleepStates.isEmpty {
            for charWindow in characterWindows {
                guard let savedState = preSleepStates[charWindow.windowId] else { continue }

                let targetOrigin: NSPoint
                let savedDisplayID = preSleepDisplayIDs[charWindow.windowId]

                if let savedID = savedDisplayID, let screen = NSScreen.screen(withDisplayID: savedID) {
                    // モニターが接続中 → 保存位置をそのモニター内に収めて復元
                    let clampedX = max(screen.frame.minX,
                        min(savedState.originX, screen.frame.maxX - savedState.width))
                    let clampedY = max(screen.frame.minY,
                        min(savedState.originY, screen.frame.maxY - savedState.height))
                    targetOrigin = NSPoint(x: clampedX, y: clampedY)
                } else {
                    // モニター未接続 → メインスクリーン中央へ + 再接続時のためペンディング追加
                    let adjusted = WindowStateManager.adjustToVisibleArea(savedState)
                    targetOrigin = NSPoint(x: adjusted.originX, y: adjusted.originY)
                    screenRestorationManager.addPending(
                        windowId: charWindow.windowId,
                        originalState: savedState,
                        displayID: savedDisplayID ?? 0,
                        adjustedOriginX: adjusted.originX,
                        adjustedOriginY: adjusted.originY
                    )
                }
                charWindow.window.setFrameOrigin(targetOrigin)
            }
            preSleepStates = [:]
            preSleepDisplayIDs = [:]
        }

        // フェーズ2: モニター再接続後の復元（ペンディングキュー）
        let restorable = screenRestorationManager.restorableEntries()
        for entry in restorable {
            guard let charWindow = characterWindows.first(where: { $0.windowId == entry.windowId }) else {
                screenRestorationManager.removePending(windowId: entry.windowId)
                continue
            }
            let currentOrigin = charWindow.window.frame.origin
            let deltaX = abs(currentOrigin.x - entry.adjustedOriginX)
            let deltaY = abs(currentOrigin.y - entry.adjustedOriginY)
            if deltaX <= 20 && deltaY <= 20 {
                charWindow.window.setFrameOrigin(
                    NSPoint(x: entry.originalState.originX, y: entry.originalState.originY)
                )
            }
            screenRestorationManager.removePending(windowId: entry.windowId)
        }
    }
}

// MARK: - NSScreen Helpers

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static func screen(withDisplayID displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == displayID }
    }

    static func screen(containing rect: NSRect) -> NSScreen? {
        screens.max {
            let areaA = $0.frame.intersection(rect)
            let areaB = $1.frame.intersection(rect)
            return areaA.width * areaA.height < areaB.width * areaB.height
        }
    }
}
