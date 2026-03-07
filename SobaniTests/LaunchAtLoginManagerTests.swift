import XCTest
import ServiceManagement
@testable import Sobani

/// シングルトンの一貫性、ステータス取得、トグル動作を検証するテスト（SMAppServiceはコード署名環境でのみ完全動作）
final class LaunchAtLoginManagerTests: XCTestCase {

    /// sharedインスタンスが同一オブジェクトであることを検証
    func testSharedInstanceIsSingleton() {
        XCTAssertTrue(LaunchAtLoginManager.shared === LaunchAtLoginManager.shared)
    }

    /// isEnabledがstatusの.enabled判定と一致することを検証
    func testIsEnabledReflectsStatus() {
        let manager = LaunchAtLoginManager.shared
        XCTAssertEqual(manager.isEnabled, manager.status == .enabled)
    }

    /// statusが有効なSMAppService.Statusのいずれかであることを検証
    func testStatusCanBeRead() {
        let status = LaunchAtLoginManager.shared.status
        let validStatuses: [SMAppService.Status] = [.enabled, .requiresApproval, .notRegistered, .notFound]
        XCTAssertTrue(validStatuses.contains(status))
    }

    /// 未署名環境でtoggle()がエラーをスローすることを検証（テスト環境の制約確認）
    func testToggleThrowsWhenNotSigned() {
        // In test environment (unsigned), register() is expected to fail
        // Verify that toggle() propagates errors instead of silently swallowing them
        let manager = LaunchAtLoginManager.shared
        guard manager.status != .enabled else { return }
        XCTAssertThrowsError(try manager.toggle())
    }
}
