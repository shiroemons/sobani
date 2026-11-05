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

    var status: SMAppService.Status {
        service.status
    }

    /// ログイン時起動を指定の状態にする。すでにその状態なら何もしない。
    ///
    /// 現在の状態を反転する操作だと、システム設定側で変更された直後に UI と逆の結果になるため、
    /// 呼び出し側は「望む状態」を渡すこと。
    func setEnabled(_ enabled: Bool) throws {
        guard enabled != isEnabled else { return }
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    /// ユーザーの承認待ち（`.requiresApproval`）ならシステム設定のログイン項目を開く。
    /// - Returns: システム設定を開いたかどうか。
    @discardableResult
    func openSystemSettingsIfApprovalRequired() -> Bool {
        guard status == .requiresApproval else { return false }
        SMAppService.openSystemSettingsLoginItems()
        return true
    }
}
