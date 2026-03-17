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
        #expect(action == #selector(SPUUpdater.checkForUpdates))
    }

    /// updaterTargetがSPUUpdaterインスタンスであることを検証
    @Test func updaterTargetIsExpectedType() {
        let target = SparkleManager.shared.updaterTarget
        #expect(target is SPUUpdater)
    }

}
