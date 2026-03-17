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

    private lazy var updater = SPUUpdater(
        hostBundle: .main,
        applicationBundle: .main,
        userDriver: SPUStandardUserDriver(hostBundle: .main, delegate: nil),
        delegate: self
    )

    override init() {
        super.init()
    }

    /// Sparkle のアップデーターを開始する。
    /// `applicationDidFinishLaunching` から呼び出すこと。
    func startUpdater() {
        do {
            try updater.start()
            logger.info("Sparkle アップデーターを開始しました")
        } catch {
            logger.error("Sparkle アップデーターの開始に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// NSMenuItem から呼び出されるアップデート確認アクション。
    /// LSUIElement アプリでダイアログが前面に表示されるよう NSApp をアクティブ化してから実行する。
    @objc func checkForUpdates(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
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

    // MARK: - SPUUpdaterDelegate

    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        Task { @MainActor [weak self] in
            self?.isInstallingUpdate = true
            self?.logger.info("Sparkle: アップデートをインストールします - \(version, privacy: .public)")
        }
    }
}
