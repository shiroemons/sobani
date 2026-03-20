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
        let instance = LaunchAtLoginManager(service: SMAppService.mainApp)
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

    // MARK: - DI Tests

    /// モックサービスでisEnabledがtrueを返すことを検証
    @Test func diMockServiceEnabled() {
        let mock = MockLoginItemService(mockStatus: .enabled)
        let manager = LaunchAtLoginManager(service: mock)
        #expect(manager.isEnabled)
        #expect(manager.status == .enabled)
    }

    /// モックサービスでisEnabledがfalseを返すことを検証
    @Test func diMockServiceNotRegistered() {
        let mock = MockLoginItemService(mockStatus: .notRegistered)
        let manager = LaunchAtLoginManager(service: mock)
        #expect(!manager.isEnabled)
        #expect(manager.status == .notRegistered)
    }

    /// モックサービスでtoggle()がregisterを呼ぶことを検証
    @Test func diMockServiceToggleCallsRegister() throws {
        let mock = MockLoginItemService(mockStatus: .notRegistered)
        let manager = LaunchAtLoginManager(service: mock)
        try manager.toggle()
        #expect(mock.registerCalled)
        #expect(!mock.unregisterCalled)
    }

    /// モックサービスでtoggle()がunregisterを呼ぶことを検証
    @Test func diMockServiceToggleCallsUnregister() throws {
        let mock = MockLoginItemService(mockStatus: .enabled)
        let manager = LaunchAtLoginManager(service: mock)
        try manager.toggle()
        #expect(mock.unregisterCalled)
        #expect(!mock.registerCalled)
    }

    /// モックサービスのエラーがtoggle()で伝播されることを検証
    @Test func diMockServiceToggleError() {
        let mock = MockLoginItemService(mockStatus: .notRegistered, shouldThrow: true)
        let manager = LaunchAtLoginManager(service: mock)
        #expect(throws: (any Error).self) { try manager.toggle() }
    }
}

/// テスト用のモックログインアイテムサービス
/// `@unchecked Sendable` は `@MainActor` テストスイート内でのみ使用すること。
/// 並行テストではレースコンディションのリスクがある。
final class MockLoginItemService: LoginItemService, @unchecked Sendable {
    let mockStatus: SMAppService.Status
    private let shouldThrow: Bool
    var registerCalled = false
    var unregisterCalled = false

    init(mockStatus: SMAppService.Status, shouldThrow: Bool = false) {
        self.mockStatus = mockStatus
        self.shouldThrow = shouldThrow
    }

    var status: SMAppService.Status {
        mockStatus
    }

    func register() throws {
        if shouldThrow { throw MockError.testError }
        registerCalled = true
    }

    func unregister() throws {
        if shouldThrow { throw MockError.testError }
        unregisterCalled = true
    }

    enum MockError: Error {
        case testError
    }
}
