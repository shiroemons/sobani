import Cocoa
import os.log

// MARK: - App Delegate

/// Sobani アプリケーションのメインデリゲート。
///
/// メニューバー専用アプリ（`LSUIElement`）として動作し、ステータスバーメニュー、
/// ウィンドウのライフサイクル管理、ホットキー監視、画面復元を統括する。
/// ウィンドウの重なり順は `zOrderedWindows` 配列で管理される。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let logger = Logger(category: "AppDelegate")
    /// Z順（前面→背面）でウィンドウを管理する単一配列。
    var zOrderedWindows: [ImageWindow] = []
    var statusItem: NSStatusItem?
    private var shouldTerminate = false
    private var shouldSkipSave = false
    /// 直近に willPowerOff（ログアウト・再起動・システム終了）を受けた時刻
    var powerOffRequestedAt: Date?
    /// すべてのウィンドウが非表示か。各ウィンドウの `isHidden` から導出する（二重管理による不整合を防ぐ）。
    var areWindowsHidden: Bool {
        !zOrderedWindows.isEmpty && zOrderedWindows.allSatisfy(\.isHidden)
    }
    var nextWindowId: Int = 1
    let screenRestorationManager = ScreenRestorationManager()
    var screenChangeDebounceTimer: Timer?
    var snapshotDebounceTimer: Timer?
    var pendingSnapshotTriggers: Set<AppConstants.SnapshotTrigger> = []
    var wakeContext = WakeRestorationContext()
    /// ディスプレイ切断時の復元用スナップショット。安定状態で定期的に更新される。
    var screenSnapshot = WakeRestorationContext()
    /// 起動直後のディスプレイ構成変化に追従するためのアンカー復元状態
    var launchContext = LaunchRestorationContext()
    var launchRestoreTimer: Timer?
    var persistDebounceTimer: Timer?
    /// 最後に書き込んだ状態（変化がなければ書き込みを省く）
    var lastPersistedStates: [WindowState] = []
    /// 起動時に読み込んだ状態（「保存せずに終了」で書き戻す。随時保存で上書き済みのため）
    private var statesAtLaunch: [WindowState] = []
    /// 直近の画面構成変更時刻（直後の保存を見送る判定に使う）
    var lastScreenChangeAt: Date?
    var windowGeometryObservers: [NSObjectProtocol] = []
    var onboardingController: OnboardingWindowController?
    weak var lastHighlightedWindow: ImageWindow?
    private var managementPanelController: ManagementPanelController?
    /// `setWindowsHidden` でまとめて表示状態を変えている間か（Z-order の再適用を最後の 1 回にまとめる）
    private var isBatchingVisibilityChanges = false

    /// ユニットテストのホストとして起動されたか。
    ///
    /// テストはこのアプリをホストに実行されるため、通常起動すると実ユーザーの
    /// `window_states.json` などを読み書きし、ステータスバーやホットキーも登録してしまう。
    nonisolated static var isRunningUnitTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier"]
            .contains { environment[$0] != nil }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningUnitTests else {
            logger.notice("Running as unit test host; skipping launch sequence")
            return
        }
        NSApp.appearance = AppThemeSettings.currentTheme.nsAppearance
        setupStatusBar()
        SparkleManager.shared.startUpdater()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshHotkeyMonitors),
            name: AppConstants.hotkeySettingsDidChange,
            object: nil
        )
        if HotkeySettings.isEnabled {
            setupHotkeyMonitors()
        }
        screenRestorationManager.loadPending()

        let savedStates = WindowStateManager.shared.loadStates()
        statesAtLaunch = savedStates
        lastPersistedStates = savedStates
        logStates(event: "states.load", savedStates)

        if savedStates.isEmpty {
            // デフォルト画像が読めなくても、監視の登録やオンボーディングは続ける（早期 return しない）
            if let image = ImageManager.shared.defaultImage() {
                let imageWindow = makeImageWindow(
                    image: image, displayName: AppConstants.defaultImageName, windowId: issueWindowId()
                )
                imageWindow.window.center()
                zOrderedWindows.append(imageWindow)
            } else {
                logger.error("Failed to load default image")
            }
        } else {
            var loadedWindows: [ImageWindow] = []
            var resolutions: [WindowState.RestoreResolution?] = []
            let screens = ScreenInfo.current()
            for state in savedStates {
                let imageWindow = createImageWindow(from: state)
                resolutions.append(imageWindow.restore(from: state, screens: screens))
                loadedWindows.append(imageWindow)
            }

            // Legacy states (windowId == 0) get new IDs assigned
            let migrationResult = Self.migrateWindowIds(
                existingIds: loadedWindows.map(\.windowId),
                legacyId: 0
            )
            for assignment in migrationResult.assignments {
                loadedWindows[assignment.oldIndex].windowId = assignment.newId
            }
            nextWindowId = migrationResult.nextId

            beginLaunchRestoration(
                windows: loadedWindows, savedStates: savedStates, resolutions: resolutions, screens: screens
            )

            zOrderedWindows = loadedWindows.reversed()
        }

        NSApp.activate()

        if OnboardingManager.shared.shouldShowOnboarding {
            if savedStates.isEmpty {
                let controller = OnboardingWindowController()
                controller.onAddImage = { [weak self] in
                    self?.changeDefaultImageFromMenu()
                }
                controller.onFinish = { [weak self] in
                    self?.statusItem?.button?.performClick(nil)
                }
                controller.show()
                onboardingController = controller
            } else {
                OnboardingManager.shared.markCompleted()
            }
        }

        setupScreenRestorationObservers()
        setupStatePersistenceObservers()
        pendingSnapshotTriggers.insert(.launch)
        updateScreenSnapshot()

        // ペンディングキューが存在する場合、起動直後に画面変化チェックをトリガー
        if screenRestorationManager.hasPending {
            handleScreenChange()
        }
    }

    @objc func bringAllToFront() {
        NSApp.activate()
        setWindowsHidden(false)
    }

    @objc func toggleAllWindowsVisibility() {
        toggleWindows(zOrderedWindows)
    }

    /// 指定ウィンドウ（省略時は全ウィンドウ）の表示状態をまとめて変更する。
    ///
    /// 表示に戻したときの Z-order の再適用は `imageWindowDidChangeHidden` が行うが、
    /// ここではウィンドウごとに適用せず最後に 1 回だけ適用する。
    func setWindowsHidden(_ hidden: Bool, windows: [ImageWindow]? = nil) {
        let targets = windows ?? zOrderedWindows
        isBatchingVisibilityChanges = true
        for imageWindow in targets where imageWindow.isHidden != hidden {
            imageWindow.setHidden(hidden)
        }
        isBatchingVisibilityChanges = false
        if !hidden {
            applyZOrderToWindows()
        }
    }

    /// すべて非表示なら表示し、1つでも表示中ならすべて非表示にする。
    private func toggleWindows(_ windows: [ImageWindow]) {
        guard !windows.isEmpty else { return }
        setWindowsHidden(!windows.allSatisfy(\.isHidden), windows: windows)
    }

    /// マウスカーソルのあるスクリーンに（最も大きく重なって）表示されているウィンドウ
    private func windowsOnCurrentScreen() -> [ImageWindow] {
        let screenFrames = NSScreen.screens.map(\.frame)
        guard let currentIndex = ScreenRestorationUtils.indexOfScreen(
            containingMouseLocation: NSEvent.mouseLocation, in: screenFrames
        ) else { return [] }

        return zOrderedWindows.filter { imageWindow in
            ScreenRestorationUtils.indexOfLargestOverlap(for: imageWindow.window.frame, in: screenFrames) == currentIndex
        }
    }

    func toggleCurrentScreenWindowsVisibility() {
        toggleWindows(windowsOnCurrentScreen())
    }

    @objc func addNewWindowFromMenu() { createNewWindow() }

    @objc func addNewWindowWithImageFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        createNewWindow(imageName: name)
    }

    /// zOrderedWindowsの順序をNSWindowに反映する（最背面から順に重ねる）
    func applyZOrderToWindows() {
        var previousWindow: ImageWindow?
        for imageWindow in zOrderedWindows.reversed() {
            guard !imageWindow.isHidden else { continue }
            if let prev = previousWindow {
                imageWindow.window.order(.above, relativeTo: prev.window.windowNumber)
            } else {
                imageWindow.window.orderFront(nil)
            }
            previousWindow = imageWindow
        }
    }

    /// windowNumber から ImageWindow を検索
    func imageWindow(forWindowNumber number: Int) -> ImageWindow? {
        return zOrderedWindows.first { $0.window.windowNumber == number }
    }

    func notifyWindowListDidChange(_ trigger: AppConstants.SnapshotTrigger) {
        NotificationCenter.default.post(
            name: AppConstants.imageWindowListDidChange,
            object: nil,
            userInfo: [AppConstants.notificationTriggerKey: trigger.rawValue]
        )
    }

    func moveWindowToFront(_ imageWindow: ImageWindow) {
        // クリックのたびに呼ばれるため、すでに最前面なら並べ替えと通知（保存・スナップショット・パネル再構築）を省く
        guard zOrderedWindows.first !== imageWindow else { return }
        zOrderedWindows = ZOrderUtils.moveToFront(imageWindow, in: zOrderedWindows)
        applyZOrderToWindows()
        notifyWindowListDidChange(.zorder)
    }

    func moveWindowForward(_ imageWindow: ImageWindow) {
        zOrderedWindows = ZOrderUtils.moveForward(imageWindow, in: zOrderedWindows)
        applyZOrderToWindows()
        notifyWindowListDidChange(.zorder)
    }

    func moveWindowBackward(_ imageWindow: ImageWindow) {
        zOrderedWindows = ZOrderUtils.moveBackward(imageWindow, in: zOrderedWindows)
        applyZOrderToWindows()
        notifyWindowListDidChange(.zorder)
    }

    func moveWindowToBack(_ imageWindow: ImageWindow) {
        zOrderedWindows = ZOrderUtils.moveToBack(imageWindow, in: zOrderedWindows)
        applyZOrderToWindows()
        notifyWindowListDidChange(.zorder)
    }

    @objc func closeAllWindows() {
        for imageWindow in zOrderedWindows {
            imageWindow.dismissAuxiliaryPanels()
            imageWindow.window.orderOut(nil)
        }
        zOrderedWindows.removeAll()
        notifyWindowListDidChange(.closeAll)
        quitIfNoWindows()
    }

    /// すべてのウィンドウが閉じられた場合にアプリを終了する。
    ///
    /// `applicationShouldTerminate` は常に `.terminateCancel` を返すため、
    /// 終了は `shouldTerminate` フラグを設定してからこのメソッドを呼ぶか、
    /// 明示的な終了アクション経由で行う必要がある。
    func quitIfNoWindows() {
        guard zOrderedWindows.isEmpty else { return }
        shouldTerminate = true
        NSApp.terminate(nil)
    }

    @objc func quitFromMenu() {
        let alert = AlertFactory.confirmation(
            messageText: L("quit.confirm_title"),
            informativeText: L("quit.confirm_message"),
            okTitle: L("quit.button"),
            cancelTitle: L("quit.cancel")
        )
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        shouldTerminate = true
        NSApp.terminate(nil)
    }

    func requestQuit() { quitFromMenu() }

    @objc func quitWithoutSavingFromMenu() {
        shouldSkipSave = true
        shouldTerminate = true
        NSApp.terminate(nil)
    }

    func requestQuitWithoutSaving() { quitWithoutSavingFromMenu() }

    /// 新しいキャラクターウィンドウを作成して表示する。
    ///
    /// - Parameter imageName: 表示する画像名。`nil` の場合はデフォルト画像を使用する。
    func createNewWindow(imageName: String? = nil) {
        if areWindowsHidden {
            setWindowsHidden(false)
        }
        let image: NSImage
        if let name = imageName,
            let registered = ImageManager.shared.loadRegisteredImage(named: name) {
            image = registered
        } else {
            image = ImageManager.shared.defaultImage() ?? NSImage()
        }
        let imageWindow = makeImageWindow(
            image: image, displayName: imageName ?? AppConstants.defaultImageName, windowId: issueWindowId()
        )
        addImageWindow(imageWindow)
    }

    /// 外部の画像ファイルを登録し、新しいウィンドウで開く。登録に失敗した場合は開かない。
    ///
    /// - Returns: ウィンドウを開けたかどうか。
    @discardableResult
    func createNewWindow(registeringImageAt url: URL) -> Bool {
        guard let savedName = ImageManager.shared.registerImage(from: url) else {
            logger.error("Failed to register image for new window")
            return false
        }
        createNewWindow(imageName: savedName)
        return true
    }

    @objc func addNewWindowWithNewImageFromMenu() {
        let panel = ImageFileDialog.makeOpenPanel(message: L("file.select_new_image_message"))
        if panel.runModal() == .OK, let url = panel.url, !createNewWindow(registeringImageAt: url) {
            ImageFileDialog.showLoadFailedAlert(fileNames: [url.lastPathComponent])
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let quitReason = NSAppleEventManager.shared().currentAppleEvent?
            .attributeDescriptor(forKeyword: kAEQuitReason)?.enumCodeValue
        let reply = Self.terminateReply(
            shouldTerminate: shouldTerminate,
            isInstallingUpdate: SparkleManager.shared.isInstallingUpdate,
            quitReason: quitReason,
            powerOffRequestedAt: powerOffRequestedAt
        )
        if reply == .terminateNow && !shouldTerminate {
            logger.notice("Terminating for system quit (reason=\(quitReason ?? 0, privacy: .public))")
        }
        return reply
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !Self.isRunningUnitTests else { return }
        if shouldSkipSave {
            // 随時保存でセッション中の変更が書き込まれているため、起動時の状態に戻す
            persistDebounceTimer?.invalidate()
            WindowStateManager.shared.saveStates(statesAtLaunch)
        } else {
            let count = persistNow(includingPending: true)
            logger.notice("Saved \(count, privacy: .public) window states on terminate")
        }
        unregisterHotkeyMonitors()
        teardownScreenRestorationObservers()
        teardownStatePersistenceObservers()
    }

}

