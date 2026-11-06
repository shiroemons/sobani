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

    /// 登録サービスのエラーがsetEnabled()で伝播されることを検証
    @Test func setEnabledPropagatesRegistrationError() {
        let mock = MockLoginItemService(mockStatus: .notRegistered, shouldThrow: true)
        let manager = LaunchAtLoginManager(service: mock)
        #expect(throws: (any Error).self) { try manager.setEnabled(true) }
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

    /// setEnabled(true)が未登録時にregisterを呼ぶことを検証
    @Test func setEnabledTrueCallsRegister() throws {
        let mock = MockLoginItemService(mockStatus: .notRegistered)
        let manager = LaunchAtLoginManager(service: mock)
        try manager.setEnabled(true)
        #expect(mock.registerCalled)
        #expect(!mock.unregisterCalled)
    }

    /// すでに望む状態ならsetEnabledは何も呼ばないことを検証（反転操作による誤動作の防止）
    @Test(arguments: [(SMAppService.Status.enabled, true), (SMAppService.Status.notRegistered, false)])
    func setEnabledIsNoOpWhenAlreadyInState(status: SMAppService.Status, enabled: Bool) throws {
        let mock = MockLoginItemService(mockStatus: status)
        let manager = LaunchAtLoginManager(service: mock)
        try manager.setEnabled(enabled)
        #expect(!mock.registerCalled)
        #expect(!mock.unregisterCalled)
    }

    /// setEnabled(false)が有効時にunregisterを呼ぶことを検証
    @Test func setEnabledFalseCallsUnregister() throws {
        let mock = MockLoginItemService(mockStatus: .enabled)
        let manager = LaunchAtLoginManager(service: mock)
        try manager.setEnabled(false)
        #expect(mock.unregisterCalled)
        #expect(!mock.registerCalled)
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
