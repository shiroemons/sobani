import AppKit
import Combine
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
    private static let sparkleAutomaticallyUpdateKey = "SUAutomaticallyUpdate"

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
        UserDefaults.standard.removeObject(forKey: Self.sparkleAutomaticallyUpdateKey)
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

    /// `canCheckForUpdates` の変化を流すパブリッシャー（購読時に現在値も流す）。
    ///
    /// 確認中・ダウンロード中に値が変わるが、`SPUUpdater.canCheckForUpdates` は KVO に対応しているため
    /// ポーリングせずに追従できる。SwiftUI の `onReceive` に描画のたびに新しいパブリッシャーを渡さないよう保持する。
    private(set) lazy var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> =
        updater.publisher(for: \.canCheckForUpdates).eraseToAnyPublisher()

    // MARK: - Private Helpers

    private func bringAppToForeground() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    private func restoreBackgroundPolicy() {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - SPUUpdaterDelegate
    // SPUUpdaterDelegate は NS_SWIFT_UI_ACTOR（メインアクター）のため、各メソッドで同期的に状態を更新できる。

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        // 同じランループ内で届く終了要求を applicationShouldTerminate が許可できるよう、同期的に立てる
        isInstallingUpdate = true
        logger.info(
            "Sparkle: アップデートをインストールします - \(item.displayVersionString, privacy: .public)"
        )
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        logger.info(
            "Sparkle: 新しいアップデートが見つかりました - \(item.displayVersionString, privacy: .public)"
        )
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        logger.info("Sparkle: 新しいアップデートはありません")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        logger.error(
            "Sparkle: アップデートチェックが中断されました - \(error.localizedDescription, privacy: .public)"
        )
    }
}

// MARK: - SPUStandardUserDriverDelegate

// SPUStandardUserDriverDelegate 自体にアクター指定はないが、呼び出し元の SPUStandardUserDriver が
// メインアクター専用のため、各メソッドはメインスレッドで呼ばれる。ダイアログ表示より先に前面化を
// 済ませるため、Task で後回しにせず同期的に処理する。
extension SparkleManager: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { false }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard handleShowingUpdate else { return }
        MainActor.assumeIsolated {
            bringAppToForeground()
            logger.info("Sparkle: 更新ダイアログ表示のためアプリを前面に移動しました")
        }
    }

    nonisolated func standardUserDriverWillShowModalAlert() {
        MainActor.assumeIsolated {
            bringAppToForeground()
            logger.info("Sparkle: モーダルアラート表示のためアプリを前面に移動しました")
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated {
            restoreBackgroundPolicy()
            logger.info("Sparkle: 更新セッション終了、アクティベーションポリシーを復元しました")
        }
    }
}