// MARK: - ImageWindowDelegate

extension AppDelegate: ImageWindowDelegate {
    var allImageWindows: [ImageWindow] { zOrderedWindows }

    func imageWindowRequestedNewWindow(_ sender: ImageWindow, imageName: String?) {
        createNewWindow(imageName: imageName)
    }

    func imageWindowRequestedNewWindowWithFileURL(_ sender: ImageWindow, fileURL: URL) {
        if !createNewWindow(registeringImageAt: fileURL) {
            ImageFileDialog.showLoadFailedAlert(fileNames: [fileURL.lastPathComponent])
        }
    }

    func imageWindowDidClose(_ sender: ImageWindow) {
        removeImageWindow(sender)
        quitIfNoWindows()
    }

    func imageWindowDidBecomeActive(_ sender: ImageWindow) {
        moveWindowToFront(sender)
    }

    /// 表示に戻したウィンドウを `zOrderedWindows` の重なり順に戻す（`orderFront` だけでは最前面に出てしまう）。
    ///
    /// ステータスメニューは開くたびに作り直すため、メニュー側の更新は不要。
    func imageWindowDidChangeHidden(_ sender: ImageWindow) {
        guard !sender.isHidden, !isBatchingVisibilityChanges else { return }
        applyZOrderToWindows()
    }

