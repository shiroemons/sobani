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
        for charWindow in characterWindows {
            let state = WindowStateManager.captureState(from: charWindow)
            preSleepStates[charWindow.windowId] = state
        }
    }

    @objc func handleDidWake() {
        // macOS はスリープ復帰時に外部モニター接続中でもウィンドウをメインモニターへ移動する。
        // モニターが完全に登録されるよう、遅延後に全ウィンドウを復元する。
        handleScreenChange()
    }

    func attemptPendingRestorations() {
        // フェーズ1: スリープ復帰後の全ウィンドウ復元
        if !preSleepStates.isEmpty {
            for charWindow in characterWindows {
                guard let savedState = preSleepStates[charWindow.windowId] else { continue }
                let adjusted = WindowStateManager.adjustToVisibleArea(savedState)
                charWindow.window.setFrameOrigin(NSPoint(x: adjusted.originX, y: adjusted.originY))
                // 位置が調整された（モニター切断）場合はペンディングへ追加
                if adjusted.originX != savedState.originX || adjusted.originY != savedState.originY {
                    screenRestorationManager.addPending(
                        windowId: charWindow.windowId,
                        originalState: savedState,
                        adjustedOriginX: adjusted.originX,
                        adjustedOriginY: adjusted.originY
                    )
                }
            }
            preSleepStates = [:]
        }

        // フェーズ2: モニター再接続後の復元（ペンディングキュー）
        let restorable = screenRestorationManager.restorableEntries(using: WindowStateManager.isPositionVisible)
        for entry in restorable {
            guard let charWindow = characterWindows.first(where: { $0.windowId == entry.windowId }) else {
                screenRestorationManager.removePending(windowId: entry.windowId)
                continue
            }
            let currentOrigin = charWindow.window.frame.origin
            let deltaX = abs(currentOrigin.x - entry.adjustedOriginX)
            let deltaY = abs(currentOrigin.y - entry.adjustedOriginY)
            if deltaX <= 20 && deltaY <= 20 {
                charWindow.window.setFrameOrigin(NSPoint(x: entry.originalState.originX, y: entry.originalState.originY))
            }
            screenRestorationManager.removePending(windowId: entry.windowId)
        }
    }
}
