import Cocoa
import os.log

// MARK: - Screen Restoration

extension AppDelegate {
    private static let screenRestorationLogger = Logger(category: "ScreenRestoration")
    /// ウィンドウ状態の変更からスナップショットを更新するまでのデバウンス間隔
    private static let snapshotDebounceInterval: TimeInterval = 0.3

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowStateChange),
            name: AppConstants.imageWindowStateDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowStateChange),
            name: AppConstants.imageWindowListDidChange,
            object: nil
        )
    }

    func teardownScreenRestorationObservers() {
        screenChangeDebounceTimer?.invalidate()
        snapshotDebounceTimer?.invalidate()
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
        NotificationCenter.default.removeObserver(
            self,
            name: AppConstants.imageWindowStateDidChange,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: AppConstants.imageWindowListDidChange,
            object: nil
        )
    }

    @objc func handleScreenChange() {
        lastScreenChangeAt = Date()
        let isLaunch = launchContext.isActive
        let screens = ScreenInfo.current()
        // handleWillSleep が位置を保存済みだが handleDidWake がまだ発火していない場合、
        // スリープ復帰中のスクリーン変更として扱う（通知センター間のレース条件対策）。
        // 起動直後はアンカー復元で追従するため wake モードにはしない
        if !wakeContext.isActive && !isLaunch {
            if !wakeContext.states.isEmpty {
                wakeContext.isActive = true
                wakeContext.retryCount = 0
                Self.screenRestorationLogger.info(
                    "screenChange: activated wake mode (willSleep saved but didWake not yet received)"
                )
            } else if !screenSnapshot.states.isEmpty {
                // ディスプレイスリープ等で willSleep が発火しない場合
                let disconnectedScreens = Set(screenSnapshot.screenFrames.keys)
                    .subtracting(screens.map(\.displayID))
                    .sorted()
                if !disconnectedScreens.isEmpty {
                    wakeContext = screenSnapshot
                    wakeContext.isActive = true
                    wakeContext.retryCount = 0
                    Self.screenRestorationLogger.info(
                        "screenChange: activated wake mode from snapshot (disconnected: \(disconnectedScreens, privacy: .public))"
                    )
                    logPositionEvent(
                        "sleep.enter.snapshot",
                        context: ["savedCount": "\(wakeContext.states.count)",
                                  "disconnectedScreens": "\(disconnectedScreens)"]
                    )
                }
            }
        }
        let isWake = wakeContext.isActive
        Self.screenRestorationLogger.notice(
            "screenChange: isWake=\(isWake, privacy: .public), isLaunch=\(isLaunch, privacy: .public), screens=\(screens.count, privacy: .public)"
        )
        logScreenLayout(screens, label: "screenChange")
        if PositionLogger.shared.isEnabled {
            PositionLogger.shared.log(
                event: "screen.change",
                screens: PositionLogger.shared.currentScreenSnapshots(),
                context: ["isWake": "\(isWake)", "isLaunch": "\(isLaunch)", "screenCount": "\(screens.count)"]
            )
        }
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
            // 通常時 → ペンディング復元を試行（1秒デバウンス）。
            // 起動直後はディスプレイ認識遅延・プライマリ入れ替わりに追従してアンカー位置を再適用する
            let interval = AppConstants.screenChangeDebounceInterval
            screenChangeDebounceTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: false
            ) { @Sendable [weak self] _ in
                MainActor.assumeIsolated {
                    self?.attemptLaunchRestoration()
                    self?.attemptPendingRestorations()
                }
            }
        }
    }

    @objc func handleWillSleep() {
        // Wake 復元中のタイマーをキャンセル
        screenChangeDebounceTimer?.invalidate()
        // スリープしている時間はペンディングの期限に含めない（復帰時に resumeExpiry）
        screenRestorationManager.suspendExpiry()

        if wakeContext.isActive {
            // 復元の途中で再びスリープした。現在位置は macOS が退避させたままの可能性があるため
            // 取り直さず、意図した位置（既存の context）を保ったまま次の復帰を待つ
            wakeContext.isActive = false
            wakeContext.retryCount = 0
        } else {
            // ペンディング中のウィンドウは退避先にいるため含めない（復帰後に Phase 2 で元の位置へ戻す）
            wakeContext = captureWindowStates(screens: ScreenInfo.current())
        }
        Self.screenRestorationLogger.info(
            "[ScreenRestoration] willSleep: saved \(self.wakeContext.states.count, privacy: .public) windows"
        )
        for (windowId, origin) in wakeContext.windowOrigins {
            let displayID = wakeContext.displayIDs[windowId] ?? AppConstants.unknownDisplayID
            let screenFrame = wakeContext.screenFrames[displayID]
            Self.screenRestorationLogger.debug("""
                  #\(windowId, privacy: .public): origin=\(NSStringFromPoint(origin), privacy: .public), \
                displayID=\(displayID, privacy: .public), sf=\(screenFrame.debugDescription, privacy: .public)
                """)
        }
        logPositionEvent("sleep.enter", context: ["savedCount": "\(wakeContext.states.count)"])
    }

    @objc func handleDidWake() {
        let restoreCount = wakeContext.states.count
        let screens = ScreenInfo.current()
        Self.screenRestorationLogger.info(
            "[ScreenRestoration] didWake: \(restoreCount, privacy: .public) windows to restore, screens=\(screens.count, privacy: .public)"
        )
        logScreenLayout(screens, label: "didWake")
        logWindowPositions(label: "didWake")
        logPositionEvent("sleep.wake", context: ["restoreCount": "\(restoreCount)"])
        logWakeDrift()
        screenRestorationManager.resumeExpiry()
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
        guard wakeContext.isActive else { return }
        let screens = ScreenInfo.current()
        guard !wakeContext.states.isEmpty else {
            // 復元対象が残っていない（ウィンドウなし・全ウィンドウがユーザー操作で外れた等）
            finishWakeRestoration(screens: screens)
            return
        }

        let restoredAll = restoreAllPreSleepWindows(screens: screens)
        wakeContext.retryCount += 1
        let retryNum = wakeContext.retryCount
        Self.screenRestorationLogger.debug("""
            attempt #\(retryNum, privacy: .public): restoredAll=\(restoredAll, privacy: .public), \
            screens=[\(screens.map { NSStringFromRect($0.frame) }.joined(separator: ", "), privacy: .public)]
            """)
        if retryNum >= 2 {
            logWindowPositions(label: "retry #\(retryNum)")
        }

        if restoredAll && wakeContext.retryCount <= AppConstants.wakeRetryCountThreshold {
            // 全復元完了だが、macOS が後から再配置する可能性があるため追加リトライ
            scheduleWakeRetry(interval: AppConstants.wakeRetryInterval)
        } else if restoredAll || wakeContext.retryCount >= AppConstants.wakeRetryMaxAttempts {
            // 確実に全復元完了 or タイムアウト → 残りをペンディングキューに移行
            finishWakeRestoration(screens: screens)
        } else {
            // 未復元ウィンドウがある → リトライ
            scheduleWakeRetry(interval: AppConstants.wakeRetryInterval)
        }
    }

    /// スリープ復帰の復元を終える。
    ///
    /// 未復元のウィンドウをペンディングキューへ移したあと、スリープ前からペンディング中だった
    /// ウィンドウ（`captureWindowStates` で除外）の復元を試みる。`attemptPendingRestorations` の
    /// 最後にスナップショットも更新されるため、スリープ前の古いスナップショットで次の画面構成変更時に
    /// wake モードが再開されることはない。
    private func finishWakeRestoration(screens: [ScreenInfo]) {
        moveUnrestoredToPendingQueue(screens: screens)
        wakeContext.clear()
        attemptPendingRestorations()
    }

    /// 全ウィンドウをスリープ前のディスプレイ基準の相対位置で復元。全ウィンドウ復元できたら true を返す。
    ///
    /// 位置はウィンドウ（回転後のバウンディングボックス）基準の生の origin で扱う。
    /// 起動時のアンカー復元と同じく、写像先が見えない場合だけクランプする。
    private func restoreAllPreSleepWindows(screens: [ScreenInfo]) -> Bool {
        // 注意: wakeContext.states から個別に除去しない。macOS はモニタ復帰時に
        // 全ウィンドウを再配置するため、リトライ毎に全ウィンドウを再復元する必要がある。
        let logScreens = PositionLogger.shared.isEnabled ? PositionLogger.shared.currentScreenSnapshots() : nil
        let screenFrames = screens.map(\.frame)
        var restoredAll = true

        for imageWindow in zOrderedWindows {
            let windowId = imageWindow.windowId
            guard wakeContext.states[windowId] != nil,
                  let savedOrigin = wakeContext.windowOrigins[windowId] else { continue }

            let savedDisplayID = wakeContext.displayIDs[windowId]
            guard let screen = findWakeTargetScreen(displayID: savedDisplayID, screens: screens) else {
                restoredAll = false
                Self.screenRestorationLogger.error(
                    "restore #\(windowId, privacy: .public): screen not found (displayID=\(savedDisplayID ?? AppConstants.unknownDisplayID, privacy: .public))"
                )
                continue
            }
            let oldFrame = savedDisplayID.flatMap { wakeContext.screenFrames[$0] }
            let windowSize = imageWindow.window.frame.size
            let restored = ScreenRestorationUtils.restoredOrigin(
                of: NSRect(origin: savedOrigin, size: windowSize),
                from: oldFrame, to: screen.frame, visibleIn: screenFrames
            )
            Self.screenRestorationLogger.debug("""
                restore #\(windowId, privacy: .public): saved=\(NSStringFromPoint(savedOrigin), privacy: .public) \
                -> \(NSStringFromPoint(restored), privacy: .public), \
                currentPos=\(NSStringFromPoint(imageWindow.window.frame.origin), privacy: .public), \
                displayID saved=\(savedDisplayID ?? AppConstants.unknownDisplayID, privacy: .public) \
                current=\(screen.displayID, privacy: .public), oldFrame=\(oldFrame.debugDescription, privacy: .public), \
                screen=\(NSStringFromRect(screen.frame), privacy: .public), winSize=\(NSStringFromSize(windowSize), privacy: .public)
                """)
            imageWindow.window.setFrameOrigin(restored)
            if PositionLogger.shared.isEnabled {
                PositionLogger.shared.log(
                    event: "wake.restore",
                    screens: logScreens,
                    windows: [PositionLogger.shared.windowSnapshot(from: imageWindow)],
                    context: [
                        "savedOrigin": "\(NSStringFromPoint(savedOrigin))",
                        "restoredOrigin": "\(NSStringFromPoint(restored))",
                        "windowSize": "\(NSStringFromSize(windowSize))",
                        "screenFrame": "\(NSStringFromRect(screen.frame))",
                    ]
                )
            }
        }
        return restoredAll
    }

    /// 未復元ウィンドウをペンディングキューに移行
    private func moveUnrestoredToPendingQueue(screens: [ScreenInfo]) {
        for imageWindow in zOrderedWindows {
            let windowId = imageWindow.windowId
            let savedDisplayID = wakeContext.displayIDs[windowId]
            guard let savedState = wakeContext.states[windowId],
                  findWakeTargetScreen(displayID: savedDisplayID, screens: screens) == nil else { continue }

            let screenFrame = savedDisplayID.flatMap { wakeContext.screenFrames[$0] }
            let adjusted = savedState.adjustedToVisibleArea(on: screens)

            // WindowState の原点は画像基準のため、回転中のウィンドウはウィンドウ原点へ変換して配置する
            imageWindow.setImageOrigin(adjusted.frame.origin)
            if PositionLogger.shared.isEnabled {
                PositionLogger.shared.log(
                    event: "pending.add",
                    windows: [PositionLogger.WindowSnapshot(
                        windowId: windowId,
                        originX: adjusted.originX, originY: adjusted.originY,
                        width: adjusted.width, height: adjusted.height,
                        imageWidth: adjusted.width, imageHeight: adjusted.height,
                        displayID: savedDisplayID
                    )],
                    context: [
                        "originalOrigin": "\(savedState.originX),\(savedState.originY)",
                        "adjustedOrigin": "\(adjusted.originX),\(adjusted.originY)",
                        "displayID": "\(savedDisplayID ?? AppConstants.unknownDisplayID)",
                    ]
                )
            }
            screenRestorationManager.addPending(
                windowId: windowId, originalState: savedState,
                displayID: savedDisplayID ?? AppConstants.unknownDisplayID,
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

    /// Phase 0（画面外ウィンドウの退避）と Phase 2（ペンディングキューからの復元）を行い、
    /// 結果の配置でスナップショットを更新する（古いスナップショットで wake モードが再開されないように）。
    func attemptPendingRestorations() {
        let screens = ScreenInfo.current()
        moveInvisibleWindowsToPending(screens: screens)

        // フェーズ2: モニター再接続後の復元（ペンディングキュー）
        restorePendingWindows(screens: screens)
        updateScreenSnapshot()
    }

    /// フェーズ0: スリープなしのモニター切断対応
    /// wakeContext.states が空（スリープ復帰でない）かつ画面外ウィンドウがある場合に対応
    private func moveInvisibleWindowsToPending(screens: [ScreenInfo]) {
        let logScreensPhase0 = PositionLogger.shared.isEnabled ? PositionLogger.shared.currentScreenSnapshots() : nil
        for imageWindow in zOrderedWindows {
            // 既にペンディング中のウィンドウは、意図した位置（originalState）を退避先で上書きしない
            guard !screenRestorationManager.isPending(windowId: imageWindow.windowId) else { continue }
            var currentState = WindowStateManager.captureState(from: imageWindow, screens: screens)
            guard !currentState.isPositionVisible(on: screens) else { continue }
            // 意図した位置は直近の安定時スナップショット（切断前のディスプレイのアンカー付き）を優先する。
            // ない場合、今の位置は現在のスクリーン構成に属さないため、アンカーなしで位置ベースに復元する
            if let snapshotState = screenSnapshot.states[imageWindow.windowId] {
                currentState = currentState.preservingPosition(of: snapshotState)
            } else {
                currentState.displayAnchor = nil
            }
            let adjusted = currentState.adjustedToVisibleArea(on: screens)
            imageWindow.setImageOrigin(adjusted.frame.origin)
            if PositionLogger.shared.isEnabled {
                PositionLogger.shared.log(
                    event: "pending.phase0",
                    screens: logScreensPhase0,
                    windows: [PositionLogger.shared.windowSnapshot(from: imageWindow)],
                    context: [
                        "currentOrigin": "\(currentState.originX),\(currentState.originY)",
                        "adjustedOrigin": "\(adjusted.originX),\(adjusted.originY)",
                    ]
                )
            }
            // displayID は切断後には取得不可のため 0 を使用（位置ベースで復元判定）
            screenRestorationManager.addPending(
                windowId: imageWindow.windowId,
                originalState: currentState,
                displayID: AppConstants.unknownDisplayID
            )
        }
    }

    private func restorePendingWindows(screens: [ScreenInfo]) {
        for entry in screenRestorationManager.restorableEntries(screens: screens) {
            guard let imageWindow = zOrderedWindows.first(where: { $0.windowId == entry.windowId })
            else {
                screenRestorationManager.removePending(windowId: entry.windowId)
                continue
            }
            // アンカー（ディスプレイ UUID）があればディスプレイ基準の相対位置で復元する
            if imageWindow.reapplyAnchoredPosition(of: entry.originalState, screens: screens) {
                if PositionLogger.shared.isEnabled {
                    PositionLogger.shared.log(
                        event: "pending.phase2.anchor",
                        windows: [PositionLogger.shared.windowSnapshot(from: imageWindow)],
                        context: [
                            "originalOrigin": "\(entry.originalState.originX),\(entry.originalState.originY)",
                            "displayUUID": entry.originalState.displayAnchor?.displayUUID ?? "",
                        ]
                    )
                }
                screenRestorationManager.removePending(windowId: entry.windowId)
                continue
            }
            // 対象モニタが見つかったら、切断前のスクリーン基準の相対位置で復元する（見えない場合だけクランプ）。
            // originalState は画像基準のため、原点・サイズとも画像基準で計算してから配置する
            if let screen = findPendingTargetScreen(for: entry, screens: screens) {
                let restored = ScreenRestorationUtils.restoredOrigin(
                    of: entry.originalState.frame,
                    from: entry.preSleepScreenFrame, to: screen.frame, visibleIn: screens.map(\.frame)
                )
                imageWindow.setImageOrigin(restored)
                if PositionLogger.shared.isEnabled {
                    PositionLogger.shared.log(
                        event: "pending.phase2",
                        windows: [PositionLogger.shared.windowSnapshot(from: imageWindow)],
                        context: [
                            "originalOrigin": "\(entry.originalState.originX),\(entry.originalState.originY)",
                            "restoredOrigin": "\(NSStringFromPoint(restored))",
                            "imageSize": "\(NSStringFromSize(entry.originalState.frame.size))",
                            "screenFrame": "\(NSStringFromRect(screen.frame))",
                        ]
                    )
                }
            }
            screenRestorationManager.removePending(windowId: entry.windowId)
        }
    }

    /// ユーザー（または調整パネル等の UI 操作）でウィンドウの位置・大きさが変わったことを示すトリガー。
    ///
    /// これらを受けたウィンドウは、起動時・スリープ復帰の自動復元の対象から外す。外さないと、
    /// 後続の画面構成変化やリトライで復元処理がユーザーの操作を元に戻し、保存時も意図した位置として
    /// 古い位置が優先されてしまう。NSWindow の移動通知は macOS による退避も拾うため使わない。
    static let userGeometryTriggers: Set<AppConstants.SnapshotTrigger> = [
        .position, .size, .reset, .crop, .rotation,
    ]

    @objc private func handleWindowStateChange(_ notification: Notification) {
        if let raw = notification.userInfo?[AppConstants.notificationTriggerKey] as? String,
           let trigger = AppConstants.SnapshotTrigger(rawValue: raw) {
            pendingSnapshotTriggers.insert(trigger)
            if Self.userGeometryTriggers.contains(trigger), let imageWindow = notification.object as? ImageWindow {
                wakeContext.release(windowId: imageWindow.windowId)
                releaseLaunchRestoration(windowId: imageWindow.windowId)
            }
        }
        schedulePersist()
        scheduleSnapshotUpdate()
    }

    /// デバウンス付きでスナップショット更新を予約する。予約済みならタイマーを作り直さず発火時刻を後ろへずらす。
    private func scheduleSnapshotUpdate() {
        if let timer = snapshotDebounceTimer, timer.isValid {
            timer.fireDate = Date().addingTimeInterval(Self.snapshotDebounceInterval)
            return
        }
        snapshotDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: Self.snapshotDebounceInterval,
            repeats: false
        ) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateScreenSnapshot()
            }
        }
    }

    /// 現在のウィンドウ位置をスナップショットに保存する。
    /// ディスプレイ切断時（willSleep なし）の復元に使用される。
    func updateScreenSnapshot() {
        // 復元中はスナップショットを更新しない（macOS が一時的に移動した位置を保存しないため）
        guard !wakeContext.isActive, !launchContext.isActive else {
            pendingSnapshotTriggers.removeAll()
            return
        }
        let triggers = pendingSnapshotTriggers.map(\.rawValue).sorted()
        pendingSnapshotTriggers.removeAll()
        screenSnapshot = captureWindowStates(screens: ScreenInfo.current())
        logPositionEvent(
            "snapshot.update",
            context: triggers.isEmpty ? nil : ["triggers": triggers.joined(separator: ",")]
        )
    }

    // MARK: - Private Helpers

    /// zOrderedWindows の現在位置を WakeRestorationContext に収集して返す。
    ///
    /// - ペンディング中のウィンドウは退避先にいるため含めない（意図した位置はペンディングキューが持つ）
    /// - どのスクリーンとも重ならないウィンドウは、ディスプレイ基準で復元しようがないため含めない
    private func captureWindowStates(screens: [ScreenInfo]) -> WakeRestorationContext {
        var ctx = WakeRestorationContext()
        let screenFrames = screens.map(\.frame)
        for imageWindow in zOrderedWindows where !screenRestorationManager.isPending(windowId: imageWindow.windowId) {
            let frame = imageWindow.window.frame
            guard let index = ScreenRestorationUtils.indexOfLargestOverlap(for: frame, in: screenFrames) else {
                continue
            }
            let screen = screens[index]
            let windowId = imageWindow.windowId
            ctx.states[windowId] = WindowStateManager.captureState(from: imageWindow, screens: screens)
            ctx.windowOrigins[windowId] = frame.origin
            ctx.displayIDs[windowId] = screen.displayID
            ctx.screenFrames[screen.displayID] = screen.frame
        }
        return ctx
    }

    /// Wake 復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致
    private func findWakeTargetScreen(displayID: CGDirectDisplayID?, screens: [ScreenInfo]) -> ScreenInfo? {
        guard let displayID else { return nil }
        return ScreenRestorationUtils.findTargetScreen(
            savedDisplayID: displayID,
            savedScreenFrame: wakeContext.screenFrames[displayID],
            availableScreens: screens,
            tolerance: AppConstants.screenMatchTolerance
        )
    }

    /// ペンディング復元時のモニタ検索: ① displayID 完全一致 → ② ジオメトリ一致 → ③ 元の位置と最も重なるスクリーン
    private func findPendingTargetScreen(for entry: PendingRestoration, screens: [ScreenInfo]) -> ScreenInfo? {
        let search = ScreenRestorationUtils.PendingScreenSearch(
            displayID: entry.displayID,
            savedScreenFrame: entry.preSleepScreenFrame,
            originalRect: entry.originalState.frame,
            unknownDisplayID: AppConstants.unknownDisplayID
        )
        return ScreenRestorationUtils.findTargetScreenForPending(
            search,
            availableScreens: screens,
            tolerance: AppConstants.screenMatchTolerance
        )
    }

    // MARK: - Diagnostics

    /// 位置ログ（有効時のみ）に、現在のスクリーン構成と全ウィンドウの位置を記録する。
    /// `context` はログが有効なときだけ評価される。
    private func logPositionEvent(_ event: String, context: @autoclosure () -> [String: String]? = nil) {
        guard PositionLogger.shared.isEnabled else { return }
        PositionLogger.shared.log(
            event: event,
            screens: PositionLogger.shared.currentScreenSnapshots(),
            windows: zOrderedWindows.map { PositionLogger.shared.windowSnapshot(from: $0) },
            context: context()
        )
    }

    private func logScreenLayout(_ screens: [ScreenInfo], label: String) {
        for screen in screens {
            Self.screenRestorationLogger.debug(
                "  \(label, privacy: .public) screen displayID=\(screen.displayID, privacy: .public), frame=\(NSStringFromRect(screen.frame), privacy: .public)"
            )
        }
    }

    private func logWindowPositions(label: String) {
        for imageWindow in zOrderedWindows {
            Self.screenRestorationLogger.debug("""
                  \(label, privacy: .public) window #\(imageWindow.windowId, privacy: .public): \
                currentPos=\(NSStringFromPoint(imageWindow.window.frame.origin), privacy: .public)
                """)
        }
    }

    /// スリープ前の位置から macOS が動かしたウィンドウを位置ログに記録する（ログ有効時のみ）
    private func logWakeDrift() {
        guard PositionLogger.shared.isEnabled else { return }
        for imageWindow in zOrderedWindows {
            guard let preSleepOrigin = wakeContext.windowOrigins[imageWindow.windowId] else { continue }
            let currentOrigin = imageWindow.window.frame.origin
            let driftX = currentOrigin.x - preSleepOrigin.x
            let driftY = currentOrigin.y - preSleepOrigin.y
            guard abs(driftX) > AppConstants.wakeDetectDriftThreshold
                || abs(driftY) > AppConstants.wakeDetectDriftThreshold else { continue }
            PositionLogger.shared.log(
                event: "wake.detect",
                screens: PositionLogger.shared.currentScreenSnapshots(),
                windows: [PositionLogger.shared.windowSnapshot(from: imageWindow)],
                context: [
                    "preSleepOrigin": NSStringFromPoint(preSleepOrigin),
                    "currentOrigin": NSStringFromPoint(currentOrigin),
                    "driftX": String(format: "%.1f", driftX),
                    "driftY": String(format: "%.1f", driftY),
                ]
            )
        }
    }
}

// MARK: - NSScreen Helpers

extension NSScreen {
    /// スクリーンの CGDirectDisplayID を取得
    var displayID: CGDirectDisplayID? {
        deviceDescription[AppConstants.screenNumberKey] as? CGDirectDisplayID
    }

    /// 再起動をまたいでも変わらないディスプレイ UUID（ベンダー・モデル・シリアル由来）
    var displayUUID: String? {
        guard let displayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }

    /// 指定された矩形と最も大きく重なるスクリーンを返す。どのスクリーンとも重ならなければ nil。
    static func screen(containing rect: NSRect) -> NSScreen? {
        let screens = screens
        return ScreenRestorationUtils.indexOfLargestOverlap(for: rect, in: screens.map(\.frame))
            .map { screens[$0] }
    }
}
