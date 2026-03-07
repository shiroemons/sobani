import XCTest
@testable import Sobani

/// オンボーディングの表示判定、完了マーク、リセット、バージョン管理、DI対応を検証するテスト
final class OnboardingManagerTests: XCTestCase {
    private let suiteName = "test-onboarding"
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var testDefaults: UserDefaults!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var manager: OnboardingManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        testDefaults.removePersistentDomain(forName: suiteName)
        manager = OnboardingManager(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        manager = nil
        super.tearDown()
    }

    /// 初期状態でオンボーディング表示が必要と判定されることを検証
    func testShouldShowOnboarding_initialState() {
        XCTAssertTrue(manager.shouldShowOnboarding)
    }

    /// 完了後にオンボーディング表示が不要と判定されることを検証
    func testShouldShowOnboarding_afterCompletion() {
        manager.markCompleted()
        XCTAssertFalse(manager.shouldShowOnboarding)
    }

    /// リセット後にオンボーディング表示が再度必要と判定されることを検証
    func testShouldShowOnboarding_afterReset() {
        manager.markCompleted()
        manager.reset()
        XCTAssertTrue(manager.shouldShowOnboarding)
    }

    /// 古いバージョンで完了済みの場合に再表示が必要と判定されることを検証
    func testShouldShowOnboarding_olderVersion() {
        testDefaults.set(0, forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertTrue(manager.shouldShowOnboarding)
    }

    /// 同じバージョンで完了済みの場合に表示不要と判定されることを検証
    func testShouldShowOnboarding_sameVersion() {
        testDefaults.set(AppConstants.Onboarding.currentVersion, forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertFalse(manager.shouldShowOnboarding)
    }

    /// 完了マークで正しいバージョン番号が保存されることを検証
    func testMarkCompleted_setsCorrectVersion() {
        manager.markCompleted()
        let stored = testDefaults.integer(forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertEqual(stored, AppConstants.Onboarding.currentVersion)
    }

    /// リセットでUserDefaultsからキーが削除されることを検証
    func testReset_removesKey() {
        manager.markCompleted()
        manager.reset()
        let stored = testDefaults.object(forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertNil(stored)
    }

    /// カスタムUserDefaultsによるDIで独立した状態管理ができることを検証
    func testDependencyInjection_customDefaults() throws {
        let otherSuite = "test-onboarding-other"
        let otherDefaults = try XCTUnwrap(UserDefaults(suiteName: otherSuite))
        otherDefaults.removePersistentDomain(forName: otherSuite)
        let otherManager = OnboardingManager(defaults: otherDefaults)

        manager.markCompleted()
        XCTAssertTrue(otherManager.shouldShowOnboarding)

        otherDefaults.removePersistentDomain(forName: otherSuite)
    }

    /// 複数回の完了マークが冪等であることを検証
    func testMultipleMarkCompleted_idempotent() {
        manager.markCompleted()
        manager.markCompleted()
        manager.markCompleted()
        let stored = testDefaults.integer(forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertEqual(stored, AppConstants.Onboarding.currentVersion)
        XCTAssertFalse(manager.shouldShowOnboarding)
    }

    /// sharedインスタンスが存在することを検証
    func testSharedInstance_exists() {
        XCTAssertNotNil(OnboardingManager.shared)
    }
}
