import XCTest
import ServiceManagement
@testable import Sobani

final class LaunchAtLoginManagerTests: XCTestCase {

    func testSharedInstanceIsSingleton() {
        XCTAssertTrue(LaunchAtLoginManager.shared === LaunchAtLoginManager.shared)
    }

    func testIsEnabledReflectsStatus() {
        let manager = LaunchAtLoginManager.shared
        XCTAssertEqual(manager.isEnabled, manager.status == .enabled)
    }

    func testStatusCanBeRead() {
        let status = LaunchAtLoginManager.shared.status
        let validStatuses: [SMAppService.Status] = [.enabled, .requiresApproval, .notRegistered, .notFound]
        XCTAssertTrue(validStatuses.contains(status))
    }

    func testToggleThrowsWhenNotSigned() {
        // In test environment (unsigned), register() is expected to fail
        // Verify that toggle() propagates errors instead of silently swallowing them
        let manager = LaunchAtLoginManager.shared
        guard manager.status != .enabled else { return }
        XCTAssertThrowsError(try manager.toggle())
    }
}
