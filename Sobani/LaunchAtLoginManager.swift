import ServiceManagement

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    private init() {}

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
