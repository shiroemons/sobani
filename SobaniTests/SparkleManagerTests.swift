import Foundation
import Sparkle
import Testing
@testable import Sobani

/// SparkleManagerのシングルトン一貫性・プロパティアクセスを検証するテスト
@Suite @MainActor struct SparkleManagerTests {

    /// sharedインスタンスが同一オブジェクトであることを検証
    @Test func sharedInstanceIsSingleton() {
        #expect(SparkleManager.shared === SparkleManager.shared)
    }

    /// checkForUpdatesActionが有効なSelectorを返すことを検証
    @Test func checkForUpdatesActionIsValidSelector() {
        let action = SparkleManager.shared.checkForUpdatesAction
        #expect(action == #selector(SparkleManager.checkForUpdates(_:)))
    }

    /// updaterTargetがSparkleManagerインスタンスであることを検証
    @Test func updaterTargetIsExpectedType() {
        let target = SparkleManager.shared.updaterTarget
        #expect(target is SparkleManager)
    }

    /// isInstallingUpdateの初期値がfalseであることを検証
    @Test func isInstallingUpdateDefaultsToFalse() {
        #expect(SparkleManager.shared.isInstallingUpdate == false)
    }

    /// canCheckForUpdatesがBoolを返すことを検証
    @Test func canCheckForUpdatesReturnsBool() {
        // canCheckForUpdates はUpdater起動前なので具体値は環境依存だが、呼び出し可能であることを確認
        _ = SparkleManager.shared.canCheckForUpdates
    }

    /// startUpdaterがクラッシュしないことを検証
    @Test func startUpdaterDoesNotCrash() {
        // テスト環境ではSparkle更新チェックは失敗するが、クラッシュしないことを確認
        SparkleManager.shared.startUpdater()
    }

    /// checkForUpdatesActionがresponds(to:)で確認可能であることを検証
    @Test func checkForUpdatesActionIsResponded() {
        let action = SparkleManager.shared.checkForUpdatesAction
        #expect(SparkleManager.shared.responds(to: action))
    }

    /// supportsGentleScheduledUpdateRemindersがfalseであることを検証
    @Test func supportsGentleScheduledUpdateReminders() {
        #expect(SparkleManager.shared.supportsGentleScheduledUpdateReminders == false)
    }

}
