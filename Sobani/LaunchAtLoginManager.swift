import ServiceManagement
import os.log

@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    private let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: "LaunchAtLoginManager")
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
