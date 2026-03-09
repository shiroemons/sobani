import Foundation
import os.log

@MainActor
final class OnboardingManager {
    static let shared = OnboardingManager()

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: "OnboardingManager")

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldShowOnboarding: Bool {
        let completedVersion = defaults.integer(forKey: AppConstants.Onboarding.completedVersionKey)
        return completedVersion < AppConstants.Onboarding.currentVersion
    }

    func markCompleted() {
        defaults.set(AppConstants.Onboarding.currentVersion, forKey: AppConstants.Onboarding.completedVersionKey)
        logger.info("Onboarding completed for version \(AppConstants.Onboarding.currentVersion)")
    }

    func reset() {
        defaults.removeObject(forKey: AppConstants.Onboarding.completedVersionKey)
        logger.info("Onboarding state reset")
    }
}
