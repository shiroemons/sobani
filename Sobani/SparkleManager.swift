import AppKit
import os.log
import Sparkle

// MARK: - Sparkle Update Manager

@MainActor
final class SparkleManager: NSObject, SPUUpdaterDelegate {
    static let shared = SparkleManager()
    private let logger = Logger(category: "SparkleManager")

    /// Sparkle がアップデートのインストールを開始したかどうか。
    /// `AppDelegate.applicationShouldTerminate` で終了を許可するために使用。
    private(set) var isInstallingUpdate = false
    private static let sparkleLastCheckTimeKey = "SULastCheckTime"

    private lazy var userDriver = SPUStandardUserDriver(hostBundle: .main, delegate: self)
    private lazy var updater = SPUUpdater(
        hostBundle: .main,
        applicationBundle: .main,
        userDriver: userDriver,
        delegate: self
    )

    override init() {
        super.init()
    }

    /// Sparkle のアップデーターを開始する。
    /// `applicationDidFinishLaunching` から呼び出すこと。
    func startUpdater() {
        // 起動時に必ず更新チェックを実行するため、
        // 前回チェック時刻をリセット
        UserDefaults.standard.removeObject(forKey: Self.sparkleLastCheckTimeKey)
        // ダイアログなしの自動インストールを無効化
        // （UserDefaultsに保存された値がInfo.plistの設定を上書きするため）
        UserDefaults.standard.removeObject(forKey: "SUAutomaticallyUpdate")
        do {
            try updater.start()
            logger.info("Sparkle アップデーターを開始しました")
        } catch {
            logger.error(
                "Sparkle アップデーターの開始に失敗しました: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// NSMenuItem から呼び出されるアップデート確認アクション。
    /// LSUIElement アプリでダイアログが前面に表示されるよう
    /// NSApp をアクティブ化してから実行する。
    @objc func checkForUpdates(_ sender: Any?) {
        bringAppToForeground()
        updater.checkForUpdates()
    }

    /// メニューアイテムに接続するアクション。
    var checkForUpdatesAction: Selector {
        #selector(checkForUpdates(_:))
    }

    /// メニューアイテムの target として使用するオブジェクト。
    var updaterTarget: AnyObject {
        self
    }

    /// アップデート確認が現在可能かどうか。
    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    // MARK: - Private Helpers

    private func bringAppToForeground() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restoreBackgroundPolicy() {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - SPUUpdaterDelegate

    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor [weak self] in
            self?.isInstallingUpdate = true
            self?.logger.info(
                "Sparkle: アップデートをインストールします - \(version, privacy: .public)"
            )
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        logger.info(
            "Sparkle: 新しいアップデートが見つかりました - \(item.displayVersionString, privacy: .public)"
        )
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        logger.info("Sparkle: 新しいアップデートはありません")
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        logger.error(
            "Sparkle: アップデートチェックが中断されました - \(error.localizedDescription, privacy: .public)"
        )
    }
}

// MARK: - SPUStandardUserDriverDelegate

extension SparkleManager: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { false }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        if handleShowingUpdate {
            Task { @MainActor [weak self] in
                self?.bringAppToForeground()
                self?.logger.info(
                    "Sparkle: 更新ダイアログ表示のためアプリを前面に移動しました"
                )
            }
        }
    }

    nonisolated func standardUserDriverWillShowModalAlert() {
        Task { @MainActor [weak self] in
            self?.bringAppToForeground()
            self?.logger.info(
                "Sparkle: モーダルアラート表示のためアプリを前面に移動しました"
            )
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor [weak self] in
            self?.restoreBackgroundPolicy()
            self?.logger.info(
                "Sparkle: 更新セッション終了、アクティベーションポリシーを復元しました"
            )
        }
    }
}
