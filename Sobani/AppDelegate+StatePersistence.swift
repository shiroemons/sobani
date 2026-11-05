import Cocoa
import os.log

// MARK: - State Persistence & Launch Restoration

/// ウィンドウ状態の常時保存と、起動直後のディスプレイ構成変化への追従を担う。
///
/// 以前は `applicationWillTerminate` でのみ保存していたため、再起動・ログアウト時に
/// 保存されず古い状態が復元されていた。状態変更をデバウンスして随時保存し、
/// 一時退避中のウィンドウは「意図した位置」で保存する。
extension AppDelegate {
    private static let persistenceLogger = Logger(category: "StatePersistence")

    // MARK: - Observers

    func setupStatePersistenceObservers() {
        let center = NotificationCenter.default
        // 調整パネル・管理パネル経由の移動やリサイズは imageWindowStateDidChange を発行しないため、
        // NSWindow の移動・リサイズ通知も保存トリガーにする
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { @Sendable [weak self] note in
                let window = note.object as? NSWindow
                MainActor.assumeIsolated {
                    guard let self, let window,
                          self.zOrderedWindows.contains(where: { $0.window === window }) else { return }
                    self.schedulePersist()
                }
            }
            windowGeometryObservers.append(observer)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWillPowerOff),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
    }

    func teardownStatePersistenceObservers() {
        persistDebounceTimer?.invalidate()
        launchRestoreTimer?.invalidate()
        for observer in windowGeometryObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowGeometryObservers.removeAll()
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
    }

    /// ログアウト・再起動・システム終了の直前。念のため即時保存し、受けた時刻を記録する。
    ///
    /// 終了理由（`kAEQuitReason`）が取得できない経路の保険として、この時刻から一定時間は
    /// 終了要求を許可する（`terminateReply`）。以前は `shouldTerminate` を立てていたため、
    /// ログアウトがキャンセルされると以後ずっと終了ガードが外れたままになっていた。
    @objc func handleWillPowerOff() {
        powerOffRequestedAt = Date()
        let count = persistNow(includingPending: true)
        Self.persistenceLogger.notice("willPowerOff: saved \(count, privacy: .public) window states")
    }

    // MARK: - Termination

    /// ログアウト・再起動・システム終了を示す Apple Event の終了理由
    nonisolated static let systemQuitReasons: Set<OSType> = [
        OSType(kAELogOut), OSType(kAEReallyLogOut),
        OSType(kAEShowRestartDialog), OSType(kAERestart),
        OSType(kAEShowShutdownDialog), OSType(kAEShutDown),
    ]

    /// willPowerOff を受けてから、終了理由のない終了要求も許可する期間。
    /// ログアウトがキャンセルされた後まで終了ガードが外れたままにならないよう期限を設ける。
    private nonisolated static let powerOffQuitGracePeriod: TimeInterval = 60

    /// 終了要求への応答を決める。
    ///
    /// 通常の終了要求（Cmd+Q 等）は誤操作防止のためキャンセルするが、ログアウト・再起動・
    /// システム終了ではキャンセルせず終了する。キャンセルすると再起動を妨げるうえ、
    /// `applicationWillTerminate` が呼ばれずウィンドウ状態が保存されない。
    /// - Parameters:
    ///   - powerOffRequestedAt: 直近に willPowerOff を受けた時刻。受けてから一定時間内なら、
    ///     終了理由が取れない終了要求も許可する
    ///   - now: 現在時刻（テスト用）
    nonisolated static func terminateReply(
        shouldTerminate: Bool,
        isInstallingUpdate: Bool,
        quitReason: OSType?,
        powerOffRequestedAt: Date? = nil,
        now: Date = Date()
    ) -> NSApplication.TerminateReply {
        if shouldTerminate || isInstallingUpdate {
            return .terminateNow
        }
        if let quitReason, systemQuitReasons.contains(quitReason) {
            return .terminateNow
        }
        if let powerOffRequestedAt, now.timeIntervalSince(powerOffRequestedAt) < powerOffQuitGracePeriod {
            return .terminateNow
        }
        return .terminateCancel
    }

    // MARK: - Position Log

    func logStates(event: String, _ states: [WindowState]) {
        guard PositionLogger.shared.isEnabled else { return }
        PositionLogger.shared.log(
            event: event,
            screens: PositionLogger.shared.currentScreenSnapshots(),
            windows: states.map { PositionLogger.shared.windowSnapshot(from: $0) },
            context: ["count": "\(states.count)"]
        )
    }

    // MARK: - Persistence

    /// デバウンス付きで保存を予約する。予約済みなら発火時刻を後ろへずらす（ドラッグ中の連続通知対策）。
    func schedulePersist(after interval: TimeInterval = AppConstants.statePersistDebounceInterval) {
        if let timer = persistDebounceTimer, timer.isValid {
            timer.fireDate = Date().addingTimeInterval(interval)
            return
        }
        persistDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.persistIfSettled()
            }
        }
    }

    /// 現在の状態を即時保存する。
    ///
    /// - Parameter includingPending: ペンディングキューも保存するか（終了時のみ）
    /// - Returns: 保存したウィンドウ数
    @discardableResult
    func persistNow(includingPending: Bool) -> Int {
        persistDebounceTimer?.invalidate()
        persistDebounceTimer = nil
        let states = persistableWindowStates()
        if states != lastPersistedStates {
            logStates(event: "states.save", states)
            WindowStateManager.shared.saveStates(states)
            lastPersistedStates = states
        }
        if includingPending {
            screenRestorationManager.savePending()
        }
        return states.count
    }

    private func persistIfSettled() {
        persistDebounceTimer = nil
        let settling = Self.isScreenConfigurationSettling(
            now: Date(),
            lastScreenChangeAt: lastScreenChangeAt,
            settleInterval: AppConstants.statePersistScreenSettleInterval,
            isRestoring: wakeContext.isActive || launchContext.isActive
        )
        guard !settling else {
            // 画面構成が落ち着くまで待ってから保存し直す
            schedulePersist(after: AppConstants.statePersistScreenSettleInterval)
            return
        }
        persistNow(includingPending: false)
    }

    /// 画面構成変更の直後、またはスリープ復帰・起動直後の復元中かを判定する。
    nonisolated static func isScreenConfigurationSettling(
        now: Date,
        lastScreenChangeAt: Date?,
        settleInterval: TimeInterval,
        isRestoring: Bool
    ) -> Bool {
        if isRestoring { return true }
        guard let lastScreenChangeAt else { return false }
        return now.timeIntervalSince(lastScreenChangeAt) < settleInterval
    }

    /// 保存用のウィンドウ状態（Z-order 背面→前面）。
    ///
    /// 一時退避中のウィンドウは現在位置ではなく意図した位置で保存する。
    /// 優先順位: スリープ復帰の復元中 → 起動直後の復元中 → ペンディングキュー。
    func persistableWindowStates() -> [WindowState] {
        var intended: [Int: WindowState] = [:]
        for entry in screenRestorationManager.pendingRestorations {
            intended[entry.windowId] = entry.originalState
        }
        intended.merge(launchContext.states) { _, launch in launch }
        if wakeContext.isActive {
            intended.merge(wakeContext.states) { _, wake in wake }
        }
        return Self.persistableStates(current: captureCurrentWindowStates(), intendedPositions: intended)
    }

    nonisolated static func persistableStates(
        current: [WindowState],
        intendedPositions: [Int: WindowState]
    ) -> [WindowState] {
        current.map { state in
            guard let intended = intendedPositions[state.windowId] else { return state }
            return state.preservingPosition(of: intended)
        }
    }

    // MARK: - Launch Restoration

    /// 起動時の復元結果を受け取り、ディスプレイ構成変化への追従を開始する。
    ///
    /// - アンカーのディスプレイが見つかったウィンドウ: 一定期間、画面構成が変わるたびに再適用する
    /// - アンカーのディスプレイが未接続、または可視領域へ退避したウィンドウ: ペンディングキューへ
    func beginLaunchRestoration(
        windows: [ImageWindow],
        savedStates: [WindowState],
        resolutions: [WindowState.RestoreResolution?],
        screens: [ScreenInfo]
    ) {
        var context = LaunchRestorationContext()
        var summary: [WindowState.AnchorResolution: Int] = [:]
        for (imageWindow, (state, optionalResolution)) in zip(windows, zip(savedStates, resolutions)) {
            guard let resolution = optionalResolution else { continue }
            summary[resolution.anchor, default: 0] += 1
            if state.displayAnchor != nil {
                context.states[imageWindow.windowId] = state
            }
            if resolution.anchor == .displayMissing || resolution.wasAdjusted {
                screenRestorationManager.addPending(
                    windowId: imageWindow.windowId,
                    originalState: state,
                    displayID: AppConstants.unknownDisplayID
                )
            }
        }
        let screenDesc = screens
            .map { "\($0.displayUUID ?? "?")@\(NSStringFromRect($0.frame))" }
            .joined(separator: ", ")
        let summaryDesc = summary.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ",")
        Self.persistenceLogger.notice(
            "launch restore: \(summaryDesc, privacy: .public) screens=[\(screenDesc, privacy: .public)]"
        )
        guard context.isActive else { return }
        launchContext = context
        launchRestoreTimer?.invalidate()
        launchRestoreTimer = Timer.scheduledTimer(
            withTimeInterval: AppConstants.launchRestoreWindow,
            repeats: false
        ) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.endLaunchRestoration()
            }
        }
    }

    /// 画面構成変化を受けて、アンカーのディスプレイ基準で位置を再適用する。
    func attemptLaunchRestoration() {
        guard launchContext.isActive else { return }
        let screens = ScreenInfo.current()
        var applied = 0
        for imageWindow in zOrderedWindows {
            guard let state = launchContext.states[imageWindow.windowId] else { continue }
            if imageWindow.reapplyAnchoredPosition(of: state, screens: screens) {
                applied += 1
            }
        }
        Self.persistenceLogger.notice(
            "launch restore: reapplied \(applied, privacy: .public)/\(self.launchContext.states.count, privacy: .public)"
        )
    }

    func endLaunchRestoration() {
        let wasRunning = launchContext.isActive
        if wasRunning {
            queueLaunchWindowsWithMissingDisplay()
        }
        cancelLaunchRestoration()
        guard wasRunning else { return }
        // ペンディング復元の最後にスナップショットも更新される
        attemptPendingRestorations()
    }

    /// 追従を終える時点でアンカーのディスプレイが接続されていないウィンドウを、意図した位置のまま
    /// ペンディングキューへ移す（launchContext を消すと意図した位置が失われ、ディスプレイが戻っても復元されないため）。
    private func queueLaunchWindowsWithMissingDisplay() {
        var queuedCount = 0
        for windowId in launchContext.windowIdsWithMissingDisplay(on: ScreenInfo.current())
        where !screenRestorationManager.isPending(windowId: windowId) {
            guard let state = launchContext.states[windowId],
                  zOrderedWindows.contains(where: { $0.windowId == windowId }) else { continue }
            screenRestorationManager.addPending(
                windowId: windowId,
                originalState: state,
                displayID: AppConstants.unknownDisplayID
            )
            queuedCount += 1
        }
        if queuedCount > 0 {
            Self.persistenceLogger.notice(
                "launch restore: queued \(queuedCount, privacy: .public) windows whose display is missing"
            )
        }
    }

    /// ユーザーが手動でウィンドウを動かした・大きさを変えた場合、以後そのウィンドウは起動時復元の対象外にする。
    func releaseLaunchRestoration(windowId: Int) {
        guard launchContext.isActive else { return }
        launchContext.release(windowId: windowId)
        if !launchContext.isActive {
            // 最後の 1 枚が外れたら追従を終える（launchContext が空なので end 側の後処理を直接行う）
            cancelLaunchRestoration()
            attemptPendingRestorations()
        }
    }

    /// レイアウト適用などでウィンドウが作り直された場合、起動時復元を打ち切る。
    func cancelLaunchRestoration() {
        launchRestoreTimer?.invalidate()
        launchRestoreTimer = nil
        launchContext.clear()
    }
}
