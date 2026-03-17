import Foundation
import os.log
import Sparkle

// MARK: - Sparkle Update Manager

@MainActor
final class SparkleManager {
    static let shared = SparkleManager()
    private let logger = Logger(category: "SparkleManager")
    private let updater: SPUUpdater

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(
        updater: SPUUpdater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: SPUStandardUserDriver(hostBundle: .main, delegate: nil),
            delegate: nil
        )
    ) {
        self.updater = updater
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

    /// メニューアイテムに接続するアクション。
    var checkForUpdatesAction: Selector {
        #selector(SPUUpdater.checkForUpdates)
    }

    /// メニューアイテムの target として使用するオブジェクト。
    var updaterTarget: AnyObject {
        updater
    }

    /// アップデート確認が現在可能かどうか。
    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

}
