import Foundation
import ServiceManagement
import Testing
@testable import Sobani

/// シングルトンの一貫性、ステータス取得、トグル動作を検証するテスト（SMAppServiceはコード署名環境でのみ完全動作）
@Suite @MainActor struct LaunchAtLoginManagerTests {

    /// sharedインスタンスが同一オブジェクトであることを検証
    @Test func sharedInstanceIsSingleton() {
        #expect(LaunchAtLoginManager.shared === LaunchAtLoginManager.shared)
    }

    /// isEnabledがstatusの.enabled判定と一致することを検証
    @Test func isEnabledReflectsStatus() {
        let manager = LaunchAtLoginManager.shared
        #expect(manager.isEnabled == (manager.status == .enabled))
    }

    /// statusが有効なSMAppService.Statusのいずれかであることを検証
    @Test func statusCanBeRead() {
        let status = LaunchAtLoginManager.shared.status
        let validStatuses: [SMAppService.Status] = [
            .enabled, .requiresApproval, .notRegistered, .notFound
        ]
        #expect(validStatuses.contains(status))
    }

    /// 未署名環境でtoggle()がエラーをスローすることを検証（テスト環境の制約確認）
    @Test func toggleThrowsWhenNotSigned() {
        // In test environment (unsigned), register() is expected to fail
        // Verify that toggle() propagates errors instead of silently swallowing them
        let manager = LaunchAtLoginManager.shared
        guard manager.status != .enabled else { return }
        #expect(throws: (any Error).self) { try manager.toggle() }
    }

    /// DI用の新しいインスタンスが作成できることを検証
    @Test func canCreateNewInstance() {
        let instance = LaunchAtLoginManager()
        #expect(instance !== LaunchAtLoginManager.shared)
    }

    /// isEnabledとstatusの関係が一貫していることを検証（環境非依存）
    @Test func isEnabledConsistentWithStatus() {
        let manager = LaunchAtLoginManager.shared
        if manager.status == .enabled {
            #expect(manager.isEnabled == true)
        } else {
            #expect(manager.isEnabled == false)
        }
    }
}
