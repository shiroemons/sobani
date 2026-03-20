import ServiceManagement

/// SMAppService の操作を抽象化するプロトコル（テストDI用）
protocol LoginItemService: Sendable {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

/// SMAppService.mainApp のデフォルト実装
extension SMAppService: LoginItemService {}

@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    private let service: LoginItemService

    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
    }

    var isEnabled: Bool {
        service.status == .enabled
    }

    func toggle() throws {
        if isEnabled {
            try service.unregister()
        } else {
            try service.register()
        }
    }

    var status: SMAppService.Status {
        service.status
    }
}
