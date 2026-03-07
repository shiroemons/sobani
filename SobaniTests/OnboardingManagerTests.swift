import Foundation
import Testing
@preconcurrency @testable import Sobani

/// オンボーディングの表示判定、完了マーク、リセット、バージョン管理、DI対応を検証するテスト
@Suite struct OnboardingManagerTests {
    private let testDefaults: UserDefaults
    private let manager: OnboardingManager
    private let suiteName: String

    init() throws {
        suiteName = "test-onboarding-\(UUID().uuidString)"
        testDefaults = try #require(UserDefaults(suiteName: suiteName))
        testDefaults.removePersistentDomain(forName: suiteName)
        manager = OnboardingManager(defaults: testDefaults)
    }

    /// 初期状態でオンボーディング表示が必要と判定されることを検証
    @Test func shouldShowOnboarding_initialState() {
        #expect(manager.shouldShowOnboarding)
    }

    /// 完了後にオンボーディング表示が不要と判定されることを検証
    @Test func shouldShowOnboarding_afterCompletion() {
        manager.markCompleted()
        #expect(!manager.shouldShowOnboarding)
    }

    /// リセット後にオンボーディング表示が再度必要と判定されることを検証
    @Test func shouldShowOnboarding_afterReset() {
        manager.markCompleted()
        manager.reset()
        #expect(manager.shouldShowOnboarding)
    }

    /// 古いバージョンで完了済みの場合に再表示が必要と判定されることを検証
    @Test func shouldShowOnboarding_olderVersion() {
        testDefaults.set(0, forKey: AppConstants.Onboarding.completedVersionKey)
        #expect(manager.shouldShowOnboarding)
    }

    /// 同じバージョンで完了済みの場合に表示不要と判定されることを検証
    @Test func shouldShowOnboarding_sameVersion() {
        testDefaults.set(AppConstants.Onboarding.currentVersion, forKey: AppConstants.Onboarding.completedVersionKey)
        #expect(!manager.shouldShowOnboarding)
    }

    /// 完了マークで正しいバージョン番号が保存されることを検証
    @Test func markCompleted_setsCorrectVersion() {
        manager.markCompleted()
        let stored = testDefaults.integer(forKey: AppConstants.Onboarding.completedVersionKey)
        #expect(stored == AppConstants.Onboarding.currentVersion)
    }

    /// リセットでUserDefaultsからキーが削除されることを検証
    @Test func reset_removesKey() {
        manager.markCompleted()
        manager.reset()
        let stored = testDefaults.object(forKey: AppConstants.Onboarding.completedVersionKey)
        #expect(stored == nil)
    }

    /// カスタムUserDefaultsによるDIで独立した状態管理ができることを検証
    @Test func dependencyInjection_customDefaults() throws {
        let otherSuite = "test-onboarding-other-\(UUID().uuidString)"
        let otherDefaults = try #require(UserDefaults(suiteName: otherSuite))
        otherDefaults.removePersistentDomain(forName: otherSuite)
        let otherManager = OnboardingManager(defaults: otherDefaults)

        manager.markCompleted()
        #expect(otherManager.shouldShowOnboarding)

        otherDefaults.removePersistentDomain(forName: otherSuite)
    }

    /// 複数回の完了マークが冪等であることを検証
    @Test func multipleMarkCompleted_idempotent() {
        manager.markCompleted()
        manager.markCompleted()
        manager.markCompleted()
        let stored = testDefaults.integer(forKey: AppConstants.Onboarding.completedVersionKey)
        #expect(stored == AppConstants.Onboarding.currentVersion)
        #expect(!manager.shouldShowOnboarding)
    }

    /// sharedインスタンスが存在することを検証
    @Test func sharedInstance_exists() {
        #expect(OnboardingManager.shared != nil)
    }
}
