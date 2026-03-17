import Foundation
import os.log
import Sparkle

// MARK: - Sparkle Update Manager

@MainActor
final class SparkleManager {
    static let shared = SparkleManager()
    private let logger = Logger(category: "SparkleManager")
    private let updaterController: SPUStandardUpdaterController

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(updaterController: SPUStandardUpdaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )) {
        self.updaterController = updaterController
    }

    /// Sparkle のアップデーターを開始する。
    /// `applicationDidFinishLaunching` から呼び出すこと。
    func startUpdater() {
        updaterController.startUpdater()
        logger.info("Sparkle アップデーターを開始しました")
    }

    /// メニューアイテムに接続するアクション。
    var checkForUpdatesAction: Selector {
        #selector(SPUStandardUpdaterController.checkForUpdates(_:))
    }

    /// メニューアイテムの target として使用するオブジェクト。
    var updaterTarget: AnyObject {
        updaterController
    }

}
