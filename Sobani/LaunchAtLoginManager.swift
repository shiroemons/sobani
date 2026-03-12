import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    /// テストDI用。プロダクションコードでは `shared` を使用すること。
    init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func toggle() throws {
        if isEnabled {
            try SMAppService.mainApp.unregister()
        } else {
            try SMAppService.mainApp.register()
        }
    }

    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }
}
