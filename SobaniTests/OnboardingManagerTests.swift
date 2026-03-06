import XCTest
@testable import Sobani

final class OnboardingManagerTests: XCTestCase {
    private let suiteName = "test-onboarding"
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var testDefaults: UserDefaults!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var manager: OnboardingManager!

    override func setUp() {
        super.setUp()
        // swiftlint:disable:next force_unwrapping
        testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removePersistentDomain(forName: suiteName)
        manager = OnboardingManager(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        manager = nil
        super.tearDown()
    }

    func testShouldShowOnboarding_initialState() {
        XCTAssertTrue(manager.shouldShowOnboarding)
    }

    func testShouldShowOnboarding_afterCompletion() {
        manager.markCompleted()
        XCTAssertFalse(manager.shouldShowOnboarding)
    }

    func testShouldShowOnboarding_afterReset() {
        manager.markCompleted()
        manager.reset()
        XCTAssertTrue(manager.shouldShowOnboarding)
    }

    func testShouldShowOnboarding_olderVersion() {
        testDefaults.set(0, forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertTrue(manager.shouldShowOnboarding)
    }

    func testShouldShowOnboarding_sameVersion() {
        testDefaults.set(AppConstants.Onboarding.currentVersion, forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertFalse(manager.shouldShowOnboarding)
    }

    func testMarkCompleted_setsCorrectVersion() {
        manager.markCompleted()
        let stored = testDefaults.integer(forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertEqual(stored, AppConstants.Onboarding.currentVersion)
    }

    func testReset_removesKey() {
        manager.markCompleted()
        manager.reset()
        let stored = testDefaults.object(forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertNil(stored)
    }

    func testDependencyInjection_customDefaults() {
        let otherSuite = "test-onboarding-other"
        // swiftlint:disable:next force_unwrapping
        let otherDefaults = UserDefaults(suiteName: otherSuite)!
        otherDefaults.removePersistentDomain(forName: otherSuite)
        let otherManager = OnboardingManager(defaults: otherDefaults)

        manager.markCompleted()
        XCTAssertTrue(otherManager.shouldShowOnboarding)

        otherDefaults.removePersistentDomain(forName: otherSuite)
    }

    func testMultipleMarkCompleted_idempotent() {
        manager.markCompleted()
        manager.markCompleted()
        manager.markCompleted()
        let stored = testDefaults.integer(forKey: AppConstants.Onboarding.completedVersionKey)
        XCTAssertEqual(stored, AppConstants.Onboarding.currentVersion)
        XCTAssertFalse(manager.shouldShowOnboarding)
    }

    func testSharedInstance_exists() {
        XCTAssertNotNil(OnboardingManager.shared)
    }
}