    func imageWindowDidDeleteImage(named name: String) {
        for imageWindow in zOrderedWindows where imageWindow.displayName == name {
            imageWindow.resetToDefault()
        }
    }
}

// MARK: - Settings Actions

extension AppDelegate {
    @objc func toggleLaunchAtLogin() {
        let manager = LaunchAtLoginManager.shared
        do {
            try manager.setEnabled(!manager.isEnabled)
        } catch {
            logger.error("Failed to toggle launch at login: \(error.localizedDescription, privacy: .public)")
            manager.openSystemSettingsIfApprovalRequired()
        }
    }

    @objc func toggleWindowSnap(_ sender: NSMenuItem) {
        let current = SnapSettings.isEnabled
        SnapSettings.isEnabled = !current
        sender.state = !current ? .on : .off
    }

    @objc func showManagementPanel() {
        if managementPanelController == nil {
            managementPanelController = ManagementPanelController(appDelegate: self)
        }
        managementPanelController?.toggle()
    }
}

// MARK: - Ghost Mode

extension AppDelegate {
    @objc func toggleAllGhostMode() {
        toggleGhostMode(for: zOrderedWindows)
    }

    func toggleCurrentScreenGhostMode() {
        toggleGhostMode(for: windowsOnCurrentScreen())
    }

    /// 1つでもゴーストモードならすべて解除し、そうでなければすべてゴーストモードにする。
    private func toggleGhostMode(for windows: [ImageWindow]) {
        let anyGhosted = windows.contains(where: \.isGhostMode)
        for imageWindow in windows {
            imageWindow.setGhostMode(!anyGhosted)
        }
    }

    @objc func disableAllGhostMode() {
        for imageWindow in zOrderedWindows {
            imageWindow.setGhostMode(false)
        }
    }

    /// ゴーストモードの共通 alpha を変更し、全ウィンドウの見た目に反映する。
    ///
    /// 個別 alpha を持つウィンドウやゴーストでないウィンドウは `refreshImageAlpha()` の結果が変わらないため、
    /// 絞り込まずに全ウィンドウへ適用してよい。
    func applyGlobalGhostAlpha(_ alpha: CGFloat) {
        GhostModeSettings.globalAlpha = alpha
        for imageWindow in zOrderedWindows {
            imageWindow.refreshImageAlpha()
        }
    }
}
